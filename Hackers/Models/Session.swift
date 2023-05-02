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
    
    /// Determine which game is active
    var activeGame: String
    
    /// Players
    var players: [PlayerSession]
    
    /// Chaos
    var chaosSession: ChaosSession
    
    /// When was the session created
    var createdAt: Time
    
    /// When was the last update
    var lastUpdatedAt: Time
    
    init(
        id: String = "",
        ended: Bool = false,
        code: String = "",
        host: String = "",
        activeGame: String = HackersGame.traditional.rawValue,
        players: [PlayerSession] = [],
        chaosSession: ChaosSession = ChaosSession(),
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.ended = ended
        self.code = code
        self.host = host
        self.activeGame = activeGame
        self.players = players
        self.chaosSession = chaosSession
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, ended, code, players, host
        case activeGame = "active_game"
        case chaosSession = "chaos_session"
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
    var chaosRedrawCount: Int
    var score: [Int: String]
    var team: String
    
    init(
        id: String = "",
        name: String = "",
        color: String = "",
        difficulty: String = "",
        chaosRedrawCount: Int = 0,
        score: [Int: String] = [:],
        team: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.difficulty = difficulty
        self.chaosRedrawCount = chaosRedrawCount
        self.score = score
        self.team = team
    }
    
    init(player: Player) {
        self.id = player.id
        self.name = player.name
        self.color = player.color.rawValue
        self.difficulty = player.chaosDifficulty.rawValue
        self.chaosRedrawCount = player.chaosRedrawCount
        self.score = player.score
        self.team = player.team
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, difficulty, score, team
        case chaosRedrawCount = "chaos_redraw_count"
    }
}

struct ChaosSession: Hashable, Codable {
    var teamDifficulty: String
    var teamRedrawCount: Int
    var arrangement: String
    var teamRule: HoleRuleDictionary
    var playerRules: [String: HoleRuleDictionary]
    
    init(
        teamDifficulty: String = GameDifficulty.medium.rawValue,
        teamRedrawCount: Int = 3,
        arrangement: String = ChaosCardArrangement.combo.rawValue,
        teamRule: HoleRuleDictionary = [:],
        playerRules: [String: HoleRuleDictionary] = [:]
    ) {
        self.teamDifficulty = teamDifficulty
        self.teamRedrawCount = teamRedrawCount
        self.arrangement = arrangement
        self.teamRule = teamRule
        self.playerRules = playerRules
    }
    
    enum CodingKeys: String, CodingKey {
        case arrangement
        case teamDifficulty = "team_difficulty"
        case teamRedrawCount = "team_redraw_count"
        case teamRule = "team_rule"
        case playerRules = "player_rules"
    }
}
