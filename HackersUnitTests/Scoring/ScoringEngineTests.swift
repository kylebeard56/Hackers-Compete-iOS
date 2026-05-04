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

    private func makeRelativeScoreEntry(
        participantID: String,
        holeNumber: Int,
        relativeToPar: Int,
        segmentID: String = "seg1"
    ) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: participantID),
            holeNumber: holeNumber,
            segmentID: segmentID,
            scoringUnitID: participantID,
            participantIDs: [participantID],
            strokes: nil,
            relativeToPar: relativeToPar,
            entryMode: .relativeToPar,
            pickedUp: false,
            entryID: participantID,
            parentID: "round1"
        )
    }

    private func makeSharedScoreEntry(
        scoringUnitID: String,
        participantIDs: [String],
        holeNumber: Int,
        strokes: Int,
        segmentID: String = "seg1"
    ) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: scoringUnitID),
            holeNumber: holeNumber,
            segmentID: segmentID,
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            strokes: strokes,
            pickedUp: false,
            entryID: participantIDs.first ?? scoringUnitID,
            parentID: "round1"
        )
    }

    private func makePartnership(id: String, teamID: String, memberIDs: [String]) -> RoundScoringGroup {
        RoundScoringGroup(
            id: id,
            teamID: teamID,
            teeGroupID: "g1",
            kind: .partnership,
            memberIDs: memberIDs,
            label: nil,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "round1"
        )
    }

    // MARK: - Stroke Play Gross

    func testStrokePlayGross_4Players18Holes() {
        let holes = makeHoles()
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

    func testStrokePlayFriendlyRelativeToPar_SumsRelativeValuesAndDerivesGrossStrokes() {
        let holes = makeHoles(count: 3)
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 3))
        let template = FormatTemplateRegistry.strokePlayGross
        let scores = [
            makeRelativeScoreEntry(participantID: "p1", holeNumber: 1, relativeToPar: 0),
            makeRelativeScoreEntry(participantID: "p1", holeNumber: 2, relativeToPar: -1),
            makeRelativeScoreEntry(participantID: "p1", holeNumber: 3, relativeToPar: 2),
        ]

        let result = ScoringEngine.computeStrokePlay(
            scores: scores,
            participants: participants,
            segment: segment,
            holes: holes,
            basis: .gross,
            scoreInputMode: .friendlyRelativeToPar,
            template: template
        )

        let row = result.rows[0]
        XCTAssertEqual(row.total, 1, accuracy: 0.01)
        XCTAssertEqual(row.holesPlayed, 3)
        XCTAssertEqual(row.holeValues[1]?.rawStrokes, 4)
        XCTAssertEqual(row.holeValues[2]?.rawStrokes, 3)
        XCTAssertEqual(row.holeValues[3]?.rawStrokes, 5)
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

    func testStableford_FriendlyRelativeToParUsesResolvedValues() {
        let holes = makeHoles(count: 5)
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 5))
        let template = FormatTemplateRegistry.stableford
        let offsets = [-2, -1, 0, 1, 2]
        let scores = offsets.enumerated().map { index, relative in
            makeRelativeScoreEntry(participantID: "p1", holeNumber: index + 1, relativeToPar: relative)
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            scoreInputMode: .friendlyRelativeToPar,
            template: template
        )

        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0].total, 10, accuracy: 0.01)
    }

    // MARK: - Vegas

    func testVegas_ExactPairs_GrossAccrual() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2))
        let template = FormatTemplateRegistry.vegas

        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
            makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 3),
            makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "p3", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "p4", holeNumber: 2, strokes: 5),
        ]

        let result = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template,
            vegasMode: .exactPair,
            selectionRule: .best2,
            selectionScope: .perHole
        )

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["t1"]?.total ?? 0, 79, accuracy: 0.01)
        XCTAssertEqual(rowMap["t2"]?.total ?? 0, 101, accuracy: 0.01)
        XCTAssertEqual(rowMap["t1"]?.holeValues[1]?.vegasPairs?.first?.composite, 45)
        XCTAssertEqual(rowMap["t2"]?.holeValues[1]?.vegasPairs?.first?.composite, 56)
    }

    func testVegas_ExactPairs_NetUsesAdjustedScores() {
        let holes = makeHoles()
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 0, teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", handicap: 0, teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", handicap: 18, teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", handicap: 18, teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 18))
        let template = FormatTemplateRegistry.vegas

        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 6),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 7),
        ]

        let result = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .net,
            template: template,
            vegasMode: .exactPair,
            selectionRule: .best2,
            selectionScope: .perHole
        )

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["t1"]?.total ?? 0, 45, accuracy: 0.01)
        XCTAssertEqual(rowMap["t2"]?.total ?? 0, 56, accuracy: 0.01)
    }

    func testVegas_FriendlyRelativeToParUsesResolvedRelativeValues() {
        let holes = makeHoles(count: 1)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 1))
        let template = FormatTemplateRegistry.vegas
        let scores = [
            makeRelativeScoreEntry(participantID: "p1", holeNumber: 1, relativeToPar: -1),
            makeRelativeScoreEntry(participantID: "p2", holeNumber: 1, relativeToPar: 0),
            makeRelativeScoreEntry(participantID: "p3", holeNumber: 1, relativeToPar: 0),
            makeRelativeScoreEntry(participantID: "p4", holeNumber: 1, relativeToPar: 1),
        ]

        let result = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            scoreInputMode: .friendlyRelativeToPar,
            template: template,
            vegasMode: .exactPair,
            selectionRule: .best2,
            selectionScope: .perHole
        )

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["t1"]?.total ?? 0, -10, accuracy: 0.01)
        XCTAssertEqual(rowMap["t2"]?.total ?? 0, 1, accuracy: 0.01)
        XCTAssertEqual(rowMap["t1"]?.holeValues[1]?.vegasPairs?.first?.lowStroke, -1)
        XCTAssertEqual(rowMap["t1"]?.holeValues[1]?.vegasPairs?.first?.highStroke, 0)
    }

    func testVegas_PartnershipAggregate_SumsPairTotals() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t1"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t1"),
            makeParticipant(id: "p5", name: "Eve", teamID: "t2"),
            makeParticipant(id: "p6", name: "Frank", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair1", teamID: "t1", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair2", teamID: "t1", memberIDs: ["p3", "p4"])
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 1))
        let template = FormatTemplateRegistry.vegas

        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
            makeScoreEntry(participantID: "p5", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p6", holeNumber: 1, strokes: 4),
        ]

        let result = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template,
            vegasMode: .partnershipAggregate,
            selectionRule: .best2,
            selectionScope: .perHole
        )

        let teamOne = result.rows.first(where: { $0.scoringUnitID == "t1" })
        XCTAssertEqual(teamOne?.total ?? 0, 101, accuracy: 0.01)
        XCTAssertEqual(teamOne?.holeValues[1]?.vegasPairs?.count, 2)
    }

    func testVegas_SelectedPairSupportsBestWorstModes() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t1"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
            makeParticipant(id: "p5", name: "Eve", teamID: "t2"),
            makeParticipant(id: "p6", name: "Frank", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 1))
        let template = FormatTemplateRegistry.vegas
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 7),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 3),
            makeScoreEntry(participantID: "p5", holeNumber: 1, strokes: 6),
            makeScoreEntry(participantID: "p6", holeNumber: 1, strokes: 8),
        ]

        let best2 = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template,
            vegasMode: .selectedPair,
            selectionRule: .best2,
            selectionScope: .perHole
        )
        XCTAssertEqual(best2.rows.first(where: { $0.scoringUnitID == "t1" })?.total ?? 0, 45, accuracy: 0.01)

        let worst2 = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template,
            vegasMode: .selectedPair,
            selectionRule: .worst2,
            selectionScope: .perHole
        )
        XCTAssertEqual(worst2.rows.first(where: { $0.scoringUnitID == "t1" })?.total ?? 0, 57, accuracy: 0.01)

        let bestAndWorst = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template,
            vegasMode: .selectedPair,
            selectionRule: .bestAndWorst,
            selectionScope: .perHole
        )
        XCTAssertEqual(bestAndWorst.rows.first(where: { $0.scoringUnitID == "t1" })?.total ?? 0, 47, accuracy: 0.01)
    }

    func testVegas_PartialHoleDoesNotCountIncompletePair() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 1))
        let template = FormatTemplateRegistry.vegas

        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
        ]

        let result = ScoringEngine.computeVegas(
            scores: scores,
            participants: participants,
            teams: teams,
            scoringGroups: [],
            segment: segment,
            holes: holes,
            basis: .gross,
            template: template,
            vegasMode: .exactPair,
            selectionRule: .best2,
            selectionScope: .perHole
        )

        XCTAssertEqual(result.rows.first(where: { $0.scoringUnitID == "t1" })?.total ?? 0, 45, accuracy: 0.01)
        XCTAssertEqual(result.rows.first(where: { $0.scoringUnitID == "t2" })?.total ?? 0, 0, accuracy: 0.01)
        XCTAssertNil(result.rows.first(where: { $0.scoringUnitID == "t2" })?.holeValues[1])
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

    // MARK: - Shared Score Owners

    func testSharedScoreOwnerMatchupUsesCanonicalScoringUnitRows() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 1),
            templateID: FormatTemplateRegistry.captainsChoice.id,
            scoringUnits: scoringGroups.map {
                ScoringUnit(id: $0.id, owner: .scoreOwner, ownerIDs: $0.memberIDs, scoringMethod: .aggregate)
            },
            matchups: [
                TeamMatchup(
                    id: "match1",
                    teamIDs: [],
                    scoreOwnerIDs: ["pair_red", "pair_blue"],
                    scoreOwnerScope: .partnership,
                    mode: .scoreOwner
                )
            ],
            competitionScope: .matchup
        )
        let scores = [
            makeSharedScoreEntry(scoringUnitID: "pair_red", participantIDs: ["p1", "p2"], holeNumber: 1, strokes: 4),
            makeSharedScoreEntry(scoringUnitID: "pair_blue", participantIDs: ["p3", "p4"], holeNumber: 1, strokes: 5),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.captainsChoice,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        XCTAssertNil(result.matchupResults[0].isPointsFormat)
        let rowMap = Dictionary(uniqueKeysWithValues: result.matchupResults[0].rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["pair_red"]?.owner, .scoreOwner)
        XCTAssertEqual(rowMap["pair_red"]?.participantIDs, ["p1", "p2"])
        XCTAssertEqual(rowMap["pair_red"]?.total, 0)
        XCTAssertEqual(rowMap["pair_red"]?.holesPlayed, 1)
        XCTAssertEqual(rowMap["pair_blue"]?.participantIDs, ["p3", "p4"])
        XCTAssertEqual(rowMap["pair_blue"]?.total, 1)
        XCTAssertEqual(rowMap["pair_blue"]?.holesPlayed, 1)
    }

    func testTeamMatchupHoleByHolePointsUsesSelectedBestScorePerHole() throws {
        let holes = [
            Hole(number: 1, par: 4, yardage: 400, handicap: 1),
            Hole(number: 2, par: 4, yardage: 410, handicap: 2),
            Hole(number: 3, par: 4, yardage: 420, handicap: 3),
        ]
        let participants = [
            makeParticipant(id: "r1", name: "Red One", teamID: "red"),
            makeParticipant(id: "r2", name: "Red Two", teamID: "red"),
            makeParticipant(id: "b1", name: "Blue One", teamID: "blue"),
            makeParticipant(id: "b2", name: "Blue Two", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 3),
            matchups: [TeamMatchup(id: "match1", teamIDs: ["red", "blue"], mode: .team)],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "r1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "r2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "b1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "b2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "r1", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "r2", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "b1", holeNumber: 2, strokes: 5),
            makeScoreEntry(participantID: "b2", holeNumber: 2, strokes: 6),
            makeScoreEntry(participantID: "r1", holeNumber: 3, strokes: 5),
            makeScoreEntry(participantID: "r2", holeNumber: 3, strokes: 6),
            makeScoreEntry(participantID: "b1", holeNumber: 3, strokes: 4),
            makeScoreEntry(participantID: "b2", holeNumber: 3, strokes: 5),
        ]

        let result = ScoringEngine.computeWithTeamScoring(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlay,
            teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
            matchupResolutionStyle: .roundAggregate,
            matchupScoringStyle: .holeByHolePoints
        )

        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        XCTAssertEqual(matchupResult.isPointsFormat, true)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["red"]?.holeValues[1]?.points, 0.5)
        XCTAssertEqual(rowMap["blue"]?.holeValues[1]?.points, 0.5)
        XCTAssertEqual(rowMap["red"]?.holeValues[2]?.points, 1)
        XCTAssertEqual(rowMap["blue"]?.holeValues[2]?.points, 0)
        XCTAssertEqual(rowMap["red"]?.holeValues[3]?.points, 0)
        XCTAssertEqual(rowMap["blue"]?.holeValues[3]?.points, 1)
        XCTAssertEqual(rowMap["red"]?.total, 1.5)
        XCTAssertEqual(rowMap["blue"]?.total, 1.5)
    }

    func testTeamMatchupAggregateRoundTotalKeepsSelectedStrokeTotals() throws {
        let holes = [
            Hole(number: 1, par: 4, yardage: 400, handicap: 1),
            Hole(number: 2, par: 4, yardage: 410, handicap: 2),
            Hole(number: 3, par: 4, yardage: 420, handicap: 3),
        ]
        let participants = [
            makeParticipant(id: "r1", name: "Red One", teamID: "red"),
            makeParticipant(id: "r2", name: "Red Two", teamID: "red"),
            makeParticipant(id: "b1", name: "Blue One", teamID: "blue"),
            makeParticipant(id: "b2", name: "Blue Two", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 3),
            matchups: [TeamMatchup(id: "match1", teamIDs: ["red", "blue"], mode: .team)],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "r1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "r2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "b1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "b2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "r1", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "r2", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "b1", holeNumber: 2, strokes: 5),
            makeScoreEntry(participantID: "b2", holeNumber: 2, strokes: 6),
            makeScoreEntry(participantID: "r1", holeNumber: 3, strokes: 5),
            makeScoreEntry(participantID: "r2", holeNumber: 3, strokes: 6),
            makeScoreEntry(participantID: "b1", holeNumber: 3, strokes: 4),
            makeScoreEntry(participantID: "b2", holeNumber: 3, strokes: 5),
        ]

        let result = ScoringEngine.computeWithTeamScoring(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlay,
            teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
            matchupResolutionStyle: .roundAggregate,
            matchupScoringStyle: .aggregateRoundTotal
        )

        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        XCTAssertEqual(matchupResult.isPointsFormat, false)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["red"]?.total, 1)
        XCTAssertEqual(rowMap["blue"]?.total, 0)
    }

    func testSharedScoreOwnerMatchupResolvesOpaqueScoringUnitRowsToPairSides() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let matchup = TeamMatchup(
            id: "match1",
            teamIDs: [],
            scoreOwnerIDs: ["pair_red", "pair_blue"],
            scoreOwnerScope: .partnership,
            mode: .scoreOwner
        )
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 1),
            templateID: FormatTemplateRegistry.captainsChoice.id,
            scoringUnits: [
                ScoringUnit(id: "unit_red", owner: .scoreOwner, ownerIDs: ["p1", "p2"], scoringMethod: .aggregate),
                ScoringUnit(id: "unit_blue", owner: .scoreOwner, ownerIDs: ["p3", "p4"], scoringMethod: .aggregate),
            ],
            matchups: [matchup],
            competitionScope: .matchup
        )
        let scores = [
            makeSharedScoreEntry(scoringUnitID: "unit_red", participantIDs: ["p1", "p2"], holeNumber: 1, strokes: 4),
            makeSharedScoreEntry(scoringUnitID: "unit_blue", participantIDs: ["p3", "p4"], holeNumber: 1, strokes: 5),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.captainsChoice,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        XCTAssertEqual(Set(result.matchupResults[0].rows.map(\.scoringUnitID)), Set(["pair_red", "pair_blue"]))
        let rowMap = Dictionary(uniqueKeysWithValues: result.matchupResults[0].rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["pair_red"]?.total, 0)
        XCTAssertEqual(rowMap["pair_blue"]?.total, 1)
        XCTAssertEqual(rowMap["pair_red"]?.participantIDs, ["p1", "p2"])
        XCTAssertEqual(rowMap["pair_blue"]?.participantIDs, ["p3", "p4"])
    }

    func testIndividualScoreOwnerMatchupInfersMatchupSideBestOnePerHole() {
        let holes = [
            Hole(number: 1, par: 4, yardage: 400, handicap: 1),
            Hole(number: 2, par: 4, yardage: 410, handicap: 2)
        ]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 2),
            templateID: FormatTemplateRegistry.strokePlay.id,
            matchups: [
                TeamMatchup(
                    id: "match1",
                    teamIDs: [],
                    scoreOwnerIDs: ["pair_red", "pair_blue"],
                    scoreOwnerScope: .partnership,
                    mode: .scoreOwner
                )
            ],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 9),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
            makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 8),
            makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "p3", holeNumber: 2, strokes: 3),
            makeScoreEntry(participantID: "p4", holeNumber: 2, strokes: 9),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlay,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .individual,
            teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
            scoringGroups: scoringGroups
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        let rowMap = Dictionary(uniqueKeysWithValues: result.matchupResults[0].rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["pair_red"]?.holeValues[1]?.points, 0)
        XCTAssertEqual(rowMap["pair_blue"]?.holeValues[1]?.points, 1)
        XCTAssertEqual(rowMap["pair_red"]?.holeValues[2]?.points, 0)
        XCTAssertEqual(rowMap["pair_blue"]?.holeValues[2]?.points, -1)
        XCTAssertEqual(rowMap["pair_red"]?.total, 0)
        XCTAssertEqual(rowMap["pair_blue"]?.total, 0)
        XCTAssertEqual(Set(rowMap["pair_red"]?.countingParticipantIDs ?? []), Set(["p1", "p2"]))
        XCTAssertEqual(Set(rowMap["pair_blue"]?.countingParticipantIDs ?? []), Set(["p3"]))
    }

    func testIndividualScoreOwnerMatchupSupportsBestTwoPerPairPerHole() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 1),
            matchups: [
                TeamMatchup(
                    id: "match1",
                    teamIDs: [],
                    scoreOwnerIDs: ["pair_red", "pair_blue"],
                    scoreOwnerScope: .partnership,
                    mode: .scoreOwner
                )
            ],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 9),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlay,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .individual,
            teamScoring: .init(mode: .bestN, count: 2, scope: .perHole),
            scoringGroups: scoringGroups
        )

        let rowMap = Dictionary(uniqueKeysWithValues: (result.matchupResults.first?.rows ?? []).map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["pair_red"]?.total, 5)
        XCTAssertEqual(rowMap["pair_blue"]?.total, 3)
        XCTAssertEqual(Set(rowMap["pair_red"]?.countingParticipantIDs ?? []), Set(["p1", "p2"]))
        XCTAssertEqual(Set(rowMap["pair_blue"]?.countingParticipantIDs ?? []), Set(["p3", "p4"]))
    }

    func testSnapshotIndividualScoreOwnerPairMatchupSelectsInsideEachSide() throws {
        let holes = [
            Hole(number: 1, par: 4, yardage: 400, handicap: 1),
            Hole(number: 2, par: 4, yardage: 410, handicap: 2)
        ]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let matchup = TeamMatchup(
            id: "match1",
            teamIDs: [],
            scoreOwnerIDs: ["pair_red", "pair_blue"],
            scoreOwnerScope: .partnership,
            mode: .scoreOwner
        )
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlay),
            competitionScope: .matchup,
            teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
            scoreOwnerScope: .individual
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: [
                makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
                makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 9),
                makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
                makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
                makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 8),
                makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 4),
                makeScoreEntry(participantID: "p3", holeNumber: 2, strokes: 3),
                makeScoreEntry(participantID: "p4", holeNumber: 2, strokes: 9),
            ]
        )

        XCTAssertEqual(snapshot.expectedMatchupMode, .partnership)
        XCTAssertFalse(ScoringEngine.shouldUseTeamAggregateScoring(snapshot: snapshot, segment: segment))

        let result = ScoringEngine.computeSnapshotResult(snapshot: snapshot, segment: segment, holes: holes, basis: .gross)
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })

        XCTAssertEqual(rowMap["pair_red"]?.total, 0)
        XCTAssertEqual(rowMap["pair_blue"]?.total, 0)
        XCTAssertEqual(Set(rowMap["pair_red"]?.countingParticipantIDs ?? []), Set(["p1", "p2"]))
        XCTAssertEqual(Set(rowMap["pair_blue"]?.countingParticipantIDs ?? []), Set(["p3"]))
    }

    func testPairMatchPlaySelectionUsesLowScoresBeforeCompare() throws {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 1),
            matchups: [
                TeamMatchup(
                    id: "match1",
                    teamIDs: [],
                    scoreOwnerIDs: ["pair_red", "pair_blue"],
                    scoreOwnerScope: .partnership,
                    mode: .scoreOwner
                )
            ],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 9),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 6),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.matchPlayIndividual,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .individual,
            teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
            scoringGroups: scoringGroups
        )

        let rowMap = Dictionary(uniqueKeysWithValues: try XCTUnwrap(result.matchupResults.first).rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["pair_red"]?.total, 1)
        XCTAssertEqual(rowMap["pair_blue"]?.total, 0)
    }

    func testSharedScoreOwnerDirectFallbackUsesNetScrambleAllowance() {
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 36, teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", handicap: 36, teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", handicap: 0, teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", handicap: 0, teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let matchup = TeamMatchup(
            id: "match1",
            teamIDs: [],
            scoreOwnerIDs: ["pair_red", "pair_blue"],
            scoreOwnerScope: .partnership,
            mode: .scoreOwner
        )
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 1),
            templateID: FormatTemplateRegistry.captainsChoice.id,
            matchups: [matchup],
            competitionScope: .matchup
        )
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.captainsChoice),
            competitionScope: .matchup,
            scoreOwnerScope: .partnership,
            sharedScoreHandicapConfig: .scramble2Player
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: [
                makeSharedScoreEntry(scoringUnitID: "pair_red", participantIDs: ["p1", "p2"], holeNumber: 1, strokes: 5),
                makeSharedScoreEntry(scoringUnitID: "pair_blue", participantIDs: ["p3", "p4"], holeNumber: 1, strokes: 4),
            ]
        )
        let result = ScoringResult(rows: [], holeStates: [:], template: FormatTemplateRegistry.captainsChoice, matchupResults: [])
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Match 1", rows: [])

        let presentation = MatchupResultPresentationBuilder.build(
            snapshot: snapshot,
            result: result,
            section: section,
            basis: .net
        )

        XCTAssertEqual(presentation.side(id: "pair_red")?.scoreLabel, "E")
        XCTAssertEqual(presentation.side(id: "pair_blue")?.scoreLabel, "E")
        XCTAssertEqual(presentation.side(id: "pair_red")?.total, 0)
    }

    func testSharedScoreOwnerNetUsesSharedHandicapAllowanceConfig() {
        let holes = makeHoles()
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 36, teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", handicap: 36, teamID: "red"),
            makeParticipant(id: "p3", name: "Cara", handicap: 0, teamID: "blue"),
            makeParticipant(id: "p4", name: "Drew", handicap: 0, teamID: "blue"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["p3", "p4"]),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            templateID: FormatTemplateRegistry.captainsChoice.id,
            scoringUnits: scoringGroups.map {
                ScoringUnit(id: $0.id, owner: .scoreOwner, ownerIDs: $0.memberIDs, scoringMethod: .aggregate)
            }
        )
        let scores = [
            makeSharedScoreEntry(scoringUnitID: "pair_red", participantIDs: ["p1", "p2"], holeNumber: 4, strokes: 5),
            makeSharedScoreEntry(scoringUnitID: "pair_blue", participantIDs: ["p3", "p4"], holeNumber: 4, strokes: 4),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .net,
            template: FormatTemplateRegistry.captainsChoice,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups,
            sharedScoreHandicapConfig: .scramble2Player
        )

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["pair_red"]?.holeValues[4]?.rawStrokes, 5)
        XCTAssertEqual(rowMap["pair_red"]?.holeValues[4]?.netStrokes, 4)
        XCTAssertEqual(rowMap["pair_red"]?.total, 0)
        XCTAssertEqual(rowMap["pair_red"]?.holesPlayed, 1)
        XCTAssertEqual(rowMap["pair_blue"]?.total, 0)
    }

    func testAlternateShotDefaultHandicapIsFiftyPercentCombinedForSharedNetScoring() {
        XCTAssertEqual(FormatTemplateRegistry.alternateShot.requirements.defaultHandicapConfig, .foursomesAlternateShot)

        let holes = makeHoles()
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 18, teamID: "red"),
            makeParticipant(id: "p2", name: "Bob", handicap: 18, teamID: "red"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["p1", "p2"]),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            templateID: FormatTemplateRegistry.alternateShot.id,
            scoringUnits: scoringGroups.map {
                ScoringUnit(id: $0.id, owner: .scoreOwner, ownerIDs: $0.memberIDs, scoringMethod: .aggregate)
            }
        )
        let scores = [
            makeSharedScoreEntry(scoringUnitID: "pair_red", participantIDs: ["p1", "p2"], holeNumber: 4, strokes: 5),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .net,
            template: FormatTemplateRegistry.alternateShot,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups
        )

        let row = result.rows.first { $0.scoringUnitID == "pair_red" }
        XCTAssertEqual(row?.holeValues[4]?.netStrokes, 4)
        XCTAssertEqual(row?.total, 0)
        XCTAssertEqual(row?.holesPlayed, 1)
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

    func testStrokesReceived_SequentialFallbackWithoutHoleIndexes_15Handicap() {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 360, handicap: nil) }
        let playedHoleNumbers = Array(1...18)

        for holeNumber in 1...18 {
            let received = ScoringEngine.strokesReceived(
                handicap: 15,
                holeNumber: holeNumber,
                holes: holes,
                playedHoleNumbers: playedHoleNumbers,
                useHandicaps: true
            )
            let expected = holeNumber <= 15 ? 1 : 0
            XCTAssertEqual(received, expected, "15 handicap should receive \(expected) on hole \(holeNumber)")
        }
    }

    func testStrokesReceived_SequentialFallbackWithoutHoleIndexes_21Handicap() {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 360, handicap: nil) }
        let playedHoleNumbers = Array(1...18)

        for holeNumber in 1...18 {
            let received = ScoringEngine.strokesReceived(
                handicap: 21,
                holeNumber: holeNumber,
                holes: holes,
                playedHoleNumbers: playedHoleNumbers,
                useHandicaps: true
            )
            let expected = holeNumber <= 3 ? 2 : 1
            XCTAssertEqual(received, expected, "21 handicap should receive \(expected) on hole \(holeNumber)")
        }
    }

    func testStrokesReceived_NineHoleBasisUsesFullValueAcrossNineHoleSegment() {
        let holes = makeHoles(count: 9)
        let playedHoleNumbers = Array(1...9)

        let total = playedHoleNumbers.reduce(0) { partial, holeNumber in
            partial + ScoringEngine.strokesReceived(
                handicap: 7,
                holeNumber: holeNumber,
                holes: holes,
                playedHoleNumbers: playedHoleNumbers,
                useHandicaps: true,
                handicapStrokeBasis: .nineHole
            )
        }

        XCTAssertEqual(total, 7)
    }

    func testStrokesReceived_EighteenHoleBasisScalesToNineHoleSegment() {
        let holes = makeHoles(count: 9)
        let playedHoleNumbers = Array(1...9)

        let total = playedHoleNumbers.reduce(0) { partial, holeNumber in
            partial + ScoringEngine.strokesReceived(
                handicap: 7,
                holeNumber: holeNumber,
                holes: holes,
                playedHoleNumbers: playedHoleNumbers,
                useHandicaps: true,
                handicapStrokeBasis: .eighteenHole
            )
        }

        XCTAssertEqual(total, 4)
    }

    func testTeamScoringMatchupBestTwoPerRoundCountsBestRoundTotals() {
        let holes = [Hole(number: 1, par: 4, yardage: 400, handicap: 1)]
        let participants = [
            makeParticipant(id: "david", name: "David", teamID: "team3"),
            makeParticipant(id: "michael", name: "Michael", teamID: "team3"),
            makeParticipant(id: "karis", name: "Karis", teamID: "team3"),
            makeParticipant(id: "abby", name: "Abby", teamID: "team3"),
            makeParticipant(id: "andrew", name: "Andrew", teamID: "team8"),
            makeParticipant(id: "kyle", name: "Kyle", teamID: "team8"),
            makeParticipant(id: "joey", name: "Joey", teamID: "team8"),
            makeParticipant(id: "greg", name: "Greg", teamID: "team8")
        ]
        let teams = [
            RoundTeam(id: "team8", name: "Team 8", color: "blue", index: 0, createdAt: .init()),
            RoundTeam(id: "team3", name: "Team 3", color: "orange", index: 1, createdAt: .init())
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 1),
            matchups: [TeamMatchup(id: "match1", teamIDs: ["team8", "team3"])],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "david", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "michael", holeNumber: 1, strokes: 12),
            makeScoreEntry(participantID: "karis", holeNumber: 1, strokes: 11),
            makeScoreEntry(participantID: "abby", holeNumber: 1, strokes: 13),
            makeScoreEntry(participantID: "andrew", holeNumber: 1, strokes: 9),
            makeScoreEntry(participantID: "kyle", holeNumber: 1, strokes: 9),
            makeScoreEntry(participantID: "joey", holeNumber: 1, strokes: 10),
            makeScoreEntry(participantID: "greg", holeNumber: 1, strokes: 11)
        ]

        let result = ScoringEngine.computeWithTeamScoring(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate,
            resolvedCompetitionScope: .matchup
        )

        let row = result.matchupResults.first?.rows.first { $0.scoringUnitID == "team3" }
        XCTAssertEqual(row?.total, 7)
        XCTAssertEqual(Set(row?.countingParticipantIDs ?? []), Set(["david", "karis"]))
    }

    func testTeamScoringMatchupBestTwoPerHoleAggregatesEachHoleSelection() {
        let holes = [
            Hole(number: 1, par: 4, yardage: 400, handicap: 1),
            Hole(number: 2, par: 4, yardage: 410, handicap: 2)
        ]
        let participants = [
            makeParticipant(id: "p1", name: "One", teamID: "team1"),
            makeParticipant(id: "p2", name: "Two", teamID: "team1"),
            makeParticipant(id: "p3", name: "Three", teamID: "team1"),
            makeParticipant(id: "p4", name: "Four", teamID: "team1"),
            makeParticipant(id: "o1", name: "Opp One", teamID: "team2"),
            makeParticipant(id: "o2", name: "Opp Two", teamID: "team2")
        ]
        let teams = [
            RoundTeam(id: "team1", name: "Team 1", color: "blue", index: 0, createdAt: .init()),
            RoundTeam(id: "team2", name: "Team 2", color: "orange", index: 1, createdAt: .init())
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [TeamMatchup(id: "match1", teamIDs: ["team1", "team2"])],
            competitionScope: .matchup
        )
        let scores = [
            makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 13),
            makeScoreEntry(participantID: "p3", holeNumber: 1, strokes: 11),
            makeScoreEntry(participantID: "p4", holeNumber: 1, strokes: 12),
            makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 13),
            makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 4),
            makeScoreEntry(participantID: "p3", holeNumber: 2, strokes: 11),
            makeScoreEntry(participantID: "p4", holeNumber: 2, strokes: 12),
            makeScoreEntry(participantID: "o1", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "o2", holeNumber: 1, strokes: 5),
            makeScoreEntry(participantID: "o1", holeNumber: 2, strokes: 5),
            makeScoreEntry(participantID: "o2", holeNumber: 2, strokes: 5)
        ]

        let result = ScoringEngine.computeWithTeamScoring(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perHole),
            matchupResolutionStyle: .roundAggregate,
            resolvedCompetitionScope: .matchup
        )

        let row = result.matchupResults.first?.rows.first { $0.scoringUnitID == "team1" }
        XCTAssertEqual(row?.total, 14)
        XCTAssertEqual(Set(row?.countingParticipantIDs ?? []), Set(["p1", "p2", "p3"]))
    }

    func testMaxScoreOverParSelectableCasesIncludeQuintAndSext() {
        XCTAssertEqual(
            MaxScoreOverPar.allCases,
            [.bogey, .double, .triple, .quad, .quint, .sext, .none]
        )
        XCTAssertEqual(MaxScoreOverPar.quint.friendlyMaxRelativeValue(for: 4), 5)
        XCTAssertEqual(MaxScoreOverPar.sext.friendlyMaxRelativeValue(for: 4), 6)
    }

    func testMaxScoreOverParSelectableCasesIncludeTwoTimesParOnlyWithCoursePars() {
        XCTAssertEqual(
            MaxScoreOverPar.selectableCases(hasCoursePars: false),
            [.bogey, .double, .triple, .quad, .quint, .sext, .none]
        )
        XCTAssertEqual(
            MaxScoreOverPar.selectableCases(hasCoursePars: true),
            [.bogey, .double, .triple, .quad, .quint, .sext, .twoTimesPar, .twoTimesParPlusOne, .none]
        )
        XCTAssertEqual(MaxScoreOverPar.twoTimesPar.maxScore(for: 3), 6)
        XCTAssertEqual(MaxScoreOverPar.twoTimesPar.maxScore(for: 4), 8)
        XCTAssertEqual(MaxScoreOverPar.twoTimesPar.maxScore(for: 5), 10)
        XCTAssertEqual(MaxScoreOverPar.twoTimesParPlusOne.maxScore(for: 3), 7)
        XCTAssertEqual(MaxScoreOverPar.twoTimesParPlusOne.maxScore(for: 4), 9)
        XCTAssertEqual(MaxScoreOverPar.twoTimesParPlusOne.maxScore(for: 5), 11)
    }

    func testMaxScoreOverParLegacyCasesRemainDecodable() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(MaxScoreOverPar.self, from: Data(#""twoTimesPar""#.utf8)),
            .twoTimesPar
        )
        XCTAssertEqual(
            try decoder.decode(MaxScoreOverPar.self, from: Data(#""twoTimesParPlusOne""#.utf8)),
            .twoTimesParPlusOne
        )
    }

    func testCourseHandicapUsesRatingSlopeAndPar() {
        let tee = Tee(
            id: "blue",
            name: "Blue",
            gender: "male",
            totalHoles: 18,
            holes: makeHoles(),
            ratingFull: 74.0,
            slopeFull: 130,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )

        XCTAssertEqual(
            HandicapCalculator.courseHandicap(index: 8.1, tee: tee, segment: .full18),
            11
        )
    }

    func testCourseHandicapMissingTeeDataFallsBackToEnteredStrokes() {
        let participant = RoundParticipant(id: "p1", teeBoxID: "blue")
        let tee = Tee(
            id: "blue",
            name: "Blue",
            gender: "male",
            totalHoles: 18,
            holes: makeHoles(),
            ratingFull: 74.0,
            slopeFull: 130,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        let segment = CourseSegment(
            courseInfo: CourseInfo(id: "c1", name: "Course", totalHoles: 18, tees: [tee]),
            holeRange: HoleRange(startHole: 1, endHole: 3),
            defaultTee: "blue"
        )

        XCTAssertNil(HandicapCalculator.courseHandicap(index: 8.1, participant: participant, courseSegment: segment))
        XCTAssertEqual(
            HandicapCalculator.strokes(
                for: 8.1,
                format: .courseHandicap,
                participant: participant,
                courseSegment: segment
            ),
            8
        )
    }

    func testFieldNormalizationSubtractsLowestActiveHandicap() {
        let participants = [
            makeParticipant(id: "peyton", name: "Peyton", handicap: 4),
            makeParticipant(id: "andrew", name: "Andrew", handicap: 12),
            makeParticipant(id: "scott", name: "Scott", handicap: 14),
            makeParticipant(id: "kyle", name: "Kyle", handicap: 18),
        ]

        let normalized = Dictionary(uniqueKeysWithValues: HandicapCalculator.normalizedParticipantsForField(participants).map { ($0.id, $0.adjustedHandicap) })

        XCTAssertEqual(normalized["peyton"], 0)
        XCTAssertEqual(normalized["andrew"], 8)
        XCTAssertEqual(normalized["scott"], 10)
        XCTAssertEqual(normalized["kyle"], 14)
    }

    func testMatchupNormalizationSubtractsLowestParticipantOnlyInsideMatchup() {
        let participants = [
            makeParticipant(id: "peyton", name: "Peyton", handicap: 4),
            makeParticipant(id: "andrew", name: "Andrew", handicap: 12),
            makeParticipant(id: "scott", name: "Scott", handicap: 14),
            makeParticipant(id: "kyle", name: "Kyle", handicap: 18),
        ]
        let matchup = TeamMatchup(participantIDs: ["andrew", "kyle"], mode: .individual)

        let normalized = Dictionary(uniqueKeysWithValues: HandicapCalculator.normalizedParticipants(participants, for: matchup, teams: [], scoringGroups: []).map { ($0.id, $0.adjustedHandicap) })

        XCTAssertEqual(normalized["peyton"], 4)
        XCTAssertEqual(normalized["andrew"], 0)
        XCTAssertEqual(normalized["scott"], 14)
        XCTAssertEqual(normalized["kyle"], 6)
    }

    func testTeamMatchupNormalizationSubtractsLowestAcrossBothTeams() {
        let participants = [
            makeParticipant(id: "peyton", name: "Peyton", handicap: 4, teamID: "red"),
            makeParticipant(id: "andrew", name: "Andrew", handicap: 12, teamID: "red"),
            makeParticipant(id: "scott", name: "Scott", handicap: 14, teamID: "blue"),
            makeParticipant(id: "kyle", name: "Kyle", handicap: 18, teamID: "blue"),
            makeParticipant(id: "guest", name: "Guest", handicap: 20, teamID: "green"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init()),
            RoundTeam(id: "green", name: "Green", color: "green", index: 2, createdAt: .init()),
        ]
        let matchup = TeamMatchup(teamIDs: ["red", "blue"], mode: .team)

        let normalized = Dictionary(uniqueKeysWithValues: HandicapCalculator.normalizedParticipants(participants, for: matchup, teams: teams, scoringGroups: []).map { ($0.id, $0.adjustedHandicap) })

        XCTAssertEqual(normalized["peyton"], 0)
        XCTAssertEqual(normalized["andrew"], 8)
        XCTAssertEqual(normalized["scott"], 10)
        XCTAssertEqual(normalized["kyle"], 14)
        XCTAssertEqual(normalized["guest"], 20)
    }

    func testScoringGroupMatchupNormalizationSubtractsLowestAcrossBothSides() {
        let participants = [
            makeParticipant(id: "peyton", name: "Peyton", handicap: 4),
            makeParticipant(id: "andrew", name: "Andrew", handicap: 12),
            makeParticipant(id: "scott", name: "Scott", handicap: 14),
            makeParticipant(id: "kyle", name: "Kyle", handicap: 18),
            makeParticipant(id: "guest", name: "Guest", handicap: 20),
        ]
        let scoringGroups = [
            makePartnership(id: "pair_red", teamID: "red", memberIDs: ["peyton", "andrew"]),
            makePartnership(id: "pair_blue", teamID: "blue", memberIDs: ["scott", "kyle"]),
        ]
        let matchup = TeamMatchup(scoreOwnerIDs: ["pair_red", "pair_blue"], mode: .partnership)

        let normalized = Dictionary(uniqueKeysWithValues: HandicapCalculator.normalizedParticipants(participants, for: matchup, teams: [], scoringGroups: scoringGroups).map { ($0.id, $0.adjustedHandicap) })

        XCTAssertEqual(normalized["peyton"], 0)
        XCTAssertEqual(normalized["andrew"], 8)
        XCTAssertEqual(normalized["scott"], 10)
        XCTAssertEqual(normalized["kyle"], 14)
        XCTAssertEqual(normalized["guest"], 20)
    }

    func testTeeGroupMatchupNormalizationSubtractsLowestAcrossBothSides() {
        let participants = [
            makeParticipant(id: "peyton", name: "Peyton", handicap: 4),
            makeParticipant(id: "andrew", name: "Andrew", handicap: 12),
            makeParticipant(id: "scott", name: "Scott", handicap: 14),
            makeParticipant(id: "kyle", name: "Kyle", handicap: 18),
            makeParticipant(id: "guest", name: "Guest", handicap: 20),
        ]
        let scoringGroups = [
            RoundScoringGroup(id: "tee_1", teeGroupID: "g1", kind: .teeGroup, memberIDs: ["peyton", "andrew"], parentID: "round1"),
            RoundScoringGroup(id: "tee_2", teeGroupID: "g2", kind: .teeGroup, memberIDs: ["scott", "kyle"], parentID: "round1"),
        ]
        let matchup = TeamMatchup(scoreOwnerIDs: ["tee_1", "tee_2"], mode: .teeGroup)

        let normalized = Dictionary(uniqueKeysWithValues: HandicapCalculator.normalizedParticipants(participants, for: matchup, teams: [], scoringGroups: scoringGroups).map { ($0.id, $0.adjustedHandicap) })

        XCTAssertEqual(normalized["peyton"], 0)
        XCTAssertEqual(normalized["andrew"], 8)
        XCTAssertEqual(normalized["scott"], 10)
        XCTAssertEqual(normalized["kyle"], 14)
        XCTAssertEqual(normalized["guest"], 20)
    }
}
