//
//  BackgroundTheme.swift
//  Hackers
//
//  Created by Kyle Beard on 2/21/26.
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

struct BackgroundTheme: View {
    @Environment(\.colorScheme) var colorScheme
    
    var palette: DesignPalette
    var theme: GolfTheme
    
    var body: some View {
        ZStack {
            palette.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            LinearGradient(
                colors: [theme.color.opacity(colorScheme.isLight ? 0.25 : 0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
//            viewModel.theme.color
//                .edgesIgnoringSafeArea(.all)
//                .opacity(0.2)
            
            GolfTopology(theme: theme)
                .frame(width: UIScreen.main.bounds.width)
                .opacity(colorScheme.isLight ? 0.35 : 0.7)
        }
    }
}
