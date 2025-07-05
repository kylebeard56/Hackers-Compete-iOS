//
//  ChaosSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

enum ChaosCardsArrangement: String {
    case team, player, combo
    
    var label: String {
        switch self {
        case .team:
            return "Party"
        case .player:
            return "Players"
        case .combo:
            return "Both"
        }
    }
}

enum ChaosCardsDifficulty: String {
    case easy, medium, hard
    
    var label: String {
        switch self {
        case .easy:     return "Kind"
        case .medium:   return "Frisky"
        case .hard:     return "Diabolical"
        }
    }
    
    /// Ratio is the number of challenge to favor cards to normalize the distribution of cards available to lessen repeats.
    func randomRuleDifficulty(with ratio: CGFloat = 1.0) -> RuleDifficulty {
//        switch self {
//        case .easy:
//            return [.favor, .favor, .favor, .challenge][Int.random(in: 0...3)]
//        case .medium:  
//            return [.favor, .favor, .challenge, .challenge][Int.random(in: 0...3)]
//        case .hard:     
//            return [.favor, .challenge, .challenge, .challenge][Int.random(in: 0...3)]
//        }
        let total = 1.0 + ratio
        let favorWeight: CGFloat
        let challengeWeight: CGFloat
        
        switch self {
        case .easy:
            favorWeight = 0.75 / total
            challengeWeight = 0.25 * ratio / total
        case .medium:
            favorWeight = 0.5 / total
            challengeWeight = 0.5 * ratio / total
        case .hard:
            favorWeight = 0.25 / total
            challengeWeight = 0.75 * ratio / total
        }
        
        let totalWeight = favorWeight + challengeWeight
        let favorProbability = favorWeight / totalWeight
        
        return Int.random(in: 0...99) < Int(favorProbability * 100) ? .favor : .challenge
    }
}

struct ChaosSession: Hashable, Codable {
    //var active: [Int]
    var arrangement: String
    var difficulty: String
    var redraws: Bool
    var teamRule: [Int: String]
    var playerRules: [String: [Int: String]]
    
    init(
        arrangement: String = kDefaultChaosCardsArrangement.rawValue,
        difficulty: String = kDefaultChaosCardsDifficulty.rawValue,
        redraws: Bool = true,
        teamRule: [Int: String] = [:],
        playerRules: [String : [Int: String]] = [:]
    ) {
        self.arrangement = arrangement
        self.difficulty = difficulty
        self.redraws = redraws
        self.teamRule = teamRule
        self.playerRules = playerRules
    }
    
    enum CodingKeys: String, CodingKey {
        case arrangement, difficulty, redraws
        case teamRule = "team_rule"
        case playerRules = "player_rules"
    }
}
