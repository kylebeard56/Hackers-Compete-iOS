//
//  Round+TeeGroup.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - TeeTimeGroup
struct TeeTimeGroup: FirebaseSubcollectable, IndexIterable {
    var id: String
    var index: Int
    var teeTime: String?        // ISO8601 format (displayed in the time zone of the course)
    var startingHole: Int       // Starting hole number
    let lastCompletedHole: Int? // Current friendly hole number
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    var name: String { "Tee Group #\(index)" }
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.teeGroups.rawValue }
    
    init(
        id: String = "",
        index: Int = 1,
        teeTime: String? = nil,
        startingHole: Int = 0,
        lastCompletedHole: Int? = nil,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.index = index
        self.teeTime = teeTime
        self.startingHole = startingHole
        self.lastCompletedHole = lastCompletedHole
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, index, schema
        case teeTime = "tee_time"
        case startingHole = "starting_hole"
        case lastCompletedHole = "last_completed_hole"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}
