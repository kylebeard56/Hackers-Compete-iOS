//
//  Hole.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import SwiftUI

struct Hole {
    let par: Int
    let yardage: Int
    let handicap: Int?
    
    init(
        par: Int,
        yardage: Int,
        handicap: Int?
    ) {
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
    }
    
    init(from apiHole: GolfCourseAPIHole) {
        self.par = apiHole.par
        self.yardage = apiHole.yardage
        self.handicap = apiHole.handicap
    }
}

extension Array where Element == Hole {
    func slice(for segment: HoleSegment) -> ArraySlice<Hole> {
        guard let r = segment.indexBounds(totalHoles: count) else { return [] }
        return self[r]
    }
}
