//
//  SeriesRoundSyncPlanning.swift
//  Hackers
//
//  Pure planning/diff helpers for syncing a linked live Round from Series state.
//

import Foundation

struct SeriesRoundSyncOptions: Equatable, Sendable {
    var syncPlayerData: Bool = false
    var syncFormat: Bool = false
    var syncOrganization: Bool = false
    var syncPairs: Bool = false
    var syncMatchups: Bool = false
    var syncHandicapSettings: Bool = false
    var preserveManualHandicapEdits: Bool = false

    var hasAny: Bool {
        syncPlayerData || syncFormat || syncOrganization || syncPairs || syncMatchups || syncHandicapSettings
    }
}

enum SeriesRoundSyncError: Error, Equatable, LocalizedError {
    case roundNotLinked
    case missingCourseSegment
    case noParticipants
    case optionsDisallowedForRoundStatus
    case organizationTeeGroupCountMismatch(expected: Int, actual: Int)
    case organizationSeriesTeamMappingMismatch
    case organizationNotAllowedLive
    case preflightFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .roundNotLinked:
            return "This league round is not linked to a live round."
        case .missingCourseSegment:
            return "The live round has no course segment to sync against."
        case .noParticipants:
            return "The live round has no participants."
        case .optionsDisallowedForRoundStatus:
            return "These sync options are not allowed for the round’s current status."
        case .organizationTeeGroupCountMismatch(let expected, let actual):
            return "Tee group count mismatch: league expects \(expected) groups but the round has \(actual). Fix tee groups or cancel sync."
        case .organizationSeriesTeamMappingMismatch:
            return "Series team ↔ round team mappings are missing or incomplete."
        case .organizationNotAllowedLive:
            return "Organization sync is not allowed while the round is live."
        case .preflightFailed(let detail):
            return detail
        case .writeFailed(let detail):
            return detail
        }
    }
}

enum SeriesRoundSyncPlanning {
    struct OrganizationPrunePlan {
        var teeGroupsToDelete: [TeeTimeGroup] = []
        var teamsToDelete: [RoundTeam] = []
        var scoringGroupsToDelete: [RoundScoringGroup] = []
        var retainedMatchups: [TeamMatchup] = []
        var didPruneMatchups: Bool = false

        var hasDeletes: Bool {
            teeGroupsToDelete.isPopulated || teamsToDelete.isPopulated || scoringGroupsToDelete.isPopulated
        }

        var hasAny: Bool { hasDeletes || didPruneMatchups }
    }

    struct LobbyAttendancePlan {
        var round: Round
        var teeGroupsToPut: [TeeTimeGroup]
        var teeGroupsToDelete: [TeeTimeGroup]
        var teamsToPut: [RoundTeam]
        var teamsToDelete: [RoundTeam]
        var participantsToPut: [RoundParticipant]
        var participantsToDelete: [RoundParticipant]
        var scoringGroupsToPut: [RoundScoringGroup]
        var scoringGroupsToDelete: [RoundScoringGroup]
        var segment: RoundSegment
        var mappingsToPut: [SeriesRoundMapping]
        var mappingsToDelete: [SeriesRoundMapping]
    }

