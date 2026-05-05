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

struct GamesUsedMatrixRow: Hashable {
    var played: Int
    var used: Int
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
    var usesCourseRatingSlopeAdjustment: Bool
    var indexRoundingMode: String
    var courseHandicapRoundingMode: String
    /// `"best"` (default) = lowest scores in pool; `"latest"` = most recent scores in chronological order.
    var scorePoolPolicy: String?
    /// Last _M_ scores by `recorded_at` enter the handicap pool; `nil` = entire history.
    var rollingPoolSize: Int?

    enum CodingKeys: String, CodingKey {
        case gamesUsedRules = "games_used_rules"
        case differentialMultiplier = "differential_multiplier"
        case earlyAdjustmentRules = "early_adjustment_rules"
        case maximumHandicap = "maximum_handicap"
        case minimumScoresForIndex = "minimum_scores_for_index"
        case defaultParForIndex = "default_par_for_index"
        case usesCourseRatingSlopeAdjustment = "uses_course_rating_slope_adjustment"
        case indexRoundingMode = "index_rounding_mode"
        case courseHandicapRoundingMode = "course_handicap_rounding_mode"
        case scorePoolPolicy = "score_pool_policy"
        case rollingPoolSize = "rolling_pool_size"
    }

    func toConfig() -> HandicapComputationConfig {
        HandicapComputationConfig(
            gamesUsedRules: gamesUsedRules.map { $0.toRule() },
            differentialMultiplier: differentialMultiplier,
            earlyAdjustmentRules: earlyAdjustmentRules.map { $0.toRule() },
            maximumHandicap: maximumHandicap,
            minimumScoresForIndex: minimumScoresForIndex,
            defaultParForIndex: defaultParForIndex,
            usesCourseRatingSlopeAdjustment: usesCourseRatingSlopeAdjustment,
            indexRoundingMode: Self.parseIndexRounding(indexRoundingMode),
            courseHandicapRoundingMode: Self.parseCourseRounding(courseHandicapRoundingMode),
            scorePoolPolicy: Self.parseScorePoolPolicy(scorePoolPolicy),
            rollingPoolSize: rollingPoolSize
        )
    }

    init(from config: HandicapComputationConfig) {
        self.gamesUsedRules = config.gamesUsedRules.map { .init(from: $0) }
        self.differentialMultiplier = config.differentialMultiplier
        self.earlyAdjustmentRules = config.earlyAdjustmentRules.map { .init(from: $0) }
        self.maximumHandicap = config.maximumHandicap
        self.minimumScoresForIndex = config.minimumScoresForIndex
        self.defaultParForIndex = config.defaultParForIndex
        self.usesCourseRatingSlopeAdjustment = config.usesCourseRatingSlopeAdjustment
        self.indexRoundingMode = Self.encodeIndexRounding(config.indexRoundingMode)
        self.courseHandicapRoundingMode = Self.encodeCourseRounding(config.courseHandicapRoundingMode)
        self.scorePoolPolicy = Self.encodeScorePoolPolicy(config.scorePoolPolicy)
        self.rollingPoolSize = config.rollingPoolSize
    }

