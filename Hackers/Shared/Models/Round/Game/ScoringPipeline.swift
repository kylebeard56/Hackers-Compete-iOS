//
//  ScoringPipeline.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Scoring Stage

/// A single composable stage in the scoring pipeline.
/// The engine walks these in order, each transforming the intermediate scoring state.
enum ScoringStage: Codable, Hashable {
    case select(RankSelection)
    case transform(PointsMap)
    case modify(ConditionalModifier)
    case reduce(Reduction)
    case compare(ComparisonRule)

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    private enum StageType: String, Codable {
        case select, transform, modify, reduce, compare
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StageType.self, forKey: .type)
        switch type {
        case .select:    self = .select(try container.decode(RankSelection.self, forKey: .payload))
        case .transform: self = .transform(try container.decode(PointsMap.self, forKey: .payload))
        case .modify:    self = .modify(try container.decode(ConditionalModifier.self, forKey: .payload))
        case .reduce:    self = .reduce(try container.decode(Reduction.self, forKey: .payload))
        case .compare:   self = .compare(try container.decode(ComparisonRule.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .select(let v):
            try container.encode(StageType.select, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .transform(let v):
            try container.encode(StageType.transform, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .modify(let v):
            try container.encode(StageType.modify, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .reduce(let v):
            try container.encode(StageType.reduce, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .compare(let v):
            try container.encode(StageType.compare, forKey: .type)
            try container.encode(v, forKey: .payload)
        }
    }
}

// MARK: - Rank Selection

struct RankSelection: Codable, Hashable {
    /// Ranks to include (1-indexed, sorted ascending). e.g. [1] = best ball, [1,2] = best 2 of N.
    var includeRanks: [Int]?
    /// Ranks to exclude. e.g. [1] = drop the best score.
    var excludeRanks: [Int]?
    /// Whether selection is applied hole-by-hole or after computing full-round totals.
    var scope: AggregationScope

    init(
        includeRanks: [Int]? = nil,
        excludeRanks: [Int]? = nil,
        scope: AggregationScope = .perHole
    ) {
        self.includeRanks = includeRanks
        self.excludeRanks = excludeRanks
        self.scope = scope
    }

    enum CodingKeys: String, CodingKey {
        case includeRanks = "include_ranks"
        case excludeRanks = "exclude_ranks"
        case scope
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeRanks = try container.decodeIfPresent([Int].self, forKey: .includeRanks)
        excludeRanks = try container.decodeIfPresent([Int].self, forKey: .excludeRanks)
        scope = try container.decodeIfPresent(AggregationScope.self, forKey: .scope) ?? .perHole
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(includeRanks, forKey: .includeRanks)
        try container.encodeIfPresent(excludeRanks, forKey: .excludeRanks)
        try container.encode(scope, forKey: .scope)
    }
}

// MARK: - Reduction

struct Reduction: Codable, Hashable {
    var mode: ReductionMode
    var scope: AggregationScope

    init(mode: ReductionMode = .sum, scope: AggregationScope = .perHole) {
        self.mode = mode
        self.scope = scope
    }
}

enum ReductionMode: String, Codable {
    case sum
    case difference
    case average
    case min
    case max
}

// MARK: - Comparison Rule

struct ComparisonRule: Codable, Hashable {
    var mode: ComparisonMode
    var tiePolicy: TiePolicy?

    init(mode: ComparisonMode = .matchPlay, tiePolicy: TiePolicy? = .half) {
        self.mode = mode
        self.tiePolicy = tiePolicy
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case tiePolicy = "tie_policy"
    }
}

enum ComparisonMode: String, Codable {
    case matchPlay = "match_play"
    case strokeDifference = "stroke_difference"
    case pointsCompare = "points_compare"
}

// MARK: - Matchup Mode

/// Indicates whether a matchup pairs teams or individual participants.
enum MatchupMode: String, Codable {
    case team
    case individual
    case scoreOwner = "score_owner"
}

// MARK: - Team Matchup

/// A pairing of exactly two teams or two participants for head-to-head competition within a segment.
struct TeamMatchup: Codable, Hashable, Identifiable {
    var id: String
    /// Exactly two team IDs (used when mode == .team). Legacy: always present for backward compatibility.
    var teamIDs: [String]
    /// Exactly two participant IDs (used when mode == .individual).
    var participantIDs: [String]?
    /// Exactly two score owner IDs (used when mode == .scoreOwner).
    var scoreOwnerIDs: [String]?
    /// The owner scope the score owner ids represent.
    var scoreOwnerScope: RoundScoreOwnerScope?
    /// Whether this matchup pairs teams or individuals. Nil decodes as .team for backward compatibility.
    var mode: MatchupMode?

    init(
        id: String = "",
        teamIDs: [String] = [],
        participantIDs: [String]? = nil,
        scoreOwnerIDs: [String]? = nil,
        scoreOwnerScope: RoundScoreOwnerScope? = nil,
        mode: MatchupMode? = nil
    ) {
        self.id = id
        self.teamIDs = teamIDs
        self.participantIDs = participantIDs
        self.scoreOwnerIDs = scoreOwnerIDs
        self.scoreOwnerScope = scoreOwnerScope
        self.mode = mode
    }

    /// Returns the pairing IDs for the current mode (teamIDs or participantIDs).
    func pairingIDs() -> [String] {
        switch mode ?? .team {
        case .individual:
            return participantIDs ?? []
        case .scoreOwner:
            return scoreOwnerIDs ?? []
        case .team:
            return teamIDs
        }
    }

    /// Whether this matchup has exactly two valid pairings.
    var isValid: Bool {
        let ids = pairingIDs().filter(\.isPopulated)
        return ids.count == 2 && Set(ids).count == 2
    }

    enum CodingKeys: String, CodingKey {
        case id
        case teamIDs = "team_ids"
        case participantIDs = "participant_ids"
        case scoreOwnerIDs = "score_owner_ids"
        case scoreOwnerScope = "score_owner_scope"
        case mode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        teamIDs = try container.decodeIfPresent([String].self, forKey: .teamIDs) ?? []
        participantIDs = try container.decodeIfPresent([String].self, forKey: .participantIDs)
        scoreOwnerIDs = try container.decodeIfPresent([String].self, forKey: .scoreOwnerIDs)
        scoreOwnerScope = try container.decodeIfPresent(RoundScoreOwnerScope.self, forKey: .scoreOwnerScope)
        mode = try container.decodeIfPresent(MatchupMode.self, forKey: .mode)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(teamIDs, forKey: .teamIDs)
        try container.encodeIfPresent(participantIDs, forKey: .participantIDs)
        try container.encodeIfPresent(scoreOwnerIDs, forKey: .scoreOwnerIDs)
        try container.encodeIfPresent(scoreOwnerScope, forKey: .scoreOwnerScope)
        try container.encodeIfPresent(mode, forKey: .mode)
    }
}
