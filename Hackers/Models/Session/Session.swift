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
    
    /// Subscription & IAP
    var unlockedPro: Bool
    
    /// # of holes for the round, 9 or 18 for V2.0
    var numberOfHoles: Int
    
    /// The starting hole # which will then tell us playing front or back
    var startingHole: Int
    
    /// Chaos
    var sideGames: [SideGameSession]
    
    /// When was the session created
    var createdAt: Time
    
    /// When was the last update
    var lastUpdatedAt: Time
    
    /// Order of the holes for the user
    var handicapHoleOrder: [Int]?
    
    init(
        id: String = "",
        partyCode: String = "",
        players: [PlayerSession] = [],
        unlockedPro: Bool = false,
        numberOfHoles: Int = 18,
        staringHole: Int = 1,
        sideGames: [SideGameSession] = [],
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time(),
        handicapHoleOrder: [Int]? =  []
    ) {
        self.id = id
        self.partyCode = partyCode
        self.players = players
        self.unlockedPro = unlockedPro
        self.numberOfHoles = numberOfHoles
        self.startingHole = staringHole
        self.sideGames = sideGames
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.handicapHoleOrder = handicapHoleOrder
    }
    
    enum CodingKeys: String, CodingKey {
        case id, players
        case partyCode = "party_code"
        case unlockedPro = "has_unlocked_pro"
        case numberOfHoles = "number_of_holes"
        case startingHole = "starting_hole"
        case sideGames = "side_games"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case handicapHoleOrder = "handicap_hole_order"
    }
}

extension Session {    
    /// Returns a sentence-form describing all players
    var playerNames: String {
        func name(for i: Int) -> String { return players[safe: i]?.name ?? "" }
        switch players.count {
        case 1:     return "\(name(for: 0))"
        case 2:     return "\(name(for: 0)) and \(name(for: 1))"
        case 3:     return "\(name(for: 0)), \(name(for: 1)), and \(name(for: 2))"
        case 4:     return "\(name(for: 0)), \(name(for: 1)), \(name(for: 2)), and \(name(for: 3))"
        default:    return ""
        }
    }
    
    /// Returns the # of holes played for a party (picks the max scored holes).
    var numberOfHolesPlayed: Int {
        players.compactMap({ $0.score.values.filter({ $0 != PlayerScore.none.rawValue }).count }).max() ?? 0
    }
    
    /// Return the starting time of a session as XX:XX
    var roundStartingTime: String {
        createdAt.iso.dateFromISO8601.toTime
    }
    
    var isExpired: Bool {
        createdAt.unix < Date().timeIntervalSince1970 - activeSessionTimeInterval
    }
}

extension Session {
    @discardableResult
    func post() async -> Result<Session, Error> {
        print("POST - Session")
        return await self.post(to: Collections.sessions.rawValue, cache: true)
    }

    @discardableResult
    func put() async -> Result<Session, Error> {
        print("PUT - Session")
        return await self.put(to: Collections.sessions.rawValue, cache: true)
    }

    @discardableResult
    func delete() async -> Result<Bool, Error> {
        print("DELETE - Session")
        return await self.delete(from: Collections.sessions.rawValue, cache: true)
    }
}