    init(
        gamesUsedRules: [GamesUsedRuleDTO] = [],
        differentialMultiplier: Double = 0.96,
        earlyAdjustmentRules: [EarlyAdjustmentRuleDTO] = [],
        maximumHandicap: Int = 21,
        minimumScoresForIndex: Int = 1,
        defaultParForIndex: Double = 36.0,
        usesCourseRatingSlopeAdjustment: Bool = true,
        indexRoundingMode: String = "down_to_tenths",
        courseHandicapRoundingMode: String = "nearest_away_from_zero",
        scorePoolPolicy: String? = nil,
        rollingPoolSize: Int? = nil
    ) {
        self.gamesUsedRules = gamesUsedRules
        self.differentialMultiplier = differentialMultiplier
        self.earlyAdjustmentRules = earlyAdjustmentRules
        self.maximumHandicap = maximumHandicap
        self.minimumScoresForIndex = minimumScoresForIndex
        self.defaultParForIndex = defaultParForIndex
        self.usesCourseRatingSlopeAdjustment = usesCourseRatingSlopeAdjustment
        self.indexRoundingMode = indexRoundingMode
        self.courseHandicapRoundingMode = courseHandicapRoundingMode
        self.scorePoolPolicy = scorePoolPolicy
        self.rollingPoolSize = rollingPoolSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gamesUsedRules = try c.decodeIfPresent([GamesUsedRuleDTO].self, forKey: .gamesUsedRules) ?? []
        differentialMultiplier = try c.decodeIfPresent(Double.self, forKey: .differentialMultiplier) ?? 0.96
        earlyAdjustmentRules = try c.decodeIfPresent([EarlyAdjustmentRuleDTO].self, forKey: .earlyAdjustmentRules) ?? []
        maximumHandicap = try c.decodeIfPresent(Int.self, forKey: .maximumHandicap) ?? 21
        minimumScoresForIndex = try c.decodeIfPresent(Int.self, forKey: .minimumScoresForIndex) ?? 1
        defaultParForIndex = try c.decodeIfPresent(Double.self, forKey: .defaultParForIndex) ?? 36.0
        usesCourseRatingSlopeAdjustment = try c.decodeIfPresent(Bool.self, forKey: .usesCourseRatingSlopeAdjustment) ?? true
        indexRoundingMode = try c.decodeIfPresent(String.self, forKey: .indexRoundingMode) ?? "down_to_tenths"
        courseHandicapRoundingMode = try c.decodeIfPresent(String.self, forKey: .courseHandicapRoundingMode) ?? "nearest_away_from_zero"
        scorePoolPolicy = try c.decodeIfPresent(String.self, forKey: .scorePoolPolicy)
        rollingPoolSize = try c.decodeIfPresent(Int.self, forKey: .rollingPoolSize)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(gamesUsedRules, forKey: .gamesUsedRules)
        try c.encode(differentialMultiplier, forKey: .differentialMultiplier)
        try c.encode(earlyAdjustmentRules, forKey: .earlyAdjustmentRules)
        try c.encode(maximumHandicap, forKey: .maximumHandicap)
        try c.encode(minimumScoresForIndex, forKey: .minimumScoresForIndex)
        try c.encode(defaultParForIndex, forKey: .defaultParForIndex)
        try c.encode(usesCourseRatingSlopeAdjustment, forKey: .usesCourseRatingSlopeAdjustment)
        try c.encode(indexRoundingMode, forKey: .indexRoundingMode)
        try c.encode(courseHandicapRoundingMode, forKey: .courseHandicapRoundingMode)
        try c.encodeIfPresent(scorePoolPolicy, forKey: .scorePoolPolicy)
        try c.encodeIfPresent(rollingPoolSize, forKey: .rollingPoolSize)
    }

    static let league2025 = HandicapComputationConfigDTO(from: .league2025)

    static let gamesUsedMatrixRange = 1...20

    func gamesUsedMatrixRows() -> [GamesUsedMatrixRow] {
        let config = toConfig()
        return Self.gamesUsedMatrixRange.map { played in
            GamesUsedMatrixRow(
                played: played,
                used: Self.clampedGamesUsed(config.gamesUsed(forPoolCount: played), played: played)
            )
        }
    }

    static func compressedGamesUsedRules(fromMatrix rows: [GamesUsedMatrixRow]) -> [GamesUsedRuleDTO] {
        let sortedRows = rows
            .filter { gamesUsedMatrixRange.contains($0.played) }
            .sorted { $0.played < $1.played }

        guard !sortedRows.isEmpty else {
            return league2025.gamesUsedRules
        }

        var rules: [GamesUsedRuleDTO] = []
        var currentLower = sortedRows[0].played
        var currentUpper = sortedRows[0].played
        var currentUsed = clampedGamesUsed(sortedRows[0].used, played: sortedRows[0].played)

        for row in sortedRows.dropFirst() {
            let used = clampedGamesUsed(row.used, played: row.played)
            if row.played == currentUpper + 1, used == currentUsed {
                currentUpper = row.played
            } else {
                rules.append(.init(playedLower: currentLower, playedUpper: currentUpper, used: currentUsed))
                currentLower = row.played
                currentUpper = row.played
                currentUsed = used
            }
        }

        rules.append(.init(playedLower: currentLower, playedUpper: 100, used: currentUsed))
        return rules
    }

    static func clampedGamesUsed(_ used: Int, played: Int) -> Int {
        min(max(used, 1), max(played, 1))
    }

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
