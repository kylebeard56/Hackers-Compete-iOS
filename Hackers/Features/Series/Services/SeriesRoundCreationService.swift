//
//  SeriesRoundCreationService.swift
//  Hackers
//
//  Handles creating a live round from series data, carrying over
//  round settings, roster, teams, optional pods, and series mappings.
//

import Foundation

enum SeriesRoundCreationFailure: Error {
    case missingSession
    case missingCourse
    case invalidCourseData(String)
    case invalidCourseHandicaps([SeriesCourseHandicapValidationIssue])
    case writeFailed(String)

    var message: String {
        switch self {
        case .missingSession:
            return "Your player session could not be loaded. Reopen the series and try again."
        case .missingCourse:
            return "Select a course and tee before starting this round."
        case .invalidCourseData(let message):
            return message
        case .invalidCourseHandicaps(let issues):
            let details = issues.prefix(8).map(\.message).joined(separator: "\n")
            let remaining = max(0, issues.count - 8)
            return remaining > 0 ? "\(details)\n…and \(remaining) more." : details
        case .writeFailed:
            return "The round could not be created. No handicap snapshot was published."
        }
    }
}

@MainActor
struct SeriesRoundCreationService: Loggable {

    func createRoundFromSeries(
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        handicaps: [String: SeriesMemberHandicap],
        selectedHandicapScoreIDsByMemberID: [String: Set<String>] = [:],
        presenceStatusByMemberID: [String: RoundParticipantPresenceStatus] = [:],
        courseSegment overrideCourseSegment: CourseSegment? = nil
    ) async -> Result<String, SeriesRoundCreationFailure> {
        guard let user = await AppData.shared.user,
              let player = await AppData.shared.getPrimaryPlayer() else {
            return .failure(.missingSession)
        }

        let courseSegment: CourseSegment
        if let overrideCourseSegment {
            courseSegment = overrideCourseSegment
        } else {
            let validation = await SeriesRoundCourseHandicapAvailability.check(seriesRound.resolvedCourse(using: series))
            guard let resolved = validation.courseSegment else {
                addBreadcrumb(level: .error, message: "Series round course validation failed: \(validation.message)")
                addEvent("series.round_creation_failed", eventProps: [
                    "series_id": series.id, "series_round_id": seriesRound.id,
                    "reason": "course_validation"
                ])
                return .failure(.invalidCourseData(validation.message))
            }
            courseSegment = resolved
        }

        let effectiveMembers = SeriesRoundParticipationPolicy.effectiveMembers(
            members: members,
            plannedTeeGroups: seriesRound.plannedTeeGroups
        )

        let issues = SeriesRoundHandicapSetup.issues(
            series: series, round: seriesRound, members: effectiveMembers,
            handicaps: handicaps, course: courseSegment
        )
        guard issues.isEmpty else { return .failure(.invalidCourseHandicaps(issues)) }

        let shareCode = await FirebaseService.shared.getUniqueShareCode()
        let roundID = HackersID.string()
        let resolvedPlan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: seriesRound,
            members: effectiveMembers,
            teams: teams,
            pods: pods,
            courseSegment: courseSegment
        )
        var round = SeriesRoundCreationMapping.roundDraft(
            id: roundID,
            shareCode: shareCode,
            createdBy: user.id,
            series: series,
            members: effectiveMembers,
            seriesRound: seriesRound,
            courseSegment: courseSegment
        )

