//
//  ScoringPipelineStageTests.swift
//  HackersTests
//
//  Created by Kyle Beard on 3/7/26.
//

@testable import Hackers
import XCTest

final class ScoringPipelineStageTests: XCTestCase {

    // MARK: - Helpers

    private func makeValue(
        participantID: String = "p1",
        gross: Int = 4,
        net: Int = 4,
        par: Int = 4,
        scoreToPar: Int = 0,
        points: Double = 0
    ) -> PipelineHoleValue {
        PipelineHoleValue(
            participantID: participantID,
            grossStrokes: gross,
            netStrokes: net,
            par: par,
            scoreToPar: scoreToPar,
            points: points,
            pickedUp: false
        )
    }

    // MARK: - SelectionResolver

    func testSelectionResolver_IncludeRank1_BestBall() {
        let participants = [
            RoundParticipant(id: "p1", name: Name("A", ""), teamID: "t1"),
            RoundParticipant(id: "p2", name: Name("B", ""), teamID: "t1"),
            RoundParticipant(id: "p3", name: Name("C", ""), teamID: "t1"),
        ]
        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [1: makeValue(participantID: "p1", scoreToPar: 1, points: 1)],
            "p2": [1: makeValue(participantID: "p2", scoreToPar: -1, points: -1)],
            "p3": [1: makeValue(participantID: "p3", scoreToPar: 0, points: 0)],
        ]

        let result = SelectionResolver.apply(
            selection: RankSelection(includeRanks: [1]),
            values: values,
            holeNumbers: [1],
            subject: .team,
            participants: participants,
            teams: [RoundTeam(id: "t1", name: "T1", color: "red", index: 0, createdAt: .init())]
        )

