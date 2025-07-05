//
//  RoundSession+Hole.swift
//  Hackers
//
//  Created by Kyle Beard on 7/9/23.
//

import SwiftUI

extension RoundSession {
    func updateHoleLogic(for hole: Int) {
        /// 1. Loop through hole range to determine what net hole the user would be on.
        var count: Int = 0
        for h in self.holeRange {
            count += 1
            if h == hole { break }
        }
        self.netHoleNumber = count
        
        /// 2. Update the side game data for the new hole number
        self.updateGames(for: hole)
    }
}
