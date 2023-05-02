//
//  Team.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import Foundation

struct Team: Hashable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var players: [String]
 
    init(players: [String] = []) {
        self.players = players
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(players)
    }
}
