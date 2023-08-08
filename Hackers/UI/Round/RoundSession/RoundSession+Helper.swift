//
//  RoundSession+Helper.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

extension RoundSession {
    var scorecardHeight: CGFloat {
        return (usingHandicaps ? 160.0 : 140.0) + CGFloat(players.count) * 60.0
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
}
