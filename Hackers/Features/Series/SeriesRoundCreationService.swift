//
//  SeriesRoundCreationService.swift
//  Hackers
//
//  Handles creating a live round from series data, carrying over
//  round settings, roster, teams, optional pods, and series mappings.
//

import Foundation

@MainActor
struct SeriesRoundCreationService: Loggable {

    func createRoundFromSeries(
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        handicaps: [String: SeriesMemberHandicap],
        courseSegment overrideCourseSegment: CourseSegment? = nil
    ) async -> String? {
        guard let user = await AppData.shared.user,
              let player = await AppData.shared.getPrimaryPlayer() else { return nil }

        guard let courseSegment = await resolveCourseSegment(
            override: overrideCourseSegment,
            selection: seriesRound.resolvedCourse(using: series)
        ) else {
            addBreadcrumb(level: .error, message: "Series round creation aborted because no course was resolved")
            return nil
        }

        let shareCode = await FirebaseService.shared.getUniqueShareCode()
        let roundID = HackersID.string()
        let template = seriesRound.roundConfig.template
        let competitionScope = resolvedCompetitionScope(for: seriesRound)
        let configuration = RoundConfiguration(
            primaryFormat: seriesRound.roundConfig.legacyGameFormat,
            formatSummary: RoundFormatSummary(from: template),
            courses: [courseSegment],
            competitionScope: competitionScope,
            teamScoring: seriesRound.roundConfig.teamScoring,
            matchupResolutionStyle: seriesRound.roundConfig.matchupResolutionStyle,
            sequentialTeeStartsEnabled: seriesRound.roundConfig.sequentialTeeStartsEnabled ?? false
        )

        var round = Round(
            id: roundID,
            shareCode: shareCode,
            createdBy: user.id,
            status: .lobby,
            players: members.compactMap(\.playerID),
            configuration: configuration,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )

        do {
            round = try await round.post().get()

            let teamMappings = try await createRoundTeams(
                roundID: roundID,
                seriesTeams: seriesRound.roundConfig.teamAssignmentMode == .seriesTeams ? teams : [],
                createdAt: round.createdAt
            )

            let matchupPlans = resolvedMatchupPlans(seriesRound: seriesRound, teams: teams, members: members)

            let groupPlans = buildTeeGroupPlans(
                members: members,
                teams: teams,
                pods: pods,
                matchupPlans: matchupPlans,
                seriesRound: seriesRound
            )

            let scheduledTeeTime: Date? = seriesRound.scheduledAt.map {
                Date(timeIntervalSince1970: $0.unix)
            }
            let teeGroups = try await createTeeGroups(
                roundID: roundID,
                groupPlans: groupPlans,
                holeRange: courseSegment.holeRange,
                useSequentialStarts: seriesRound.roundConfig.usesSequentialTeeStarts,
                scheduledTeeTime: scheduledTeeTime
            )
            let groupIDsByPlanID = Dictionary(uniqueKeysWithValues: zip(groupPlans.map(\.id), teeGroups.map(\.id)))
            let memberAssignments = buildMemberAssignments(groupPlans: groupPlans, groupIDsByPlanID: groupIDsByPlanID)

            var createdParticipants: [RoundParticipant] = []
            var createdMappings: [SeriesRoundMapping] = []
            var participantIDsBySeriesMemberID: [String: String] = [:]

            for member in members {
                let assignment = memberAssignments[member.id]
                let effectiveHandicap = Int((handicaps[member.id]?.effectiveIndex ?? 0).rounded())
                let teamMapping = member.teamID.flatMap { teamMappings[$0] }
                let teeBoxID = resolvedTeeBoxID(for: member, courseSegment: courseSegment)

                let participant = RoundParticipant(
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
                    isHost: member.playerID == player.id,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: roundID
                )

                let created = try await participant.post().get()
                createdParticipants.append(created)
                participantIDsBySeriesMemberID[member.id] = created.id
                createdMappings.append(
                    SeriesRoundMapping(
                        id: "\(seriesRound.id)_participant_\(created.id)",
                        seriesRoundID: seriesRound.id,
                        roundOwnerType: .participant,
                        roundOwnerID: created.id,
                        competitorType: .member,
                        competitorID: member.id,
                        createdAt: .init(),
                        lastUpdatedAt: .init(),
                        parentID: series.id
                    )
                )
            }

            let roundMatchups = matchupPlans.compactMap { plan -> TeamMatchup? in
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

            let segment = RoundSegment(
                id: HackersID.string(),
                roundID: roundID,
                holeRange: courseSegment.holeRange,
                gameFormat: seriesRound.roundConfig.legacyGameFormat,
                templateID: seriesRound.roundConfig.formatTemplateID,
                scoringUnits: [],
                matchups: roundMatchups.isEmpty ? nil : roundMatchups,
                competitionScope: competitionScope,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
            _ = try await segment.post().get()

            for mapping in teamMappings.values {
                createdMappings.append(
                    SeriesRoundMapping(
                        id: "\(seriesRound.id)_team_\(mapping.roundTeamID)",
                        seriesRoundID: seriesRound.id,
                        roundOwnerType: .team,
                        roundOwnerID: mapping.roundTeamID,
                        competitorType: .team,
                        competitorID: mapping.seriesTeamID,
                        createdAt: .init(),
                        lastUpdatedAt: .init(),
                        parentID: series.id
                    )
                )
            }

            for mapping in createdMappings {
                _ = await FirebaseService.shared.addSeriesRoundMapping(mapping)
            }

            addEvent(
                "series.round_creation_succeeded",
                eventProps: [
                    "series_id": series.id,
                    "series_round_id": seriesRound.id,
                    "round_id": roundID,
                    "participant_count": createdParticipants.count,
                    "team_count": teamMappings.count
                ]
            )
            return roundID
        } catch {
            addBreadcrumb(level: .error, message: "Failed to create live round from series", error: error)
            return nil
        }
    }

    // MARK: - Course Resolution

    /// Resolves a persisted tee box id against loaded `Course` tees. API-sourced courses now use stable tee ids; older
    /// Firestore values may reference one-off UUIDs from a previous fetch—fall back to the first tee when unmatched.
    private func resolvedDefaultTeeID(persistedID: String, course: Course) -> String? {
        guard persistedID.isPopulated else { return nil }
        if course.tees.contains(where: { $0.id == persistedID }) { return persistedID }
        return course.tees.first?.id
    }

    private func resolveCourseSegment(
        override: CourseSegment?,
        selection: SeriesCourseSelection?
    ) async -> CourseSegment? {
        if let override { return override }
        guard let selection, selection.courseID.isPopulated else { return nil }

        let course: Course?
        if let apiID = Int(selection.courseID) {
            do {
                let apiCourse = try await GolfCourseAPI.shared.getCourse(by: apiID)
                course = Course(from: apiCourse, with: selection.courseID, useStableTeeIDs: true)
            } catch {
                switch await FirebaseService.shared.getCourseByID(selection.courseID) {
                case .success(let fetched): course = fetched
                case .failure: course = nil
                }
            }
        } else {
            switch await FirebaseService.shared.getCourseByID(selection.courseID) {
            case .success(let fetched): course = fetched
            case .failure: course = nil
            }
        }

        guard let course else { return nil }
        let totalHoles = course.tees.map(\.totalHoles).max() ?? selection.holeSegment.holeCount
        let holeRange = selection.holeSegment.toHoleRange(totalHoles: totalHoles) ?? selection.holeSegment.holeRange
        let defaultTee = resolvedDefaultTeeID(persistedID: selection.defaultTeeBoxID, course: course)
        return CourseSegment(
            courseInfo: CourseInfo(course: course, for: selection.holeSegment),
            holeRange: holeRange,
            defaultTee: defaultTee
        )
    }

    // MARK: - Team + Matchup Construction

    private struct RoundTeamMapping {
        let seriesTeamID: String
        let roundTeamID: String
    }

    private func createRoundTeams(
        roundID: String,
        seriesTeams: [SeriesTeam],
        createdAt: Time
    ) async throws -> [String: RoundTeamMapping] {
        guard seriesTeams.isPopulated else { return [:] }

        var mappings: [String: RoundTeamMapping] = [:]
        for (index, team) in seriesTeams.sorted(by: { $0.index < $1.index }).enumerated() {
            let roundTeam = RoundTeam(
                id: HackersID.string(),
                name: team.name,
                color: team.roundColorToken,
                index: index,
                createdAt: createdAt,
                lastUpdatedAt: createdAt,
                parentID: roundID
            )
            let created = try await roundTeam.post().get()
            mappings[team.id] = RoundTeamMapping(seriesTeamID: team.id, roundTeamID: created.id)
        }
        return mappings
    }

    private func resolvedCompetitionScope(for seriesRound: SeriesRound) -> CompetitionScope {
        if seriesRound.matchupPlans.isPopulated
            || seriesRound.roundConfig.matchupMode == .teamVsTeam
            || seriesRound.roundConfig.matchupMode == .individualVsIndividual {
            return .matchup
        }
        return seriesRound.roundConfig.resolvedCompetitionScope
    }

    private func resolvedMatchupPlans(
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

    // MARK: - Tee Group Construction

    private struct GroupPlan: Identifiable {
        let id: String
        let memberIDs: [String]
    }

    private struct MemberAssignment {
        let groupID: String
        let teeOrder: Int
    }

    private func buildTeeGroupPlans(
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan],
        seriesRound: SeriesRound
    ) -> [GroupPlan] {
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

    private func buildPodAlignedGroupPlans(
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan]
    ) -> [GroupPlan] {
        guard matchupPlans.isPopulated else { return [] }
        let podsByTeam = Dictionary(grouping: pods.filter(\.isSchedulable)) { $0.teamID }
        var plans: [GroupPlan] = []

        for plan in matchupPlans.sorted(by: { $0.index < $1.index }) {
            guard plan.podGroupingStrategy == .alignByIndex else { continue }
            let podsA = (podsByTeam[plan.teamAID] ?? []).sorted { $0.index < $1.index }
            let podsB = (podsByTeam[plan.teamBID] ?? []).sorted { $0.index < $1.index }
            guard podsA.isPopulated, podsB.isPopulated, podsA.count == podsB.count else { continue }

            for index in podsA.indices {
                plans.append(
                    GroupPlan(
                        id: "matchup_\(plan.id)_pod_\(index)",
                        memberIDs: podsA[index].memberIDs + podsB[index].memberIDs
                    )
                )
            }
        }

        return plans
    }

    private func sequentialGroupPlans(for members: [SeriesMember], teams: [SeriesTeam]) -> [GroupPlan] {
        let teamOrder = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.index) })
        let orderedMembers = members.sorted { lhs, rhs in
            let lhsTeam = lhs.teamID.flatMap { teamOrder[$0] } ?? .max
            let rhsTeam = rhs.teamID.flatMap { teamOrder[$0] } ?? .max
            if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
            return lhs.name.fullName < rhs.name.fullName
        }

