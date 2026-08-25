//
//  HotPotatoSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct HotPotatoSession: Hashable, Codable {
    var play: [Int: String] // [Hole: ID] which could be player_id or team name
    var multiplier: [Int: Int]
    
    init(
        play: [Int : String] = [:],
        multiplier: [Int : Int] = [:]
    ) {
        self.play = play
        self.multiplier = multiplier
    }
    
    enum CodingKeys: String, CodingKey {
        case play, multiplier
    }
}
