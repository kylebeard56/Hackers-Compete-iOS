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
    var preserveManualHandicapEdits: Bool = false

    var hasAny: Bool { syncPlayerData || syncFormat || syncOrganization }
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
            switch matchup.mode ?? .team {
            case .team:
                return matchup.teamIDs.allSatisfy(activeTeamIDs.contains)
            case .individual:
                return (matchup.participantIDs ?? []).allSatisfy(activeParticipantIDs.contains)
            case .scoreOwner:
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

        return zip(sorted, templateGroups).map { existing, template in
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

    static func buildUpdatedSegment(
        series: Series,
        seriesRound: SeriesRound,
        courseSegment: CourseSegment,
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup],
        existingSegment: RoundSegment,
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        participatingMembers: [SeriesMember],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink]
    ) -> RoundSegment {
        let resolvedPlan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: seriesRound,
            members: participatingMembers,
            teams: teams,
            pods: pods,
            courseSegment: courseSegment
        )
        let matchupPlans = resolvedPlan.matchupPlans
        let participantIDs = Dictionary(
            uniqueKeysWithValues: participants.compactMap { p -> (String, String)? in
                guard let m = p.seriesMemberID else { return nil }
                return (m, p.id)
            }
        )

        let resolvedMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: matchupPlans,
            teamMappings: teamLinks,
            participantIDsBySeriesMemberID: participantIDs,
            scoringGroups: scoringGroups,
            participants: participants
        )

        let scoringUnits = SeriesRoundCreationMapping.buildScoringUnits(
            seriesRound: seriesRound,
            participants: participants,
            scoringGroups: scoringGroups,
            teamMappings: teamLinks
        )

        var segment = existingSegment
        segment.holeRange = courseSegment.holeRange
        segment.gameFormat = SeriesRoundCreationMapping.primaryGameFormatForRound(series: series, seriesRound: seriesRound)
        segment.templateID = seriesRound.roundConfig.formatTemplateID
        segment.scoringUnits = scoringUnits
        segment.matchups = resolvedMatchups.isEmpty ? nil : resolvedMatchups
        segment.competitionScope = resolvedPlan.competitionScope
        segment.lastUpdatedAt = .init()
        return segment
    }
}
