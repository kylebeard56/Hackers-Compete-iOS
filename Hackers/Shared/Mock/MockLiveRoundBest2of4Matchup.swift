//
//  MockLiveRoundBest2of4Matchup.swift
//  Hackers
//
//  Created by Kyle Beard on 3/10/26.
//

import SwiftUI

/// Best 2 of 4 matchup: Red vs Blue. Players split across tee groups for integrity accountability
/// — each group has 2 Red + 2 Blue so opponents verify each other's scores.
/// Group 1: Red (Kyle, Jake) + Blue (Drew, Nick)
/// Group 2: Red (Liam, Ethan) + Blue (Noah, Mason)
enum MockLiveRoundBest2of4Matchup {
    static let roundID = "mock_round_best2of4_matchup"
    private static let defaultTeeID = defaultCourseSegment.courseInfo.tees.first?.id ?? "default_tee_1"

    static let teams: [RoundTeam] = [
        .init(id: "team_red", name: "Red Team", color: "red", index: 0, createdAt: .init(), parentID: roundID),
        .init(id: "team_blue", name: "Blue Team", color: "blue", index: 1, createdAt: .init(), parentID: roundID),
    ]

    static let teeGroups: [TeeTimeGroup] = [
        .init(id: "group_1", index: 0, teeTime: "8:00 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_2", index: 1, teeTime: "8:08 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
    ]

    /// Group 1: 2 Red + 2 Blue. Group 2: 2 Red + 2 Blue. Integrated for accountability.
    static let participants: [RoundParticipant] = [
        makeParticipant(id: "p01", first: "Kyle", last: "Beard", teamID: "team_red", groupID: "group_1", teeOrder: 1, handicap: 8, isHost: true),
        makeParticipant(id: "p02", first: "Jake", last: "Palmer", teamID: "team_red", groupID: "group_1", teeOrder: 2, handicap: 12),
        makeParticipant(id: "p03", first: "Drew", last: "Collins", teamID: "team_blue", groupID: "group_1", teeOrder: 3, handicap: 15),
        makeParticipant(id: "p04", first: "Nick", last: "Rivera", teamID: "team_blue", groupID: "group_1", teeOrder: 4, handicap: 18),
        makeParticipant(id: "p05", first: "Liam", last: "Carter", teamID: "team_red", groupID: "group_2", teeOrder: 1, handicap: 6),
        makeParticipant(id: "p06", first: "Ethan", last: "Brooks", teamID: "team_red", groupID: "group_2", teeOrder: 2, handicap: 22),
        makeParticipant(id: "p07", first: "Noah", last: "Reeves", teamID: "team_blue", groupID: "group_2", teeOrder: 3, handicap: 10),
        makeParticipant(id: "p08", first: "Mason", last: "Harper", teamID: "team_blue", groupID: "group_2", teeOrder: 4, handicap: 25),
    ]

    static let matchups: [TeamMatchup] = [
        .init(id: "m1", teamIDs: ["team_red", "team_blue"]),
    ]

    static let segment: RoundSegment = .init(
        id: "segment_1",
        roundID: roundID,
        holeRange: .init(startHole: 1, endHole: 18),
        gameFormat: .strokePlay,
        templateID: FormatTemplateRegistry.strokePlay.id,
        scoringUnits: teams.map { .init(id: "unit_\($0.id)", owner: .team, ownerIDs: [$0.id], scoringMethod: .individual) },
        matchups: matchups,
        competitionScope: .matchup,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: roundID
    )

    /// Sample scores for first 4 holes so matchup results show meaningful data.
    static let scoring: [ScoreEntry] = {
        let segID = segment.id
        var entries: [ScoreEntry] = []
        let parByHole = [4, 3, 4, 5]  // holes 1–4
        // Red group 1: Kyle 4,4,4,5; Jake 5,4,5,6
        // Red group 2: Liam 4,3,4,5; Ethan 5,4,5,6
        // Blue group 1: Drew 4,3,5,5; Nick 5,4,4,6
        // Blue group 2: Noah 4,4,4,5; Mason 6,4,5,6
        let scores: [(String, [Int])] = [
            ("p01", [4, 4, 4, 5]),
            ("p02", [5, 4, 5, 6]),
            ("p03", [4, 3, 5, 5]),
            ("p04", [5, 4, 4, 6]),
            ("p05", [4, 3, 4, 5]),
            ("p06", [5, 4, 5, 6]),
            ("p07", [4, 4, 4, 5]),
            ("p08", [6, 4, 5, 6]),
        ]
        for (pid, strokes) in scores {
            let p = participants.first(where: { $0.id == pid })!
            for (idx, s) in strokes.enumerated() {
                let hole = idx + 1
                entries.append(ScoreEntry(
                    id: ScoreEntry.makeID(hole: hole, segment: segID, scoringUnit: pid),
                    holeNumber: hole,
                    segmentID: segID,
                    groupID: p.groupID ?? "",
                    scoringUnitID: pid,
                    participantIDs: [pid],
                    strokes: s,
                    entryID: pid,
                    parentID: roundID
                ))
            }
        }
        return entries
    }()

    static let snapshot: RoundSnapshot = .init(
        round: round,
        participants: participants,
        teams: teams,
        teeGroups: teeGroups,
        segments: [segment],
        scoring: scoring
    )

    static let round: Round = .init(
        id: roundID,
        shareCode: "B2OF4",
        createdBy: "player_p01",
        status: .live,
        players: participants.compactMap(\.playerID),
        configuration: .init(
            primaryFormat: .init(
                type: .strokePlay,
                configuration: .init(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlay),
            courses: [defaultCourseSegment],
            competitionScope: .matchup,
            teamScoring: .init(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate
        ),
        createdAt: .init(),
        lastUpdatedAt: .init()
    )

    private static func makeParticipant(
        id: String,
        first: String,
        last: String,
        teamID: String,
        groupID: String,
        teeOrder: Int,
        handicap: Int,
        isHost: Bool = false
    ) -> RoundParticipant {
        .init(
            id: id,
            userID: "user_\(id)",
            playerID: "player_\(id)",
            name: Name(first, last),
            teeBoxID: defaultTeeID,
            originalHandicap: handicap,
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID,
            teeOrder: teeOrder,
            isHost: isHost,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private static var defaultCourseSegment: CourseSegment {
        let courseInfo = CourseInfo(
            course: Course(from: MockCourses.mountainPark, with: "course_id"),
            for: .full18
        )
        return .init(
            courseInfo: courseInfo,
            holeRange: HoleSegment.full18.holeRange,
            defaultTee: courseInfo.tees.first?.id ?? "default_tee_1"
        )
    }
}
