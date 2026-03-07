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
        self.requiresHandicaps = requiresHandicaps
        self.defaultHandicapConfig = defaultHandicapConfig
        self.defaultMaxScoreOverPar = defaultMaxScoreOverPar
        self.defaultScoreBasis = defaultScoreBasis
    }

    enum CodingKeys: String, CodingKey {
        case requiresTeams = "requires_teams"
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
