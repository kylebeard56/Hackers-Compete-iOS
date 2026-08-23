//
//  HoleRange.swift
//  Hackers
//
//  Created by Kyle Beard on 9/2/25.
//

import Foundation

// MARK: - Hole Range
struct HoleRange: Codable, Hashable {
    var startHole: Int
    var endHole: Int
    
    init(
        startHole: Int = 0,
        endHole: Int = 0
    ) {
        self.startHole = startHole
        self.endHole = endHole
    }
    
    init(segment: HoleSegment) {
        let range = segment.holeRange
        self.startHole = range.startHole
        self.endHole = range.endHole
    }
    
    var count: Int { endHole - startHole + 1 }
    var holeNumbers: [Int] { Array(max(1, startHole)...max(max(1, startHole), endHole == 0 ? 18 : endHole)) }
    var segment: HoleSegment { HoleSegment(range: self) }
    func contains(_ hole: Int) -> Bool { hole >= startHole && hole <= endHole }
}
