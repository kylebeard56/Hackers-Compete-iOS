//
//  ColorScheme.swift
//  Hackers
//
//  Created by Kyle Beard on 7/14/25.
//

import SwiftUI

/// This is used to shorthand map a color
enum ColorSchemeGrayShade {
    case gray
    case gray2
    case gray3
    case gray4
    case gray5
    case gray6
    case gray7
    
    var color: Color {
        switch self {
        case .gray:     return .hackersGray
        case .gray2:    return .hackersGray2
        case .gray3:    return .hackersGray3
        case .gray4:    return .hackersGray4
        case .gray5:    return .hackersGray5
        case .gray6:    return .hackersGray6
        case .gray7:    return .hackersGray7
        }
    }
}

extension ColorScheme {
    var isLight: Bool { self == .light }
    var isDark: Bool { self == .dark }
    
    var blurStyle: UIBlurEffect.Style {
        self.isLight ? .light : .dark
    }
    
    var translucent: CGFloat {
        self.isLight ? 0.1 : 0.25
    }
    
    func set(_ light: ColorSchemeGrayShade, _ dark: ColorSchemeGrayShade) -> Color {
        self.isLight ? light.color : dark.color
    }
}
