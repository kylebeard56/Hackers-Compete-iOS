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

enum PlayerStatus: String {
    case active, inactive
}

struct Player: Hashable, Codable, Playable, FirebaseIdentifiable {
    var id: String
    var userID: String?
    var playerID: String?
    var name: Name
    var rounds: [String]
    var handicaps: [Handicap]
    var isPrimary: Bool
    var status: String
    
    var playerHistory: [String: PlayerHistoryEntry]
    var courseHistory: [String: CourseHistoryEntry]
    var processedRoundIds: [String]
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection = Collections.players.name
    var schema: Int = 1
    
    /// Flagged as offline since there is no userID associated with this player
    var isOffline: Bool { userID == nil }
    
    /// The status is equal to active
    var isActive: Bool { status == PlayerStatus.active.rawValue }
    
    /// LOCAL: Flagged to be created in players collection when ingested into the game lobby
    var needsToBeCreated: Bool = false
    
    init(
        id: String = HackersID.string(),
        userID: String? = nil,
        name: Name = .init(),
        rounds: [String] = [],
        handicaps: [Handicap] = [],
        isPrimary: Bool = false,
        status: String = PlayerStatus.active.rawValue,
        playerHistory: [String: PlayerHistoryEntry] = [:],
        courseHistory: [String: CourseHistoryEntry] = [:],
        processedRoundIds: [String] = [],
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.userID = userID
        self.playerID = id
        self.name = name.normalizedForStorage
        self.rounds = rounds
        self.handicaps = handicaps
        self.isPrimary = isPrimary
        self.status = status
        self.playerHistory = playerHistory
        self.courseHistory = courseHistory
        self.processedRoundIds = processedRoundIds
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    init(
        playable: any Playable,
        rounds: [String] = [],
        handicaps: [Handicap] = [],
        isPrimary: Bool = false,
        status: String = PlayerStatus.active.rawValue,
        playerHistory: [String: PlayerHistoryEntry] = [:],
        courseHistory: [String: CourseHistoryEntry] = [:],
        processedRoundIds: [String] = [],
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        let fallbackID = HackersID.string()
        
        self.id = playable.playerID ?? fallbackID
        self.userID = playable.userID
        self.playerID = playable.playerID ?? fallbackID
        self.name = playable.name.normalizedForStorage
        self.rounds = rounds
        self.handicaps = handicaps
        self.isPrimary = isPrimary
        self.status = status
        self.playerHistory = playerHistory
        self.courseHistory = courseHistory
        self.processedRoundIds = processedRoundIds
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, rounds, handicaps, status, schema
        case userID = "user_id"
        case playerID = "player_id"
        case isPrimary = "is_primary"
        case playerHistory = "player_history"
        case courseHistory = "course_history"
        case processedRoundIds = "processed_round_ids"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userID = try c.decodeIfPresent(String.self, forKey: .userID)
        playerID = try c.decodeIfPresent(String.self, forKey: .playerID) ?? id
        name = try c.decode(Name.self, forKey: .name)
        rounds = try c.decode([String].self, forKey: .rounds)
        handicaps = try c.decode([Handicap].self, forKey: .handicaps)
        isPrimary = try c.decode(Bool.self, forKey: .isPrimary)
        status = try c.decode(String.self, forKey: .status)
        playerHistory = try c.decodeIfPresent([String: PlayerHistoryEntry].self, forKey: .playerHistory) ?? [:]
        courseHistory = try c.decodeIfPresent([String: CourseHistoryEntry].self, forKey: .courseHistory) ?? [:]
        processedRoundIds = try c.decodeIfPresent([String].self, forKey: .processedRoundIds) ?? []
        createdAt = try c.decode(Time.self, forKey: .createdAt)
        lastUpdatedAt = try c.decode(Time.self, forKey: .lastUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(userID, forKey: .userID)
        try c.encodeIfPresent(playerID, forKey: .playerID)
        try c.encode(name, forKey: .name)
        try c.encode(rounds, forKey: .rounds)
        try c.encode(handicaps, forKey: .handicaps)
        try c.encode(isPrimary, forKey: .isPrimary)
        try c.encode(status, forKey: .status)
        try c.encode(playerHistory, forKey: .playerHistory)
        try c.encode(courseHistory, forKey: .courseHistory)
        try c.encode(processedRoundIds, forKey: .processedRoundIds)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
}

extension Player {
    func exists(within collection: [Player]) -> Bool {
        collection.contains { $0.id == self.id }
    }
    
    func isHost(in snapshot: RoundSnapshot) -> Bool {
        self.id == snapshot.participants.first(where: \.isHost)?.playerID
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
        let normalized = normalizedForStorage
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(normalized.givenName, forKey: .givenName)
        try container.encode(normalized.familyName, forKey: .familyName)
        try container.encode(normalized.searchKey, forKey: .searchKey)
        try container.encode(normalized.searchKeyReverse, forKey: .searchKeyReverse)
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
    var normalizedForStorage: Name {
        let given = givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = familyName.trimmingCharacters(in: .whitespacesAndNewlines)

        if given.isEmpty, family.isEmpty {
            return Name()
        }

        if given.localizedCaseInsensitiveCompare(family) == .orderedSame,
           given.contains(where: \.isWhitespace) {
            return Name(given)
        }

        if family.isEmpty, given.contains(where: \.isWhitespace) {
            return Name(given)
        }

        if given.isEmpty, family.contains(where: \.isWhitespace) {
            return Name(family)
        }

        return Name(given, family)
    }

    var normalizedMatchKey: String {
        normalizedForStorage.trimmedFullName.normalizedForSearch
    }

    var isEmpty: Bool { givenName.isEmpty || familyName.isEmpty }
    var isPopulated: Bool { givenName.isPopulated || familyName.isPopulated }
    var fullName: String {
        [givenName, familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(\.isPopulated)
            .joined(separator: " ")
    }
    var initials: String { "\(givenName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))\(familyName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))" }
    
    var trimmedFullName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var displayNameWithPlaceholder: String {
        let t = trimmedFullName
        return t.isEmpty ? "First Last" : t
    }
    
    var displayInitialsWithPlaceholder: String {
        guard !trimmedFullName.isEmpty else { return "FL" }
        return initials
    }
}

extension Name {
    func matches(_ query: String) -> Bool {
        let query = query.normalizedForSearch
        guard !query.isEmpty else { return true }

        if searchKey.contains(query) || searchKeyReverse.contains(query) {
            return true
        }

        let parts = query.split(separator: " ")
        if parts.count > 1 {
            return parts.allSatisfy { part in
                searchKey.contains(part) || searchKeyReverse.contains(part)
            }
        }

        return false
    }
}
