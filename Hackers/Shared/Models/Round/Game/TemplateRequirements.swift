//
//  TemplateRequirements.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Template Requirements

/// Structural constraints that drive lobby validation and setup UI.
/// The lobby reads these to decide which sections to show; the engine never touches them.
struct TemplateRequirements: Codable, Hashable {
    var minPlayers: Int?
    var maxPlayers: Int?
    var teamSize: TeamSizeRule?
    var teeGroupSize: TeeGroupRule?
    var requiresTeams: Bool
    var requiresMatchups: Bool
    var requiresHandicaps: Bool
    var defaultHandicapConfig: HandicapConfiguration
    var defaultMaxScoreOverPar: MaxScoreOverPar
    var defaultScoreBasis: ScoreBasis

    init(
        minPlayers: Int? = nil,
        maxPlayers: Int? = nil,
        teamSize: TeamSizeRule? = nil,
        teeGroupSize: TeeGroupRule? = nil,
        requiresTeams: Bool = false,
        requiresMatchups: Bool = false,
        requiresHandicaps: Bool = false,
        defaultHandicapConfig: HandicapConfiguration = .individualStrokePlay,
        defaultMaxScoreOverPar: MaxScoreOverPar = .quad,
        defaultScoreBasis: ScoreBasis = .gross
    ) {
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.teamSize = teamSize
        self.teeGroupSize = teeGroupSize
        self.requiresTeams = requiresTeams
        self.requiresMatchups = requiresMatchups
        self.requiresHandicaps = requiresHandicaps
        self.defaultHandicapConfig = defaultHandicapConfig
        self.defaultMaxScoreOverPar = defaultMaxScoreOverPar
        self.defaultScoreBasis = defaultScoreBasis
    }

    /// Display string for min/max players (e.g. "2-20 players", "4 players").
    var playersRangeDisplayString: String? {
        if let min = minPlayers, let max = maxPlayers {
            return min == max ? "\(min) players" : "\(min)-\(max) players"
        }
        if let min = minPlayers {
            return "\(min)+ players"
        }
        if let max = maxPlayers {
            return "1-\(max) players"
        }
        if let teamSize = teamSize, requiresTeams {
            switch teamSize {
            case .exact(let n):
                return "\(n * 2)+ players"
            case .range(let minPer, _):
                let minTotal = 2 * minPer
                return "\(minTotal)+ players"
            case .any:
                return "2+ players"
            }
        }
        return "2+ players"
    }

    enum CodingKeys: String, CodingKey {
        case requiresTeams = "requires_teams"
        case requiresMatchups = "requires_matchups"
        case requiresHandicaps = "requires_handicaps"
        case defaultHandicapConfig = "default_handicap_config"
        case defaultMaxScoreOverPar = "default_max_score_over_par"
        case defaultScoreBasis = "default_score_basis"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case teamSize = "team_size"
        case teeGroupSize = "tee_group_size"
    }
}

// MARK: - Team Size Rule

enum TeamSizeRule: Codable, Hashable {
    /// Exactly N players per team.
    case exact(Int)
    /// Between min and max players per team (inclusive).
    case range(min: Int, max: Int)
    /// Any number of players per team.
    case any

    /// Maximum players per team for rank selection (Best 1, Best 2, etc.). Nil for .any.
    var maxTeamSize: Int? {
        switch self {
        case .exact(let n): return n
        case .range(_, let max): return max
        case .any: return nil
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type, value, min, max
    }

    private enum RuleType: String, Codable {
        case exact, range, any
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RuleType.self, forKey: .type)
        switch type {
        case .exact:
            let value = try container.decode(Int.self, forKey: .value)
            self = .exact(value)
        case .range:
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            self = .range(min: min, max: max)
        case .any:
            self = .any
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exact(let value):
            try container.encode(RuleType.exact, forKey: .type)
            try container.encode(value, forKey: .value)
        case .range(let min, let max):
            try container.encode(RuleType.range, forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        case .any:
            try container.encode(RuleType.any, forKey: .type)
        }
    }
}

// MARK: - Tee Group Size Rule

enum TeeGroupRule: Codable, Hashable {
    case exact(Int)
    case range(min: Int, max: Int)
    case any

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type, value, min, max
    }

    private enum RuleType: String, Codable {
        case exact, range, any
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RuleType.self, forKey: .type)
        switch type {
        case .exact:
            let value = try container.decode(Int.self, forKey: .value)
            self = .exact(value)
        case .range:
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            self = .range(min: min, max: max)
        case .any:
            self = .any
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exact(let value):
            try container.encode(RuleType.exact, forKey: .type)
            try container.encode(value, forKey: .value)
        case .range(let min, let max):
            try container.encode(RuleType.range, forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        case .any:
            try container.encode(RuleType.any, forKey: .type)
        }
    }
}
