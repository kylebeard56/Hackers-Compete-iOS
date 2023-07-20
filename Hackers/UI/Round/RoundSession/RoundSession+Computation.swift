//
//  RoundSession+Computation.swift
//  Hackers
//
//  Created by Kyle Beard on 7/16/23.
//

import Foundation

enum StrokeScoringFormat {
    case medal, stableford, fibonacci
}

extension RoundSession {
    
    // MARK: - Stroke Play (Medal, Stableford, Fibonacci)
    
    func score(for player: Player, on hole: Int, using format: StrokeScoringFormat) -> String {
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
    
    func calculateAccruedScore(
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
    
    func bestBallScore(
        for hole: Int,
        using format: StrokeScoringFormat = .medal
    ) -> Int {
        let scores = players
            .compactMap({ $0.score[hole] })
            .compactMap({ PlayerScore(rawValue: $0) })
        switch format {
        case .medal:
            return scores.map({ $0.numericalValue }).sorted(by: <).prefix(2).reduce(0, +)
        case .stableford:
            return scores.map({ $0.stablefordValue }).sorted(by: >).prefix(2).reduce(0, +)
        case .fibonacci:
            return scores.map({ $0.fibonacciValue }).sorted(by: >).prefix(2).reduce(0, +)
        }
    }
    
    func bestBallTotal(
        over holes: [Int],
        using format: StrokeScoringFormat = .medal,
        upTo hole: Int? = nil
    ) -> String {
        var value: Int = 0
        let end = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
        for h in holes[0...end] {
            value += bestBallScore(for: h, using: format)
        }
        return format == .medal ? value.toGolfScore : "\(value)"
    }
}
