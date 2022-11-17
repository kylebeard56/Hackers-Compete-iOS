//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

struct Player: Equatable, Identifiable {
    var id: String
    var name: String
    var color: Color
    var isPlaying: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        color: Color = Color.systemBlue,
        isPlaying: Bool = true
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.isPlaying = isPlaying
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
}

extension Binding where Value == Player {
    static var player: Binding<Player> {
        return .constant(Player())
    }
}