        XCTAssertEqual(result.count, 1, "Should have 1 team")
        XCTAssertEqual(result["t1"]?[1]?.points, -1, "Should select the best (lowest) score")
    }

    func testSelectionResolver_IncludeRanks1And2() {
        let sorted: [(String, PipelineHoleValue)] = [
            ("p1", makeValue(points: -2)),
            ("p2", makeValue(points: -1)),
            ("p3", makeValue(points: 0)),
            ("p4", makeValue(points: 1)),
        ]

        let result = SelectionResolver.filterByRanks(sorted: sorted, includeRanks: [1, 2], excludeRanks: nil)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].1.points, -2)
        XCTAssertEqual(result[1].1.points, -1)
    }

    func testSelectionResolver_ExcludeRank1() {
        let sorted: [(String, PipelineHoleValue)] = [
            ("p1", makeValue(points: -2)),
            ("p2", makeValue(points: -1)),
            ("p3", makeValue(points: 0)),
        ]

        let result = SelectionResolver.filterByRanks(sorted: sorted, includeRanks: nil, excludeRanks: [1])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].1.points, -1)
        XCTAssertEqual(result[1].1.points, 0)
    }

    func testSelectionResolver_FewerPlayersThanRanks() {
        let sorted: [(String, PipelineHoleValue)] = [
            ("p1", makeValue(points: -1)),
        ]

        let result = SelectionResolver.filterByRanks(sorted: sorted, includeRanks: [1, 2], excludeRanks: nil)
        XCTAssertEqual(result.count, 1, "Should return only available scores when fewer players than requested ranks")
    }

    // MARK: - PointsTransformer

    func testPointsTransformer_ParRelative_Stableford() {
        let eagleVal = makeValue(scoreToPar: -2, points: -2)
        let birdieVal = makeValue(scoreToPar: -1, points: -1)
        let parVal = makeValue(scoreToPar: 0, points: 0)
        let bogeyVal = makeValue(scoreToPar: 1, points: 1)
        let doubleBogeyVal = makeValue(scoreToPar: 2, points: 2)
        let tripleBogeyVal = makeValue(scoreToPar: 3, points: 3)

        let pointsMap = PointsMap.stableford

        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: eagleVal), 4)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: birdieVal), 3)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: parVal), 2)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: bogeyVal), 1)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: doubleBogeyVal), 0)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: tripleBogeyVal), 0, "Worse than double bogey should still be 0")
    }

    func testPointsTransformer_ParDependent() {
        let par3 = makeValue(par: 3, scoreToPar: 0)
        let par4 = makeValue(par: 4, scoreToPar: 0)
        let par5 = makeValue(par: 5, scoreToPar: 0)

        let pointsMap = PointsMap(mode: .parDependent, parMultiplier: 1.0)

        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: par3), 3)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: par4), 4)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: par5), 5)
    }

    func testPointsTransformer_Fixed() {
        let val = makeValue(par: 4, scoreToPar: -1)
        let pointsMap = PointsMap(mode: .fixed)
        XCTAssertEqual(PointsTransformer.computePoints(pointsMap: pointsMap, value: val), 1)
    }

    // MARK: - ModifierApplicator

    func testModifierApplicator_BirdieDoubles() {
        let modifier = ConditionalModifier(
            predicate: .scoreToPar(.lessThanOrEqual, -1),
            effect: .multiply(2.0),
            scope: .perHole
        )

        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [
                1: makeValue(scoreToPar: -1, points: 3),  // birdie, should double
                2: makeValue(scoreToPar: 0, points: 2),   // par, should stay
                3: makeValue(scoreToPar: -2, points: 4),  // eagle, should double
            ]
        ]

        let result = ModifierApplicator.apply(modifier: modifier, values: values, holeNumbers: [1, 2, 3])

        XCTAssertEqual(result["p1"]?[1]?.points, 6, "Birdie points should double from 3 to 6")
        XCTAssertEqual(result["p1"]?[2]?.points, 2, "Par points should stay at 2")
        XCTAssertEqual(result["p1"]?[3]?.points, 8, "Eagle points should double from 4 to 8")
    }

    func testModifierApplicator_AddBonus() {
        let modifier = ConditionalModifier(
            predicate: .scoreToPar(.equal, 0),
            effect: .add(1.0),
            scope: .perHole
        )

        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [1: makeValue(scoreToPar: 0, points: 2)]
        ]

        let result = ModifierApplicator.apply(modifier: modifier, values: values, holeNumbers: [1])
        XCTAssertEqual(result["p1"]?[1]?.points, 3, "Should add 1 to par score")
    }

    func testModifierApplicator_ReplaceEffect() {
        let modifier = ConditionalModifier(
            predicate: .rawStrokes(.greaterThanOrEqual, 10),
            effect: .replace(0),
            scope: .perHole
        )

        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [1: makeValue(gross: 10, scoreToPar: 6, points: 6)]
        ]

        let result = ModifierApplicator.apply(modifier: modifier, values: values, holeNumbers: [1])
        XCTAssertEqual(result["p1"]?[1]?.points, 0, "10+ strokes should replace points with 0")
    }

    // MARK: - ReductionResolver

    func testReductionResolver_SumPerRound() {
        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [
                1: makeValue(points: 3),
                2: makeValue(points: 2),
                3: makeValue(points: 4),
            ]
        ]

        let result = ReductionResolver.apply(
            reduction: Reduction(mode: .sum, scope: .perRound),
            values: values,
            holeNumbers: [1, 2, 3]
        )

        // Sum = 9, distributed evenly = 3 per hole
        let totalPoints = [1, 2, 3].compactMap { result["p1"]?[$0]?.points }.reduce(0, +)
        XCTAssertEqual(totalPoints, 9, accuracy: 0.01)
    }

    func testReductionResolver_AveragePerRound() {
        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [
                1: makeValue(points: 2),
                2: makeValue(points: 4),
                3: makeValue(points: 6),
            ]
        ]

        let result = ReductionResolver.apply(
            reduction: Reduction(mode: .average, scope: .perRound),
            values: values,
            holeNumbers: [1, 2, 3]
        )

        // Average = 4, each hole should have 4/3
        let hole1 = result["p1"]?[1]?.points ?? 0
        XCTAssertEqual(hole1, 4.0 / 3.0, accuracy: 0.01)
    }

    // MARK: - ComparisonResolver

    func testComparisonResolver_MatchPlayHalf() {
        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [
                1: makeValue(participantID: "p1", scoreToPar: -1, points: -1), // wins
                2: makeValue(participantID: "p1", scoreToPar: 1, points: 1),   // loses
                3: makeValue(participantID: "p1", scoreToPar: 0, points: 0),   // tie
            ],
            "p2": [
                1: makeValue(participantID: "p2", scoreToPar: 0, points: 0),
                2: makeValue(participantID: "p2", scoreToPar: -1, points: -1),
                3: makeValue(participantID: "p2", scoreToPar: 0, points: 0),
            ],
        ]

        let result = ComparisonResolver.apply(
            rule: ComparisonRule(mode: .matchPlay, tiePolicy: .half),
            values: values,
            holeNumbers: [1, 2, 3],
            participants: [],
            teams: []
        )

        let p1Total = [1, 2, 3].compactMap { result["p1"]?[$0]?.points }.reduce(0, +)
        let p2Total = [1, 2, 3].compactMap { result["p2"]?[$0]?.points }.reduce(0, +)

        XCTAssertEqual(p1Total, 1.5, accuracy: 0.01, "p1: 1 win + 0.5 tie = 1.5")
        XCTAssertEqual(p2Total, 1.5, accuracy: 0.01, "p2: 1 win + 0.5 tie = 1.5")
    }

    func testComparisonResolver_MatchPlayCarryover() {
        let values: [String: [Int: PipelineHoleValue]] = [
            "p1": [
                1: makeValue(participantID: "p1", points: 0), // tie
                2: makeValue(participantID: "p1", points: 0), // tie
                3: makeValue(participantID: "p1", points: -1), // p1 wins
            ],
            "p2": [
                1: makeValue(participantID: "p2", points: 0), // tie
                2: makeValue(participantID: "p2", points: 0), // tie
                3: makeValue(participantID: "p2", points: 0), // loses
            ],
        ]

        let result = ComparisonResolver.apply(
            rule: ComparisonRule(mode: .matchPlay, tiePolicy: .carryover),
            values: values,
            holeNumbers: [1, 2, 3],
            participants: [],
            teams: []
        )

        let p1Total = [1, 2, 3].compactMap { result["p1"]?[$0]?.points }.reduce(0, +)
        // Hole 1: tie → carryover=1. Hole 2: tie → carryover=2 (1+1). Hole 3: p1 wins → gets 3 (1+2)
        XCTAssertEqual(p1Total, 3, accuracy: 0.01, "p1 should get 3 points with carryover from 2 tied holes")
    }
}
