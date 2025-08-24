//
//  Round+Groupings.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - TeeTimeGroup
struct TeeTimeGroup: Hashable, Codable {
    var id: String
    var order: Int
    var players: [String]       // Links to Playable
    var teeTime: String?        // ISO8601 format (displayed in the time zone of the course)
    var startingHole: Int       // Starting hole number
    var startingIndex: Int      // Index of the starting hole based on hole order
    var holeOrder: [Int]        // Order of holes to play [10, 11, 12, ... , 1, 2, 3, ... 9]
    var currentIndex: Int       // Current index of the hole
    let currentHoleNumber: Int  // Current friendly hole number
    
    init(
        id: String = "",
        order: Int = 0,
        players: [String] = [],
        teeTime: String? = nil,
        startingHole: Int = 0,
        startingIndex: Int = 0,
        holeOrder: [Int] = [],
        currentIndex: Int = 0
    ) {
        self.id = id
        self.order = order
        self.players = players
        self.teeTime = teeTime
        self.startingHole = startingHole
        self.startingIndex = startingIndex
        self.holeOrder = holeOrder
        self.currentIndex = currentIndex
        self.currentHoleNumber = holeOrder[currentIndex]
    }
    
    enum CodingKeys: String, CodingKey {
        case id, order, players
        case teeTime = "tee_time"
        case startingHole = "starting_hole"
        case startingIndex = "starting_index"
        case holeOrder = "hole_order"
        case currentHoleNumber = "current_hole_number"
        case currentIndex = "current_index"
    }
}
