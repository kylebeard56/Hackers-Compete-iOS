//
//  SeriesRoundCreationMapping.swift
//  Hackers
//
//  Pure mapping from series round + roster state into round documents used when starting a live round.
//  Covered by SeriesRoundCreationMappingTests.
//

import Foundation

enum SeriesRoundCreationMapping {

    /// Links a series team id to the corresponding `RoundTeam` document id after create.
    struct SeriesToRoundTeamLink: Equatable {
        let seriesTeamID: String
        let roundTeamID: String
    }

    struct TeeGroupPlan: Identifiable, Equatable {
        let id: String
        let memberIDs: [String]
    }

    struct MemberAssignment: Equatable {
        let groupID: String
        let teeOrder: Int
    }

    // MARK: - Round root + configuration

    static func resolvedCompetitionScope(for seriesRound: SeriesRound) -> CompetitionScope {
        if seriesRound.matchupPlans.isPopulated
            || seriesRound.roundConfig.matchupMode == .teamVsTeam
            || seriesRound.roundConfig.matchupMode == .individualVsIndividual {
            return .matchup
        }
        return seriesRound.roundConfig.resolvedCompetitionScope
    }

    static func roundConfiguration(
        seriesRound: SeriesRound,
        courseSegment: CourseSegment,
        competitionScope: CompetitionScope
    ) -> RoundConfiguration {
        let template = seriesRound.roundConfig.template
        return RoundConfiguration(
            primaryFormat: seriesRound.roundConfig.legacyGameFormat,
            formatSummary: RoundFormatSummary(from: template),
            courses: [courseSegment],
            competitionScope: competitionScope,
            teamScoring: seriesRound.roundConfig.teamScoring,
            matchupResolutionStyle: seriesRound.roundConfig.matchupResolutionStyle,
            sequentialTeeStartsEnabled: seriesRound.roundConfig.sequentialTeeStartsEnabled ?? false
        )
    }

    /// Values used when creating the root `Round` before Firestore post (share code and timestamps filled by caller).
    static func roundDraft(
        id: String,
        shareCode: String,
        createdBy: String,
        members: [SeriesMember],
        seriesRound: SeriesRound,
        courseSegment: CourseSegment
    ) -> Round {
        let competitionScope = resolvedCompetitionScope(for: seriesRound)
        return Round(
            id: id,
            shareCode: shareCode,
            createdBy: createdBy,
            status: .lobby,
            players: members.compactMap(\.playerID),
            configuration: roundConfiguration(
                seriesRound: seriesRound,
                courseSegment: courseSegment,
                competitionScope: competitionScope
            ),
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
    }

    // MARK: - Matchups + tee groups

    static func resolvedMatchupPlans(
        seriesRound: SeriesRound,
        teams: [SeriesTeam],
        members: [SeriesMember]
    ) -> [SeriesRoundMatchupPlan] {
        if seriesRound.matchupPlans.isPopulated {
            return seriesRound.matchupPlans.sorted { $0.index < $1.index }
        }

        switch seriesRound.roundConfig.matchupMode {
        case .teamVsTeam:
            let orderedTeams = teams.sorted { $0.index < $1.index }
            var plans: [SeriesRoundMatchupPlan] = []
            var index = 0
            var cursor = 0
            while cursor + 1 < orderedTeams.count {
                plans.append(
                    SeriesRoundMatchupPlan(
                        id: HackersID.string(),
                        teamAID: orderedTeams[cursor].id,
                        teamBID: orderedTeams[cursor + 1].id,
                        index: index,
                        podGroupingStrategy: seriesRound.roundConfig.podGroupingStrategy
                    )
                )
                cursor += 2
                index += 1
            }
            return plans
        case .individualVsIndividual:
            let orderedMembers = members.sorted {
                $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
            }
            var plans: [SeriesRoundMatchupPlan] = []
            var index = 0
            var cursor = 0
            while cursor + 1 < orderedMembers.count {
                plans.append(
                    SeriesRoundMatchupPlan(
                        id: HackersID.string(),
                        memberAID: orderedMembers[cursor].id,
                        memberBID: orderedMembers[cursor + 1].id,
                        index: index
                    )
                )
                cursor += 2
                index += 1
            }
            return plans
        case .none, .field:
            return []
        }
    }

    static func buildTeeGroupPlans(
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan],
        seriesRound: SeriesRound
    ) -> [TeeGroupPlan] {
        if seriesRound.roundConfig.teeGroupMode == .podAligned || seriesRound.roundConfig.podGroupingStrategy == .alignByIndex {
            let podPlans = buildPodAlignedGroupPlans(teams: teams, pods: pods, matchupPlans: matchupPlans)
            if podPlans.isPopulated {
                let assignedMemberIDs = Set(podPlans.flatMap(\.memberIDs))
                let leftovers = members.filter { !assignedMemberIDs.contains($0.id) }
                return podPlans + sequentialGroupPlans(for: leftovers, teams: teams)
            }
        }

        return sequentialGroupPlans(for: members, teams: teams)
    }

