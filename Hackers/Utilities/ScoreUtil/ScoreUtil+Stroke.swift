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
            using format: StrokeScoringFormat
        ) -> String {
            let value = (PlayerScore(rawValue: player.score[hole] ?? "") ?? .none)
            if value == .none { return "-" }
            
            switch format {
            case .medal:
                return value.numericalValue.toGolfScore
            case .stableford:
                return "\(value.stablefordValue)"
            case .fibonacci:
                return "\(value.fibonacciValue)"
            }
        }
        
        /// Compute the total score over a given range of holes for a single player.
        static func computeTotal(
            for player: Player,
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil
        ) -> Int {
            var score: Int = 0
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            for h in holes[0...last] {
                let s = PlayerScore(rawValue: player.score[h] ?? "") ?? .none
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
            upTo hole: Int? = nil
        ) -> Int {
            let first = holes.first ?? hole ?? 0
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            return players.compactMap({
                $0.team[first] == team
                ? self.computeTotal(for: $0, over: Array(holes[0...last]), using: format)
                : nil
            }).reduce(0, +)
        }
        
        /// Compute the best ball score for a group of players on a single hole.
        static func bestBallScore(
            for players: [Player],
            on hole: Int,
            using format: StrokeScoringFormat = .medal
        ) -> Int {
            let scores = players.compactMap({ $0.score[hole] }).compactMap({ PlayerScore(rawValue: $0) })
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
            upTo hole: Int? = nil
        ) -> String {
            if holes.isEmpty { return "-" }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            let value = holes[0...last].reduce(0) { $0 + bestBallScore(for: players, on: $1, using: format) }
            return format == .medal ? value.toGolfScore : "\(value)"
        }
    }
}
