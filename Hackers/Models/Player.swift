//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

/// Different from `RuleDifficulty` in which this difficulty actually drives which rule difficulty is drawn.
enum GameDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var randomRuleDifficulty: RuleDifficulty {
        switch self {
        case .easy:
            // 75% chance of favor
            let r: [RuleDifficulty] = [.favor, .favor, .favor, .challenge]
            return r[Int.random(in: 0...3)]
        case .medium:
            // 50% chance of favor
            let r: [RuleDifficulty] = [.favor, .favor, .challenge, .challenge]
            return r[Int.random(in: 0...3)]
        case .hard:
            // 25% chance of favor
            let r: [RuleDifficulty] = [.favor, .challenge, .challenge, .challenge]
            return r[Int.random(in: 0...3)]
        }
    }
}

struct Player: Hashable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var color: Color
    var difficulty: GameDifficulty
    var redrawCount: Int

    init(
        name: String = "",
        color: Color = Color.systemBlue,
        difficulty: GameDifficulty = .medium,
        redrawCount: Int = 3
    ) {
        self.name = name
        self.color = color
        self.difficulty = difficulty
        self.redrawCount = redrawCount
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
