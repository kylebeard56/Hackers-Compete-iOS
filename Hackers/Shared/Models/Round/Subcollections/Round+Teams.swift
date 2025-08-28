//
//  Round+Team.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

struct RoundTeam: FirebaseSubcollectable {
    var id: String
    var name: String        // App assigned name like Team 1, Team 2, etc
    var players: [String]   // Links to Playable
    var color: ColorValue   // Color value identifier for the team
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentCollection: String
    var parentID: String
    var subcollectionName: String
    
    init(
        id: String,
        name: String,
        players: [String],
        color: ColorValue,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentCollection: String = Collections.rounds.name,
        parentID: String = "",
        subcollectionName: String = RoundSubcollection.teams.rawValue
    ) {
        self.id = id
        self.name = name
        self.players = players
        self.color = color
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentCollection = parentCollection
        self.parentID = parentID
        self.subcollectionName = subcollectionName
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, players, color
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentCollection = "parent_collection"
        case parentID = "parent_id"
        case subcollectionName = "subcollection_name"
    }
}
