//
//  Color.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

extension UIColor {
    var hexValue: String {
        let components = self.cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0

        let hexString = String.init(
            format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255))
        )
        return hexString
     }
}

extension Color {
    var hexValue: String {
        let components = self.cgColor?.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0

        let hexString = String.init(
            format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255))
        )
        return hexString
    }
    
    var toGradient: LinearGradient {
        LinearGradient(colors: [self, self], startPoint: .leading, endPoint: .trailing)
    }
}

extension ColorScheme {
    var isLight: Bool { self == .light }
    var isDark: Bool { self == .dark }
    
    var blurStyle: UIBlurEffect.Style {
        self.isLight ? .light : .dark
    }
    
    var translucent: CGFloat {
        self.isLight ? 0.125 : 0.25
    }
    
    /// SystemGray6 if light, SystemGray5 is dark
    var superlightGray: Color {
        self.isLight ? .systemGray6 : .systemGray5
    }
    
    /// SystemGray5 if light, SystemGray3 is dark
    var lightGray: Color {
        self.isLight ? .systemGray5 : .systemGray3
    }
    
    /// SystemGray6 if light, SystemGray2 is dark
    var contrastGray: Color {
        self.isLight ? .systemGray6 : .systemGray2
    }
    
    var pageIndicatorTintColor: UIColor {
        self.isLight ? .systemGray6 : .systemGray5
    }
    
    var currentPageIndicatorTintColor: UIColor {
        self.isLight ? .systemGray4 : .systemGray3
    }
}
