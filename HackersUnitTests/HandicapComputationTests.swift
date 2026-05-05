//
//  HandicapComputationTests.swift
//  HackersUnitTests
//
//  Created by Codex on 3/6/26.
//

import Testing
@testable import Hackers

@Suite("Handicap Computation")
struct HandicapComputationTests {
    @Test("Games-used rule boundary mapping")
    func gamesUsedMappingBoundaries() throws {
        let mapping: [(Int, Int)] = [
            (1, 1),
            (5, 1),
            (6, 2),
            (8, 2),
            (9, 3),
            (12, 4),
            (16, 5),
            (17, 6),
            (19, 7),
            (20, 8),
            (21, 8),
        ]

        for (played, expectedUsed) in mapping {
            let scores = sampleScores(count: played)
            let result = try #require(computeHandicapIndex(scores: scores))
            #expect(result.gamesUsed == expectedUsed)
        }
    }

    @Test("Default DTO expands to played-used matrix")
    func defaultDTOExpandsToPlayedUsedMatrix() {
        let rows = HandicapComputationConfigDTO.league2025.gamesUsedMatrixRows()
        let expected: [(Int, Int)] = [
            (1, 1), (2, 1), (3, 1), (4, 1), (5, 1),
            (6, 2), (7, 2), (8, 2),
            (9, 3), (10, 3), (11, 3),
            (12, 4), (13, 4), (14, 4),
            (15, 5), (16, 5),
            (17, 6), (18, 6),
            (19, 7),
            (20, 8),
        ]

        #expect(rows.map { "\($0.played):\($0.used)" } == expected.map { "\($0.0):\($0.1)" })
    }

