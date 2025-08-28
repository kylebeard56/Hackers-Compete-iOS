//
//  Round+Groupings.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - TeeTimeGroup
struct TeeTimeGroup: FirebaseSubcollectable {
    var id: String
    var order: Int
    var players: [String]       // Links to Playable
    var teeTime: String?        // ISO8601 format (displayed in the time zone of the course)
    var startingHole: Int       // Starting hole number
    let lastCompletedHole: Int  // Current friendly hole number
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentCollection: String
    var parentID: String
    var subcollectionName: String
    
    init(
        id: String = "",
        order: Int = 0,
        players: [String] = [],
        teeTime: String? = nil,
        startingHole: Int = 0,
        lastCompletedHole: Int = 0,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentCollection: String = Collections.rounds.name,
        parentID: String = "",
        subcollectionName: String = RoundSubcollection.groups.rawValue
    ) {
        self.id = id
        self.order = order
        self.players = players
        self.teeTime = teeTime
        self.startingHole = startingHole
        self.lastCompletedHole = lastCompletedHole
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentCollection = parentCollection
        self.parentID = parentID
        self.subcollectionName = subcollectionName
    }
    
    enum CodingKeys: String, CodingKey {
        case id, order, players
        case teeTime = "tee_time"
        case startingHole = "starting_hole"
        case lastCompletedHole = "last_completed_hole"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentCollection = "parent_collection"
        case parentID = "parent_id"
        case subcollectionName = "subcollection_name"
    }
}
