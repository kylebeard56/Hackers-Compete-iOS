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
    case water
    case bunkers
    case trees
    case wind
    
    var displayName: String {
        switch self {
        case .water:        return "Water"
        case .bunkers:      return "Bunkers"
        case .trees:        return "Trees"
        case .wind:         return "Wind"
        }
    }
    
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
    var par: Int
    var conditions: [String]
    
    init(
        par: Int = 0,
        conditions: [String] = []
    ) {
        self.par = par
        self.conditions = conditions
    }
    
    var isEmpty: Bool {
        par == 0 && conditions.isEmpty
    }
}

extension Binding where Value == HoleDetails {
    static var holeDetails: Binding<HoleDetails> {
        return .constant(HoleDetails())
    }
}