    static func organizationPrunePlan(
        snapshot: RoundSnapshot,
        matchups: [TeamMatchup]? = nil
    ) -> OrganizationPrunePlan {
        let participantIDs = Set(snapshot.participants.map(\.id))
        let activeParticipantIDs = Set(snapshot.participants.filter(\.isPresenceActive).map(\.id))
        let populatedTeeGroupIDs = Set(snapshot.participants.compactMap(\.groupID).filter(\.isPopulated))
        let populatedTeamIDs = Set(snapshot.participants.compactMap(\.teamID).filter(\.isPopulated))

        let scoringGroupsToDelete = snapshot.scoringGroups.filter { group in
            group.memberIDs.filter(participantIDs.contains).isEmpty
        }
        let deletedScoringGroupIDs = Set(scoringGroupsToDelete.map(\.id))
        let retainedScoringGroups = snapshot.scoringGroups.filter { !deletedScoringGroupIDs.contains($0.id) }

        let retainedScoringGroupIDsWithActivePlayers = Set(retainedScoringGroups.compactMap { group -> String? in
            group.memberIDs.contains(where: activeParticipantIDs.contains) ? group.id : nil
        })
        let activeTeamIDs = Set(snapshot.participants.compactMap { participant -> String? in
            guard participant.isPresenceActive, let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return teamID
        })

        let currentMatchups = matchups ?? snapshot.roundSegment?.matchups ?? []
        let retainedMatchups = currentMatchups.filter { matchup in
            guard matchup.isValid else { return false }
            switch matchup.effectiveMode {
            case .team:
                return matchup.teamIDs.allSatisfy(activeTeamIDs.contains)
            case .individual:
                return (matchup.participantIDs ?? []).allSatisfy(activeParticipantIDs.contains)
            case .partnership, .teeGroup, .scoreOwner:
                return (matchup.scoreOwnerIDs ?? []).allSatisfy(retainedScoringGroupIDsWithActivePlayers.contains)
            }
        }

        return OrganizationPrunePlan(
            teeGroupsToDelete: snapshot.teeGroups.filter { !populatedTeeGroupIDs.contains($0.id) },
            teamsToDelete: snapshot.teams.filter { !populatedTeamIDs.contains($0.id) },
            scoringGroupsToDelete: scoringGroupsToDelete,
            retainedMatchups: retainedMatchups,
            didPruneMatchups: retainedMatchups.count != currentMatchups.count
        )
    }

    /// Team links keyed by **series** team id (from `SeriesRoundMapping`).
    static func teamLinks(
        mappings: [SeriesRoundMapping],
        seriesRoundID: String
    ) -> [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] {
        var result: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [:]
        for m in mappings where m.seriesRoundID == seriesRoundID && m.roundOwnerType == .team && m.competitorType == .team {
            result[m.competitorID] = SeriesRoundCreationMapping.SeriesToRoundTeamLink(
                seriesTeamID: m.competitorID,
                roundTeamID: m.roundOwnerID
            )
        }
        return result
    }

    /// Members aligned to `snapshot.participants` order (series players on the round).
    static func participatingMembers(
        snapshot: RoundSnapshot,
        membersByID: [String: SeriesMember]
    ) -> [SeriesMember] {
        snapshot.participants.compactMap { p in
            guard let sid = p.seriesMemberID else { return nil }
            return membersByID[sid]
        }
    }

    static func validateOptions(
        _ options: SeriesRoundSyncOptions,
        roundStatus: RoundStatus
    ) -> SeriesRoundSyncError? {
        guard options.hasAny else { return nil }
        switch roundStatus {
        case .complete, .archived:
            return .optionsDisallowedForRoundStatus
        case .live, .paused:
            if options.syncFormat || options.syncOrganization {
                return .optionsDisallowedForRoundStatus
            }
            return nil
        case .lobby:
            return nil
        }
    }

    static func partnershipScoringGroupPatch(
        roundID: String,
        seriesRound: SeriesRound,
        participants: [RoundParticipant],
        partnershipPlans: [SeriesRoundPartnershipPlan],
        teeGroups: [TeeTimeGroup],
        existingScoringGroups: [RoundScoringGroup]
    ) -> (
        mergedScoringGroups: [RoundScoringGroup],
        scoringGroupsToPut: [RoundScoringGroup],
        scoringGroupsToDelete: [RoundScoringGroup]
    ) {
        let builtPartnershipGroups = SeriesRoundCreationMapping.buildRoundScoringGroups(
            roundID: roundID,
            seriesRound: seriesRound,
            participants: participants,
            partnershipPlans: partnershipPlans,
            teeGroups: teeGroups
        )
        .filter { $0.kind == .partnership }

        let existingPartnershipGroups = existingScoringGroups.filter { $0.kind == .partnership }
        let existingPartnershipByID = Dictionary(uniqueKeysWithValues: existingPartnershipGroups.map { ($0.id, $0) })
        let nextByID = Dictionary(uniqueKeysWithValues: builtPartnershipGroups.map { ($0.id, $0) })
        let scoringGroupsToDelete = existingPartnershipGroups.filter { nextByID[$0.id] == nil }
        let scoringGroupsToPut = builtPartnershipGroups.map { group -> RoundScoringGroup in
            var next = group
            if let old = existingPartnershipByID[group.id] {
                next.createdAt = old.createdAt
            }
            next.parentID = roundID
            next.lastUpdatedAt = .init()
            return next
        }

        return (
            mergedScoringGroups: existingScoringGroups.filter { $0.kind != .partnership } + scoringGroupsToPut,
            scoringGroupsToPut: scoringGroupsToPut,
            scoringGroupsToDelete: scoringGroupsToDelete
        )
    }

