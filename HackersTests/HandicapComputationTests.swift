//
//  HandicapComputationTests.swift
//  HackersTests
//
//  Created by Codex on 3/6/26.
//

@testable import Hackers
import XCTest

final class HandicapComputationTests: XCTestCase {
    func testGamesUsedMappingBoundaries() {
        let mapping: [(Int, Int)] = [
            (1, 1),
            (4, 1),
            (5, 1),
            (6, 2),
            (8, 2),
            (9, 3),
            (20, 8),
        ]

        for (played, expectedUsed) in mapping {
            let scores = sampleScores(count: played)
            let result = computeHandicapIndex(scores: scores)
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.gamesUsed, expectedUsed)
        }
    }

    func testIndexUsesRoundDownToTenths() {
        let scores = [45.11] // (45.11 - 36) * 0.96 = 8.7456 -> 8.7
        let result = computeHandicapIndex(scores: scores)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.handicapIndex, 8.7, accuracy: 0.000_001)
    }

    func testEarlyAdjustmentAndProvisionalWindow() {
        let oneToThreeScores = [40.0, 40.0, 40.0]
        let fourScores = [40.0, 40.0, 40.0, 40.0]

        let result3 = computeHandicap(scores: oneToThreeScores, par: 36, rating: 35.15, slope: 125)
        let result4 = computeHandicap(scores: fourScores, par: 36, rating: 35.15, slope: 125)

        XCTAssertNotNil(result3)
        XCTAssertNotNil(result4)

        XCTAssertEqual(result3?.earlyAdjustmentApplied, -2)
        XCTAssertEqual(result4?.earlyAdjustmentApplied, -1)
        XCTAssertEqual(result3?.indexResult.isProvisional, true)
        XCTAssertEqual(result4?.indexResult.isProvisional, true)
    }

    func testMaximumHandicapCap() {
        let highScores = sampleScores(count: 20, start: 80.0)
        let result = computeHandicap(scores: highScores, par: 36, rating: 35.15, slope: 125)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.finalHandicap, 21)
    }

    func testCustomConfigOverride() {
        var config = HandicapComputationConfig.league2025
        config.gamesUsedRules = [.init(playedRange: 1...100, used: 2)]
        config.differentialMultiplier = 1.0
        config.defaultParForIndex = 36.0
        config.minimumScoresForIndex = 1
        config.maximumHandicap = 99
        config.earlyAdjustmentRules = []

        let result = computeHandicapIndex(scores: [50.0, 40.0, 60.0], config: config)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.gamesUsed, 2)
        XCTAssertEqual(result?.differentialAverage, 45.0, accuracy: 0.000_001)
        XCTAssertEqual(result?.handicapIndex, 9.0, accuracy: 0.000_001)
    }

    func testWorkbookLikeParitySample() {
        let scores = [
            54.0, 48.0, 56.0, 49.0, 49.0, 51.0, 49.0, 46.0, 50.0, 45.0,
            51.0, 45.0, 41.0, 57.0, 47.0, 49.0, 44.0, 53.0, 54.0, 45.0,
        ]

        let indexResult = computeHandicapIndex(scores: scores)
        let handicapResult = computeHandicap(scores: scores, par: 36, rating: 35.15, slope: 125)

        XCTAssertNotNil(indexResult)
        XCTAssertEqual(indexResult?.gamesPlayed, 20)
        XCTAssertEqual(indexResult?.gamesUsed, 8)
        XCTAssertEqual(indexResult?.differentialAverage, 45.125, accuracy: 0.000_001)
        XCTAssertEqual(indexResult?.handicapIndex, 8.7, accuracy: 0.000_001)

        XCTAssertNotNil(handicapResult)
        XCTAssertEqual(handicapResult?.courseHandicap, 9)
        XCTAssertEqual(handicapResult?.earlyAdjustmentApplied, 0)
        XCTAssertEqual(handicapResult?.finalHandicap, 9)
    }

    private func sampleScores(count: Int, start: Double = 40.0) -> [Double] {
        (0..<count).map { start + Double($0) }
    }
}