        do {
            round = try await round.post().get()

            let teamsPayload = SeriesRoundCreationMapping.buildRoundTeamsArray(
                roundID: roundID,
                seriesTeams: resolvedPlan.seriesTeamsForRound,
                createdAt: round.createdAt
            )
            let teeGroupsPayload = SeriesRoundPlanningService.teeGroupsPayload(
                roundID: roundID,
                plannedTeeGroups: resolvedPlan.plannedStructure.teeGroups,
                createdAt: round.createdAt
            )

            async let teamMappingsTask = batchPostRoundTeams(seriesTeams: resolvedPlan.seriesTeamsForRound, payload: teamsPayload)
            async let teeGroupsTask = batchPostTeeGroups(payload: teeGroupsPayload)
            let (teamMappings, teeGroups) = try await (teamMappingsTask, teeGroupsTask)

            let groupIDsByPlanID = Dictionary(
                uniqueKeysWithValues: zip(resolvedPlan.teeGroupPlans.map { $0.id }, teeGroups.map { $0.id })
            )
            let memberAssignments = SeriesRoundCreationMapping.buildMemberAssignments(
                groupPlans: resolvedPlan.teeGroupPlans,
                groupIDsByPlanID: groupIDsByPlanID
            )
            let plannedSeatsByMemberID = Dictionary(
                uniqueKeysWithValues: resolvedPlan.plannedStructure.teeGroups
                    .flatMap(\.seats)
                    .map { ($0.memberID, $0) }
            )

            if series.handicapConfig.isEnabled {
                let missingHandicapMemberIDs = SeriesRoundCreationMapping.membersMissingEffectiveHandicap(
                    members: effectiveMembers,
                    handicaps: handicaps
                )
                if missingHandicapMemberIDs.isPopulated {
                    addBreadcrumb(
                        level: .warning,
                        message: "Series round creation has members without effective handicaps",
                        parameters: [
                            "Series ID": series.id,
                            "Series Round ID": seriesRound.id,
                            "Member Count": "\(missingHandicapMemberIDs.count)"
                        ]
                    )
                    addEvent(
                        "series.round_creation_missing_handicaps",
                        eventProps: [
                            "series_id": series.id,
                            "series_round_id": seriesRound.id,
                            "member_count": missingHandicapMemberIDs.count
                        ]
                    )
                }
            }

            let participantsPayload = SeriesRoundCreationMapping.buildParticipantPayloads(
                members: effectiveMembers,
                roundID: roundID,
                teamMappings: teamMappings,
                memberAssignments: memberAssignments,
                handicaps: handicaps,
                maximumHandicap: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
                courseSegment: courseSegment,
                handicapEntryFormat: seriesRound.roundConfig.handicapEntryFormat,
                handicapStrokeBasis: series.handicapConfig.strokeBasis,
                selectedHandicapScoreIDsByMemberID: selectedHandicapScoreIDsByMemberID,
                roundHandicapInputs: seriesRound.handicapInputs,
                roundScoringStrokeBasis: seriesRound.roundConfig.handicapStrokeBasis,
                hostPlayerID: player.id,
                presenceStatusByMemberID: presenceStatusByMemberID,
                plannedSeatsByMemberID: plannedSeatsByMemberID
            )

            let createdParticipants = try await participantsPayload.batchPostChunked().get()
            let teeGroupSummaries = Round.teeGroupDisplayNamesByPlayerID(from: createdParticipants)
            if teeGroupSummaries.isPopulated {
                round.teeGroupDisplayNamesByPlayerID = teeGroupSummaries
                round.lastUpdatedAt = .init()
                round = try await round.put().get()
            }
            let populatedTeeGroupIDs = Set(createdParticipants.compactMap(\.groupID).filter(\.isPopulated))
            let retainedTeeGroups = teeGroups.filter { populatedTeeGroupIDs.contains($0.id) }
            for group in teeGroups where !populatedTeeGroupIDs.contains(group.id) {
                if case .failure(let error) = await group.delete() {
                    addBreadcrumb(level: .error, message: "series.round_creation tee group prune failed", error: error)
                    throw error
                }
            }

            var participantIDsBySeriesMemberID: [String: String] = [:]
            var createdMappings: [SeriesRoundMapping] = []
            for created in createdParticipants {
                guard let memberID = created.seriesMemberID else { continue }
                participantIDsBySeriesMemberID[memberID] = created.id
                createdMappings.append(
                    SeriesRoundCreationMapping.seriesRoundParticipantMapping(
                        seriesRoundID: seriesRound.id,
                        seriesID: series.id,
                        memberID: memberID,
                        participantID: created.id
                    )
                )
            }

            let scoringGroupsPayload = SeriesRoundCreationMapping.buildRoundScoringGroups(
                roundID: roundID,
                seriesRound: seriesRound,
                participants: createdParticipants,
                partnershipPlans: resolvedPlan.partnershipPlans,
                teeGroups: retainedTeeGroups
            )
            let createdScoringGroups = try await scoringGroupsPayload.batchPostChunked().get()
            let scoringUnits = SeriesRoundCreationMapping.buildScoringUnits(
                seriesRound: seriesRound,
                participants: createdParticipants,
                scoringGroups: createdScoringGroups,
                teamMappings: teamMappings
            )

            let roundMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
                seriesRound: seriesRound,
                matchupPlans: resolvedPlan.matchupPlans,
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
                competitionScope: resolvedPlan.competitionScope,
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
            return .success(roundID)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to create live round from series", error: error)
            addEvent(
                "series.round_creation_failed",
                eventProps: [
                    "series_id": series.id,
                    "series_round_id": seriesRound.id,
                    "reason": "write_failed"
                ]
            )
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    // MARK: - Course Resolution

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
