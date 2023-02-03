//
//  Session.swift
//  Hackers
//
//  Created by Kyle Beard on 2/3/23.
//

import Foundation

struct Session: Hashable, Codable {
    /// Identifier for Firebase
    var id: String
    
    /// Redemption code for selected
    var code: String
    
    /// ID of the player who is the current host
    var host: String
    
    /// Gameplay rules
    var teamDifficulty: String
    var teamRedrawCount: Int
    var players: [PlayerSession]
    var gameplay: GameplaySession
    
    /// When was the session created
    var createdAt: Time
    
    /// When was the last update
    var lastUpdatedAt: Time
    
    init(
        id: String,
        code: String,
        host: String,
        teamDifficulty: String,
        teamRedrawCount: Int,
        players: [PlayerSession],
        gameplay: GameplaySession,
        createdAt: Time,
        lastUpdatedAt: Time
    ) {
        self.id = id
        self.code = code
        self.host = host
        self.teamDifficulty = teamDifficulty
        self.teamRedrawCount = teamRedrawCount
        self.players = players
        self.gameplay = gameplay
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, code, players, host, gameplay
        case teamDifficulty = "team_difficulty"
        case teamRedrawCount = "team_redraw_count"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

struct PlayerSession: Hashable, Codable {
    var id: String
    var name: String
    var color: String
    var difficulty: String
    var redrawCount: Int
    
    init(
        id: String,
        name: String,
        color: String,
        difficulty: String,
        redrawCount: Int
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.difficulty = difficulty
        self.redrawCount = redrawCount
    }
    
    init(player: Player) {
        self.id = player.id
        self.name = player.name
        self.color = player.color.rawValue
        self.difficulty = player.difficulty.rawValue
        self.redrawCount = player.redrawCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, difficulty
        case redrawCount = "redraw_count"
    }
}

/// Corresponds to [Hole Number : Rule ID]
typealias RuleSession = [Int : String]

struct GameplaySession: Hashable, Codable {
    var teamRule: RuleSession
    var playerRules: [RuleSession]
}
