//
//  PlayerSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct PlayerSession: Hashable, Codable {
    var id: String
    var name: String
    var color: String
    var score: [Int: String]
    var handicap: [Int: Int]
    var team: String
    
    init(
        id: String = "",
        name: String = "",
        color: String = "",
        score: [Int: String] = [:],
        handicap: [Int: Int] = [:],
        team: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.score = score
        self.handicap = handicap
        self.team = team
    }
    
    init(player: Player) {
        self.id = player.id
        self.name = player.name
        self.color = player.color.rawValue
        self.score = player.score
        self.handicap = player.handicap
        self.team = player.team
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, score, handicap, team
    }
}
