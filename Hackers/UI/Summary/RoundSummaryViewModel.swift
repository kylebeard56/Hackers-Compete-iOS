//
//  RoundSummaryViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 2/17/23.
//

import Foundation
import SwiftUI

typealias PlayerScoreDifficultyPair = (PlayerScore, RuleDifficulty)

struct PlayerResult {
    var name: String
    var color: Color
    var difficulty: GameDifficulty
    var holesScored: Int
    var totalCards: Int
    var favorCards: Int
    var challengeCards: Int
    var scorecard: [PlayerScoreDifficultyPair]
    var scoreTotal: Int
    var scoreFavor: Int
    var scoreChallenge: Int
    var differential: CGFloat                    // i.e. 0.2 above par
    var favorDifferential: CGFloat               // i.e. -0.4 when favor rule
    var challengeDifferential: CGFloat           // i.e. +0.6 when challenge rule
}

struct CardTypeResult {
    var favor: Int
    var challenge: Int
    
    init(favor: Int = 0, challenge: Int = 0) {
        self.favor = favor
        self.challenge = challenge
    }
    
    var count: Int {
        favor + challenge
    }
}

class RoundSummaryViewModel: Hackable {
    @Published var session: Session = Session()
    
    /// Name, score for round, and breakdown of # of birdies, pars, bogeys, etc..
    @Published var playerResult: [PlayerResult] = []
    
    /// Total # of favor and challenge cards in round
//    @Published var totalCards: CardTypeResult = CardTypeResult()
//
//    /// Total # of team favor and challenge cards in round
//    @Published var teamCards: CardTypeResult = CardTypeResult()
//
//    /// Aggregate # of player favor and challenge cards in round
//    @Published var playerCards: CardTypeResult = CardTypeResult()
    
    init() {
        print("init RoundSummaryViewModel")
    }
    
    deinit { print("deinit RoundSummaryViewModel") }
    
    func load(_ s: Session, _ r: [Rule]) {
        self.session = s
        
        // TODO: In future, include metrics accounting for team and player card diffculty offsetting each
        // I think right now since the same team card is applied, it still keeps it even.
        
        for p in s.players {
            let score = p.score
                .compactMap({ (PlayerScore(rawValue: $0.value) ?? PlayerScore.none).numericalValue })
                .reduce(0, +)
            
            let holesScored = p.score
                .compactMap({ (PlayerScore(rawValue: $0.value) ?? PlayerScore.none) })
                .filter({ $0 != .none })
                .count
            
            var diff: CGFloat = 0.0
            if holesScored > 0 {
                diff = CGFloat(score) / CGFloat(holesScored)
            }

            var scorecard: [PlayerScoreDifficultyPair] = Array(
                repeating: (PlayerScore.none, RuleDifficulty.none),
                count: 18)
            
            /// Total # of rules
            var totalCards: Int = 0
            var favorCards: Int = 0
            var challengeCards: Int = 0
            
            /// Metrics by card type and scoring result when both provided
            var favorScore: Int = 0
            var favorScored: Int = 0
            var challengeScore: Int = 0
            var challengeScored: Int = 0
            
            if let rules = s.gameplay.playerRules[p.id] {
                totalCards = rules.keys.count
                
                for i in 0...rules.count {
                    if let id = rules[i], let rule = r.first(where: { $0.id == id }) {
                        let type = RuleDifficulty(rawValue: rule.difficulty) ?? .none
                        let playerScore = PlayerScore(rawValue: p.score[i] ?? "") ?? .none
                        if type == .favor {
                            print("FAVOR: append \(playerScore.name) for \(p.name)")
                            favorScore += playerScore.numericalValue
                            favorScored += 1
                        }
                        if type == .challenge {
                            print("CHALLENGE: append \(playerScore.name) for \(p.name)")
                            challengeScore += playerScore.numericalValue
                            challengeScored += 1
                        }
                    }
                }
                
                for i in 1...18 {
                    if let id = rules[i], let rule = r.first(where: { $0.id == id }) {
                        let score = PlayerScore(rawValue: p.score[i] ?? "") ?? .none
                        let diff = RuleDifficulty(rawValue: rule.difficulty) ?? .none
                        scorecard[i] = (score, diff)
                    }
                }
            }
            
            favorCards = scorecard.filter({ $0.1 == .favor }).count
            challengeCards = scorecard.filter({ $0.1 == .challenge }).count
            
            var favorDiff: CGFloat = 0.0
            if favorScored > 0 {
                favorDiff = CGFloat(favorScore) / CGFloat(favorScored)
            }
            var challengeDiff: CGFloat = 0.0
            if challengeScored > 0 {
                challengeDiff = CGFloat(challengeScore) / CGFloat(challengeScored)
            }
            
            let r = PlayerResult(
                name: p.name,
                color: GameColor(rawValue: p.color)?.value ?? .systemBlue,
                difficulty: GameDifficulty(rawValue: p.difficulty) ?? .medium,
                holesScored: holesScored,
                totalCards: totalCards,
                favorCards: favorCards,
                challengeCards: challengeCards,
                scorecard: scorecard,
                scoreTotal: score,
                scoreFavor: favorScore,
                scoreChallenge: challengeScore,
                differential: diff,
                favorDifferential: favorDiff,
                challengeDifferential: challengeDiff)
            
            printPretty(r)
            playerResult.append(r)
        }
        
        playerResult = playerResult.sorted(by: { $0.scoreTotal < $1.scoreTotal })
    }
}

