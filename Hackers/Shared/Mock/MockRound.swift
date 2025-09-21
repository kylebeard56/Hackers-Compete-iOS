//
//  MockRound.swift
//  Hackers
//
//  Created by Kyle Beard on 9/16/25.
//

import SwiftUI

enum MockRoundSnapshot {
    static let strokePlaySnapshot: RoundSnapshot = .init(
        round: MockRound.strokePlay,
        participants: MockParticipants.all,
        teams: MockTeams.all,
        teeGroups: MockTeeGroups.all,
        segments: MockSegments.all,
        scoring: MockScoreEntry.firstTwoHoles
    )
}

enum MockRound {
    static let strokePlay: Round = .init(
        id: "round_1",
        shareCode: "ABC123",
        createdBy: "player_1",
        status: .lobby,
        players: ["player_1"],
        configuration: .init(
            primaryFormat: .strokePlay,
            courses: [
                .init(
                    courseInfo: CourseInfo(
                        course: Course(from: MockCourses.mountainPark, with: "course_id"),
                        for: .full18
                    ),
                    holeRange: HoleSegment.full18.holeRange
                )
            ],
            defaultTee: "default_tee_1"
        ),
        createdAt: .init(),
        lastUpdatedAt: .init()
    )
}

enum MockParticipants {
    static let participant1: RoundParticipant = .init(
        id: "participant_1",
        userID: "user_1",
        playerID: "player_1",
        name: Name("John", "Smith"),
        teeBoxID: "default_tee_1",
        originalHandicap: 12,
        adjustedHandicap: 12,
        teamID: "team_1",
        groupID: "group_1",
        teeOrder: 1,
        isHost: true,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let participant2: RoundParticipant = .init(
        id: "participant_2",
        userID: "user_2",
        playerID: "player_2",
        name: Name("Mike", "Johnson"),
        teeBoxID: "default_tee_1",
        originalHandicap: 8,
        adjustedHandicap: 8,
        teamID: "team_1",
        groupID: "group_1",
        teeOrder: 2,
        isHost: false,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let participant3: RoundParticipant = .init(
        id: "participant_3",
        userID: "user_3",
        playerID: "player_3",
        name: Name("Sarah", "Wilson"),
        teeBoxID: "default_tee_1",
        originalHandicap: 15,
        adjustedHandicap: 15,
        teamID: "team_2",
        groupID: "group_1",
        teeOrder: 3,
        isHost: false,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let participant4: RoundParticipant = .init(
        id: "participant_4",
        userID: "user_4",
        playerID: "player_4",
        name: Name("Tom", "Davis"),
        teeBoxID: "default_tee_1",
        originalHandicap: 20,
        adjustedHandicap: 20,
        teamID: "team_2",
        groupID: "group_1",
        teeOrder: 4,
        isHost: false,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let all: [RoundParticipant] = [participant1, participant2, participant3, participant4]
}

enum MockTeams {
    static let team1: RoundTeam = .init(
        id: "team_1",
        name: "Team Alpha",
        color: .blue,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let team2: RoundTeam = .init(
        id: "team_2",
        name: "Team Bravo",
        color: .red,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let all: [RoundTeam] = [team1, team2]
}

enum MockTeeGroups {
    static let group1: TeeTimeGroup = .init(
        id: "group_1",
        teeTime: "2025-09-16T08:00:00Z",
        startingHole: 1,
        lastCompletedHole: 0,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let all: [TeeTimeGroup] = [group1]
}

enum MockSegments {
    static let mainSegment: RoundSegment = .init(
        id: "segment_1",
        roundID: "round_1",
        holeRange: .init(startHole: 1, endHole: 18),
        gameFormat: .strokePlay,
        scoringUnits: [
            .init(
                id: "unit_participant_1",
                owner: .participant,
                ownerIDs: ["participant_1"],
                scoringMethod: .individual
            ),
            .init(
                id: "unit_participant_2",
                owner: .participant,
                ownerIDs: ["participant_2"],
                scoringMethod: .individual
            ),
            .init(
                id: "unit_participant_3",
                owner: .participant,
                ownerIDs: ["participant_3"],
                scoringMethod: .individual
            ),
            .init(
                id: "unit_participant_4",
                owner: .participant,
                ownerIDs: ["participant_4"],
                scoringMethod: .individual
            )
        ],
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let all: [RoundSegment] = [mainSegment]
}

enum MockScoreEntry {
    
    // MARK: - Scores for Hole 1
    
    static let hole1Participant1: ScoreEntry = .init(
        id: "h1_s1_u1",
        holeNumber: 1,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_1",
        participantIDs: ["participant_1"],
        strokes: 4,
        pickedUp: false,
        entryID: "participant_1",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let hole1Participant2: ScoreEntry = .init(
        id: "h1_s1_u2",
        holeNumber: 1,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_2",
        participantIDs: ["participant_2"],
        strokes: 3,
        pickedUp: false,
        entryID: "participant_2",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let hole1Participant3: ScoreEntry = .init(
        id: "h1_s1_u3",
        holeNumber: 1,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_3",
        participantIDs: ["participant_3"],
        strokes: 5,
        pickedUp: false,
        entryID: "participant_3",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let hole1Participant4: ScoreEntry = .init(
        id: "h1_s1_u4",
        holeNumber: 1,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_4",
        participantIDs: ["participant_4"],
        strokes: 6,
        pickedUp: false,
        entryID: "participant_4",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    // MARK: - Scores for Hole 2
    
    static let hole2Participant1: ScoreEntry = .init(
        id: "h2_s1_u1",
        holeNumber: 2,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_1",
        participantIDs: ["participant_1"],
        strokes: 3,
        pickedUp: false,
        entryID: "participant_1",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let hole2Participant2: ScoreEntry = .init(
        id: "h2_s1_u2",
        holeNumber: 2,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_2",
        participantIDs: ["participant_2"],
        strokes: 4,
        pickedUp: false,
        entryID: "participant_2",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let hole2Participant3: ScoreEntry = .init(
        id: "h2_s1_u3",
        holeNumber: 2,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_3",
        participantIDs: ["participant_3"],
        strokes: 4,
        pickedUp: false,
        entryID: "participant_3",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let hole2Participant4: ScoreEntry = .init(
        id: "h2_s1_u4",
        holeNumber: 2,
        segmentID: "segment_1",
        groupID: "group_1",
        scoringUnitID: "unit_participant_4",
        participantIDs: ["participant_4"],
        strokes: 5,
        pickedUp: false,
        entryID: "participant_4",
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let firstTwoHoles: [ScoreEntry] = [
        hole1Participant1, hole1Participant2, hole1Participant3, hole1Participant4,
        hole2Participant1, hole2Participant2, hole2Participant3, hole2Participant4
    ]
}
