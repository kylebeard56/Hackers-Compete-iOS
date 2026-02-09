//
//  ColorScheme.swift
//  Hackers
//
//  Created by Kyle Beard on 7/14/25.
//

import SwiftUI

/// This is used to shorthand map a color
enum ColorSchemeGrayShade {
    case white
    case gray
    case gray2
    case gray3
    case gray4
    case gray5
    case gray6
//    case gray7
    
    var color: Color {
        switch self {
        case .white:    return .white
        case .gray:     return .neutral
        case .gray2:    return .neutral2
        case .gray3:    return .neutral3
        case .gray4:    return .neutral4
        case .gray5:    return .neutral5
        case .gray6:    return .neutral6
//        case .gray7:    return .neutral7
        }
    }
}

extension ColorScheme {
    var isLight: Bool { self == .light }
    var isDark: Bool { self == .dark }
    
    var opposite: ColorScheme {
        isLight ? .dark : .light
    }
    
    var blurStyle: UIBlurEffect.Style {
        self.isLight ? .light : .dark
    }
    
    var translucent: CGFloat {
        self.isLight ? 0.1 : 0.25
    }
    
    var ultraTranslucent: CGFloat {
        translucent / 2.5
    }
    
    func set(_ light: ColorSchemeGrayShade, _ dark: ColorSchemeGrayShade) -> Color {
        self.isLight ? light.color : dark.color
    }
}
