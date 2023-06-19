//
//  Team.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/23.
//

import Foundation

struct Team: Hashable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var players: [String]
 
    init(
         name: String = "",
         players: [String] = []
    ) {
        self.name = name
        self.players = players
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(players)
    }
}
