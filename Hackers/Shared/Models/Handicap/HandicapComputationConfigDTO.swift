//
//  HandicapComputationConfigDTO.swift
//  Hackers
//
//  Codable DTO for persisting HandicapComputationConfig to Firestore.
//  Maps bidirectionally to the in-memory computation types.
//

import Foundation

struct GamesUsedRuleDTO: Hashable, Codable {
    var playedLower: Int
    var playedUpper: Int
    var used: Int

    enum CodingKeys: String, CodingKey {
        case playedLower = "played_lower"
        case playedUpper = "played_upper"
        case used
    }

    func toRule() -> GamesUsedRule {
        .init(playedRange: playedLower...playedUpper, used: used)
    }

    init(from rule: GamesUsedRule) {
        self.playedLower = rule.playedRange.lowerBound
        self.playedUpper = rule.playedRange.upperBound
        self.used = rule.used
    }

    init(playedLower: Int = 1, playedUpper: Int = 5, used: Int = 1) {
        self.playedLower = playedLower
        self.playedUpper = playedUpper
        self.used = used
    }
}

struct EarlyAdjustmentRuleDTO: Hashable, Codable {
    var playedLower: Int
    var playedUpper: Int
    var adjustment: Int

    enum CodingKeys: String, CodingKey {
        case playedLower = "played_lower"
        case playedUpper = "played_upper"
        case adjustment
    }

    func toRule() -> EarlyAdjustmentRule {
        .init(playedRange: playedLower...playedUpper, adjustment: adjustment)
    }

    init(from rule: EarlyAdjustmentRule) {
        self.playedLower = rule.playedRange.lowerBound
        self.playedUpper = rule.playedRange.upperBound
        self.adjustment = rule.adjustment
    }

    init(playedLower: Int = 1, playedUpper: Int = 3, adjustment: Int = -2) {
        self.playedLower = playedLower
        self.playedUpper = playedUpper
        self.adjustment = adjustment
    }
}

struct HandicapComputationConfigDTO: Hashable, Codable {
    var gamesUsedRules: [GamesUsedRuleDTO]
    var differentialMultiplier: Double
    var earlyAdjustmentRules: [EarlyAdjustmentRuleDTO]
    var maximumHandicap: Int
    var minimumScoresForIndex: Int
    var defaultParForIndex: Double
    var indexRoundingMode: String
    var courseHandicapRoundingMode: String
    /// `"best"` (default) = lowest scores in pool; `"latest"` = most recent scores in chronological order.
    var scorePoolPolicy: String?

    enum CodingKeys: String, CodingKey {
        case gamesUsedRules = "games_used_rules"
        case differentialMultiplier = "differential_multiplier"
        case earlyAdjustmentRules = "early_adjustment_rules"
        case maximumHandicap = "maximum_handicap"
        case minimumScoresForIndex = "minimum_scores_for_index"
        case defaultParForIndex = "default_par_for_index"
        case indexRoundingMode = "index_rounding_mode"
        case courseHandicapRoundingMode = "course_handicap_rounding_mode"
        case scorePoolPolicy = "score_pool_policy"
    }

    func toConfig() -> HandicapComputationConfig {
        HandicapComputationConfig(
            gamesUsedRules: gamesUsedRules.map { $0.toRule() },
            differentialMultiplier: differentialMultiplier,
            earlyAdjustmentRules: earlyAdjustmentRules.map { $0.toRule() },
            maximumHandicap: maximumHandicap,
            minimumScoresForIndex: minimumScoresForIndex,
            defaultParForIndex: defaultParForIndex,
            indexRoundingMode: Self.parseIndexRounding(indexRoundingMode),
            courseHandicapRoundingMode: Self.parseCourseRounding(courseHandicapRoundingMode),
            scorePoolPolicy: Self.parseScorePoolPolicy(scorePoolPolicy)
        )
    }

    init(from config: HandicapComputationConfig) {
        self.gamesUsedRules = config.gamesUsedRules.map { .init(from: $0) }
        self.differentialMultiplier = config.differentialMultiplier
        self.earlyAdjustmentRules = config.earlyAdjustmentRules.map { .init(from: $0) }
        self.maximumHandicap = config.maximumHandicap
        self.minimumScoresForIndex = config.minimumScoresForIndex
        self.defaultParForIndex = config.defaultParForIndex
        self.indexRoundingMode = Self.encodeIndexRounding(config.indexRoundingMode)
        self.courseHandicapRoundingMode = Self.encodeCourseRounding(config.courseHandicapRoundingMode)
        self.scorePoolPolicy = Self.encodeScorePoolPolicy(config.scorePoolPolicy)
    }

    init(
        gamesUsedRules: [GamesUsedRuleDTO] = [],
        differentialMultiplier: Double = 0.96,
        earlyAdjustmentRules: [EarlyAdjustmentRuleDTO] = [],
        maximumHandicap: Int = 21,
        minimumScoresForIndex: Int = 1,
        defaultParForIndex: Double = 36.0,
        indexRoundingMode: String = "down_to_tenths",
        courseHandicapRoundingMode: String = "nearest_away_from_zero",
        scorePoolPolicy: String? = nil
    ) {
        self.gamesUsedRules = gamesUsedRules
        self.differentialMultiplier = differentialMultiplier
        self.earlyAdjustmentRules = earlyAdjustmentRules
        self.maximumHandicap = maximumHandicap
        self.minimumScoresForIndex = minimumScoresForIndex
        self.defaultParForIndex = defaultParForIndex
        self.indexRoundingMode = indexRoundingMode
        self.courseHandicapRoundingMode = courseHandicapRoundingMode
        self.scorePoolPolicy = scorePoolPolicy
    }

    static let league2025 = HandicapComputationConfigDTO(from: .league2025)

    // MARK: - Score pool policy

    private static func parseScorePoolPolicy(_ raw: String?) -> HandicapScorePoolPolicy {
        switch raw {
        case "latest": return .latestOfUsedCount
        default: return .bestOfUsedCount
        }
    }

    private static func encodeScorePoolPolicy(_ policy: HandicapScorePoolPolicy) -> String? {
        switch policy {
        case .bestOfUsedCount: return nil
        case .latestOfUsedCount: return "latest"
        }
    }

    // MARK: - Rounding mode serialization

    private static func parseIndexRounding(_ value: String) -> HandicapIndexRoundingMode {
        switch value {
        case "toward_zero_to_tenths": return .towardZeroToTenths
        case "nearest_to_tenths": return .nearestToTenths
        default: return .downToTenths
        }
    }

    private static func encodeIndexRounding(_ mode: HandicapIndexRoundingMode) -> String {
        switch mode {
        case .downToTenths: return "down_to_tenths"
        case .towardZeroToTenths: return "toward_zero_to_tenths"
        case .nearestToTenths: return "nearest_to_tenths"
        }
    }

    private static func parseCourseRounding(_ value: String) -> CourseHandicapRoundingMode {
        switch value {
        case "nearest_to_even": return .nearestToEven
        case "toward_zero": return .towardZero
        default: return .nearestAwayFromZero
        }
    }

    private static func encodeCourseRounding(_ mode: CourseHandicapRoundingMode) -> String {
        switch mode {
        case .nearestAwayFromZero: return "nearest_away_from_zero"
        case .nearestToEven: return "nearest_to_even"
        case .towardZero: return "toward_zero"
        }
    }
}
