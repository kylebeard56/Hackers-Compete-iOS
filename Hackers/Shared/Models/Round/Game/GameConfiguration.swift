//
//  GameConfiguration.swift
//  Hackers
//
//  Created by Kyle Beard on 9/2/25.
//

import Foundation

enum TiePolicy: String, Codable {
    case half           // 0.5 point like true match play
    case pushover       // 0 points, next hole is reset
    case carryover      // 0 points, but ads 1 point to bank until winner gets bank
}

// MARK: - Game Configuration (setup + rules)
struct GameConfiguration: Hashable, Codable {
    var method: ScoringMethod               // Individual or
    var aggregation: Aggregation?           // If teams, determine aggregation computation
    var basis: ScoreBasis                   // Gross or net scoring (should this be automatically determined elsewhere?)
    var handicap: HandicapConfiguration
    var requiresTeams: Bool
    var teeGroupOnly: Bool
    var minPlayers: Int?                    // Minimum number of players needed to play
    var maxPlayers: Int?                    // Maximum number of players allowed
    
    // Match play only
    var pointsPerHole: Int?
    var tiePolicy: TiePolicy?

    init(
        method: ScoringMethod = .individual,
        aggregation: Aggregation? = nil,
        basis: ScoreBasis = .gross,
        handicap: HandicapConfiguration = .init(),
        requiresTeams: Bool = false,
        teeGroupOnly: Bool = false,
        minPlayers: Int? = nil,
        maxPlayers: Int? = nil,
        pointsPerHole: Int? = nil,
        tiePolicy: TiePolicy? = nil
    ) {
        self.method = method
        self.aggregation = aggregation
        self.basis = basis
        self.handicap = handicap
        self.requiresTeams = requiresTeams
        self.teeGroupOnly = teeGroupOnly
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.pointsPerHole = pointsPerHole
        self.tiePolicy = tiePolicy
    }

    enum CodingKeys: String, CodingKey {
        case method, aggregation, basis, handicap
        case requiresTeams = "requires_teams"
        case teeGroupOnly = "tee_group_only"
        case minPlayers = "min_number_players"
        case maxPlayers = "max_number_players"
        case pointsPerHole = "points_per_hole"
        case tiePolicy = "tie_policy"
    }
}

extension GameConfiguration {
    static var strokePlay: GameConfiguration {
        GameConfiguration(
            method: .individual,
            aggregation: nil,
            basis: .gross,
            handicap: .individualStrokePlay,
            requiresTeams: false,
            teeGroupOnly: false,
            pointsPerHole: nil,
            tiePolicy: nil
        )
    }

    static var matchPlay: GameConfiguration {
        GameConfiguration(
            method: .individual,
            aggregation: nil,
            basis: .gross,
            handicap: .individualMatchPlay,
            requiresTeams: false,
            teeGroupOnly: false,
            pointsPerHole: 1,
            tiePolicy: .half
        )
    }
}

// MARK: - Handicap Configuration (scaling dependent on game format)
struct HandicapConfiguration: Hashable, Codable {
    var percentage: Double                  // Base percentage (0.0 to 1.0)
    var isTeamCombined: Bool                // If true, apply to combined team handicaps
    var positionPercentages: [Double]?      // Non-flat dilution for formats like scramble
    
    init(
        percentage: Double = 1.0,
        isTeamCombined: Bool = false,
        positionPercentages: [Double]? = nil
    ) {
        self.percentage = percentage
        self.isTeamCombined = isTeamCombined
        self.positionPercentages = positionPercentages
    }
    
    enum CodingKeys: String, CodingKey {
        case percentage
        case isTeamCombined = "is_team_combined"
        case positionPercentages = "position_percentages"
    }
}

extension HandicapConfiguration {
    // USGA standard configurations
    static let individualStrokePlay = HandicapConfiguration(percentage: 1.0) //0.95)
    static let individualMatchPlay = HandicapConfiguration(percentage: 0.9)
//    static let fourBallStrokePlay = HandicapConfiguration(percentage: 0.85)
//    static let fourBallMatchPlay = HandicapConfiguration(percentage: 0.90)
//    static let foursomes = HandicapConfiguration(percentage: 0.50, isTeamCombined: true)
//    static let scramble4Player = HandicapConfiguration(percentage: 1.0, positionPercentages: [0.25, 0.20, 0.15, 0.10])
//    static let scramble2Player = HandicapConfiguration(percentage: 1.0, positionPercentages: [0.35, 0.15])
//    static let bestBall1of4 = HandicapConfiguration(percentage: 0.75)
//    static let bestBall2of4 = HandicapConfiguration(percentage: 0.85)
//    static let none = HandicapConfiguration(percentage: 0.0)
}