    static func buildMemberAssignmentsForSync(
        series: Series,
        snapshot: RoundSnapshot,
        seriesRound: SeriesRound,
        participatingMembers: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod]
    ) throws -> ([String: SeriesRoundCreationMapping.MemberAssignment], [SeriesRoundCreationMapping.TeeGroupPlan]) {
        guard let courseSegment = snapshot.courseSegment else {
            throw SeriesRoundSyncError.missingCourseSegment
        }
        let resolvedPlan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: seriesRound,
            members: participatingMembers,
            teams: teams,
            pods: pods,
            courseSegment: courseSegment
        )
        let groupPlans = resolvedPlan.teeGroupPlans
        let sortedTeeGroups = snapshot.teeGroups.sorted { $0.index < $1.index }
        let effectivePlans: [SeriesRoundCreationMapping.TeeGroupPlan] = groupPlans.isPopulated
            ? groupPlans
            : [SeriesRoundCreationMapping.TeeGroupPlan(id: "group_0", memberIDs: [])]

        guard effectivePlans.count == sortedTeeGroups.count else {
            throw SeriesRoundSyncError.organizationTeeGroupCountMismatch(
                expected: effectivePlans.count,
                actual: sortedTeeGroups.count
            )
        }

        let groupIDsByPlanID = Dictionary(
            uniqueKeysWithValues: zip(effectivePlans.map { $0.id }, sortedTeeGroups.map { $0.id })
        )
        let assignments = SeriesRoundCreationMapping.buildMemberAssignments(
            groupPlans: effectivePlans,
            groupIDsByPlanID: groupIDsByPlanID
        )
        return (assignments, effectivePlans)
    }

    /// Updates tee group schedule fields (tee time / starting hole) to match league intent without changing ids.
    static func teeGroupsWithLeagueSchedule(
        snapshot: RoundSnapshot,
        groupPlans: [SeriesRoundCreationMapping.TeeGroupPlan],
        seriesRound: SeriesRound
    ) throws -> [TeeTimeGroup] {
        let sorted = snapshot.teeGroups.sorted { $0.index < $1.index }
        let effectivePlans: [SeriesRoundCreationMapping.TeeGroupPlan] = groupPlans.isPopulated
            ? groupPlans
            : [SeriesRoundCreationMapping.TeeGroupPlan(id: "group_0", memberIDs: [])]
        guard effectivePlans.count == sorted.count else {
            throw SeriesRoundSyncError.organizationTeeGroupCountMismatch(
                expected: effectivePlans.count,
                actual: sorted.count
            )
        }

        guard let courseSegment = snapshot.courseSegment else {
            throw SeriesRoundSyncError.missingCourseSegment
        }

        let scheduledTeeTime: Date? = seriesRound.scheduledAt.map {
            Date(timeIntervalSince1970: $0.unix)
        }
        let templateGroups = SeriesRoundCreationMapping.buildTeeGroupsArray(
            roundID: snapshot.round.id,
            groupPlans: effectivePlans,
            holeRange: courseSegment.holeRange,
            useSequentialStarts: seriesRound.roundConfig.usesSequentialTeeStarts,
            scheduledTeeTime: scheduledTeeTime
        )
        let scheduledGroups = SeriesRoundCreationMapping.teeGroupsWithSchedule(
            templateGroups,
            holeRange: courseSegment.holeRange,
            useShotgunStart: seriesRound.roundConfig.usesSequentialTeeStarts,
            scheduledTeeTime: scheduledTeeTime,
            fallbackTeeTime: sorted.compactMap(\.teeTime).first
        )

        return zip(sorted, scheduledGroups).map { existing, template in
            var next = existing
            next.teeTime = template.teeTime
            next.startingHole = template.startingHole
            next.lastUpdatedAt = .init()
            return next
        }
    }

    static func roundTeamsPatch(
        seriesTeamsForRound: [SeriesTeam],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        snapshot: RoundSnapshot
    ) throws -> [RoundTeam] {
        guard seriesTeamsForRound.isPopulated else { return [] }

        let sortedSeries = seriesTeamsForRound.sorted { $0.index < $1.index }
        let expectedSeriesTeamIDs = Set(sortedSeries.map(\.id))
        let relevantTeamLinks = teamLinks.filter { expectedSeriesTeamIDs.contains($0.key) }
        guard sortedSeries.count == relevantTeamLinks.count else {
            throw SeriesRoundSyncError.organizationSeriesTeamMappingMismatch
        }

        var patched: [RoundTeam] = []
        for seriesTeam in sortedSeries {
            guard let link = relevantTeamLinks[seriesTeam.id],
                  var roundTeam = snapshot.teams.first(where: { $0.id == link.roundTeamID }) else {
                throw SeriesRoundSyncError.organizationSeriesTeamMappingMismatch
            }
            roundTeam.name = seriesTeam.name
            roundTeam.color = seriesTeam.roundColorToken
            roundTeam.lastUpdatedAt = .init()
            patched.append(roundTeam)
        }
        return patched
    }

    static func organizationTeamMappingPreflightError(
        seriesTeamsForRound: [SeriesTeam],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        snapshot: RoundSnapshot
    ) -> SeriesRoundSyncError? {
        guard seriesTeamsForRound.isPopulated else { return nil }

        let sortedSeries = seriesTeamsForRound.sorted { $0.index < $1.index }
        let expectedSeriesTeamIDs = Set(sortedSeries.map(\.id))
        let relevantTeamLinks = teamLinks.filter { expectedSeriesTeamIDs.contains($0.key) }
        let missingSeriesTeamIDs = sortedSeries
            .filter { relevantTeamLinks[$0.id] == nil }
            .map(\.id)
        let missingRoundTeamIDs = relevantTeamLinks.values
            .filter { link in !snapshot.teams.contains(where: { $0.id == link.roundTeamID }) }
            .map(\.roundTeamID)

        guard sortedSeries.count != relevantTeamLinks.count
                || missingSeriesTeamIDs.isPopulated
                || missingRoundTeamIDs.isPopulated else {
            return nil
        }

        var parts = [
            "Series team mappings are incomplete for organization sync.",
            "Expected \(sortedSeries.count), found \(relevantTeamLinks.count)."
        ]
        if missingSeriesTeamIDs.isPopulated {
            parts.append("Missing series team IDs: \(missingSeriesTeamIDs.joined(separator: ", ")).")
        }
        if missingRoundTeamIDs.isPopulated {
            parts.append("Missing round team IDs: \(missingRoundTeamIDs.joined(separator: ", ")).")
        }
        parts.append("Round has \(snapshot.teams.count) teams.")
        return .preflightFailed(parts.joined(separator: " "))
    }

    /// Applies player-field sync (name, tee, handicaps) onto existing participants.
    /// Does not change team/group/tee order — use `participantsWithOrganizationSync` for that.
    static func participantsWithPlayerDataSync(
        participants: [RoundParticipant],
        roundID: String,
        participatingMembers: [SeriesMember],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        memberAssignments: [String: SeriesRoundCreationMapping.MemberAssignment],
        handicaps: [String: SeriesMemberHandicap],
        maximumHandicap: Int? = nil,
        courseSegment: CourseSegment,
        handicapEntryFormat: HandicapEntryFormat = .strokes,
        handicapStrokeBasis: SeriesHandicapStrokeBasis? = nil,
        hostPlayerID: String?,
        preserveManualHandicapEdits: Bool
    ) -> [RoundParticipant] {
        let templates = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: participatingMembers,
            roundID: roundID,
            teamMappings: teamLinks,
            memberAssignments: memberAssignments,
            handicaps: handicaps,
            maximumHandicap: maximumHandicap,
            courseSegment: courseSegment,
            handicapEntryFormat: handicapEntryFormat,
            handicapStrokeBasis: handicapStrokeBasis,
            hostPlayerID: hostPlayerID
        )
        let templateByMemberID = Dictionary(uniqueKeysWithValues: zip(participatingMembers.map(\.id), templates))

        return participants.map { existing in
            guard let memberID = existing.seriesMemberID,
                  let template = templateByMemberID[memberID] else {
                return existing
            }
            var next = template
            next.id = existing.id
            next.createdAt = existing.createdAt
            next.parentID = existing.parentID
            next.isHost = existing.isHost
            next.userID = existing.userID
            next.playerID = existing.playerID
            next.seriesMemberID = existing.seriesMemberID
            next.groupID = existing.groupID
            next.teamID = existing.teamID
            next.teeOrder = existing.teeOrder
            next.presenceStatus = existing.presenceStatus

            if preserveManualHandicapEdits, existing.isLeagueHandicapModifiedFromCreation {
                next.originalHandicap = existing.originalHandicap
                next.adjustedHandicap = existing.adjustedHandicap
                next.handicapIndex = existing.handicapIndex ?? next.handicapIndex
                next.leagueHandicapStrokesAtCreation = existing.leagueHandicapStrokesAtCreation
            }

            next.lastUpdatedAt = .init()
            return next
        }
    }

    /// Applies organization fields (team, group, tee order) from league assignments — `memberAssignments` must include all roster members on the round.
    static func participantsWithOrganizationSync(
        participants: [RoundParticipant],
        participatingMembers: [SeriesMember],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        memberAssignments: [String: SeriesRoundCreationMapping.MemberAssignment],
        usesSeriesTeams: Bool
    ) -> [RoundParticipant] {
        participants.map { existing in
            guard let memberID = existing.seriesMemberID else { return existing }
            var next = existing
            if let assignment = memberAssignments[memberID] {
                next.groupID = assignment.groupID
                next.teeOrder = assignment.teeOrder
            }
            if usesSeriesTeams {
                let teamMapping = participatingMembers.first(where: { $0.id == memberID })?.teamID.flatMap { teamLinks[$0] }
                next.teamID = teamMapping?.roundTeamID
            }
            next.lastUpdatedAt = .init()
            return next
        }
    }

    static func buildLobbyAttendancePlan(
        series: Series,
        seriesRound: SeriesRound,
        participatingMembers: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        handicaps: [String: SeriesMemberHandicap],
        seriesMappings: [SeriesRoundMapping],
        snapshot: RoundSnapshot,
        hostPlayerID: String?,
        presenceStatusByMemberID: [String: RoundParticipantPresenceStatus]
    ) throws -> LobbyAttendancePlan {
        guard snapshot.round.status == .lobby else {
            throw SeriesRoundSyncError.optionsDisallowedForRoundStatus
        }
        guard !snapshot.scoring.contains(where: \.hasRecordedScore) else {
            throw SeriesRoundSyncError.preflightFailed("RSVP can no longer rebuild this lobby because score entries already exist.")
        }
        guard let courseSegment = snapshot.courseSegment,
              let existingSegment = snapshot.roundSegment else {
            throw SeriesRoundSyncError.missingCourseSegment
        }

        let resolvedPlan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: seriesRound,
            members: participatingMembers,
            teams: teams,
            pods: pods,
            courseSegment: courseSegment
        )
        let usesSeriesTeams = seriesRound.roundConfig.teamAssignmentMode == .seriesTeams
        let existingTeamLinks = teamLinks(mappings: seriesMappings, seriesRoundID: seriesRound.id)
        let existingTeamByID = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })

        let seriesTeamsForRound = usesSeriesTeams ? resolvedPlan.seriesTeamsForRound.sorted { $0.index < $1.index } : []
        var teamLinksBySeriesID: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [:]
        var teamsToPut: [RoundTeam] = []
        for (index, seriesTeam) in seriesTeamsForRound.enumerated() {
            let existingID = existingTeamLinks[seriesTeam.id]?.roundTeamID
            var roundTeam = existingID.flatMap { existingTeamByID[$0] } ?? RoundTeam(
                id: HackersID.string(),
                name: seriesTeam.name,
                color: seriesTeam.roundColorToken,
                index: index,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: snapshot.round.id
            )
            roundTeam.name = seriesTeam.name
            roundTeam.color = seriesTeam.roundColorToken
            roundTeam.index = index
            roundTeam.parentID = snapshot.round.id
            roundTeam.lastUpdatedAt = .init()
            teamsToPut.append(roundTeam)
            teamLinksBySeriesID[seriesTeam.id] = .init(seriesTeamID: seriesTeam.id, roundTeamID: roundTeam.id)
        }

        let templateGroups = SeriesRoundPlanningService.teeGroupsPayload(
            roundID: snapshot.round.id,
            plannedTeeGroups: resolvedPlan.plannedStructure.teeGroups,
            createdAt: .init()
        )
        let existingGroups = snapshot.teeGroups.sorted { $0.index < $1.index }
        let teeGroupsToPut = templateGroups.enumerated().map { index, template -> TeeTimeGroup in
            let existingGroup = index < existingGroups.count ? existingGroups[index] : nil
            var group = index < existingGroups.count ? existingGroups[index] : template
            group.index = index
            group.teeTime = template.teeTime
            group.startingHole = existingGroup
                .flatMap { courseSegment.holeRange.holeNumbers.contains($0.startingHole) ? $0.startingHole : nil }
                ?? template.startingHole
            group.parentID = snapshot.round.id
            group.lastUpdatedAt = .init()
            return group
        }
        let teeGroupsToDelete = Array(existingGroups.dropFirst(teeGroupsToPut.count))
        let groupIDsByPlanID = Dictionary(
            uniqueKeysWithValues: zip(resolvedPlan.teeGroupPlans.map(\.id), teeGroupsToPut.map(\.id))
        )
        let memberAssignments = SeriesRoundCreationMapping.buildMemberAssignments(
            groupPlans: resolvedPlan.teeGroupPlans,
            groupIDsByPlanID: groupIDsByPlanID
        )

        let templates = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: participatingMembers,
            roundID: snapshot.round.id,
            teamMappings: teamLinksBySeriesID,
            memberAssignments: memberAssignments,
            handicaps: handicaps,
            maximumHandicap: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
            courseSegment: courseSegment,
            handicapEntryFormat: seriesRound.roundConfig.handicapEntryFormat,
            handicapStrokeBasis: seriesRound.roundConfig.handicapStrokeBasis,
            hostPlayerID: hostPlayerID,
            presenceStatusByMemberID: presenceStatusByMemberID
        )
        let existingParticipantByMemberID = Dictionary(
            uniqueKeysWithValues: snapshot.participants.compactMap { participant -> (String, RoundParticipant)? in
                guard let memberID = participant.seriesMemberID else { return nil }
                return (memberID, participant)
            }
        )
        let participatingMemberIDs = Set(participatingMembers.map(\.id))
        let nonSeriesParticipants = snapshot.participants.filter { $0.seriesMemberID == nil }
        let participantsToPut = zip(participatingMembers, templates).map { member, template -> RoundParticipant in
            guard let existing = existingParticipantByMemberID[member.id] else { return template }
            var next = template
            next.id = existing.id
            next.createdAt = existing.createdAt
            next.parentID = existing.parentID
            next.isHost = existing.isHost
            next.userID = existing.userID ?? template.userID
            next.playerID = existing.playerID ?? template.playerID
            next.lastUpdatedAt = .init()
            return next
        }
        let participantsToDelete = snapshot.participants.filter { participant in
            guard let memberID = participant.seriesMemberID else { return false }
            return !participatingMemberIDs.contains(memberID)
        }
        let workingParticipants = nonSeriesParticipants + participantsToPut

        let populatedTeeGroupIDs = Set(workingParticipants.compactMap(\.groupID).filter(\.isPopulated))
        let retainedTeeGroups = teeGroupsToPut.filter { populatedTeeGroupIDs.contains($0.id) }
        let emptyTeeGroupsToDelete = teeGroupsToPut.filter { !populatedTeeGroupIDs.contains($0.id) }
        let populatedTeamIDs = Set(workingParticipants.compactMap(\.teamID).filter(\.isPopulated))
        let teamsToDelete = snapshot.teams.filter { !populatedTeamIDs.contains($0.id) }

        let scoringGroupsToPut = SeriesRoundCreationMapping.buildRoundScoringGroups(
            roundID: snapshot.round.id,
            seriesRound: seriesRound,
            participants: workingParticipants,
            partnershipPlans: resolvedPlan.partnershipPlans,
            teeGroups: retainedTeeGroups
        )
        let scoringGroupsByID = Dictionary(uniqueKeysWithValues: scoringGroupsToPut.map { ($0.id, $0) })
        let scoringGroupsToDelete = snapshot.scoringGroups.filter { scoringGroupsByID[$0.id] == nil }

        let segment = buildUpdatedSegment(
            series: series,
            seriesRound: seriesRound,
            courseSegment: courseSegment,
            participants: workingParticipants,
            scoringGroups: scoringGroupsToPut,
            existingSegment: existingSegment,
            teams: teams,
            pods: pods,
            participatingMembers: participatingMembers,
            teamLinks: teamLinksBySeriesID
        )

        var round = snapshot.round
        round.players = workingParticipants.compactMap(\.playerID)
        round.configuration.handicapsEnabled = resolvedPlan.roundConfiguration.useHandicaps
        round.configuration.handicapStrokeBasis = seriesRound.roundConfig.handicapStrokeBasis
        round.configuration.leagueHandicapMaximum = series.handicapConfig.isEnabled
            ? series.handicapConfig.config.maximumHandicap
            : nil
        round.lastUpdatedAt = .init()

        let mappingsToPut = buildSeriesRoundMappings(
            seriesID: series.id,
            seriesRoundID: seriesRound.id,
            teamLinks: teamLinksBySeriesID,
            participatingMembers: participatingMembers,
            participants: workingParticipants,
            scoringGroups: scoringGroupsToPut
        )
        let nextMappingIDs = Set(mappingsToPut.map(\.id))
        let mappingsToDelete = seriesMappings.filter { mapping in
            mapping.seriesRoundID == seriesRound.id && !nextMappingIDs.contains(mapping.id)
        }

        return LobbyAttendancePlan(
            round: round,
            teeGroupsToPut: retainedTeeGroups,
            teeGroupsToDelete: teeGroupsToDelete + emptyTeeGroupsToDelete,
            teamsToPut: teamsToPut.filter { populatedTeamIDs.contains($0.id) },
            teamsToDelete: teamsToDelete,
            participantsToPut: participantsToPut,
            participantsToDelete: participantsToDelete,
            scoringGroupsToPut: scoringGroupsToPut,
            scoringGroupsToDelete: scoringGroupsToDelete,
            segment: segment,
            mappingsToPut: mappingsToPut,
            mappingsToDelete: mappingsToDelete
        )
    }

    static func buildSeriesRoundMappings(
        seriesID: String,
        seriesRoundID: String,
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        participatingMembers: [SeriesMember],
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup]
    ) -> [SeriesRoundMapping] {
        var mappings: [SeriesRoundMapping] = []
        let participantByMemberID = Dictionary(uniqueKeysWithValues: participants.compactMap { participant -> (String, RoundParticipant)? in
            guard let memberID = participant.seriesMemberID else { return nil }
            return (memberID, participant)
        })
        for member in participatingMembers {
            guard let participant = participantByMemberID[member.id] else { continue }
            mappings.append(
                SeriesRoundCreationMapping.seriesRoundParticipantMapping(
                    seriesRoundID: seriesRoundID,
                    seriesID: seriesID,
                    memberID: member.id,
                    participantID: participant.id
                )
            )
        }
        for link in teamLinks.values {
            mappings.append(
                SeriesRoundCreationMapping.seriesRoundTeamMapping(
                    seriesRoundID: seriesRoundID,
                    seriesID: seriesID,
                    link: link
                )
            )
        }
        for scoringGroup in scoringGroups {
            mappings.append(
                contentsOf: SeriesRoundCreationMapping.seriesRoundScoreOwnerMappings(
                    seriesRoundID: seriesRoundID,
                    seriesID: seriesID,
                    scoringGroup: scoringGroup,
                    participants: participants,
                    teamMappings: teamLinks
                )
            )
        }
        return mappings
    }

    static func buildUpdatedSegment(
        series: Series,
        seriesRound: SeriesRound,
        scoringSeriesRound: SeriesRound? = nil,
        courseSegment: CourseSegment,
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup],
        existingSegment: RoundSegment,
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        participatingMembers: [SeriesMember],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink],
        updateFormat: Bool = true,
        updateScoringUnits: Bool = true,
        updateMatchups: Bool = true
    ) -> RoundSegment {
        let resolvedPlan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: seriesRound,
            members: participatingMembers,
            teams: teams,
            pods: pods,
            courseSegment: courseSegment
        )

        var segment = existingSegment
        if updateFormat {
            segment.holeRange = courseSegment.holeRange
            segment.gameFormat = SeriesRoundCreationMapping.primaryGameFormatForRound(series: series, seriesRound: seriesRound)
            segment.templateID = seriesRound.roundConfig.formatTemplateID
            segment.competitionScope = resolvedPlan.competitionScope
        }
        if updateScoringUnits {
            segment.scoringUnits = SeriesRoundCreationMapping.buildScoringUnits(
                seriesRound: scoringSeriesRound ?? seriesRound,
                participants: participants,
                scoringGroups: scoringGroups,
                teamMappings: teamLinks
            )
        }
        if updateMatchups {
            let matchupSeriesRound = scoringSeriesRound ?? seriesRound
            let participantIDs = Dictionary(
                uniqueKeysWithValues: participants.compactMap { p -> (String, String)? in
                    guard let m = p.seriesMemberID else { return nil }
                    return (m, p.id)
                }
            )
            let resolvedMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
                seriesRound: matchupSeriesRound,
                matchupPlans: resolvedPlan.matchupPlans,
                teamMappings: teamLinks,
                participantIDsBySeriesMemberID: participantIDs,
                scoringGroups: scoringGroups,
                participants: participants
            )
            segment.matchups = resolvedMatchups.isEmpty ? nil : resolvedMatchups
        }
        segment.lastUpdatedAt = .init()
        return segment
    }

    static func scoringSeriesRoundForExistingRound(
        _ seriesRound: SeriesRound,
        roundConfiguration: RoundConfiguration,
        existingSegment: RoundSegment
    ) -> SeriesRound {
        var copy = seriesRound
        var config = copy.roundConfig
        config.formatTemplateID = roundConfiguration.formatSummary?.templateID
            ?? existingSegment.templateID
            ?? config.formatTemplateID
        config.competitionScope = roundConfiguration.competitionScope
        config.teamScoring = roundConfiguration.teamScoring
        config.matchupResolutionStyle = roundConfiguration.matchupResolutionStyle
        let template = FormatTemplateRegistry.template(for: config.formatTemplateID)
        config.scoreOwnerScope = template.scoreSource == .shared ? roundConfiguration.scoreOwnerScope : .individual
        config.matchupScoringStyle = roundConfiguration.matchupScoringStyle
        config.holeWinPoints = roundConfiguration.holeWinPoints
        config.matchWinnerBonusPoints = roundConfiguration.matchWinnerBonusPoints
        config.matchTiePolicy = roundConfiguration.matchTiePolicy
        config.selectionDomain = roundConfiguration.selectionDomain
        config.sequentialTeeStartsEnabled = roundConfiguration.sequentialTeeStartsEnabled
        config.sharedScoreHandicapConfig = roundConfiguration.sharedScoreHandicapConfig
        config.matchupMode = seriesMatchupMode(
            from: roundConfiguration,
            segment: existingSegment,
            fallback: config.matchupMode
        )
        copy.roundConfig = config
        return copy
    }

    static func seriesMatchupMode(
        from configuration: RoundConfiguration,
        segment: RoundSegment?,
        fallback: SeriesMatchupMode
    ) -> SeriesMatchupMode {
        guard configuration.resolvedCompetitionScope == .matchup else { return .field }

        let matchups = segment?.matchups ?? []
        if matchups.contains(where: { $0.effectiveMode == .partnership }) {
            return .teeGroupPartnerships
        }
        if matchups.contains(where: { $0.effectiveMode == .team }) {
            return .teamVsTeam
        }
        if matchups.contains(where: { $0.effectiveMode == .individual }) {
            return .individualVsIndividual
        }
        if configuration.selectionDomain == .partnership && fallback == .teeGroupPartnerships {
            return .teeGroupPartnerships
        }
        return configuration.primaryFormat.configuration.requiresTeams ? .teamVsTeam : .individualVsIndividual
    }
}
