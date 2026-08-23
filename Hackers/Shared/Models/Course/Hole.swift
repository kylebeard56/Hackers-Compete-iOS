//
//  Hole.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import SwiftUI

struct Hole: Hashable, Codable {
    var number: Int
    let par: Int
    let yardage: Int
    let handicap: Int?
    
    init(
        number: Int,
        par: Int,
        yardage: Int,
        handicap: Int?
    ) {
        self.number = number
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
    }
    
    init(from hole: GolfCourseAPIHole, number: Int) {
        self.number = number
        self.par = hole.par
        self.yardage = hole.yardage
        self.handicap = hole.handicap
    }
    
    enum CodingKeys: String, CodingKey {
        case number, par, yardage, handicap
    }
}

extension Array where Element == Hole {
    func slice(for segment: HoleSegment) -> ArraySlice<Hole> {
        guard let r = segment.indexBounds(totalHoles: count) else { return [] }
        return self[r]
    }
}
