//
//  HoleUtil.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/23.
//

import Foundation

struct HoleUtil {
    /// Constructs a linear array of integers in sequential order starting on whichever you hole
    static func buildRange(starting: Int, playing: Int) -> [Int] {
        var range: [Int] = []
        
        /// Construct a linear range for the hole numbers to be played for index calculation purposes.
        /// ex: If starting on 4 and playing 18, it would be 4...18 + 1...3 in this exact order
        range = starting == 1 ? Array(1...18) : Array(starting...18) + Array(1...(starting - 1))
        if playing != 18 {
            /// If playing nine holes, filter out the side which users aren't playing from our sequenced range.
            range = starting <= 9 ? range.filter(\.isFrontNine) : range.filter(\.isBackNine)
        }
        
        return range
    }
}