    private static func buildPodAlignedGroupPlans(
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan]
    ) -> [TeeGroupPlan] {
        guard matchupPlans.isPopulated else { return [] }
        let podsByTeam = Dictionary(grouping: pods.filter(\.isSchedulable)) { $0.teamID }
        var plans: [TeeGroupPlan] = []

        for plan in matchupPlans.sorted(by: { $0.index < $1.index }) {
            guard plan.podGroupingStrategy == .alignByIndex else { continue }
            let podsA = (podsByTeam[plan.teamAID] ?? []).sorted { $0.index < $1.index }
            let podsB = (podsByTeam[plan.teamBID] ?? []).sorted { $0.index < $1.index }
            guard podsA.isPopulated, podsB.isPopulated, podsA.count == podsB.count else { continue }

            for index in podsA.indices {
                plans.append(
                    TeeGroupPlan(
                        id: "matchup_\(plan.id)_pod_\(index)",
                        memberIDs: podsA[index].memberIDs + podsB[index].memberIDs
                    )
                )
            }
        }

        return plans
    }

    private static func sequentialGroupPlans(for members: [SeriesMember], teams: [SeriesTeam]) -> [TeeGroupPlan] {
        let teamOrder = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.index) })
        let orderedMembers = members.sorted { lhs, rhs in
            let lhsTeam = lhs.teamID.flatMap { teamOrder[$0] } ?? .max
            let rhsTeam = rhs.teamID.flatMap { teamOrder[$0] } ?? .max
            if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
            return lhs.name.fullName < rhs.name.fullName
        }

        return stride(from: 0, to: orderedMembers.count, by: 4).map { start in
            let chunk = Array(orderedMembers[start..<min(start + 4, orderedMembers.count)])
            return TeeGroupPlan(id: "group_\(start / 4)", memberIDs: chunk.map(\.id))
        }
    }

    static func buildMemberAssignments(
        groupPlans: [TeeGroupPlan],
        groupIDsByPlanID: [String: String]
    ) -> [String: MemberAssignment] {
        var assignments: [String: MemberAssignment] = [:]
        for groupPlan in groupPlans {
            guard let groupID = groupIDsByPlanID[groupPlan.id] else { continue }
            for (index, memberID) in groupPlan.memberIDs.enumerated() {
                assignments[memberID] = MemberAssignment(groupID: groupID, teeOrder: index + 1)
            }
        }
        return assignments
    }

    static func buildTeeGroupsArray(
        roundID: String,
        groupPlans: [TeeGroupPlan],
        holeRange: HoleRange,
        useSequentialStarts: Bool,
        scheduledTeeTime: Date? = nil
    ) -> [TeeTimeGroup] {
        let plans = groupPlans.isPopulated ? groupPlans : [TeeGroupPlan(id: "group_0", memberIDs: [])]
        let iso = ISO8601DateFormatter()
        return plans.enumerated().map { index, _ in
            let teeTime: String? = scheduledTeeTime.map { base in
                let offset = base.addingTimeInterval(Double(index) * 8 * 60)
                return iso.string(from: offset)
            }
            var group = TeeTimeGroup(
                id: HackersID.string(),
                index: index,
                teeTime: nil,
                startingHole: useSequentialStarts
                    ? TeeTimeGroup.sequentialStartingHole(forSequenceIndex: index, in: holeRange)
                    : holeRange.startHole,
                lastCompletedHole: nil,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
            group.teeTime = teeTime
            return group
        }
    }

    // MARK: - Teams

    static func buildRoundTeamsArray(
        roundID: String,
        seriesTeams: [SeriesTeam],
        createdAt: Time
    ) -> [RoundTeam] {
        guard seriesTeams.isPopulated else { return [] }

        return seriesTeams.sorted(by: { $0.index < $1.index }).enumerated().map { index, team in
            RoundTeam(
                id: HackersID.string(),
                name: team.name,
                color: team.roundColorToken,
                index: index,
                createdAt: createdAt,
                lastUpdatedAt: createdAt,
                parentID: roundID
            )
        }
    }

    static func teamMappingsFromPosted(seriesTeams: [SeriesTeam], posted: [RoundTeam]) -> [String: SeriesToRoundTeamLink] {
        let sorted = seriesTeams.sorted(by: { $0.index < $1.index })
        guard sorted.count == posted.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(sorted, posted).map { team, roundTeam in
            (team.id, SeriesToRoundTeamLink(seriesTeamID: team.id, roundTeamID: roundTeam.id))
        })
    }

    // MARK: - Participants + segment + Firestore mappings

    static func resolvedTeeBoxID(for member: SeriesMember, courseSegment: CourseSegment) -> String {
        if let teeBoxID = member.defaultTeeBoxID, teeBoxID.isPopulated {
            return teeBoxID
        }
        if let defaultTee = courseSegment.defaultTee, defaultTee.isPopulated {
            return defaultTee
        }
        return courseSegment.courseInfo.tees.first?.id ?? ""
    }

    static func buildParticipantPayloads(
        members: [SeriesMember],
        roundID: String,
        teamMappings: [String: SeriesToRoundTeamLink],
        memberAssignments: [String: MemberAssignment],
        handicaps: [String: SeriesMemberHandicap],
        courseSegment: CourseSegment,
        hostPlayerID: String?
    ) -> [RoundParticipant] {
        members.map { member in
            let assignment = memberAssignments[member.id]
            let effectiveHandicap = Int((handicaps[member.id]?.effectiveIndex ?? 0).rounded())
            let teamMapping = member.teamID.flatMap { teamMappings[$0] }
            let teeBoxID = resolvedTeeBoxID(for: member, courseSegment: courseSegment)
            return RoundParticipant(
                id: HackersID.string(),
                userID: member.userID,
                playerID: member.playerID,
                name: member.name,
                teeBoxID: teeBoxID,
                originalHandicap: effectiveHandicap,
                adjustedHandicap: effectiveHandicap,
                seriesMemberID: member.id,
                teamID: teamMapping?.roundTeamID,
                groupID: assignment?.groupID,
                teeOrder: assignment?.teeOrder,
                isHost: hostPlayerID != nil && member.playerID == hostPlayerID,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
        }
    }

    static func buildRoundMatchups(
        seriesRound: SeriesRound,
        matchupPlans: [SeriesRoundMatchupPlan],
        teamMappings: [String: SeriesToRoundTeamLink],
        participantIDsBySeriesMemberID: [String: String]
    ) -> [TeamMatchup] {
        matchupPlans.compactMap { plan -> TeamMatchup? in
            switch seriesRound.roundConfig.matchupMode {
            case .teamVsTeam:
                guard let teamA = teamMappings[plan.teamAID]?.roundTeamID,
                      let teamB = teamMappings[plan.teamBID]?.roundTeamID else { return nil }
                return TeamMatchup(id: plan.id, teamIDs: [teamA, teamB], participantIDs: nil, mode: .team)
            case .individualVsIndividual:
                guard let memberAID = plan.memberAID,
                      let memberBID = plan.memberBID,
                      let participantAID = participantIDsBySeriesMemberID[memberAID],
                      let participantBID = participantIDsBySeriesMemberID[memberBID] else {
                    return nil
                }
                return TeamMatchup(
                    id: plan.id,
                    teamIDs: [],
                    participantIDs: [participantAID, participantBID],
                    mode: .individual
                )
            case .none, .field:
                return nil
            }
        }
    }

    static func buildRoundSegment(
        roundID: String,
        seriesRound: SeriesRound,
        courseSegment: CourseSegment,
        competitionScope: CompetitionScope,
        matchups: [TeamMatchup]
    ) -> RoundSegment {
        RoundSegment(
            id: HackersID.string(),
            roundID: roundID,
            holeRange: courseSegment.holeRange,
            gameFormat: seriesRound.roundConfig.legacyGameFormat,
            templateID: seriesRound.roundConfig.formatTemplateID,
            scoringUnits: [],
            matchups: matchups.isEmpty ? nil : matchups,
            competitionScope: competitionScope,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    static func seriesRoundParticipantMapping(
        seriesRoundID: String,
        seriesID: String,
        memberID: String,
        participantID: String
    ) -> SeriesRoundMapping {
        SeriesRoundMapping(
            id: "\(seriesRoundID)_participant_\(participantID)",
            seriesRoundID: seriesRoundID,
            roundOwnerType: .participant,
            roundOwnerID: participantID,
            competitorType: .member,
            competitorID: memberID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
    }

    static func seriesRoundTeamMapping(
        seriesRoundID: String,
        seriesID: String,
        link: SeriesToRoundTeamLink
    ) -> SeriesRoundMapping {
        SeriesRoundMapping(
            id: "\(seriesRoundID)_team_\(link.roundTeamID)",
            seriesRoundID: seriesRoundID,
            roundOwnerType: .team,
            roundOwnerID: link.roundTeamID,
            competitorType: .team,
            competitorID: link.seriesTeamID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
    }
}
