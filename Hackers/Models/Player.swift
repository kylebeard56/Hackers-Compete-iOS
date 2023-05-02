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
    var chaosDifficulty: GameDifficulty
    var chaosRedrawCount: Int
    var score: [Int: String]
    var team: String

    init(
        name: String = "",
        color: GameColor = .blue,
        difficulty: GameDifficulty = .medium,
        redrawCount: Int = kRedrawCountDefault,
        score: [Int: String] = [:],
        team: String = ""
    ) {
        self.name = name
        self.color = color
        self.chaosDifficulty = difficulty
        self.chaosRedrawCount = redrawCount
        self.score = score
        self.team = team
    }
    
    init(session: PlayerSession) {
        self.id = session.id
        self.name = session.name
        self.color = GameColor(rawValue: session.color) ?? .blue
        self.chaosDifficulty = GameDifficulty(rawValue: session.difficulty) ?? .medium
        self.chaosRedrawCount = session.chaosRedrawCount
        self.score = session.score
        self.team = session.team
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
            if let _ = PlayerScore(rawValue: score[i] ?? "") { return true }
        }
        return false
    }
    func totalRawScore() -> Int {
        rawScoringSum(for: 1...18)
    }
    
    func totalStablefordScore() -> Int {
        stablefordScoringSum(for: 1...18)
    }
    
    func totalScore(for type: LeaderboardScoringType = .traditional) -> String {
        if type == .traditional {
            return rawScoringSum(for: 1...18).toGolfScore
        } else if type == .stableford {
            return "\(stablefordScoringSum(for: 1...18))"
        } else if type == .vegas {
            // TODO
            return rawScoringSum(for: 1...18).toGolfScore
        } else {
            return rawScoringSum(for: 1...18).toGolfScore
        }
    }
    
    func rawScoringSum(for range: ClosedRange<Int>) -> Int {
        var sum: Int = 0
        for i in range {
            let s = PlayerScore(rawValue: score[i] ?? "") ?? .none
            sum += s.numericalValue
        }
        return sum
    }
    
    func stablefordScoringSum(for range: ClosedRange<Int>) -> Int {
        var sum: Int = 0
        for i in range {
            let s = PlayerScore(rawValue: score[i] ?? "") ?? .none
            sum += s.stablefordValue
        }
        return sum
    }
    
    func scoringSum(for range: ClosedRange<Int>) -> String {
        return rawScoringSum(for: range).toGolfScore
    }
    
    static func ==(lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
        && lhs.name == rhs.name
        && lhs.color == rhs.color
        && lhs.chaosDifficulty == rhs.chaosDifficulty
        && lhs.chaosRedrawCount == rhs.chaosRedrawCount
        && lhs.score == rhs.score
        && lhs.team == rhs.team
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(color)
        hasher.combine(chaosDifficulty)
        hasher.combine(chaosRedrawCount)
        hasher.combine(score)
        hasher.combine(team)
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
            let r: [RuleDifficulty] = Array(repeating: .favor, count: 3) +  Array(repeating: .challenge, count: 1)
            return r[Int.random(in: 0...3)]
        case .medium:
            // 50% chance of favor
            let r: [RuleDifficulty] = Array(repeating: .favor, count: 1) +  Array(repeating: .challenge, count: 1)
            return r[Int.random(in: 0...1)]
        case .hard:
            // 25% chance of favor
            let r: [RuleDifficulty] = Array(repeating: .favor, count: 1) +  Array(repeating: .challenge, count: 3)
            return r[Int.random(in: 0...3)]
        }
    }
}
