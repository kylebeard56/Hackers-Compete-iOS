//
//  ScoreUtil+Generic.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/23.
//

import Foundation

extension ScoreUtil {
    enum TiePosition {
        case first, second, third
    }
    
    /// Checks if the input tuple has a tie for a specific position.
    /// Assumption: The values provided are sorted appropriately.
    static func didTie(for position: TiePosition, with value: [(Any, Int)]) -> Bool {
        if position == .first {
            if value.count < 2 { return false }
            return value[0].1 == value[1].1
        }
        
        if position == .second {
            if value.count < 3 { return false }
            return value[1].1 == value[2].1
        }
        
        if position == .third {
            if value.count < 4 { return false }
            return value[2].1 == value[3].1
        }
        
        return false
    }
}
