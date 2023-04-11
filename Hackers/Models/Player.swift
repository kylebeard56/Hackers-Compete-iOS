//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

struct Player: Hashable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var color: GameColor
    var difficulty: GameDifficulty
    var redrawCount: Int
    var score: [Int: String]

    init(
        name: String = "",
        color: GameColor = .blue,
        difficulty: GameDifficulty = .medium,
        redrawCount: Int = 3,
        score: [Int: String] = [:]
    ) {
        self.name = name
        self.color = color
        self.difficulty = difficulty
        self.redrawCount = redrawCount
        self.score = score
    }
    
    init(session: PlayerSession) {
        self.id = session.id
        self.name = session.name
        self.color = GameColor(rawValue: session.color) ?? .blue
        self.difficulty = GameDifficulty(rawValue: session.difficulty) ?? .medium
        self.redrawCount = session.redrawCount
        self.score = session.score
    }
    
    var isPlaying: Bool {
        return !name.isEmpty
    }
    
    func textualScore(for hole: Int) -> String {
        if let s = PlayerScore(rawValue: score[hole] ?? "") {
            return s.numericalValue.toGolfScore
        } else {
            return "-"
        }
    }
    
    func hasScore(in range: ClosedRange<Int>) -> Bool {
        for i in range {
            if let s = PlayerScore(rawValue: score[i] ?? "") { return true }
        }
        return false
    }
    
    func scoringSum(for range: ClosedRange<Int>) -> String {
        var sum: Int = 0
        for i in range {
            let s = PlayerScore(rawValue: score[i] ?? "") ?? .none
            sum += s.numericalValue
        }
        return sum.toGolfScore
    }
    
    static func ==(lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
        && lhs.name == rhs.name
        && lhs.color == rhs.color
        && lhs.difficulty == rhs.difficulty
        && lhs.redrawCount == rhs.redrawCount
        && lhs.score == rhs.score
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(color)
        hasher.combine(difficulty)
        hasher.combine(redrawCount)
        hasher.combine(score)
    }
}

extension Binding where Value == Player {
    static var player: Binding<Player> {
        return .constant(Player())
    }
}

enum GameColor: String {
    case blue, green, purple, indigo, red, orange, yellow
    
    var value: Color {
        switch self {
        case .blue:         return .systemBlue
        case .green:        return .systemGreen
        case .purple:       return .systemPurple
        case .indigo:       return .systemIndigo
        case .red:          return .systemRed
        case .orange:       return .systemOrange
        case .yellow:       return .systemYellow
        }
    }
}

/// Different from `RuleDifficulty` in which this difficulty actually drives which rule difficulty is drawn.
enum GameDifficulty: String {
    case easy, medium, hard
    
    var label: String {
        switch self {
        case .easy:     return "Easy"
        case .medium:   return "Medium"
        case .hard:     return "Hard"
        }
    }
    
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