        return stride(from: 0, to: orderedMembers.count, by: 4).map { start in
            let chunk = Array(orderedMembers[start..<min(start + 4, orderedMembers.count)])
            return GroupPlan(id: "group_\(start / 4)", memberIDs: chunk.map(\.id))
        }
    }

    private func createTeeGroups(
        roundID: String,
        groupPlans: [GroupPlan],
        holeRange: HoleRange,
        useSequentialStarts: Bool,
        scheduledTeeTime: Date? = nil
    ) async throws -> [TeeTimeGroup] {
        let plans = groupPlans.isPopulated ? groupPlans : [GroupPlan(id: "group_0", memberIDs: [])]
        let iso = ISO8601DateFormatter()
        var teeGroups: [TeeTimeGroup] = []
        for (index, _) in plans.enumerated() {
            let teeTime: String? = scheduledTeeTime.map { base in
                let offset = base.addingTimeInterval(Double(index) * 8 * 60)
                return iso.string(from: offset)
            }
            var group = TeeTimeGroup(
                id: HackersID.string(),
                index: index,
                startingHole: useSequentialStarts
                    ? TeeTimeGroup.sequentialStartingHole(forSequenceIndex: index, in: holeRange)
                    : holeRange.startHole,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
            group.teeTime = teeTime
            teeGroups.append(try await group.post().get())
        }
        return teeGroups
    }

    private func buildMemberAssignments(
        groupPlans: [GroupPlan],
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

    private func resolvedTeeBoxID(for member: SeriesMember, courseSegment: CourseSegment) -> String {
        if let teeBoxID = member.defaultTeeBoxID, teeBoxID.isPopulated {
            return teeBoxID
        }
        if let defaultTee = courseSegment.defaultTee, defaultTee.isPopulated {
            return defaultTee
        }
        return courseSegment.courseInfo.tees.first?.id ?? ""
    }
}
