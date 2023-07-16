//
//  RoundSession+Helper.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

extension RoundSession {
    
    var holeScoringHeight: CGFloat {
        return 200.0 + CGFloat(players.count) * 60.0
    }
    
    func scoringExists(for hole: Int) -> Bool {
        for p in players {
            if let s = PlayerScore(rawValue: p.score[hole] ?? "") {
                if s == .none { continue }
                return true
            }
        }
        return false
    }
    
    func calculateAccruedScore(
        for player: Player,
        over holes: Range<Int>,
        format: StrokeScoringFormat = .medal
    ) -> Int {
        var score: Int = 0
        for i in holes {
            let hole = holeRange[i]
            let s = PlayerScore(rawValue: player.score[hole] ?? "") ?? .par
            switch format {
            case .medal:        score += s.numericalValue
            case .stableford:   score += s.stablefordValue
            case .football:     score += s.footballValue
            }
        }
        return score
    }
}
