//
//  SeriesRoundSyncService.swift
//  Hackers
//
//  Commissioner sync: push Series / SeriesRound state into an existing linked Round.
//

import Foundation

@MainActor
struct SeriesRoundSyncService: Loggable {

    func syncRoundFromSeries(
        series: Series,
        seriesRound: SeriesRound,
        membersByID: [String: SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        handicaps: [String: SeriesMemberHandicap],
        seriesMappings: [SeriesRoundMapping],
        snapshot: RoundSnapshot,
        roundStatus: RoundStatus,
        hostPlayerID: String?,
        options: SeriesRoundSyncOptions
    ) async -> Result<Void, SeriesRoundSyncError> {
        let startedAt = ContinuousClock.now
        defer {
            SeriesPerformanceRecorder.shared.record(
                .roundSync,
                startedAt: startedAt,
                itemCount: snapshot.participants.count,
                context: seriesRound.id
            )
        }
        guard options.hasAny else { return .success(()) }

        if let err = SeriesRoundSyncPlanning.validateOptions(options, roundStatus: roundStatus) {
            return .failure(err)
        }
        guard snapshot.participants.isPopulated else { return .failure(.noParticipants) }
        guard let courseSegment = snapshot.courseSegment else { return .failure(.missingCourseSegment) }

        let participatingMembers = SeriesRoundSyncPlanning.participatingMembersForSync(
            seriesRound: seriesRound,
            snapshot: snapshot,
            membersByID: membersByID
        )
        if (options.syncPlayerData || options.syncOrganization || options.syncPairs || options.syncMatchups),
           participatingMembers.isEmpty {
            return .failure(.noParticipants)
        }

        let teamLinks = SeriesRoundSyncPlanning.teamLinks(
            mappings: seriesMappings,
            seriesRoundID: seriesRound.id
        )
        let usesSeriesTeams = seriesRound.roundConfig.teamAssignmentMode == .seriesTeams
        let resolvedPlan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: seriesRound,
            members: participatingMembers,
            teams: teams,
            pods: pods,
            courseSegment: courseSegment
        )
        let plannedSeatsByMemberID = Dictionary(
            uniqueKeysWithValues: resolvedPlan.plannedStructure.teeGroups.flatMap(\.seats).map { ($0.memberID, $0) }
        )
        let seriesTeamsForRound = usesSeriesTeams ? resolvedPlan.seriesTeamsForRound : []
        let seriesTeamIDsForRound = Set(seriesTeamsForRound.map(\.id))
        let relevantTeamLinks = usesSeriesTeams
            ? SeriesRoundSyncPlanning.teamLinksForSync(
                seriesTeamsForRound: seriesTeamsForRound,
                existingLinks: teamLinks.filter { seriesTeamIDsForRound.contains($0.key) },
                roundID: snapshot.round.id
            )
            : [:]
        let partnershipPlans = SeriesRoundCreationMapping.resolvedPartnershipPlans(
            seriesRound: seriesRound,
            teams: teams,
            pods: pods,
            members: participatingMembers
        )

        if roundStatus == .lobby, options.syncOrganization {
            let presenceStatusByMemberID = Dictionary(
                uniqueKeysWithValues: participatingMembers.map { member in
                    let existing = snapshot.participants.first { $0.seriesMemberID == member.id }
                    return (member.id, existing?.presenceStatus ?? .active)
                }
            )
            do {
                let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
                    series: series,
                    seriesRound: seriesRound,
                    participatingMembers: participatingMembers,
                    teams: teams,
                    pods: pods,
                    handicaps: handicaps,
                    seriesMappings: seriesMappings,
                    snapshot: snapshot,
                    hostPlayerID: hostPlayerID,
                    presenceStatusByMemberID: presenceStatusByMemberID,
                    updateFormat: options.syncFormat,
                    pruneNonSeriesParticipants: true
                )
                if case .failure(let error) = await applyLobbyReconciliationPlan(plan) {
                    return .failure(error)
                }
                addSyncAppliedEvent(
                    series: series,
                    seriesRound: seriesRound,
                    roundID: snapshot.round.id,
                    roundStatus: roundStatus,
                    options: options
                )
                return .success(())
            } catch let err as SeriesRoundSyncError {
                return .failure(err)
            } catch {
                addBreadcrumb(level: .error, message: "series.round_sync lobby reconciliation failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        let memberAssignments: [String: SeriesRoundCreationMapping.MemberAssignment]
        let teeSchedulePlans: [SeriesRoundCreationMapping.TeeGroupPlan]
        if options.syncOrganization {
            do {
                let built = try SeriesRoundSyncPlanning.buildMemberAssignmentsForSync(
                    series: series,
                    snapshot: snapshot,
                    seriesRound: seriesRound,
                    participatingMembers: participatingMembers,
                    teams: teams,
                    pods: pods
                )
                memberAssignments = built.0
                teeSchedulePlans = built.1
            } catch let e as SeriesRoundSyncError {
                return .failure(e)
            } catch {
                return .failure(.writeFailed(error.localizedDescription))
            }
        } else {
            memberAssignments = Self.inferredAssignments(from: snapshot.participants)
            teeSchedulePlans = []
        }

        var workingParticipants = snapshot.participants
        var workingScoringGroups = snapshot.scoringGroups
        var workingTeeGroups = snapshot.teeGroups
        var workingRound = snapshot.round
        let desiredSubstitutesScore = seriesRound.policyBinding?.resolvedSubstitutesScore
            ?? series.settings.substitutesScore
        let desiredRoundName = Round.normalizedName(seriesRound.title)

        if workingRound.name != desiredRoundName {
            workingRound.name = desiredRoundName
            workingRound.lastUpdatedAt = .init()
            let roundToPut = await roundPreservingCurrentStatus(workingRound)
            switch await roundToPut.put() {
            case .success(let updated):
                workingRound = updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "series.round_sync name put failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncFormat {
            workingRound.configuration = resolvedPlan.roundConfiguration
                .preservingRoundLocalStablefordPoints(from: workingRound.configuration)
            workingRound.lastUpdatedAt = .init()
            let roundToPut = await roundPreservingCurrentStatus(workingRound)
            switch await roundToPut.put() {
            case .success(let updated):
                workingRound = updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "series.round_sync format put failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncHandicapSettings {
            let resolvedHandicapEntryFormat: HandicapEntryFormat = seriesRound.roundConfig.handicapEntryFormat == .courseHandicap
                && !HandicapCalculator.hasCourseHandicapData(courseSegment: courseSegment)
                ? .strokes
                : seriesRound.roundConfig.handicapEntryFormat
            workingRound.configuration.handicapsEnabled = resolvedPlan.roundConfiguration.useHandicaps
            workingRound.configuration.handicapEntryFormat = resolvedHandicapEntryFormat
            workingRound.configuration.handicapNormalizationMode = seriesRound.roundConfig.handicapNormalizationMode
            workingRound.configuration.handicapStrokeBasis = seriesRound.roundConfig.handicapStrokeBasis
            workingRound.configuration.leagueHandicapMaximum = series.handicapConfig.isEnabled
                ? series.handicapConfig.config.maximumHandicap
                : nil
            workingRound.configuration.substitutesScore = desiredSubstitutesScore
            workingRound.lastUpdatedAt = .init()
            let roundToPut = await roundPreservingCurrentStatus(workingRound)
            switch await roundToPut.put() {
            case .success(let updated):
                workingRound = updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "series.round_sync handicap settings put failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if !options.syncFormat,
           !options.syncHandicapSettings,
           (options.syncPlayerData || options.syncOrganization),
           (workingRound.configuration.handicapStrokeBasis != seriesRound.roundConfig.handicapStrokeBasis
            || workingRound.configuration.substitutesScore != desiredSubstitutesScore) {
            if workingRound.configuration.handicapStrokeBasis != seriesRound.roundConfig.handicapStrokeBasis {
                workingRound.configuration.handicapStrokeBasis = seriesRound.roundConfig.handicapStrokeBasis
            }
            if workingRound.configuration.substitutesScore != desiredSubstitutesScore {
                workingRound.configuration.substitutesScore = desiredSubstitutesScore
            }
            workingRound.lastUpdatedAt = .init()
            let roundToPut = await roundPreservingCurrentStatus(workingRound)
            switch await roundToPut.put() {
            case .success(let updated):
                workingRound = updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "series.round_sync handicap basis put failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncOrganization {
            do {
                let patchedTeams = try SeriesRoundSyncPlanning.roundTeamsPatch(
                    seriesTeamsForRound: seriesTeamsForRound,
                    teamLinks: relevantTeamLinks,
                    snapshot: snapshot
                )
                for team in patchedTeams {
                    if case .failure(let error) = await team.put() {
                        addBreadcrumb(level: .error, message: "series.round_sync team put failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }

                let updatedTeeGroups = try SeriesRoundSyncPlanning.teeGroupsWithLeagueSchedule(
                    snapshot: snapshot,
                    groupPlans: teeSchedulePlans,
                    plannedTeeGroups: resolvedPlan.plannedStructure.teeGroups,
                    seriesRound: seriesRound
                )
                for group in updatedTeeGroups {
                    if case .failure(let error) = await group.put() {
                        addBreadcrumb(level: .error, message: "series.round_sync tee group put failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }

                workingParticipants = SeriesRoundSyncPlanning.participantsWithOrganizationSync(
                    participants: workingParticipants.filter { participant in
                        guard let memberID = participant.seriesMemberID else { return false }
                        return participatingMembers.contains { $0.id == memberID }
                    },
                    participatingMembers: participatingMembers,
                    teamLinks: relevantTeamLinks,
                    memberAssignments: memberAssignments,
                    plannedSeatsByMemberID: plannedSeatsByMemberID,
                    usesSeriesTeams: usesSeriesTeams
                )
                let existingMemberIDs = Set(workingParticipants.compactMap(\.seriesMemberID))
                let missingMembers = participatingMembers.filter { !existingMemberIDs.contains($0.id) }
                if missingMembers.isPopulated {
                    let newParticipants = SeriesRoundCreationMapping.buildParticipantPayloads(
                        members: missingMembers,
                        roundID: snapshot.round.id,
                        teamMappings: relevantTeamLinks,
                        memberAssignments: memberAssignments,
                        handicaps: handicaps,
                        maximumHandicap: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
                        courseSegment: courseSegment,
                        handicapEntryFormat: workingRound.configuration.handicapEntryFormat,
                        handicapStrokeBasis: workingRound.configuration.handicapStrokeBasis,
                        hostPlayerID: hostPlayerID,
                        plannedSeatsByMemberID: plannedSeatsByMemberID
                    )
                    workingParticipants.append(contentsOf: newParticipants)
                }
                let targetMemberIDs = Set(participatingMembers.map(\.id))
                let participantsToDelete = snapshot.participants.filter { participant in
                    guard let memberID = participant.seriesMemberID else { return true }
                    return !targetMemberIDs.contains(memberID)
                }
                for participant in participantsToDelete {
                    if case .failure(let error) = await participant.delete() {
                        addBreadcrumb(level: .error, message: "series.round_sync participant prune failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }

                let populatedTeeGroupIDs = Set(workingParticipants.compactMap(\.groupID).filter(\.isPopulated))
                let retainedTeeGroups = updatedTeeGroups.filter { populatedTeeGroupIDs.contains($0.id) }
                workingTeeGroups = retainedTeeGroups
                let desiredTeeGroupIDs = Set(updatedTeeGroups.map(\.id))
                let teeGroupsToDelete = snapshot.teeGroups.filter { group in
                    !desiredTeeGroupIDs.contains(group.id) || !populatedTeeGroupIDs.contains(group.id)
                } + updatedTeeGroups.filter { !populatedTeeGroupIDs.contains($0.id) }
                var deletedTeeGroupIDs = Set<String>()
                for group in teeGroupsToDelete where !deletedTeeGroupIDs.contains(group.id) {
                    deletedTeeGroupIDs.insert(group.id)
                    if case .failure(let error) = await group.delete() {
                        addBreadcrumb(level: .error, message: "series.round_sync tee group prune failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }

                let populatedTeamIDs = Set(workingParticipants.compactMap(\.teamID).filter(\.isPopulated))
                for team in snapshot.teams where !populatedTeamIDs.contains(team.id) {
                    if case .failure(let error) = await team.delete() {
                        addBreadcrumb(level: .error, message: "series.round_sync team prune failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }
            } catch let err as SeriesRoundSyncError {
                return .failure(err)
            } catch {
                addBreadcrumb(level: .error, message: "series.round_sync organization failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncOrganization {
            guard let existingSegment = snapshot.roundSegment else {
                return .failure(.missingCourseSegment)
            }
            let scoringGroupSeriesRound = options.syncFormat
                ? seriesRound
                : SeriesRoundSyncPlanning.scoringSeriesRoundForExistingRound(
                    seriesRound,
                    roundConfiguration: workingRound.configuration,
                    existingSegment: existingSegment
                )
            let patch = SeriesRoundSyncPlanning.teeGroupScoringGroupPatch(
                roundID: snapshot.round.id,
                seriesRound: scoringGroupSeriesRound,
                participants: workingParticipants,
                partnershipPlans: partnershipPlans,
                teeGroups: workingTeeGroups.sorted { $0.index < $1.index },
                existingScoringGroups: workingScoringGroups
            )

            for group in patch.scoringGroupsToDelete {
                if case .failure(let error) = await group.delete() {
                    addBreadcrumb(level: .error, message: "series.round_sync tee scoring group delete failed", error: error)
                    return .failure(.writeFailed(error.localizedDescription))
                }
            }

            if patch.scoringGroupsToPut.isPopulated {
                if case .failure(let error) = await Self.batchPutSubcollection(patch.scoringGroupsToPut) {
                    addBreadcrumb(level: .error, message: "series.round_sync tee scoring groups batch failed", error: error)
                    return .failure(.writeFailed(error.localizedDescription))
                }
            }
            workingScoringGroups = patch.mergedScoringGroups
        }

        if options.syncPairs {
            let patch = SeriesRoundSyncPlanning.partnershipScoringGroupPatch(
                roundID: snapshot.round.id,
                seriesRound: seriesRound,
                participants: workingParticipants,
                partnershipPlans: partnershipPlans,
                teeGroups: workingTeeGroups.sorted { $0.index < $1.index },
                existingScoringGroups: workingScoringGroups
            )

            for group in patch.scoringGroupsToDelete {
                if case .failure(let error) = await group.delete() {
                    addBreadcrumb(level: .error, message: "series.round_sync scoring group delete failed", error: error)
                    return .failure(.writeFailed(error.localizedDescription))
                }
            }

            if patch.scoringGroupsToPut.isPopulated {
                if case .failure(let error) = await Self.batchPutSubcollection(patch.scoringGroupsToPut) {
                    addBreadcrumb(level: .error, message: "series.round_sync scoring groups batch failed", error: error)
                    return .failure(.writeFailed(error.localizedDescription))
                }
            }
            workingScoringGroups = patch.mergedScoringGroups
        }

        if options.syncOrganization || options.syncPairs {
            await replaceMappings(
                seriesID: series.id,
                seriesRoundID: seriesRound.id,
                teamLinks: relevantTeamLinks,
                participatingMembers: participatingMembers,
                participants: workingParticipants,
                scoringGroups: workingScoringGroups
            )
        }

        if options.syncFormat || options.syncOrganization || options.syncPairs || options.syncMatchups {
            guard var mainSegment = snapshot.roundSegment else {
                return .failure(.missingCourseSegment)
            }
            let scoringSeriesRound = options.syncFormat
                ? seriesRound
                : SeriesRoundSyncPlanning.scoringSeriesRoundForExistingRound(
                    seriesRound,
                    roundConfiguration: workingRound.configuration,
                    existingSegment: mainSegment
                )
            mainSegment = SeriesRoundSyncPlanning.buildUpdatedSegment(
                series: series,
                seriesRound: seriesRound,
                scoringSeriesRound: scoringSeriesRound,
                courseSegment: courseSegment,
                participants: workingParticipants,
                scoringGroups: workingScoringGroups,
                existingSegment: mainSegment,
                teams: teams,
                pods: pods,
                participatingMembers: participatingMembers,
                teamLinks: relevantTeamLinks,
                updateFormat: options.syncFormat,
                updateScoringUnits: options.syncFormat || options.syncOrganization || options.syncPairs,
                updateMatchups: options.syncMatchups
            )
            if case .failure(let error) = await mainSegment.put() {
                addBreadcrumb(level: .error, message: "series.round_sync segment put failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncPlayerData {
            workingParticipants = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
                participants: workingParticipants,
                roundID: snapshot.round.id,
                participatingMembers: participatingMembers,
                teamLinks: teamLinks,
                memberAssignments: memberAssignments,
                handicaps: handicaps,
                maximumHandicap: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
                courseSegment: courseSegment,
                handicapEntryFormat: workingRound.configuration.handicapEntryFormat,
                handicapStrokeBasis: workingRound.configuration.handicapStrokeBasis,
                hostPlayerID: hostPlayerID,
                plannedSeatsByMemberID: plannedSeatsByMemberID,
                preserveManualHandicapEdits: options.preserveManualHandicapEdits
            )
        }

        if options.syncHandicapSettings && !options.syncPlayerData {
            workingParticipants = workingParticipants.map { existing in
                guard let memberID = existing.seriesMemberID else { return existing }
                if options.preserveManualHandicapEdits, existing.isLeagueHandicapModifiedFromCreation {
                    guard workingRound.configuration.handicapEntryFormat == .courseHandicap,
                          existing.handicapIndex == nil,
                          let effectiveIndex = handicaps[memberID]?.effectiveIndex else {
                        return existing
                    }
                    var preserved = existing
                    preserved.handicapIndex = effectiveIndex
                    preserved.lastUpdatedAt = .init()
                    return preserved
                }
                let input = handicaps[memberID]?.effectiveIndex
                    ?? existing.handicapIndex
                    ?? Double(existing.originalHandicap)
                var next = HandicapCalculator.participant(
                    existing,
                    applying: input,
                    format: workingRound.configuration.handicapEntryFormat,
                    courseSegment: courseSegment,
                    maximumHandicap: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
                    handicapStrokeBasis: workingRound.configuration.resolvedHandicapStrokeBasis(
                        holeCount: courseSegment.holeSegment.holeCount
                    )
                )
                next.leagueHandicapStrokesAtCreation = next.adjustedHandicap
                next.lastUpdatedAt = .init()
                return next
            }
        }

        if options.syncPlayerData || options.syncOrganization || options.syncHandicapSettings {
            if case .failure(let error) = await Self.batchPutSubcollection(workingParticipants) {
                addBreadcrumb(level: .error, message: "series.round_sync participants batch failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncPlayerData || options.syncOrganization {
            let nextPlayerIDs = workingParticipants.compactMap(\.playerID)
            let nextTeeGroupSummaries = Round.teeGroupDisplayNamesByPlayerID(from: workingParticipants)
            if workingRound.players != nextPlayerIDs || workingRound.teeGroupDisplayNamesByPlayerID != nextTeeGroupSummaries {
                workingRound.players = nextPlayerIDs
                workingRound.teeGroupDisplayNamesByPlayerID = nextTeeGroupSummaries
                workingRound.lastUpdatedAt = .init()
                let roundToPut = await roundPreservingCurrentStatus(workingRound)
                switch await roundToPut.put() {
                case .success(let updated):
                    workingRound = updated
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "series.round_sync round players put failed", error: error)
                    return .failure(.writeFailed(error.localizedDescription))
                }
            }
        }

        addSyncAppliedEvent(
            series: series,
            seriesRound: seriesRound,
            roundID: snapshot.round.id,
            roundStatus: roundStatus,
            options: options
        )
        return .success(())
    }

    private func applyLobbyReconciliationPlan(
        _ plan: SeriesRoundSyncPlanning.LobbyAttendancePlan
    ) async -> Result<Void, SeriesRoundSyncError> {
        let roundToPut = await roundPreservingCurrentStatus(plan.round)
        switch await roundToPut.put() {
        case .success:
            break
        case .failure(let error):
            addBreadcrumb(level: .error, message: "series.round_sync lobby round put failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }

        for item in plan.teeGroupsToDelete {
            if case .failure(let error) = await item.delete() {
                addBreadcrumb(level: .error, message: "series.round_sync lobby tee group delete failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }
        for item in plan.teamsToDelete {
            if case .failure(let error) = await item.delete() {
                addBreadcrumb(level: .error, message: "series.round_sync lobby team delete failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }
        for item in plan.scoringGroupsToDelete {
            if case .failure(let error) = await item.delete() {
                addBreadcrumb(level: .error, message: "series.round_sync lobby scoring group delete failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }
        for item in plan.participantsToDelete {
            if case .failure(let error) = await item.delete() {
                addBreadcrumb(level: .error, message: "series.round_sync lobby participant delete failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }
        for item in plan.mappingsToDelete {
            if case .failure(let error) = await item.delete() {
                addBreadcrumb(level: .error, message: "series.round_sync lobby mapping delete failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if case .failure(let error) = await Self.batchPutSubcollection(plan.teeGroupsToPut) {
            addBreadcrumb(level: .error, message: "series.round_sync lobby tee groups batch failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }
        if case .failure(let error) = await Self.batchPutSubcollection(plan.teamsToPut) {
            addBreadcrumb(level: .error, message: "series.round_sync lobby teams batch failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }
        if case .failure(let error) = await Self.batchPutSubcollection(plan.participantsToPut) {
            addBreadcrumb(level: .error, message: "series.round_sync lobby participants batch failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }
        if case .failure(let error) = await Self.batchPutSubcollection(plan.scoringGroupsToPut) {
            addBreadcrumb(level: .error, message: "series.round_sync lobby scoring groups batch failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }
        if case .failure(let error) = await Self.batchPutSubcollection(plan.mappingsToPut) {
            addBreadcrumb(level: .error, message: "series.round_sync lobby mappings batch failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }

        if case .failure(let error) = await plan.segment.put() {
            addBreadcrumb(level: .error, message: "series.round_sync lobby segment put failed", error: error)
            return .failure(.writeFailed(error.localizedDescription))
        }
        return .success(())
    }

    private func addSyncAppliedEvent(
        series: Series,
        seriesRound: SeriesRound,
        roundID: String,
        roundStatus: RoundStatus,
        options: SeriesRoundSyncOptions
    ) {
        addEvent(
            "series.round_sync_applied",
            eventProps: [
                "series_id": series.id,
                "series_round_id": seriesRound.id,
                "round_id": roundID,
                "sync_player": options.syncPlayerData,
                "sync_format": options.syncFormat,
                "sync_organization": options.syncOrganization,
                "sync_pairs": options.syncPairs,
                "sync_matchups": options.syncMatchups,
                "sync_handicap_settings": options.syncHandicapSettings,
                "round_status": roundStatus.rawValue
            ]
        )
    }

    private func roundPreservingCurrentStatus(_ round: Round) async -> Round {
        var next = round
        switch await FirebaseService.shared.getRoundDocument(byID: round.id) {
        case .success(let current):
            if Self.shouldPreserveCurrentRoundStatus(candidate: next.status, current: current.status) {
                next.status = current.status
            }
        case .failure(let error):
            addBreadcrumb(level: .error, message: "series.round_sync could not refresh round status before put", error: error)
        }
        return next
    }

    nonisolated static func shouldPreserveCurrentRoundStatus(
        candidate: RoundStatus,
        current: RoundStatus
    ) -> Bool {
        candidate == .lobby && (current == .live || current == .paused || current == .complete)
    }

    private static func inferredAssignments(
        from participants: [RoundParticipant]
    ) -> [String: SeriesRoundCreationMapping.MemberAssignment] {
        var dict: [String: SeriesRoundCreationMapping.MemberAssignment] = [:]
        for p in participants {
            guard let mid = p.seriesMemberID, let gid = p.groupID, let order = p.teeOrder else { continue }
            dict[mid] = SeriesRoundCreationMapping.MemberAssignment(groupID: gid, teeOrder: order)
        }
        return dict
    }

    private static func batchPutSubcollection<T: FirebaseSubcollectable>(
        _ items: [T],
        chunkSize: Int = 400
    ) async -> Result<Void, Error> {
        guard !items.isEmpty else { return .success(()) }
        var offset = 0
        while offset < items.count {
            let end = min(offset + chunkSize, items.count)
            let chunk = Array(items[offset..<end])
            switch await chunk.batchPut() {
            case .failure(let error):
                return .failure(error)
            case .success:
                break
            }
            offset = end
        }
        return .success(())
    }

    private func replaceMappings(
        seriesID: String,
        seriesRoundID: String,
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        participatingMembers: [SeriesMember],
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup]
    ) async {
        var newMappings: [SeriesRoundMapping] = []
        let participantByMemberID = Dictionary(uniqueKeysWithValues: participants.compactMap { p -> (String, RoundParticipant)? in
            guard let m = p.seriesMemberID else { return nil }
            return (m, p)
        })

        for member in participatingMembers {
            guard let participant = participantByMemberID[member.id] else { continue }
            newMappings.append(
                SeriesRoundCreationMapping.seriesRoundParticipantMapping(
                    seriesRoundID: seriesRoundID,
                    seriesID: seriesID,
                    memberID: member.id,
                    participantID: participant.id
                )
            )
        }

        for link in teamLinks.values {
            newMappings.append(
                SeriesRoundCreationMapping.seriesRoundTeamMapping(
                    seriesRoundID: seriesRoundID,
                    seriesID: seriesID,
                    link: link
                )
            )
        }

        for scoringGroup in scoringGroups {
            newMappings.append(
                contentsOf: SeriesRoundCreationMapping.seriesRoundScoreOwnerMappings(
                    seriesRoundID: seriesRoundID,
                    seriesID: seriesID,
                    scoringGroup: scoringGroup,
                    participants: participants,
                    teamMappings: teamLinks
                )
            )
        }

        let existing = await FirebaseService.shared.fetchSeriesRoundMappings(
            seriesID: seriesID,
            seriesRoundID: seriesRoundID
        )
        let newIDs = Set(newMappings.map(\.id))
        for old in existing where !newIDs.contains(old.id) {
            _ = await old.delete()
        }

        if newMappings.isPopulated {
            _ = await Self.batchPutSubcollection(newMappings)
        }
    }
}
