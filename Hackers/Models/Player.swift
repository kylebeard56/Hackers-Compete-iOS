//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

/**
 |- players: [PlayerSession]
    |- id: String
    |- name: String
    |- color: String
    |- score: HoleDict
    |- handicap: [Int: Int]
    |- team: HoleDict
 */

struct Player: Hashable, Equatable, Identifiable {
    var id: String
    var name: String
    var color: GameColor
    var score: [Int: String]
    var handicap: [Int: Int]
    var team: String

    init(
        id: String = UUID().uuidString,
        name: String = "",
        color: GameColor = .blue,
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
    
    init(session: PlayerSession) {
        self.id = session.id
        self.name = session.name
        self.color = GameColor(rawValue: session.color) ?? .blue
        self.score = session.score
        self.handicap = session.handicap
        self.team = session.team
    }
    
    /// Clear out player scores and teams, but preserve name, color, and HCP in current app memory.
    func stripped() -> Player {
        Player(name: self.name, color: self.color, score: [:], handicap: self.handicap, team: "")
    }
    
    var toSession: PlayerSession? {
        PlayerSession(player: self)
    }
    
    var isPlaying: Bool {
        return !name.isEmpty
    }
    
    var scoreCount: Int {
        score.values.filter({ PlayerScore(rawValue: $0) != PlayerScore.none }).count
    }
    
    var scoredHoles: [Int] {
        var holes: [Int] = []
        for (k,v) in score {
            if let s = PlayerScore(rawValue: v), s != PlayerScore.none {
                holes.append(k)
            }
        }
        return holes
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
    
//    func totalScore(for type: LeaderboardScoringType = .traditional) -> String {
//        if type == .traditional {
//            return rawScoringSum(for: 1...18).toGolfFormat
//        } else if type == .stableford {
//            return "\(stablefordScoringSum(for: 1...18))"
//        } else if type == .vegas {
//            // TODO
//            return rawScoringSum(for: 1...18).toGolfFormat
//        } else {
//            return rawScoringSum(for: 1...18).toGolfFormat
//        }
//    }
    
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
        && lhs.score == rhs.score
        && lhs.handicap == rhs.handicap
        && lhs.team == rhs.team
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(color)
        hasher.combine(score)
        hasher.combine(handicap)
        hasher.combine(team)
    }
}

extension Binding where Value == Player {
    static var player: Binding<Player> {
        return .constant(Player())
    }
}

enum GameColor: String {
    case blue, green, purple, indigo, pink, orange
    
    var value: Color {
        switch self {
        case .blue:         return .systemBlue
        case .green:        return .systemGreen
        case .purple:       return .systemPurple
        case .indigo:       return .systemIndigo
//        case .red:          return .systemRed
        case .pink:         return .systemPink
        case .orange:       return .systemOrange
        }
    }
}

