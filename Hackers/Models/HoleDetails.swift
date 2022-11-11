//
//  HoleDetails.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

enum HolePar: Int {
    case none = 0
    case three = 3
    case four = 4
    case five = 5
}

enum HoleCondition: String {
    case water = "Water"
    case bunkers = "Bunkers"
    case trees = "Trees"
    case wind = "Wind"
    
    var icon: Awesome {
        switch self {
        case .water:    return .water
        case .bunkers:  return .umbrellaBeach
        case .trees:    return .trees
        case .wind:     return .wind
        }
    }
}

struct HoleDetails {
    var par: HolePar
    var conditions: [HoleCondition]
    
    init(
        par: HolePar = .none,
        conditions: [HoleCondition] = []
    ) {
        self.par = par
        self.conditions = conditions
    }
    
    var isEmpty: Bool {
        par == .none && conditions.isEmpty
    }
}

extension Binding where Value == HoleDetails {
    static var holeDetails: Binding<HoleDetails> {
        return .constant(HoleDetails())
    }
}
