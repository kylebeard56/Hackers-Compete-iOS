//
//  ScoreUtil+Vegas.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

extension ScoreUtil {
    struct Vegas {
        static func computeScore(for players: [Player], on team: String, on hole: Int) -> Int {
            var scores: [Int] = []
            for p in players {
                if p.team[hole] == team {
                    let s = PlayerScore(rawValue: p.score[hole] ?? "") ?? .none
                    scores.append(s.numericalValue)
                }
            }
            
            let min = scores.min() ?? 0
            let max = scores.max() ?? 0
            return min * 10 + max
        }
        
        static func computeTotal(
            for players: [Player],
            for team: String,
            over holes: [Int],
            upTo hole: Int? = nil
        ) -> Int {
            if holes.isEmpty { return 0 }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            return holes[0...last].reduce(0) { $0 + computeScore(for: players, on: team, on: $1) }
        }
    }
}
