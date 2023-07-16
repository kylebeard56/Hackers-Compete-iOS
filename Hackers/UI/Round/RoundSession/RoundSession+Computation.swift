//
//  RoundSession+Computation.swift
//  Hackers
//
//  Created by Kyle Beard on 7/16/23.
//

import Foundation

enum StrokeScoringFormat {
    case medal, stableford, football
}

extension RoundSession {
    
    // MARK: - Stroke Play (Medal, Stableford, Football)
    
    func score(for player: Player, on hole: Int, using format: StrokeScoringFormat) -> String {
        let value = (PlayerScore(rawValue: player.score[hole] ?? "") ?? .none)
        if value == .none { return "-" }
        
        switch format {
        case .medal:
            return value.numericalValue.toGolfScore
        case .stableford:
            return "\(value.stablefordValue)"
        case .football:
            return "\(value.footballValue)"
        }
    }
    
    func calculateAccruedScore(
        for player: Player,
        over holes: [Int],
        using format: StrokeScoringFormat = .medal
    ) -> Int {
        var score: Int = 0
        for h in holes {
            let s = PlayerScore(rawValue: player.score[h] ?? "") ?? .par
            switch format {
            case .medal:        score += s.numericalValue
            case .stableford:   score += s.stablefordValue
            case .football:     score += s.footballValue
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
        case .football:
            return scores.map({ $0.footballValue }).sorted(by: >).prefix(2).reduce(0, +)
        }
    }
    
    func bestBallTotal(
        over holes: [Int],
        using format: StrokeScoringFormat = .medal,
        upTo hole: Int? = nil
    ) -> String {
        let stoppageHole = hole ?? holes.last ?? 0
        var value: Int = 0
        for h in holes {
            if h > stoppageHole { break }
            value += bestBallScore(for: h, using: format)
        }
        return format == .medal ? value.toGolfScore : "\(value)"
    }
}
