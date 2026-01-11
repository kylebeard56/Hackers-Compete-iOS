//
//  Round+Participant.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - RoundParticipant
struct RoundParticipant: FirebaseSubcollectable, Playable {
    var id: String              // unique participant ID for subcollection
    var userID: String?         // the id of the authenticated user (upstream of player profiles)
    var playerID: String?       // the id of the specific user's player profile
    
    var name: Name              // Name or value to dislay in UI
    var teeBoxID: String
    var originalHandicap: Int   // Starting, inputted handicap from user
    var adjustedHandicap: Int   // Handicap adjustment based on course and slope adjustment
    
    var teamID: String?
    var groupID: String?
    var teeOrder: Int?
    var isHost: Bool
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.participants.rawValue }
    
    init(
        id: String = "",
        userID: String? = nil,
        playerID: String? = nil,
        name: Name = .init(),
        teeBoxID: String = "",
        originalHandicap: Int = 0,
        adjustedHandicap: Int = 0,
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.userID = userID
        self.playerID = playerID
        self.name = name
        self.teeBoxID = teeBoxID
        self.originalHandicap = originalHandicap
        self.adjustedHandicap = adjustedHandicap
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    init(
        player: Player,
        teeBoxID: String = "",
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        let handicap = player.handicaps.first?.value ?? 0
        
        self.id = HackersID.string()
        self.userID = player.userID
        self.playerID = player.id
        self.name = player.name
        
        self.teeBoxID = teeBoxID
        self.originalHandicap = handicap
        self.adjustedHandicap = handicap
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case playerID = "player_id"
        
        case name
        case teeBoxID = "tee_box_id"
        case originalHandicap = "original_handicap"
        case adjustedHandicap = "adjusted_handicap"
        
        case teamID = "team_id"
        case groupID = "group_id"
        case teeOrder = "tee_order"
        case isHost = "is_host"
        
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
        case schema
    }
}

extension RoundParticipant {
    var isOnline: Bool { userID != nil }
    var isOffline: Bool { userID == nil }
}

extension RoundParticipant {
    var alphabeticName: String {
        name.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
