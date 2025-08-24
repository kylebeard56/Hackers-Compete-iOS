//
//  GameFormat.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation
import Foundation

// MARK: - Game Format Types
enum GameFormatType: String, CaseIterable, Codable {
    case strokePlay = "stroke_play"
    case matchPlay = "match_play"
    case scramble = "scramble"
    case stableford = "stableford"
    case custom = "custom"
    case bestBall = "best_ball"
    case alternate = "alternate_shot"
    case skins = "skins"
    
    var displayName: String {
        switch self {
        case .strokePlay: return "Stroke Play"
        case .matchPlay: return "Match Play"
        case .scramble: return "Scramble"
        case .stableford: return "Stableford"
        case .custom: return "Custom Scoring"
        case .bestBall: return "Best Ball"
        case .alternate: return "Alternate Shot"
        case .skins: return "Skins"
        }
    }
}

// MARK: - Handicap Configuration
struct HandicapConfiguration: Codable, Hashable {
    var percentage: Double              // Base percentage (0.0 to 1.0)
    var isTeamCombined: Bool           // If true, apply to combined team handicaps
    var positionPercentages: [Double]? // For formats like scramble [0.25, 0.20, 0.15, 0.10]
    
    init(percentage: Double, isTeamCombined: Bool = false, positionPercentages: [Double]? = nil) {
        self.percentage = percentage
        self.isTeamCombined = isTeamCombined
        self.positionPercentages = positionPercentages
    }
    
    // USGA standard configurations
    static let individualStrokePlay = HandicapConfiguration(percentage: 0.95)
    static let individualMatchPlay = HandicapConfiguration(percentage: 1.0)
    static let fourBallStrokePlay = HandicapConfiguration(percentage: 0.85)
    static let fourBallMatchPlay = HandicapConfiguration(percentage: 0.90)
    static let foursomes = HandicapConfiguration(percentage: 0.50, isTeamCombined: true)
    static let scramble4Player = HandicapConfiguration(percentage: 1.0, positionPercentages: [0.25, 0.20, 0.15, 0.10])
    static let scramble2Player = HandicapConfiguration(percentage: 1.0, positionPercentages: [0.35, 0.15])
    static let bestBall1of4 = HandicapConfiguration(percentage: 0.75)
    static let bestBall2of4 = HandicapConfiguration(percentage: 0.85)
    static let none = HandicapConfiguration(percentage: 0.0)
}

// MARK: - Score Result (relative to par)
enum ScoreResult: Int, CaseIterable, Codable {
    case albatross = -3
    case eagle = -2
    case birdie = -1
    case par = 0
    case bogey = 1
    case doubleBogey = 2
    case tripleBogey = 3
    case quadrupleBogeyOrWorse = 4
    
    var friendlyName: String {
        switch self {
        case .albatross: return "Albatross"
        case .eagle: return "Eagle"
        case .birdie: return "Birdie"
        case .par: return "Par"
        case .bogey: return "Bogey"
        case .doubleBogey: return "Double Bogey"
        case .tripleBogey: return "Triple Bogey"
        case .quadrupleBogeyOrWorse: return "Quadruple Bogey+"
        }
    }
    
    static func from(strokes: Int, par: Int) -> ScoreResult {
        let difference = strokes - par
        return ScoreResult(rawValue: min(difference, 4)) ?? .quadrupleBogeyOrWorse
    }
}

// MARK: - Scoring Configuration (Universal Scoring Funnel)
struct ScoringConfiguration: Codable, Hashable {
    var albatross: Int
    var eagle: Int
    var birdie: Int
    var par: Int
    var bogey: Int
    var doubleBogey: Int
    var tripleBogey: Int
    var quadrupleBogeyOrWorse: Int
    
    // Calculate points for any score result
    func points(for scoreResult: ScoreResult) -> Int {
        switch scoreResult {
        case .albatross: return albatross
        case .eagle: return eagle
        case .birdie: return birdie
        case .par: return par
        case .bogey: return bogey
        case .doubleBogey: return doubleBogey
        case .tripleBogey: return tripleBogey
        case .quadrupleBogeyOrWorse: return quadrupleBogeyOrWorse
        }
    }
    
    // Calculate points from raw strokes and par
    func points(strokes: Int, par: Int) -> Int {
        let scoreResult = ScoreResult.from(strokes: strokes, par: par)
        return points(for: scoreResult)
    }
    
