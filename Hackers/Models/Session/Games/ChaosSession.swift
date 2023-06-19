//
//  ChaosSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

enum ChaosCardsArrangement: String {
    case team, player, combo
}

enum ChaosCardsDifficulty: String {
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
        case .easy:     return [.favor, .favor, .favor, .challenge][Int.random(in: 0...3)]
        case .medium:   return [.favor, .favor, .challenge, .challenge][Int.random(in: 0...3)]
        case .hard:     return [.favor, .challenge, .challenge, .challenge][Int.random(in: 0...3)]
        }
    }
}

struct ChaosSession: Hashable, Codable {
    var active: [Int]
    var arrangement: String
    var difficulty: String
    var redraws: Bool
    var teamRule: [Int: String]
    var playerRules: [String: [Int: String]]
    
    init(
        active: [Int] = [],
        arrangement: String = ChaosCardsArrangement.combo.rawValue,
        difficulty: String = ChaosCardsDifficulty.medium.rawValue,
        redraws: Bool = true,
        teamRule: [Int: String] = [:],
        playerRules: [String : [Int: String]] = [:]
    ) {
        self.active = active
        self.arrangement = arrangement
        self.difficulty = difficulty
        self.redraws = redraws
        self.teamRule = teamRule
        self.playerRules = playerRules
    }
    
    enum CodingKeys: String, CodingKey {
        case active, arrangement, difficulty, redraws
        case teamRule = "team_rule"
        case playerRules = "player_rules"
    }
}
