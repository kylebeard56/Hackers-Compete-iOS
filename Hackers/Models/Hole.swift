//
//  Hole.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import Foundation

struct Hole {
    var number: Int
    var details: HoleDetails
    var rules: [Rule]
    
    init(
        number: Int = 1,
        details: HoleDetails = HoleDetails(),
        rules: [Rule] = []
    ) {
        self.number = number
        self.details = details
        self.rules = rules
    }
}
