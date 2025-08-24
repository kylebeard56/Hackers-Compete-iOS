//
//  Round+Team.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - RoundTeam
struct RoundTeam: Hashable, Codable {
    var id: String
    var name: String        // App assigned name like Team 1, Team 2, etc
    var players: [String]   // Links to Playable
    var color: ColorValue   // Color value identifier for the team
    var holes: [Int]        // Hole range for which this team is constructed (using hole numbers, not indices)
    
    init(
        id: String,
        name: String,
        players: [String],
        color: ColorValue,
        holes: [Int]
    ) {
        self.id = id
        self.name = name
        self.players = players
        self.color = color
        self.holes = holes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, players, color, holes
    }
}
