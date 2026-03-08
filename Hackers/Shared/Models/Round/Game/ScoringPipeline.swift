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

    init(includeRanks: [Int]? = nil, excludeRanks: [Int]? = nil) {
        self.includeRanks = includeRanks
        self.excludeRanks = excludeRanks
    }

    enum CodingKeys: String, CodingKey {
        case includeRanks = "include_ranks"
        case excludeRanks = "exclude_ranks"
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

// MARK: - Team Matchup

/// A pairing of exactly two teams for head-to-head competition within a segment.
struct TeamMatchup: Codable, Hashable, Identifiable {
    var id: String
    /// Exactly two team IDs that compete against each other.
    var teamIDs: [String]

    init(id: String = "", teamIDs: [String] = []) {
        self.id = id
        self.teamIDs = teamIDs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case teamIDs = "team_ids"
    }
}
