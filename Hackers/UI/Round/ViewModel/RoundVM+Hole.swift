//
//  RoundViewModel+Hole.swift
//  Hackers
//
//  Created by Kyle Beard on 7/9/23.
//

import SwiftUI

extension RoundViewModel {
    func updateHoleLogic(for hole: Int) {
        /// 1. Loop through hole range to determine what net hole the user would be on.
        var count: Int = 0
        for h in self.holeRange {
            count += 1
            if h == hole { break }
        }
        self.netHoleNumber = count
        
        /// 2. Find the first hole sequentially in the hole range that wasn't scored
        self.nextSequentialHole = holeRange.firstIndex(where: { !scoringExists(for: $0) }) ?? startingHole
        
        // TODO: Read below
        /// Instead of an index-add approach, we will make side game be a partitioned effort. How will this work?
        /// I say I want to play a game, the holes are instantly the 1...18.
        /// After 6 holes, I change to another game. Then, my holes become 1...6 and 7...18. This way we condense the range for.
        
        /// 3. Update the side game data for the new hole number
        self.updateGames(for: hole)
    }
}
