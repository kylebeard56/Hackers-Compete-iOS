//
//  GolfTopology.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

enum GolfTheme: CaseIterable {
    case green, purple, yellow
    
    var displayName: String {
        switch self {
        case .green:  return "Green"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        }
    }
    
    var image: String {
        switch self {
        case .green:    return "TopologyGreen"
        case .purple:   return "TopologyPurple"
        case .yellow:   return "TopologyYellow"
        }
    }
    
    var color: Color {
        switch self {
        case .green:    return .accentGreen
        case .purple:   return .accentPurple
        case .yellow:   return .accentYellow
        }
    }
}

struct GolfTopology: View {
    var theme: GolfTheme = .green
    var body: some View {
        Image(theme.image)
            .interpolation(.high)
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
    }
}
