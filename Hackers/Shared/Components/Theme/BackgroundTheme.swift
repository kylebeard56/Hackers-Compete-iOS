//
//  BackgroundTheme.swift
//  Hackers
//
//  Created by Kyle Beard on 2/21/26.
//

import SwiftUI

enum GolfTheme: CaseIterable {
    case green, purple, yellow, course
    
    static var colorOptions: [GolfTheme] { [.green, .purple, .yellow] }
    
    var displayName: String {
        switch self {
        case .green:  return "Green"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        case .course: return "Course"
        }
    }
    
    var image: String {
        switch self {
        case .green:    return "TopologyGreen"
        case .purple:   return "TopologyPurple"
        case .yellow:   return "TopologyYellow"
        case .course:   return "CartoonCourse"
        }
    }
    
    var color: Color {
        switch self {
        case .green:    return .accentGreen
        case .purple:   return .accentPurple
        case .yellow:   return .accentYellow
        case .course:   return .accentGreen
        }
    }
    
    var scorecardOpacity: CGFloat {
        switch self {
        case .green:    return 0.65
        case .purple:   return 0.65
        case .yellow:   return 0.85
        case .course:   return 0.65
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
            
            GolfTopology(theme: theme)
                .frame(width: UIScreen.main.bounds.width)
                .opacity(colorScheme.isLight ? 0.35 : 0.7)
        }
    }
}
