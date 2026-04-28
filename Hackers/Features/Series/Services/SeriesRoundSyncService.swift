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
        guard options.hasAny else { return .success(()) }

        if let err = SeriesRoundSyncPlanning.validateOptions(options, roundStatus: roundStatus) {
            return .failure(err)
        }
        if options.syncOrganization, roundStatus == .live || roundStatus == .paused {
            return .failure(.organizationNotAllowedLive)
        }
        guard snapshot.participants.isPopulated else { return .failure(.noParticipants) }
        guard let courseSegment = snapshot.courseSegment else { return .failure(.missingCourseSegment) }

        let participatingMembers = SeriesRoundSyncPlanning.participatingMembers(
            snapshot: snapshot,
            membersByID: membersByID
        )
        if (options.syncPlayerData || options.syncOrganization), participatingMembers.isEmpty {
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
        let seriesTeamsForRound = usesSeriesTeams ? resolvedPlan.seriesTeamsForRound : []
        let seriesTeamIDsForRound = Set(seriesTeamsForRound.map(\.id))
        let relevantTeamLinks = teamLinks.filter { seriesTeamIDsForRound.contains($0.key) }
        if options.syncOrganization,
           let preflightError = SeriesRoundSyncPlanning.organizationTeamMappingPreflightError(
                seriesTeamsForRound: seriesTeamsForRound,
                teamLinks: teamLinks,
                snapshot: snapshot
           ) {
            return .failure(preflightError)
        }
        let partnershipPlans = SeriesRoundCreationMapping.resolvedPartnershipPlans(
            seriesRound: seriesRound,
            teams: teams,
            pods: pods,
            members: participatingMembers
        )

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
        var workingRound = snapshot.round

        if options.syncFormat {
            workingRound.configuration = resolvedPlan.roundConfiguration
            workingRound.lastUpdatedAt = .init()
            switch await workingRound.put() {
            case .success(let updated):
                workingRound = updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "series.round_sync format put failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if !options.syncFormat,
           (options.syncPlayerData || options.syncOrganization),
           workingRound.configuration.handicapStrokeBasis != series.handicapConfig.strokeBasis {
            workingRound.configuration.handicapStrokeBasis = series.handicapConfig.strokeBasis
            workingRound.lastUpdatedAt = .init()
            switch await workingRound.put() {
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
                    seriesRound: seriesRound
                )
                for group in updatedTeeGroups {
                    if case .failure(let error) = await group.put() {
                        addBreadcrumb(level: .error, message: "series.round_sync tee group put failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }

                workingParticipants = SeriesRoundSyncPlanning.participantsWithOrganizationSync(
                    participants: workingParticipants,
                    participatingMembers: participatingMembers,
                    teamLinks: relevantTeamLinks,
                    memberAssignments: memberAssignments,
                    usesSeriesTeams: usesSeriesTeams
                )

                let populatedTeeGroupIDs = Set(workingParticipants.compactMap(\.groupID).filter(\.isPopulated))
                let retainedTeeGroups = updatedTeeGroups.filter { populatedTeeGroupIDs.contains($0.id) }
                for group in updatedTeeGroups where !populatedTeeGroupIDs.contains(group.id) {
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

                let sortedTeeGroups = retainedTeeGroups.sorted { $0.index < $1.index }
                let builtGroups = SeriesRoundCreationMapping.buildRoundScoringGroups(
                    roundID: snapshot.round.id,
                    seriesRound: seriesRound,
                    participants: workingParticipants,
                    partnershipPlans: partnershipPlans,
                    teeGroups: sortedTeeGroups
                )

                let existingByID = Dictionary(uniqueKeysWithValues: snapshot.scoringGroups.map { ($0.id, $0) })
                let nextByID = Dictionary(uniqueKeysWithValues: builtGroups.map { ($0.id, $0) })
                let removed = snapshot.scoringGroups.filter { nextByID[$0.id] == nil }
                for group in removed {
                    if case .failure(let error) = await group.delete() {
                        addBreadcrumb(level: .error, message: "series.round_sync scoring group delete failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }

                let mergedGroups = builtGroups.map { group -> RoundScoringGroup in
                    var g = group
                    if let old = existingByID[group.id] {
                        g.createdAt = old.createdAt
                    }
                    g.parentID = snapshot.round.id
                    g.lastUpdatedAt = .init()
                    return g
                }

                if mergedGroups.isPopulated {
                    if case .failure(let error) = await Self.batchPutSubcollection(mergedGroups) {
                        addBreadcrumb(level: .error, message: "series.round_sync scoring groups batch failed", error: error)
                        return .failure(.writeFailed(error.localizedDescription))
                    }
                }
                workingScoringGroups = mergedGroups

                await replaceMappings(
                    seriesID: series.id,
                    seriesRoundID: seriesRound.id,
                    teamLinks: relevantTeamLinks,
                    participatingMembers: participatingMembers,
                    participants: workingParticipants,
                    scoringGroups: workingScoringGroups
                )
            } catch let err as SeriesRoundSyncError {
                return .failure(err)
            } catch {
                addBreadcrumb(level: .error, message: "series.round_sync organization failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        if options.syncFormat || options.syncOrganization {
            guard var mainSegment = snapshot.roundSegment else {
                return .failure(.missingCourseSegment)
            }
            mainSegment = SeriesRoundSyncPlanning.buildUpdatedSegment(
                series: series,
                seriesRound: seriesRound,
                courseSegment: courseSegment,
                participants: workingParticipants,
                scoringGroups: workingScoringGroups,
                existingSegment: mainSegment,
                teams: teams,
                pods: pods,
                participatingMembers: participatingMembers,
                teamLinks: relevantTeamLinks
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
                hostPlayerID: hostPlayerID,
                preserveManualHandicapEdits: options.preserveManualHandicapEdits
            )
        }

        if options.syncPlayerData || options.syncOrganization {
            if case .failure(let error) = await Self.batchPutSubcollection(workingParticipants) {
                addBreadcrumb(level: .error, message: "series.round_sync participants batch failed", error: error)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        addEvent(
            "series.round_sync_applied",
            eventProps: [
                "series_id": series.id,
                "series_round_id": seriesRound.id,
                "round_id": snapshot.round.id,
                "sync_player": options.syncPlayerData,
                "sync_format": options.syncFormat,
                "sync_organization": options.syncOrganization,
                "round_status": roundStatus.rawValue
            ]
        )
        return .success(())
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
