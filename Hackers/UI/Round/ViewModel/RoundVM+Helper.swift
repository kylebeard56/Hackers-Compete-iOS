//
//  RoundVM+Helper.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

extension RoundViewModel {
    
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
    
    func calculateAccruedScore(for player: Player, over holes: Range<Int>) -> Int {
        var score: Int = 0
        for i in holes {
            let hole = holeRange[i]
            let s = PlayerScore(rawValue: player.score[hole] ?? "") ?? .par
            score += s.numericalValue
        }
        return score
    }
}
