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
    
    /// Redemption code for selected
    var partyCode: String
    
    /// Players
    var players: [PlayerSession]
    
    /// Chaos
    var sideGames: [SideGameSession]
    
    /// When was the session created
    var createdAt: Time
    
    /// When was the last update
    var lastUpdatedAt: Time
    
    init(
        id: String = "",
        partyCode: String = "",
        players: [PlayerSession] = [],
        sideGames: [SideGameSession] = [],
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.partyCode = partyCode
        self.players = players
        self.sideGames = sideGames
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, players
        case partyCode = "party_code"
        case sideGames = "side_games"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
    
    private func name(for i: Int) -> String {
        return players[safe: i]?.name ?? ""
    }
    
    var playerNames: String {
        switch players.count {
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
