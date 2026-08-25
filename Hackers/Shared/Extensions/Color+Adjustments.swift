//
//  Color+Adjustments.swift
//  Hackers
//

import SwiftUI
import UIKit

extension Color {
    func lighten(by percentage: CGFloat = 30) -> Color {
        Color(UIColor(self).lighten(by: percentage) ?? UIColor(self))
    }

    func darken(by percentage: CGFloat = 30) -> Color {
        Color(UIColor(self).darken(by: percentage) ?? UIColor(self))
    }
}

extension UIColor {
    func lighten(by percentage: CGFloat = 30) -> UIColor? {
        adjust(by: abs(percentage))
    }

    func darken(by percentage: CGFloat = 30) -> UIColor? {
        adjust(by: -abs(percentage))
    }

    func adjust(by percentage: CGFloat = 30) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return UIColor(
            red: min(red + percentage / 100, 1),
            green: min(green + percentage / 100, 1),
            blue: min(blue + percentage / 100, 1),
            alpha: alpha
        )
    }
}