    @Test("Played-used matrix compresses saved rules and extends row twenty")
    func playedUsedMatrixCompressesSavedRules() {
        let rows = HandicapComputationConfigDTO.league2025.gamesUsedMatrixRows()
        let rules = HandicapComputationConfigDTO.compressedGamesUsedRules(fromMatrix: rows)
        let expected: [(Int, Int, Int)] = [
            (1, 5, 1),
            (6, 8, 2),
            (9, 11, 3),
            (12, 14, 4),
            (15, 16, 5),
            (17, 18, 6),
            (19, 19, 7),
            (20, 100, 8),
        ]

        #expect(
            rules.map { "\($0.playedLower):\($0.playedUpper):\($0.used)" }
                == expected.map { "\($0.0):\($0.1):\($0.2)" }
        )
    }

    @Test("Legacy broad rule hydrates as clamped effective matrix")
    func legacyBroadRuleHydratesAsClampedEffectiveMatrix() {
        let dto = HandicapComputationConfigDTO(
            gamesUsedRules: [.init(playedLower: 1, playedUpper: 100, used: 4)]
        )
        let rows = dto.gamesUsedMatrixRows()

        let firstSix = rows.prefix(6).map { "\($0.played):\($0.used)" }
        let expectedFirstSix = [
            (1, 1),
            (2, 2),
            (3, 3),
            (4, 4),
            (5, 4),
            (6, 4),
        ].map { "\($0.0):\($0.1)" }
        #expect(firstSix == expectedFirstSix)
        #expect(rows.last == GamesUsedMatrixRow(played: 20, used: 4))
    }

    @Test("Index rounds down to one decimal")
    func indexUsesRoundDownToTenths() throws {
        let scores = [45.11] // (45.11 - 36) * 0.96 = 8.7456 -> 8.7
        let result = try #require(computeHandicapIndex(scores: scores))
        #expect(abs(result.handicapIndex - 8.7) < 0.000_001)
    }

    @Test("Early-adjustment and provisional window")
    func earlyAdjustmentAndProvisionalWindow() throws {
        let oneToThreeScores = [40.0, 40.0, 40.0]
        let fourScores = [40.0, 40.0, 40.0, 40.0]

        let result3 = try #require(
            computeHandicap(scores: oneToThreeScores, par: 36, rating: 35.15, slope: 125)
        )
        let result4 = try #require(
            computeHandicap(scores: fourScores, par: 36, rating: 35.15, slope: 125)
        )

        #expect(result3.earlyAdjustmentApplied == -2)
        #expect(result4.earlyAdjustmentApplied == -1)
        #expect(result3.indexResult.isProvisional == true)
        #expect(result4.indexResult.isProvisional == true)
    }

    @Test("Maximum handicap cap is enforced")
    func maximumHandicapCap() throws {
        let highScores = sampleScores(count: 20, start: 80.0)
        let result = try #require(computeHandicap(scores: highScores, par: 36, rating: 35.15, slope: 125))
        #expect(result.finalHandicap == 21)
    }

    @Test("Custom config override")
    func customConfigOverride() throws {
        var config = HandicapComputationConfig.league2025
        config.gamesUsedRules = [.init(playedRange: 1...100, used: 2)]
        config.differentialMultiplier = 1.0
        config.defaultParForIndex = 36.0
        config.minimumScoresForIndex = 1
        config.maximumHandicap = 99
        config.earlyAdjustmentRules = []

        let result = try #require(computeHandicapIndex(scores: [50.0, 40.0, 60.0], config: config))
        #expect(result.gamesUsed == 2)
        #expect(abs(result.differentialAverage - 45.0) < 0.000_001)
        #expect(abs(result.handicapIndex - 9.0) < 0.000_001)
    }

    @Test("Workbook-like parity sample")
    func workbookLikeParitySample() throws {
        let scores = [
            54.0, 48.0, 56.0, 49.0, 49.0, 51.0, 49.0, 46.0, 50.0, 45.0,
            51.0, 45.0, 41.0, 57.0, 47.0, 49.0, 44.0, 53.0, 54.0, 45.0,
        ]

        let indexResult = try #require(computeHandicapIndex(scores: scores))
        let handicapResult = try #require(computeHandicap(scores: scores, par: 36, rating: 35.15, slope: 125))

        #expect(indexResult.gamesPlayed == 20)
        #expect(indexResult.gamesUsed == 8)
        #expect(abs(indexResult.differentialAverage - 45.125) < 0.000_001)
        #expect(abs(indexResult.handicapIndex - 8.7) < 0.000_001)
        #expect(handicapResult.courseHandicap == 9)
        #expect(handicapResult.earlyAdjustmentApplied == 0)
        #expect(handicapResult.finalHandicap == 9)
    }

    @Test("Kyle Beard workbook row: best-score selection and differential average")
    func kyleBeardWorkbookRowDifferentialParity() throws {
        // Source: "Raw Scores + Handicaps (2022)" row for Kyle Beard in
        // 2025 Golf League Standings - Week 12.xls
        // Workbook values: gamesPlayed=17, gamesUsed=12, differential=50.396307
        let workbookScores = [
            53.755682, 54, 53, 55, 48, 54, 50, 64, 49, 44, 64, 53, 50, 51, 48, 52, 53,
        ]

        var config = HandicapComputationConfig.league2025
        config.gamesUsedRules = [.init(playedRange: 17...17, used: 12)]
        config.earlyAdjustmentRules = []

        let indexResult = try #require(computeHandicapIndex(scores: workbookScores, config: config))

        #expect(indexResult.gamesPlayed == 17)
        #expect(indexResult.gamesUsed == 12)
        #expect(abs(indexResult.differentialAverage - 50.396307) < 0.000_001)

        // With this utility's configured equation (par-based index):
        #expect(abs(indexResult.handicapIndex - 13.8) < 0.000_001)

        let full = try #require(
            computeHandicap(
                scores: workbookScores,
                par: 36,
                rating: 35.15,
                slope: 125,
                config: config
            )
        )
        #expect(full.courseHandicap == 14)
        #expect(full.finalHandicap == 14)
    }

    @Test("User-facing summary: default league config")
    func userFacingSummaryLeague2025() {
        let text = HandicapComputationConfig.league2025.userFacingSummaryCaption()
        #expect(text.contains("at least one recorded score"))
        #expect(text.contains("Every recorded score"))
        #expect(text.contains("lowest normalized scores"))
        #expect(text.contains("rating and slope"))
    }

    @Test("User-facing summary: rolling window and latest policy")
    func userFacingSummaryRollingLatest() {
        var cfg = HandicapComputationConfig.league2025
        cfg.rollingPoolSize = 10
        cfg.scorePoolPolicy = .latestOfUsedCount
        let text = cfg.userFacingSummaryCaption()
        #expect(text.contains("10 scores"))
        #expect(text.contains("most recent scores from that pool"))
    }

    @Test("Short sheet subtitle: league2025 default")
    func userFacingShortSheetSubtitleLeague2025() {
        let text = HandicapComputationConfig.league2025.userFacingShortSheetSubtitle()
        #expect(text.hasPrefix("Taking up to "))
        #expect(text.contains("lowest scores"))
        #expect(text.contains("recorded scores"))
    }

    @Test("Short sheet subtitle: rolling pool and latest policy")
    func userFacingShortSheetSubtitleRollingLatest() {
        var cfg = HandicapComputationConfig.league2025
        cfg.rollingPoolSize = 10
        cfg.scorePoolPolicy = .latestOfUsedCount
        let text = cfg.userFacingShortSheetSubtitle()
        #expect(text.contains("most recent scores"))
        #expect(text.contains("most recent 10 scores"))
    }

    private func sampleScores(count: Int, start: Double = 40.0) -> [Double] {
        (0..<count).map { start + Double($0) }
    }
}
