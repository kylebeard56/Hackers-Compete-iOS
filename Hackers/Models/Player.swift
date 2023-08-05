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
    var color: GameColor
    var score: [Int: String]
    var handicap: [Int: Int]
    var team: [Int: String]

    init(
        id: String = UUID().uuidString,
        name: String = "",
        color: GameColor = .blue,
        score: [Int: String] = [:],
        handicap: [Int: Int] = [:],
        team: [Int: String] = [:]
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
        Player(name: self.name, color: self.color, score: [:], handicap: self.handicap, team: [:])
    }
    
    var toSession: PlayerSession? {
        PlayerSession(player: self)
    }
    
    var isPlaying: Bool {
        return !name.isEmpty
    }
    
    // MARK: - Scoring and HCP
    
    var handicapIndex: Int {
        self.handicap.values.compactMap({ $0 }).reduce(0, +)
    }
    
    func grossScore(for hole: Int) -> PlayerScore {
        return PlayerScore(rawValue: self.score[hole] ?? "") ?? .none
    }
    
    func netScore(for hole: Int) -> PlayerScore {
        let hcp = self.handicap[hole] ?? 0
        return grossScore(for: hole).computeNetScore(with: hcp)
    }
    
    func score(for hole: Int, handicaps: Bool = true) -> PlayerScore {
        return handicaps ? netScore(for: hole) : grossScore(for: hole)
    }
    
    var scoreCount: Int {
        score.values.filter({ PlayerScore(rawValue: $0) != PlayerScore.none }).count
    }
    
    func hasScore(in range: ClosedRange<Int>) -> Bool {
        for i in range {
            /// If a single instance has a score in range that isn't empty
            if let s = score[i], !s.isEmpty { return true }
        }
        return false
    }
    
    // MARK: - View builders
    
    @ViewBuilder func netScoreLabel(for score: PlayerScore, on hole: Int) -> some View {
        let hcp = self.handicap[hole] ?? 0
        
        if score == .none {
            Text(hcp == 0 ? "No strokes" : "\(hcp) stroke\(hcp > 1 ? "s" : "")")
                .font(.dmSans(size: 12, weight: .medium))
                .foregroundColor(Color.systemGray2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
        } else {
            Text("Net \(self.score(for: hole).name.lowercased())")
                .font(.dmSans(size: 12, weight: .medium))
                .foregroundColor(Color.systemGray2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
        }
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

