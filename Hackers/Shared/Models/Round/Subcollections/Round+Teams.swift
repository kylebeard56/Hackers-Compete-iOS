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
    var color: ColorValue   // Color value identifier for the team
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.teams.rawValue }
    
    init(
        id: String,
        name: String,
        color: ColorValue,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, schema
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}
