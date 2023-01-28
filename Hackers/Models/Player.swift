//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

/// Different from `RuleDifficulty` in which this difficulty actually drives which rule difficulty is drawn.
enum PlayerDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

struct Player: Hashable, Equatable, Identifiable {
    var id: String
    var name: String
    var color: Color
    var difficulty: PlayerDifficulty
    var shuffleCount: Int

    init(
        id: String = UUID().uuidString,
        name: String = "",
        color: Color = Color.systemBlue,
        difficulty: PlayerDifficulty = .medium,
        shuffleCount: Int = 3
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.difficulty = difficulty
        self.shuffleCount = shuffleCount
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
