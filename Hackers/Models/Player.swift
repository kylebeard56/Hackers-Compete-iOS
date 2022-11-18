//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

struct Player: Hashable, Equatable, Identifiable {
    var id: String
    var name: String
    var color: Color

    init(
        id: String = UUID().uuidString,
        name: String = "",
        color: Color = Color.systemBlue
    ) {
        self.id = id
        self.name = name
        self.color = color
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
    
    var isPlaying: Bool {
        return !name.isEmpty
    }
}

extension Binding where Value == Player {
    static var player: Binding<Player> {
        return .constant(Player())
    }
}
