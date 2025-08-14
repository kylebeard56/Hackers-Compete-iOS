//
//  Color.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/25.
//

import SwiftUI

extension Color {
    func interpolate(to other: Color, fraction: Double) -> Color {
        // Convert to UIColor for component access
        let ui1 = UIColor(self)
        let ui2 = UIColor(other)

        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        ui1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        ui2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)

        // Handle hue wrap-around properly
        let hueDiff = h2 - h1
        let wrappedHueDiff = abs(hueDiff) > 0.5 ? hueDiff - copysign(1.0, hueDiff) : hueDiff
        let h = h1 + CGFloat(fraction) * wrappedHueDiff

        let s = s1 + (s2 - s1) * CGFloat(fraction)
        let b = b1 + (b2 - b1) * CGFloat(fraction)
        let a = a1 + (a2 - a1) * CGFloat(fraction)

        return Color(hue: Double((h < 0 ? h + 1 : h).truncatingRemainder(dividingBy: 1)),
                     saturation: Double(s),
                     brightness: Double(b),
                     opacity: Double(a))
    }
}
