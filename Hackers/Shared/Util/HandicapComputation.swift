//
//  HandicapComputation.swift
//  Hackers
//
//  Created by Codex on 3/6/26.
//

import Foundation

struct GamesUsedRule {
    let playedRange: ClosedRange<Int>
    let used: Int
}

struct EarlyAdjustmentRule {
    let playedRange: ClosedRange<Int>
    let adjustment: Int
}

enum HandicapIndexRoundingMode {
    case downToTenths
    case towardZeroToTenths
    case nearestToTenths

    func apply(_ value: Double) -> Double {
        switch self {
        case .downToTenths:
            return floor(value * 10.0) / 10.0
        case .towardZeroToTenths:
            let scaled = value * 10.0
            return (scaled < 0 ? ceil(scaled) : floor(scaled)) / 10.0
        case .nearestToTenths:
            return (value * 10.0).rounded() / 10.0
        }
    }
}

/// How scores are chosen when `gamesUsed` is less than rounds played.
enum HandicapScorePoolPolicy: String, Codable, Hashable {
    /// WHS-style: use the lowest numeric differentials (or scores) in the pool.
    case bestOfUsedCount
    /// Rolling: use the most recently entered scores (caller orders oldest → newest).
    case latestOfUsedCount
}

enum CourseHandicapRoundingMode {
    case nearestAwayFromZero
    case nearestToEven
    case towardZero

    func apply(_ value: Double) -> Int {
        switch self {
        case .nearestAwayFromZero:
            return Int(value.rounded(.toNearestOrAwayFromZero))
        case .nearestToEven:
            return Int(value.rounded(.toNearestOrEven))
        case .towardZero:
            return Int(value.rounded(.towardZero))
        }
    }
}

struct HandicapComputationConfig {
    var gamesUsedRules: [GamesUsedRule]
    var differentialMultiplier: Double
    var earlyAdjustmentRules: [EarlyAdjustmentRule]
    var maximumHandicap: Int
    var minimumScoresForIndex: Int
    var defaultParForIndex: Double
    var indexRoundingMode: HandicapIndexRoundingMode
    var courseHandicapRoundingMode: CourseHandicapRoundingMode
    var scorePoolPolicy: HandicapScorePoolPolicy

    static let league2025 = HandicapComputationConfig(
        gamesUsedRules: [
            .init(playedRange: 1...5, used: 1),
            .init(playedRange: 6...8, used: 2),
            .init(playedRange: 9...11, used: 3),
            .init(playedRange: 12...14, used: 4),
            .init(playedRange: 15...16, used: 5),
            .init(playedRange: 17...18, used: 6),
            .init(playedRange: 19...19, used: 7),
            .init(playedRange: 20...20, used: 8),
        ],
        differentialMultiplier: 0.96,
        earlyAdjustmentRules: [
            .init(playedRange: 1...3, adjustment: -2),
            .init(playedRange: 4...4, adjustment: -1),
        ],
        maximumHandicap: 21,
        minimumScoresForIndex: 1,
        defaultParForIndex: 36.0,
        indexRoundingMode: .downToTenths,
        courseHandicapRoundingMode: .nearestAwayFromZero,
        scorePoolPolicy: .bestOfUsedCount
    )
}

struct HandicapIndexResult {
    let gamesPlayed: Int
    let gamesUsed: Int
    let selectedBestScores: [Double]
    let differentialAverage: Double
    let handicapIndex: Double
    let isProvisional: Bool
}

struct HandicapComputationResult {
    let indexResult: HandicapIndexResult
    let courseHandicap: Int
    let earlyAdjustmentApplied: Int
    let finalHandicap: Int
}

func computeHandicapIndex(
    scores: [Double],
    config: HandicapComputationConfig = .league2025
) -> HandicapIndexResult? {
    let normalizedScores = normalized(scores)
    let gamesPlayed = normalizedScores.count

    guard gamesPlayed >= config.minimumScoresForIndex else { return nil }

    let gamesUsed = gamesUsedForPlayed(gamesPlayed, rules: config.gamesUsedRules)
    guard gamesUsed > 0 else { return nil }

    let take = min(gamesUsed, gamesPlayed)
    let selectedBestScores: [Double] = {
        switch config.scorePoolPolicy {
        case .bestOfUsedCount:
            return Array(normalizedScores.sorted().prefix(take))
        case .latestOfUsedCount:
            return Array(normalizedScores.suffix(take))
        }
    }()
    guard !selectedBestScores.isEmpty else { return nil }

    let differentialAverage = mean(selectedBestScores)
    let rawIndex = (differentialAverage - config.defaultParForIndex) * config.differentialMultiplier
    let handicapIndex = config.indexRoundingMode.apply(rawIndex)

    return HandicapIndexResult(
        gamesPlayed: gamesPlayed,
        gamesUsed: gamesUsed,
        selectedBestScores: selectedBestScores,
        differentialAverage: differentialAverage,
        handicapIndex: handicapIndex,
        isProvisional: gamesPlayed < 5
    )
}

func computeHandicap(
    scores: [Double],
    par: Double,
    rating: Double,
    slope: Double,
    config: HandicapComputationConfig = .league2025
) -> HandicapComputationResult? {
    guard let indexResult = computeHandicapIndex(scores: scores, config: config) else { return nil }

    let rawCourseHandicap = indexResult.handicapIndex * slope / 113.0 + rating - par
    let courseHandicap = config.courseHandicapRoundingMode.apply(rawCourseHandicap)
    let earlyAdjustment = earlyAdjustmentForPlayed(indexResult.gamesPlayed, rules: config.earlyAdjustmentRules)
    let finalHandicap = min(courseHandicap + earlyAdjustment, config.maximumHandicap)

    return HandicapComputationResult(
        indexResult: indexResult,
        courseHandicap: courseHandicap,
        earlyAdjustmentApplied: earlyAdjustment,
        finalHandicap: finalHandicap
    )
}

private func normalized(_ scores: [Double]) -> [Double] {
    scores.filter { $0.isFinite }
}

private func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

private func gamesUsedForPlayed(_ played: Int, rules: [GamesUsedRule]) -> Int {
    nearestGamesUsedRule(played: played, rules: rules)?.used ?? 0
}

private func earlyAdjustmentForPlayed(_ played: Int, rules: [EarlyAdjustmentRule]) -> Int {
    rules.first(where: { $0.playedRange.contains(played) })?.adjustment ?? 0
}

private func nearestGamesUsedRule(played: Int, rules: [GamesUsedRule]) -> GamesUsedRule? {
    guard !rules.isEmpty else { return nil }
    let sortedRules = rules.sorted { $0.playedRange.lowerBound < $1.playedRange.lowerBound }

    if let exact = sortedRules.first(where: { $0.playedRange.contains(played) }) {
        return exact
    }

    return sortedRules.min { lhs, rhs in
        distanceFromRange(played, to: lhs.playedRange) < distanceFromRange(played, to: rhs.playedRange)
    }
}

private func distanceFromRange(_ value: Int, to range: ClosedRange<Int>) -> Int {
    if range.contains(value) { return 0 }
    if value < range.lowerBound { return range.lowerBound - value }
    return value - range.upperBound
}
