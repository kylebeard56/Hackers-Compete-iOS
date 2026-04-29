//
//  GameConfiguration.swift
//  Hackers
//
//  Created by Kyle Beard on 9/2/25.
//

import Foundation

// MARK: - Max Score Over Par

enum MaxScoreOverPar: String, CaseIterable, Codable {
    case bogey                  // par + 1
    case double                 // par + 2
    case triple                 // par + 3
    case quad                   // par + 4
    case quint                  // par + 5
    case sext                   // par + 6
    case twoTimesPar            // par * 2
    case twoTimesParPlusOne     // par * 2 + 1
    case none                   // no limit

    static var allCases: [MaxScoreOverPar] {
        selectableCases
    }

    static var selectableCases: [MaxScoreOverPar] {
        [.bogey, .double, .triple, .quad, .quint, .sext, .none]
    }

    static func selectableCases(hasCoursePars: Bool) -> [MaxScoreOverPar] {
        if hasCoursePars {
            return [.bogey, .double, .triple, .quad, .quint, .sext, .twoTimesPar, .twoTimesParPlusOne, .none]
        }
        return selectableCases
    }
    
    var displayName: String {
        switch self {
        case .bogey:             return "Bogey"
        case .double:            return "Double"
        case .triple:            return "Triple"
        case .quad:              return "Quad"
        case .quint:             return "Quint"
        case .sext:              return "Sext"
        case .twoTimesPar:       return "2x Par"
        case .twoTimesParPlusOne: return "2x Par + 1"
        case .none:              return "None"
        }
    }
    
    func maxScore(for par: Int) -> Int {
        switch self {
        case .bogey:                return par + 1
        case .double:               return par + 2
        case .triple:               return par + 3
        case .quad:                 return par + 4
        case .quint:                return par + 5
        case .sext:                 return par + 6
        case .twoTimesPar:          return par * 2
        case .twoTimesParPlusOne:   return par * 2 + 1
        case .none:                 return 99  // effectively no limit for scoring UI
        }
    }

    func friendlyMaxRelativeValue(for par: Int) -> Int {
        switch self {
        case .none:
            return 12
        default:
            return maxScore(for: par) - par
        }
    }
}

enum TiePolicy: String, Codable {
    case half           // 0.5 point like true match play
    case pushover       // 0 points, next hole is reset
    case carryover      // 0 points, but ads 1 point to bank until winner gets bank
}

// MARK: - Game Configuration (setup + rules)
/// @deprecated: Use GameTemplate.requirements + GameTemplate.pipeline instead.
/// Retained for backward compatibility with existing Firestore documents.
struct GameConfiguration: Hashable, Codable {
    var method: ScoringMethod               // Individual or
    var aggregation: Aggregation?           // If teams, determine aggregation computation
    var basis: ScoreBasis                   // Gross or net scoring (should this be automatically determined elsewhere?)
    var handicap: HandicapConfiguration
    var requiresTeams: Bool
    var teeGroupOnly: Bool                  // [ASAP] TODO: Remove this GameConfiguration format
    var minPlayers: Int?                    // Minimum number of players needed to play
    var maxPlayers: Int?                    // Maximum number of players allowed
    
    // Match play only
    var pointsPerHole: Int?
    var tiePolicy: TiePolicy?
    
    // Max score cap for hole scoring (e.g. quad = par + 4)
    var maxScoreOverPar: MaxScoreOverPar

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
        tiePolicy: TiePolicy? = nil,
        maxScoreOverPar: MaxScoreOverPar = .quad
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
        self.maxScoreOverPar = maxScoreOverPar
    }

    enum CodingKeys: String, CodingKey {
        case method, aggregation, basis, handicap
        case requiresTeams = "requires_teams"
        case teeGroupOnly = "tee_group_only"
        case minPlayers = "min_number_players"
        case maxPlayers = "max_number_players"
        case pointsPerHole = "points_per_hole"
        case tiePolicy = "tie_policy"
        case maxScoreOverPar = "max_score_over_par"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        method = try c.decode(ScoringMethod.self, forKey: .method)
        aggregation = try c.decodeIfPresent(Aggregation.self, forKey: .aggregation)
        basis = try c.decode(ScoreBasis.self, forKey: .basis)
        handicap = try c.decode(HandicapConfiguration.self, forKey: .handicap)
        requiresTeams = try c.decode(Bool.self, forKey: .requiresTeams)
        teeGroupOnly = try c.decode(Bool.self, forKey: .teeGroupOnly)
        minPlayers = try c.decodeIfPresent(Int.self, forKey: .minPlayers)
        maxPlayers = try c.decodeIfPresent(Int.self, forKey: .maxPlayers)
        pointsPerHole = try c.decodeIfPresent(Int.self, forKey: .pointsPerHole)
        tiePolicy = try c.decodeIfPresent(TiePolicy.self, forKey: .tiePolicy)
        maxScoreOverPar = try c.decodeIfPresent(MaxScoreOverPar.self, forKey: .maxScoreOverPar) ?? .quad
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(method, forKey: .method)
        try c.encodeIfPresent(aggregation, forKey: .aggregation)
        try c.encode(basis, forKey: .basis)
        try c.encode(handicap, forKey: .handicap)
        try c.encode(requiresTeams, forKey: .requiresTeams)
        try c.encode(teeGroupOnly, forKey: .teeGroupOnly)
        try c.encodeIfPresent(minPlayers, forKey: .minPlayers)
        try c.encodeIfPresent(maxPlayers, forKey: .maxPlayers)
        try c.encodeIfPresent(pointsPerHole, forKey: .pointsPerHole)
        try c.encodeIfPresent(tiePolicy, forKey: .tiePolicy)
        try c.encode(maxScoreOverPar, forKey: .maxScoreOverPar)
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
            tiePolicy: nil,
            maxScoreOverPar: .quad
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
            tiePolicy: .half,
            maxScoreOverPar: .quad
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
    static let scramble2Player = HandicapConfiguration(percentage: 1.0, isTeamCombined: true, positionPercentages: [0.35, 0.15])
    static let foursomesAlternateShot = HandicapConfiguration(percentage: 0.50, isTeamCombined: true)
//    static let fourBallStrokePlay = HandicapConfiguration(percentage: 0.85)
//    static let fourBallMatchPlay = HandicapConfiguration(percentage: 0.90)
//    static let foursomes = HandicapConfiguration(percentage: 0.50, isTeamCombined: true)
//    static let scramble4Player = HandicapConfiguration(percentage: 1.0, positionPercentages: [0.25, 0.20, 0.15, 0.10])
//    static let scramble2Player = HandicapConfiguration(percentage: 1.0, positionPercentages: [0.35, 0.15])
//    static let bestBall1of4 = HandicapConfiguration(percentage: 0.75)
//    static let bestBall2of4 = HandicapConfiguration(percentage: 0.85)
//    static let none = HandicapConfiguration(percentage: 0.0)
}
