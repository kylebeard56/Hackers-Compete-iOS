//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 8/19/25.
//

import Foundation

protocol Playable {
    /// DB internal ID
    var id: String { get set }
    
    /// ID of the `HackersUser` (nil if offline player)
    var userID: String?  { get set }
    
    /// ID of the `PlayerProfile` (nil if offline)
    var playerID: String? { get set }
    
    /// Friendly display name
    var name: Name { get set }
}

// MARK: - Player

struct Player: Hashable, Codable, Playable, FirebaseIdentifiable {
    var id: String
    var userID: String?
    var playerID: String?
    var name: Name
    var rounds: [String]
    var handicaps: [Handicap]
    var isPrimary: Bool
    var isOffline: Bool { userID == nil }
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection = Collections.players.name
    var schema: Int = 1
    
    init(
        id: String = HackersID.string(),
        userID: String? = nil,
        name: Name = .init(),
        rounds: [String] = [],
        handicaps: [Handicap] = [],
        isPrimary: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.userID = userID
        self.playerID = id
        self.name = name
        self.rounds = rounds
        self.handicaps = handicaps
        self.isPrimary = isPrimary
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    init(
        playable: any Playable,
        rounds: [String] = [],
        handicaps: [Handicap] = [],
        isPrimary: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = playable.playerID ?? HackersID.string()
        self.userID = playable.userID
        self.playerID = playable.playerID
        self.name = playable.name
        self.rounds = rounds
        self.handicaps = handicaps
        self.isPrimary = isPrimary
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, rounds, handicaps, schema
        case isPrimary = "is_primary"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

// MARK: - Name

struct Name: Hashable, Codable {
    var givenName: String
    var familyName: String
    
    init(_ givenName: String = "", _ familyName: String = "") {
        self.givenName = givenName
        self.familyName = familyName
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.givenName  = try c.decode(String.self, forKey: .givenName)
        self.familyName = try c.decode(String.self, forKey: .familyName)
        _ = try c.decodeIfPresent(String.self, forKey: .searchKey)
        _ = try c.decodeIfPresent(String.self, forKey: .searchKeyReverse)
    }
    
    enum CodingKeys: String, CodingKey {
        case givenName = "given_name"
        case familyName = "family_name"
        case searchKey = "search_key"
        case searchKeyReverse = "search_key_reverse"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(givenName, forKey: .givenName)
        try container.encode(familyName, forKey: .familyName)
        try container.encode(searchKey, forKey: .searchKey)
        try container.encode(searchKeyReverse, forKey: .searchKeyReverse)
    }
}

extension Name {
    private var normalizedGiven: String { givenName.normalizedForSearchToken }
    private var normalizedFamily: String { familyName.normalizedForSearchToken }
    
    var searchKey: String { "\(normalizedGiven) \(normalizedFamily)".normalizedForSearch }
    var searchKeyReverse: String { "\(normalizedFamily) \(normalizedGiven)".normalizedForSearch }
    
    static var forwardSearchField: String { Name.CodingKeys.searchKey.rawValue }
    static var reverseSearchField: String { Name.CodingKeys.searchKeyReverse.rawValue }
}

extension Name {
    init(_ full: String) {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

        switch parts.count {
        case 0:
            self.givenName = ""
            self.familyName = ""
        case 1:
            self.givenName = String(parts[0])
            self.familyName = ""
        default:
            self.givenName = String(parts[0])
            self.familyName = String(parts[1])
        }
    }
}

extension Name {
    var isEmpty: Bool { givenName.isEmpty || familyName.isEmpty }
    var isPopulated: Bool { givenName.isPopulated || familyName.isPopulated }
    var fullName: String { "\(givenName) \(familyName)" }
    var initials: String { "\(givenName.prefix(1))\(familyName.prefix(1))" }
}
