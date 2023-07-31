//
//  ScoreUtil+Stroke.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

extension ScoreUtil {
    struct Stroke {
        /// Compute the score for a single player on a single hole.
        static func computeScore(
            for player: Player,
            on hole: Int,
            using format: StrokeScoringFormat,
            handicaps: Bool = true
        ) -> String {
            let score = player.score(for: hole, handicaps: handicaps)
            if score == .none { return "-" }
            
            switch format {
            case .medal:
                return score.numericalValue.toGolfScore
            case .stableford:
                return "\(score.stablefordValue)"
            case .fibonacci:
                return "\(score.fibonacciValue)"
            }
        }
        
        /// Compute the total score over a given range of holes for a single player.
        static func computeTotal(
            for player: Player,
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> Int {
            var score: Int = 0
            if holes.isEmpty { return score }
            
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            for h in holes[0...last] {
                let s = player.score(for: h, handicaps: handicaps)
                switch format {
                case .medal:        score += s.numericalValue
                case .stableford:   score += s.stablefordValue
                case .fibonacci:    score += s.fibonacciValue
                }
            }
            return score
        }
        
        /// Compute the total score for a single team over a given range of holes for a group of players.
        static func computeTotal(
            for players: [Player],
            on team: String = "",
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> Int {
            let first = holes.first ?? hole ?? 0
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            return players.compactMap({
                $0.team[first] == team
                ? self.computeTotal(for: $0, over: Array(holes[0...last]), using: format, handicaps: handicaps)
                : nil
            }).reduce(0, +)
        }
        
        /// Compute the best ball score for a group of players on a single hole.
        static func bestBallScore(
            for players: [Player],
            on hole: Int,
            using format: StrokeScoringFormat = .medal,
            handicaps: Bool = true
        ) -> Int {
            let scores = players.compactMap({ $0.score(for: hole, handicaps: handicaps) })
            switch format {
            case .medal:
                return scores.map({ $0.numericalValue }).sorted(by: <).prefix(2).reduce(0, +)
            case .stableford:
                return scores.map({ $0.stablefordValue }).sorted(by: >).prefix(2).reduce(0, +)
            case .fibonacci:
                return scores.map({ $0.fibonacciValue }).sorted(by: >).prefix(2).reduce(0, +)
            }
        }
        
        /// Compute the best ball score for a group of players over a given range of holes.
        static func bestBallTotal(
            for players: [Player],
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> String {
            if holes.isEmpty { return "-" }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            let value = holes[0...last].reduce(0) {
                $0 + bestBallScore(for: players, on: $1, using: format, handicaps: handicaps)
            }
            return format == .medal ? value.toGolfScore : "\(value)"
        }
    }
}
