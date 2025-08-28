//
//  RoundPlayer.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - RoundParticipant
struct RoundParticipant: FirebaseSubcollectable, Playable {
    var id: String              // should match id in Player
    var userID: String?         // should match userID in Player
    
    var displayName: String     // Name or value to dislay in UI
    var teeBoxID: String
    var originalHandicap: Int   // Starting, inputted handicap from user
    var adjustedHandicap: Int   // Handicap adjustment based on course and slope adjustment
    
    var teamID: String?
    var groupID: String?
    var teeOrder: Int?
    var isHost: Bool
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentCollection: String
    var parentID: String
    var subcollectionName: String
    
    init(
        id: String = "",
        userID: String? = nil,
        displayName: String = "",
        teeBoxID: String = "",
        originalHandicap: Int = 0,
        adjustedHandicap: Int = 0,
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentCollection: String = Collections.rounds.name,
        parentID: String = "",
        subcollectionName: String = RoundSubcollection.participants.rawValue
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.teeBoxID = teeBoxID
        self.originalHandicap = originalHandicap
        self.adjustedHandicap = adjustedHandicap
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentCollection = parentCollection
        self.parentID = parentID
        self.subcollectionName = subcollectionName
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        
        case displayName = "display_name"
        case teeBoxID = "tee_box_id"
        case originalHandicap = "original_handicap"
        case adjustedHandicap = "adjusted_handicap"
        
        case teamID = "team_id"
        case groupID = "group_id"
        case teeOrder = "tee_order"
        case isHost = "is_host"
        
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentCollection = "parent_collection"
        case parentID = "parent_id"
        case subcollectionName = "subcollection_name"
    }
}
