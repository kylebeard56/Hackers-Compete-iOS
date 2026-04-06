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
        let competitionScope = SeriesRoundCreationMapping.resolvedCompetitionScope(for: seriesRound)
        var round = SeriesRoundCreationMapping.roundDraft(
            id: roundID,
            shareCode: shareCode,
            createdBy: user.id,
            series: series,
            members: members,
            seriesRound: seriesRound,
            courseSegment: courseSegment
        )

        do {
            round = try await round.post().get()

            let matchupPlans = SeriesRoundCreationMapping.resolvedMatchupPlans(
                seriesRound: seriesRound,
                teams: teams,
                members: members
            )
            let partnershipPlans = SeriesRoundCreationMapping.resolvedPartnershipPlans(
                seriesRound: seriesRound,
                teams: teams,
                pods: pods,
                members: members
            )

            let groupPlans = SeriesRoundCreationMapping.buildTeeGroupPlans(
                members: members,
                teams: teams,
                pods: pods,
                matchupPlans: matchupPlans,
                seriesRound: seriesRound
            )

            let scheduledTeeTime: Date? = seriesRound.scheduledAt.map {
                Date(timeIntervalSince1970: $0.unix)
            }

            let seriesTeamsForRound = seriesRound.roundConfig.teamAssignmentMode == .seriesTeams ? teams : []
            let teamsPayload = SeriesRoundCreationMapping.buildRoundTeamsArray(
                roundID: roundID,
                seriesTeams: seriesTeamsForRound,
                createdAt: round.createdAt
            )
            let teeGroupsPayload = SeriesRoundCreationMapping.buildTeeGroupsArray(
                roundID: roundID,
                groupPlans: groupPlans,
                holeRange: courseSegment.holeRange,
                useSequentialStarts: seriesRound.roundConfig.usesSequentialTeeStarts,
                scheduledTeeTime: scheduledTeeTime
            )

            async let teamMappingsTask = batchPostRoundTeams(seriesTeams: seriesTeamsForRound, payload: teamsPayload)
            async let teeGroupsTask = batchPostTeeGroups(payload: teeGroupsPayload)
            let (teamMappings, teeGroups) = try await (teamMappingsTask, teeGroupsTask)

            let groupIDsByPlanID = Dictionary(uniqueKeysWithValues: zip(groupPlans.map(\.id), teeGroups.map(\.id)))
            let memberAssignments = SeriesRoundCreationMapping.buildMemberAssignments(
                groupPlans: groupPlans,
                groupIDsByPlanID: groupIDsByPlanID
            )

            let participantsPayload = SeriesRoundCreationMapping.buildParticipantPayloads(
                members: members,
                roundID: roundID,
                teamMappings: teamMappings,
                memberAssignments: memberAssignments,
                handicaps: handicaps,
                courseSegment: courseSegment,
                hostPlayerID: player.id
            )

            let createdParticipants = try await participantsPayload.batchPostChunked().get()

            var participantIDsBySeriesMemberID: [String: String] = [:]
            var createdMappings: [SeriesRoundMapping] = []
            for (member, created) in zip(members, createdParticipants) {
                participantIDsBySeriesMemberID[member.id] = created.id
                createdMappings.append(
                    SeriesRoundCreationMapping.seriesRoundParticipantMapping(
                        seriesRoundID: seriesRound.id,
                        seriesID: series.id,
                        memberID: member.id,
                        participantID: created.id
                    )
                )
            }

            let scoringGroupsPayload = SeriesRoundCreationMapping.buildRoundScoringGroups(
                roundID: roundID,
                seriesRound: seriesRound,
                participants: createdParticipants,
                partnershipPlans: partnershipPlans,
                teeGroups: teeGroups
            )
            let createdScoringGroups = try await scoringGroupsPayload.batchPostChunked().get()
            let scoringUnits = SeriesRoundCreationMapping.buildScoringUnits(
                seriesRound: seriesRound,
                participants: createdParticipants,
                scoringGroups: createdScoringGroups
            )

            let roundMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
                seriesRound: seriesRound,
                matchupPlans: matchupPlans,
                teamMappings: teamMappings,
                participantIDsBySeriesMemberID: participantIDsBySeriesMemberID,
                scoringGroups: createdScoringGroups,
                participants: createdParticipants
            )

            let segment = SeriesRoundCreationMapping.buildRoundSegment(
                roundID: roundID,
                series: series,
                seriesRound: seriesRound,
                courseSegment: courseSegment,
                competitionScope: competitionScope,
                matchups: roundMatchups,
                scoringUnits: scoringUnits
            )
            _ = try await segment.post().get()

            for link in teamMappings.values {
                createdMappings.append(
                    SeriesRoundCreationMapping.seriesRoundTeamMapping(
                        seriesRoundID: seriesRound.id,
                        seriesID: series.id,
                        link: link
                    )
                )
            }

            for scoringGroup in createdScoringGroups {
                createdMappings.append(
                    contentsOf: SeriesRoundCreationMapping.seriesRoundScoreOwnerMappings(
                        seriesRoundID: seriesRound.id,
                        seriesID: series.id,
                        scoringGroup: scoringGroup,
                        participants: createdParticipants,
                        teamMappings: teamMappings
                    )
                )
            }

            if createdMappings.isPopulated {
                _ = try await createdMappings.batchPostChunked().get()
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

    private func batchPostRoundTeams(
        seriesTeams: [SeriesTeam],
        payload: [RoundTeam]
    ) async throws -> [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] {
        guard payload.isPopulated else { return [:] }
        let posted = try await payload.batchPostChunked().get()
        return SeriesRoundCreationMapping.teamMappingsFromPosted(seriesTeams: seriesTeams, posted: posted)
    }

    private func batchPostTeeGroups(payload: [TeeTimeGroup]) async throws -> [TeeTimeGroup] {
        try await payload.batchPostChunked().get()
    }

}
