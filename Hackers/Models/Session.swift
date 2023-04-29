//
//  Session.swift
//  Hackers
//
//  Created by Kyle Beard on 2/3/23.
//

import Foundation

struct Session: FirebaseIdentifiable {
    /// Identifier for Firebase
    var id: String
    
    /// Boolean for whether session ended
    var ended: Bool
    
    /// Redemption code for selected
    var code: String
    
    /// ID of the player who is the current host
    var host: String
    
    /// Cards of Chaos rules
    var teamDifficulty: String
    var teamRedrawCount: Int
    var arrangement: String
    var players: [PlayerSession]
    var gameplay: GameplaySession
    
    /// When was the session created
    var createdAt: Time
    
    /// When was the last update
    var lastUpdatedAt: Time
    
    init(
        id: String = "",
        ended: Bool = false,
        code: String = "",
        host: String = "",
        teamDifficulty: String = "",
        teamRedrawCount: Int = 0,
        players: [PlayerSession] = [],
        arrangement: String = "",
        gameplay: GameplaySession = GameplaySession(),
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.ended = ended
        self.code = code
        self.host = host
        self.teamDifficulty = teamDifficulty
        self.teamRedrawCount = teamRedrawCount
        self.arrangement = arrangement
        self.players = players
        self.gameplay = gameplay
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, ended, code, players, host, gameplay, arrangement
        case teamDifficulty = "team_difficulty"
        case teamRedrawCount = "team_redraw_count"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
    
    private func name(for i: Int) -> String {
        return players[safe: i]?.name ?? ""
    }
    
    var playerNames: String {
        let p = players
        
        switch p.count {
        case 1:     return "\(name(for: 0))"
        case 2:     return "\(name(for: 0)) and \(name(for: 1))"
        case 3:     return "\(name(for: 0)), \(name(for: 1)), and \(name(for: 2))"
        case 4:     return "\(name(for: 0)), \(name(for: 1)), \(name(for: 2)), and \(name(for: 3))"
        default:    return ""
        }
    }
}

extension Session {
    @discardableResult
    func post() async -> Result<Session, Error> {
        print("POST - Session")
        return await self.post(to: Collections.sessions.rawValue, cache: false)
    }

    @discardableResult
    func put() async -> Result<Session, Error> {
        print("PUT - Session")
        return await self.put(to: Collections.sessions.rawValue, cache: false)
    }

    @discardableResult
    func delete() async -> Result<Bool, Error> {
        print("DELETE - Session")
        return await self.delete(from: Collections.sessions.rawValue, cache: false)
    }
}


struct PlayerSession: Hashable, Codable {
    var id: String
    var name: String
    var color: String
    var difficulty: String
    var redrawCount: Int
    var score: [Int: String]
    
    init(
        id: String = "",
        name: String = "",
        color: String = "",
        difficulty: String = "",
        redrawCount: Int = 0,
        score: [Int: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.difficulty = difficulty
        self.redrawCount = redrawCount
        self.score = score
    }
    
    init(player: Player) {
        self.id = player.id
        self.name = player.name
        self.color = player.color.rawValue
        self.difficulty = player.difficulty.rawValue
        self.redrawCount = player.redrawCount
        self.score = player.score
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, difficulty, score
        case redrawCount = "redraw_count"
    }
}

/// Corresponds to [Hole Number : Rule ID]
//typealias RuleSession = [Int : String]

struct GameplaySession: Hashable, Codable {
    var teamRule: HoleRuleDictionary
    var playerRules: [String: HoleRuleDictionary]
    
    init(
        teamRule: HoleRuleDictionary = [:],
        playerRules: [String: HoleRuleDictionary] = [:]
    ) {
        self.teamRule = teamRule
        self.playerRules = playerRules
    }
}
