//
//  Scoring+Stroke.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

extension ScoringService {
    struct Stroke {
        static func score(for player: Player, on hole: Int, using format: StrokeScoringFormat) -> String {
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
        
        static func calculateAccruedScore(
            for player: Player,
            over holes: [Int],
            using format: StrokeScoringFormat = .medal
        ) -> Int {
            var score: Int = 0
            for h in holes {
                let s = PlayerScore(rawValue: player.score[h] ?? "") ?? .none
                switch format {
                case .medal:        score += s.numericalValue
                case .stableford:   score += s.stablefordValue
                case .fibonacci:    score += s.fibonacciValue
                }
            }
            return score
        }
        
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
        
        static func bestBallTotal(
            for players: [Player],
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil
        ) -> String {
            if holes.isEmpty { return "-" }
            //var value: Int = 0
            let end = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
//            for h in holes[0...end] {
//                value += bestBallScore(for: players, on: h, using: format)
//            }
            let value = holes[0...end].reduce(0) {
                bestBallScore(for: players, on: $0, using: format) + bestBallScore(for: players, on: $1, using: format)
            }
            return format == .medal ? value.toGolfScore : "\(value)"
        }
    }
}
