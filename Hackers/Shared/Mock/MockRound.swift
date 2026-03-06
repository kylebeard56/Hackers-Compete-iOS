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
                    holeRange: HoleSegment.full18.holeRange,
                    defaultTee: "default_tee_1"
                )
            ]
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
        name: "Red Team",
        color: "red",
        index: 0,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let team2: RoundTeam = .init(
        id: "team_2",
        name: "Blue Team",
        color: "blue",
        index: 1,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: "round_1"
    )
    
    static let all: [RoundTeam] = [team1, team2]
}

enum MockTeeGroups {
    static let group1: TeeTimeGroup = .init(
        id: "group_1",
        index: 1,
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

// MARK: - Mock Completed Round (for Round History / RoundOutcomeView)

/// Completed round mock for testing Round History and outcome views.
enum MockCompletedRound {
    static func completedSnapshot(roundID: String) -> RoundSnapshot {
        let round = Round(
            id: roundID,
            shareCode: "MOCK",
            createdBy: "player_1",
            status: .complete,
            players: MockParticipants.all.compactMap(\.playerID),
            configuration: .init(
                primaryFormat: .strokePlay,
                courses: [
                    .init(
                        courseInfo: CourseInfo(
                            course: Course(from: MockCourses.mountainPark, with: "course_id"),
                            for: .full18
                        ),
                        holeRange: HoleSegment.full18.holeRange,
                        defaultTee: "default_tee_1"
                    )
                ]
            ),
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
        let participants = MockParticipants.all.map { p in
            RoundParticipant(
                id: p.id,
                userID: p.userID,
                playerID: p.playerID,
                name: p.name,
                teeBoxID: p.teeBoxID,
                originalHandicap: p.originalHandicap,
                adjustedHandicap: p.adjustedHandicap,
                teamID: p.teamID,
                groupID: p.groupID,
                teeOrder: p.teeOrder,
                isHost: p.isHost,
                createdAt: p.createdAt,
                lastUpdatedAt: p.lastUpdatedAt,
                parentID: roundID
            )
        }
        let teams = MockTeams.all.map { t in
            RoundTeam(
                id: t.id,
                name: t.name,
                color: t.color,
                index: t.index,
                createdAt: t.createdAt,
                lastUpdatedAt: t.lastUpdatedAt,
                parentID: roundID
            )
        }
        let teeGroups = MockTeeGroups.all.map { g in
            TeeTimeGroup(
                id: g.id,
                index: g.index,
                teeTime: g.teeTime,
                startingHole: g.startingHole,
                lastCompletedHole: 18,
                createdAt: g.createdAt,
                lastUpdatedAt: g.lastUpdatedAt,
                parentID: roundID
            )
        }
        let segment = RoundSegment(
            id: "segment_1",
            roundID: roundID,
            holeRange: .init(startHole: 1, endHole: 18),
            gameFormat: .strokePlay,
            scoringUnits: MockSegments.mainSegment.scoringUnits,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
        let scoring = makeFull18HoleScores(roundID: roundID)
        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: teams,
            teeGroups: teeGroups,
            segments: [segment],
            scoring: scoring
        )
    }

    private static func makeFull18HoleScores(roundID: String) -> [ScoreEntry] {
        let participantIDs = ["participant_1", "participant_2", "participant_3", "participant_4"]
        let unitIDs = ["unit_participant_1", "unit_participant_2", "unit_participant_3", "unit_participant_4"]
        // Par-like scores: 3,4,5,4,4,3,4,5,4 (front) + 4,4,3,5,4,4,3,4,5 (back)
        let parByHole = [3, 4, 5, 4, 4, 3, 4, 5, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5]
        var result: [ScoreEntry] = []
        for hole in 1...18 {
            let par = parByHole[hole - 1]
            for (idx, pid) in participantIDs.enumerated() {
                let offset = (hole + idx) % 4 // Deterministic: -1, 0, 1, 2
                let strokes = max(1, par + offset - 1)
                result.append(ScoreEntry(
                    id: "h\(hole)_s1_u\(idx + 1)",
                    holeNumber: hole,
                    segmentID: "segment_1",
                    groupID: "group_1",
                    scoringUnitID: unitIDs[idx],
                    participantIDs: [pid],
                    strokes: max(1, strokes),
                    pickedUp: false,
                    entryID: pid,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: roundID
                ))
            }
        }
        return result
    }
}

// MARK: - Mock Individual Scorecard (for IndividualScorecardView previews)

/// Scorecard variants for IndividualScorecardView previews.
enum MockIndividualScorecard {
    static func snapshot(
        roundID: String = "mock_scorecard",
        holeRange: HoleRange,
        scoredHoles: ClosedRange<Int>,
        participantID: String = "participant_1"
    ) -> RoundSnapshot {
        let base = MockCompletedRound.completedSnapshot(roundID: roundID)
        let courseInfo = CourseInfo(
            course: Course(from: MockCourses.mountainPark, with: "course_id"),
            for: holeRange.segment
        )
        let courseSegment = CourseSegment(
            courseInfo: courseInfo,
            holeRange: holeRange,
            defaultTee: courseInfo.tees.first?.id
        )
        var round = base.round
        round.configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            courses: [courseSegment]
        )
        let segment = RoundSegment(
            id: "segment_1",
            roundID: roundID,
            holeRange: holeRange,
            gameFormat: .strokePlay,
            scoringUnits: MockSegments.mainSegment.scoringUnits,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
        let unitIDs = ["unit_participant_1", "unit_participant_2", "unit_participant_3", "unit_participant_4"]
        let participantIDs = ["participant_1", "participant_2", "participant_3", "participant_4"]
        let parByHole = [3, 4, 5, 4, 4, 3, 4, 5, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5]
        var scoring: [ScoreEntry] = []
        for hole in scoredHoles {
            guard hole >= holeRange.startHole, hole <= holeRange.endHole else { continue }
            let par = parByHole[hole - 1]
            for (idx, pid) in participantIDs.enumerated() {
                let offset = (hole + idx) % 4
                let strokes = max(1, par + offset - 1)
                scoring.append(ScoreEntry(
                    id: "h\(hole)_s1_u\(idx + 1)",
                    holeNumber: hole,
                    segmentID: "segment_1",
                    groupID: "group_1",
                    scoringUnitID: unitIDs[idx],
                    participantIDs: [pid],
                    strokes: strokes,
                    pickedUp: false,
                    entryID: pid,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: roundID
                ))
            }
        }
        return RoundSnapshot(
            round: round,
            participants: base.participants,
            teams: base.teams,
            teeGroups: base.teeGroups,
            segments: [segment],
            scoring: scoring
        )
    }

    static var front9Full: RoundSnapshot {
        snapshot(
            holeRange: HoleRange(startHole: 1, endHole: 9),
            scoredHoles: 1...9
        )
    }

    static var back9Full: RoundSnapshot {
        snapshot(
            holeRange: HoleRange(startHole: 10, endHole: 18),
            scoredHoles: 10...18
        )
    }

    static var full18Full: RoundSnapshot {
        snapshot(
            holeRange: HoleRange(startHole: 1, endHole: 18),
            scoredHoles: 1...18
        )
    }

    static var full18Partial: RoundSnapshot {
        snapshot(
            holeRange: HoleRange(startHole: 1, endHole: 18),
            scoredHoles: 1...6
        )
    }
}
