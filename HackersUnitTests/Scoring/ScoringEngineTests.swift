//
//  ScoringEngineTests.swift
//  HackersTests
//
//  Created by Kyle Beard on 3/7/26.
//

@testable import Hackers
import XCTest

final class ScoringEngineTests: XCTestCase {

    // MARK: - Test Fixtures

    private func makeParticipant(id: String, name: String, handicap: Int = 0, teamID: String? = nil, groupID: String? = nil) -> RoundParticipant {
        RoundParticipant(
            id: id,
            name: Name(name, "Test"),
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID
        )
    }

    private func makeHoles(count: Int = 18) -> [Hole] {
        let pars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 4, 5]
        let handicaps = [7, 3, 15, 1, 9, 17, 5, 11, 13, 8, 16, 2, 10, 4, 18, 6, 12, 14]
        return (0..<count).map { i in
            Hole(number: i + 1, par: pars[i % pars.count], yardage: 350 + i * 10, handicap: handicaps[i % handicaps.count])
        }
    }

    private func makeSegment(holeRange: HoleRange = HoleRange(startHole: 1, endHole: 18), templateID: String? = nil) -> RoundSegment {
        RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: holeRange,
            templateID: templateID
        )
    }

    private func makeScoreEntry(participantID: String, holeNumber: Int, strokes: Int, segmentID: String = "seg1") -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: participantID),
            holeNumber: holeNumber,
            segmentID: segmentID,
            scoringUnitID: participantID,
            participantIDs: [participantID],
            strokes: strokes,
            pickedUp: false,
            entryID: participantID,
            parentID: "round1"
        )
    }

    // MARK: - Stroke Play Gross

    func testStrokePlayGross_4Players18Holes() {
        let holes = makeHoles()
        let totalPar = holes.reduce(0) { $0 + $1.par }
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
            makeParticipant(id: "p3", name: "Charlie"),
            makeParticipant(id: "p4", name: "Dave"),
        ]
        let segment = makeSegment()
        let template = FormatTemplateRegistry.strokePlayGross

        // Alice: all pars (total = 0 to par)
        // Bob: all bogeys (+18)
        // Charlie: all birdies (-18)
        // Dave: mixed (par on even holes, bogey on odd) = +9
        var scores: [ScoreEntry] = []
        for hole in holes {
            scores.append(makeScoreEntry(participantID: "p1", holeNumber: hole.number, strokes: hole.par))
            scores.append(makeScoreEntry(participantID: "p2", holeNumber: hole.number, strokes: hole.par + 1))
            scores.append(makeScoreEntry(participantID: "p3", holeNumber: hole.number, strokes: hole.par - 1))
            let daveStrokes = hole.number % 2 == 0 ? hole.par : hole.par + 1
            scores.append(makeScoreEntry(participantID: "p4", holeNumber: hole.number, strokes: daveStrokes))
        }

        let result = ScoringEngine.computeStrokePlay(
            scores: scores,
            participants: participants,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template
        )

        XCTAssertEqual(result.rows.count, 4)

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })

        XCTAssertEqual(rowMap["p1"]?.total, 0, "Alice should be even par")
        XCTAssertEqual(rowMap["p2"]?.total, 18, "Bob should be +18")
        XCTAssertEqual(rowMap["p3"]?.total, -18, "Charlie should be -18")
        XCTAssertEqual(rowMap["p4"]?.total, 9, "Dave should be +9")

        XCTAssertEqual(rowMap["p1"]?.holesPlayed, 18)
        XCTAssertEqual(rowMap["p3"]?.holesPlayed, 18)

        // Leaderboard order: Charlie < Alice < Dave < Bob
        let leaderboard = LeaderboardBuilder.buildIndividualLeaderboard(
            result: result, participants: participants
        )
        XCTAssertEqual(leaderboard.map(\.scoringUnitID), ["p3", "p1", "p4", "p2"])
        XCTAssertEqual(leaderboard[0].placeLabel, "1.")
        XCTAssertEqual(leaderboard[1].placeLabel, "2.")
    }

    // MARK: - Stroke Play Net

    func testStrokePlayNet_HandicapAdjustment() {
        let holes = makeHoles()
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 0),
            makeParticipant(id: "p2", name: "Bob", handicap: 18),
        ]
        let segment = makeSegment()
        let template = FormatTemplateRegistry.strokePlayNet

        // Both shoot all pars
        var scores: [ScoreEntry] = []
        for hole in holes {
            scores.append(makeScoreEntry(participantID: "p1", holeNumber: hole.number, strokes: hole.par))
            scores.append(makeScoreEntry(participantID: "p2", holeNumber: hole.number, strokes: hole.par))
        }

        let result = ScoringEngine.computeStrokePlay(
            scores: scores,
            participants: participants,
            segment: segment,
            holes: holes,
            basis: .net,
            template: template
        )

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })

        // Alice (0 hcp): net = gross, even par
        XCTAssertEqual(rowMap["p1"]?.total, 0, "Alice net should be even")
        // Bob (18 hcp): receives 1 stroke per hole, so net = gross - 1 per hole = -18
        XCTAssertEqual(rowMap["p2"]?.total, -18, "Bob net should be -18 with 18 handicap")
    }

    func testStrokePlayNet_HighHandicapAllocation() {
        let holes = makeHoles()
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 36),
        ]
        let segment = makeSegment()
        let template = FormatTemplateRegistry.strokePlayNet

        var scores: [ScoreEntry] = []
        for hole in holes {
            scores.append(makeScoreEntry(participantID: "p1", holeNumber: hole.number, strokes: hole.par + 2))
        }

        let result = ScoringEngine.computeStrokePlay(
            scores: scores,
            participants: participants,
            segment: segment,
            holes: holes,
            basis: .net,
            template: template
        )

        let row = result.rows.first!
        // 36 hcp = 2 strokes per hole, so net = (par+2) - 2 - par = 0 per hole
        XCTAssertEqual(row.total, 0, "36 handicap receiving 2 strokes per hole should net to even")
    }

    // MARK: - Stableford via Pipeline

    func testStableford_PointsComputation() {
        let holes = makeHoles()
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
        ]
        let segment = makeSegment()
        let template = FormatTemplateRegistry.stableford

        // Alice: eagle(-2)=4, birdie(-1)=3, par(0)=2, bogey(+1)=1, double(+2)=0 pattern
        let offsets = [-2, -1, 0, 1, 2, -1, 0, 1, 0, 0, -1, 0, 1, 0, -1, 0, 1, 0]
        let expectedPoints: [Double] = [4, 3, 2, 1, 0, 3, 2, 1, 2, 2, 3, 2, 1, 2, 3, 2, 1, 2]
        let totalExpected = expectedPoints.reduce(0, +) // 36

        var scores: [ScoreEntry] = []
        for (i, hole) in holes.enumerated() {
            scores.append(makeScoreEntry(participantID: "p1", holeNumber: hole.number, strokes: hole.par + offsets[i]))
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template
        )

        XCTAssertEqual(result.rows.count, 1)
        let row = result.rows[0]
        XCTAssertEqual(row.total, totalExpected, accuracy: 0.01, "Stableford total should be \(totalExpected)")
    }

    // MARK: - Best Ball via Pipeline

    func testBestBall_2v2() {
        let holes = makeHoles(count: 4)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "teamA"),
            makeParticipant(id: "p2", name: "Bob", teamID: "teamA"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "teamB"),
            makeParticipant(id: "p4", name: "Dave", teamID: "teamB"),
        ]
        let teams = [
            RoundTeam(id: "teamA", name: "Team A", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "teamB", name: "Team B", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 4))
        let template = FormatTemplateRegistry.bestBall

        // Hole 1 (par 4): Alice=3, Bob=5 → best=3 (-1); Charlie=4, Dave=6 → best=4 (0)
        // Hole 2 (par 4): Alice=5, Bob=3 → best=3 (-1); Charlie=3, Dave=5 → best=3 (-1)
        // Hole 3 (par 3): Alice=3, Bob=4 → best=3 (0); Charlie=2, Dave=5 → best=2 (-1)
        // Hole 4 (par 4): Alice=4, Bob=4 → best=4 (0); Charlie=5, Dave=3 → best=3 (-1)
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 3),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
            makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 5),
            makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 3),
            makeScoreEntry(participantID: "p3", holeNumber: 2, strokes: 3),
            makeScoreEntry(participantID: "p4", holeNumber: 2, strokes: 5),
            makeScoreEntry(participantID: "p1", holeNumber: 3, strokes: 3),
            makeScoreEntry(participantID: "p2", holeNumber: 3, strokes: 4),
            makeScoreEntry(participantID: "p3", holeNumber: 3, strokes: 2),
            makeScoreEntry(participantID: "p4", holeNumber: 3, strokes: 5),
            makeScoreEntry(participantID: "p1", holeNumber: 4, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 4, strokes: 4),
            makeScoreEntry(participantID: "p3", holeNumber: 4, strokes: 5),
            makeScoreEntry(participantID: "p4", holeNumber: 4, strokes: 3),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template
        )

        XCTAssertEqual(result.rows.count, 2, "Should have 2 team rows")
        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })

        // Team A: best ball per hole: 3+3+3+4 = 13, par = 4+4+3+4 = 15, so -2
        // Team B: best ball per hole: 4+3+2+3 = 12, par = 4+4+3+4 = 15, so -3
        XCTAssertNotNil(rowMap["teamA"])
        XCTAssertNotNil(rowMap["teamB"])
    }

    // MARK: - Best 2 of 4 via Pipeline

    func testBest2of4_TeamSelection() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t1"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t1"),
        ]
        let teams = [RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init())]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 1))
        var template = FormatTemplateRegistry.bestBall
        template.pipeline = [
            .select(RankSelection(includeRanks: [1, 2])),
            .reduce(Reduction(mode: .sum, scope: .perRound))
        ]

        // Scores: Alice=3, Bob=5, Charlie=4, Dave=6
        // Sorted: 3, 4, 5, 6. Best 2 = 3, 4 (rank 1 and 2)
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 3),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template
        )

        XCTAssertEqual(result.rows.count, 1, "Should have 1 team row")
        let row = result.rows[0]
        // Best 2 scores: 3(-1) + 4(0) = -1 total relative to par
        XCTAssertEqual(row.scoringUnitID, "t1")
    }

    // MARK: - Match Play via Pipeline

    func testMatchPlay_Individual() {
        let holes = makeHoles(count: 4)
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 4))
        let template = FormatTemplateRegistry.matchPlayIndividual

        // Hole 1: Alice=3, Bob=4 → Alice wins (1 pt)
        // Hole 2: Alice=5, Bob=4 → Bob wins (1 pt)
        // Hole 3: Alice=3, Bob=3 → Tie (0.5 pts each with half policy)
        // Hole 4: Alice=4, Bob=5 → Alice wins (1 pt)
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 3),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 5),
            makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "p1", holeNumber: 3, strokes: 3),
            makeScoreEntry(participantID: "p2", holeNumber: 3, strokes: 3),
            makeScoreEntry(participantID: "p1", holeNumber: 4, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 4, strokes: 5),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template
        )

        XCTAssertEqual(result.rows.count, 2)
        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })

        // Alice: 1 + 0 + 0.5 + 1 = 2.5
        // Bob: 0 + 1 + 0.5 + 0 = 1.5
        XCTAssertEqual(rowMap["p1"]?.total ?? 0, 2.5, accuracy: 0.01, "Alice should have 2.5 match play points")
        XCTAssertEqual(rowMap["p2"]?.total ?? 0, 1.5, accuracy: 0.01, "Bob should have 1.5 match play points")
    }

    // MARK: - Hole States

    func testHoleStates_PartiallyScored() {
        let holes = makeHoles(count: 3)
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 3))
        let template = FormatTemplateRegistry.strokePlayGross

        // Hole 1: both scored → complete
        // Hole 2: only Alice scored → partial
        // Hole 3: nobody scored → unscored
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 3),
        ]

        let result = ScoringEngine.computeStrokePlay(
            scores: scores,
            participants: participants,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template
        )

        XCTAssertEqual(result.holeStates[1], .complete)
        XCTAssertEqual(result.holeStates[2], .partial)
        XCTAssertEqual(result.holeStates[3], .unscored)
    }

    // MARK: - Strokes Received

    func testStrokesReceived_NoHandicap() {
        let received = ScoringEngine.strokesReceived(handicap: 0, holeHandicap: 1, useHandicaps: true)
        XCTAssertEqual(received, 0)
    }

    func testStrokesReceived_18Handicap() {
        // 18 hcp = 1 full stroke per hole (18/18 = 1, rem = 0)
        for holeHcp in 1...18 {
            let received = ScoringEngine.strokesReceived(handicap: 18, holeHandicap: holeHcp, useHandicaps: true)
            XCTAssertEqual(received, 1, "18 hcp should get 1 stroke on hole with handicap \(holeHcp)")
        }
    }

    func testStrokesReceived_9Handicap() {
        // 9 hcp = 0 full (9/18=0), rem = 9
        // Gets extra stroke on holes with handicap 1-9
        for holeHcp in 1...18 {
            let received = ScoringEngine.strokesReceived(handicap: 9, holeHandicap: holeHcp, useHandicaps: true)
            let expected = holeHcp <= 9 ? 1 : 0
            XCTAssertEqual(received, expected, "9 hcp on hole hcp \(holeHcp)")
        }
    }

    func testStrokesReceived_HandicapsDisabled() {
        let received = ScoringEngine.strokesReceived(handicap: 18, holeHandicap: 1, useHandicaps: false)
        XCTAssertEqual(received, 0, "Should return 0 when handicaps disabled")
    }
}