    // Predefined configurations for different formats
    static let strokePlay = ScoringConfiguration(
        albatross: -3, eagle: -2, birdie: -1, par: 0,
        bogey: 1, doubleBogey: 2, tripleBogey: 3, quadrupleBogeyOrWorse: 4
    )
    
    static let stableford = ScoringConfiguration(
        albatross: 5, eagle: 4, birdie: 3, par: 2,
        bogey: 1, doubleBogey: 0, tripleBogey: 0, quadrupleBogeyOrWorse: 0
    )
    
    static let customDefault = ScoringConfiguration(
        albatross: 5, eagle: 3, birdie: 1, par: 0,
        bogey: -1, doubleBogey: -2, tripleBogey: -3, quadrupleBogeyOrWorse: -4
    )
}

// MARK: - Game Format Protocol
protocol GameFormat {
    var name: String { get }
    var formatType: GameFormatType { get }
    var handicapConfiguration: HandicapConfiguration { get }
    var isTeamBased: Bool { get }
}

// MARK: - Team Configuration
struct TeamConfiguration: Codable, Hashable {
    var teamSize: Int
    var scoringMethod: TeamScoringMethod
    
    enum TeamScoringMethod: String, CaseIterable, Codable {
        case bestBall = "best_ball"
        case scramble = "scramble"
        case alternate = "alternate_shot"
        case combined = "combined"
        
        var displayName: String {
            switch self {
            case .bestBall: return "Best Ball"
            case .scramble: return "Scramble"
            case .alternate: return "Alternate Shot"
            case .combined: return "Combined Scores"
            }
        }
    }
}

// MARK: - Match Play Configuration
struct MatchPlayConfiguration: Codable, Hashable {
    // Placeholder for potential match play specific settings
    init() {}
}

// MARK: - Global Game Format
struct GlobalGameFormat: GameFormat, Codable, Identifiable {
    var id = HackersID.string()
    var name: String
    var formatType: GameFormatType
    var handicapConfiguration: HandicapConfiguration
    var isTeamBased: Bool
    
    // Optional composition properties
    var teamConfiguration: TeamConfiguration?
    var scoringConfiguration: ScoringConfiguration
    var matchPlayConfiguration: MatchPlayConfiguration?
    
    init(
        name: String,
        formatType: GameFormatType,
        handicapConfiguration: HandicapConfiguration = .individualStrokePlay,
        isTeamBased: Bool = false,
        teamConfiguration: TeamConfiguration? = nil,
        scoringConfiguration: ScoringConfiguration? = nil,
        matchPlayConfiguration: MatchPlayConfiguration? = nil
    ) {
        self.name = name
        self.formatType = formatType
        self.handicapConfiguration = handicapConfiguration
        self.isTeamBased = isTeamBased
        self.teamConfiguration = teamConfiguration
        self.matchPlayConfiguration = matchPlayConfiguration
        
        // Set scoring configuration based on format type
        if let customConfig = scoringConfiguration {
            self.scoringConfiguration = customConfig
        } else {
            switch formatType {
            case .strokePlay, .matchPlay:
                self.scoringConfiguration = .strokePlay
            case .stableford:
                self.scoringConfiguration = .stableford
            case .custom:
                self.scoringConfiguration = .customDefault
            default:
                self.scoringConfiguration = .strokePlay
            }
        }
    }
}

// MARK: - Factory Methods
extension GlobalGameFormat {
    static func strokePlay(name: String = "Stroke Play") -> GlobalGameFormat {
        return GlobalGameFormat(
            name: name,
            formatType: .strokePlay,
            handicapConfiguration: .individualStrokePlay
        )
    }
    
    static func matchPlay(name: String = "Match Play") -> GlobalGameFormat {
        return GlobalGameFormat(
            name: name,
            formatType: .matchPlay,
            handicapConfiguration: .individualMatchPlay,
            matchPlayConfiguration: MatchPlayConfiguration()
        )
    }
    
    static func stableford(name: String = "Stableford") -> GlobalGameFormat {
        return GlobalGameFormat(
            name: name,
            formatType: .stableford,
            handicapConfiguration: .individualStrokePlay,
            scoringConfiguration: .stableford
        )
    }
}
