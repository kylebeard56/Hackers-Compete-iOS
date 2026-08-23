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
    
    func everyoneScored(on hole: Int, team: String = "") -> Bool {
        players.filter({ (team.isEmpty ? true : $0.team[hole] == team) && $0.score(for: hole) == .none }).isEmpty
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
