//
//  Round.swift
//  Hackers
//
//  Created by Kyle Beard on 8/20/25.
//

import SwiftUI

// MARK: - Round
struct Round: FirebaseIdentifiable {
    var id: String
    var createdBy: String
    var status: String
    var configuration: RoundConfiguration
    
    var courseInfo: CourseInfo
    var players: [RoundPlayer]
    var scorecards: [PlayerScorecard]
    var groups: [TeeTimeGroup]
    var teams: [RoundTeam]
    var scores: [String: [Int: HoleScore]]     // ID of Playable or TeeTimeGroup as key : value as [hole number: score]
    var globalFormat: GlobalGameFormat
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection: String { Collections.rounds.name }
}

enum RoundStatus: String {
    case lobby, active, completed, cancelled
}

// MARK: - RoundConfiguration
struct RoundConfiguration: Hashable, Codable {
    var groupScoringEnabled: Bool       // Team format requires group scoring, makes many games ineligible.
    var useHandicaps: Bool              // Whether to apply handicaps or not
}

// MARK: - CourseInfo
struct CourseInfo: Hashable, Codable {
    var id: String
    var name: String
    var totalHoles: Int
    var tees: [String: TeeBox]  // Tee box ID as key with data as value
}

struct TeeBox: Hashable, Codable {
    var id: String
    var name: String
    var totalPar: Int
    var par: [Int: Int]         // [hole: par]
}

// MARK: - RoundPlayer
struct RoundPlayer: Hashable, Codable, Playable {
    var id: String              // should match id in Player
    var userID: String?         // should match userID in Player
    var handicap: Int?
    var teeBoxID: String
    var groupID: String?
    var teamID: String?
}

// MARK: - PlayerScorecard
struct PlayerScorecard: Hashable, Codable {
    var id: String                  // Should match id in Playable
    var totalStrokes: Int           // Computed by value entered, or net summation if using friendly name
    var totalPar: Int               // Aggregated par value through round
    var scoreToPar: Int             // totalStrokes - totalPar
    var holesCompleted: Int         // How many holes down (i.e. Thru 2)
    var leaderboardPosition: Int    // Ranking on leaderboard from scoreToPar
}

// MARK: - TeeTimeGroup
struct TeeTimeGroup: Hashable, Codable {
    var id: String
    var order: Int
    var players: [String]       // Links to Playable
    var teeTime: String?        // ISO8601 format (displayed in the time zone of the course)
    var startingHole: Int       // Starting hole number
    var startingIndex: Int      // Index of the starting hole based on hole order
    var holeOrder: [Int]        // Order of holes to play [10, 11, 12, ... , 1, 2, 3, ... 9]
    var currentIndex: Int       // Current index of the hole
    
    var currentHole: Int { holeOrder[currentIndex] }
}

// MARK: - RoundTeam
struct RoundTeam: Hashable, Codable {
    var id: String
    var name: String        // App assigned name like Team 1, Team 2, etc
    var players: [String]   // Links to Playable
    var color: ColorValue   // Color value identifier for the team
    var holes: [Int]        // Hole range for which this team is constructed
}

struct ColorValue: Hashable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    
    enum CodingKeys: String, CodingKey {
        case red, green, blue
    }
    
    var color: Color {
        Color(UIColor(red: red, green: green, blue: blue, alpha: 1.0))
    }
}

// MARK: - HoleScore
struct HoleScore: Hashable, Codable {
    var hole: Int                   // Unique key for this score using the hole number
    var strokes: Int?               // Stroke count
    var friendlyScore: String?      // Stroke friendly name (birdie, par, bogey)
    var par: Int?                   // Par value for the hole, so we can always return net logic
    var handicapStrokes: Int?       // Number of strokes given for handicap
    var lastUpdatedAt: Time         // When the score was set
    var updatedBy: String           // Who set the score
}

// MARK: - GlobalGameFormat
struct GlobalGameFormat: Hashable, Codable {
    var format: String              // Name of the game (i.e. stroke play, match play, capt choice, stableford)
    var handicapMethod: String      // Full, percentage, etc
}

enum HandicapMethod {
    case full, percentage, none
}
