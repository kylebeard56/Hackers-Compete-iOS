//
//  DynamicColor.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import SwiftUI
import UIKit

// TODO: Instead of having this, we should create an extension off of the color value that converts to light/dark
//struct DynamicColor: Hashable, Codable {
//    var light: ColorValue
//    var dark: ColorValue
//    
//    init(
//        red: Double = 0,
//        green: Double = 0,
//        blue: Double = 0,
//        scheme: ColorScheme
//    ) {
//        let input = ColorValue(red: red, green: green, blue: blue)
//        switch scheme {
//        case .light:
//            self.light = input
//            self.dark = input.converted(from: .light, to: .dark)
//        case .dark:
//            self.dark = input
//            self.light = input.converted(from: .dark, to: .light)
//        @unknown default:
//            self.light = input
//            self.dark = input.converted(from: .light, to: .dark)
//        }
//    }
//    
//    init(hex: String, scheme: ColorScheme) {
//        let colorValue = ColorValue(hex: hex)
//        switch scheme {
//        case .light:
//            self.light = colorValue
//            self.dark = colorValue.converted(from: .light, to: .dark)
//        case .dark:
//            self.dark = colorValue
//            self.light = colorValue.converted(from: .dark, to: .light)
//        @unknown default:
//            self.light = colorValue
//            self.dark = colorValue.converted(from: .light, to: .dark)
//        }
//    }
//    
//    init(color: Color) {
//        let c = ColorValue(color: color)
//        self.light = c
//        self.dark = ColorValue(color: color).converted(from: .light, to: .dark)
//    }
//}

struct ColorValue: Hashable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var hex: String?
    
    init(red: Double = 0, green: Double = 0, blue: Double = 0) {
        self.red = red
        self.green = green
        self.blue = blue
    }
    
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        
        if cleanHex.count == 6 {
            self.red = Double((rgb & 0xFF0000) >> 16) / 255.0
            self.green = Double((rgb & 0x00FF00) >> 8) / 255.0
            self.blue = Double(rgb & 0x0000FF) / 255.0
        } else if cleanHex.count == 3 {
            // Short hex format like "F0A"
            let r = (rgb & 0xF00) >> 8
            let g = (rgb & 0x0F0) >> 4
            let b = rgb & 0x00F
            self.red = Double(r * 17) / 255.0  // 17 = 0x11, converts F -> FF
            self.green = Double(g * 17) / 255.0
            self.blue = Double(b * 17) / 255.0
        } else {
            // Invalid hex, default to black
            self.red = 0
            self.green = 0
            self.blue = 0
        }
        
        self.hex = "#" + cleanHex.uppercased()
    }
    
    init(color: Color) {
        // Convert SwiftUI Color to UIColor to extract RGB components
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Extract RGB components
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.red = Double(red)
            self.green = Double(green)
            self.blue = Double(blue)
        } else {
            // Fallback: try to resolve the color in different color spaces
            let ciColor = CIColor(color: uiColor)
            self.red = Double(ciColor.red)
            self.green = Double(ciColor.green)
            self.blue = Double(ciColor.blue)
        }
        
        // Generate hex representation
        let r = Int((self.red * 255).clamped(0, 255))
        let g = Int((self.green * 255).clamped(0, 255))
        let b = Int((self.blue * 255).clamped(0, 255))
        self.hex = String(format: "#%02X%02X%02X", r, g, b)
    }
    
    enum CodingKeys: String, CodingKey { case red, green, blue }
    
    var color: Color {
        Color(UIColor(red: red, green: green, blue: blue, alpha: 1.0))
    }
}

// MARK: - Shortcut colors

extension ColorValue {
    static var red: ColorValue { ColorValue(color: .red) }
    static var orange: ColorValue { ColorValue(color: .orange) }
    static var yellow: ColorValue { ColorValue(color: .yellow) }
    static var green: ColorValue { ColorValue(color: .green) }
    static var blue: ColorValue { ColorValue(color: .blue) }
    static var indigo: ColorValue { ColorValue(color: .indigo) }
    static var purple: ColorValue { ColorValue(color: .purple) }

    /// WCAG 2.1 relative luminance in linear sRGB, 0...1.
    var wcagRelativeLuminance: Double {
        relativeLuminanceSRGB(red, green, blue)
    }

    /// Label color for text on a solid fill of this color (independent of color scheme).
    var preferredContrastingLabelColor: Color {
        wcagRelativeLuminance < 0.179 ? .white : .black
    }
}

// MARK: - SwiftUI Color (resolved contrast on solid fills)

extension Color {
    /// Black or white for icons/text on a solid `background`, using colors resolved for `colorScheme`.
    static func accessibleLabelOnSolidBackground(background: Color, colorScheme: ColorScheme) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let resolved = UIColor(background).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let lr: Double
        let lg: Double
        let lb: Double
        if resolved.getRed(&r, green: &g, blue: &b, alpha: &a) {
            lr = Double(r)
            lg = Double(g)
            lb = Double(b)
        } else {
            let ci = CIColor(color: resolved)
            lr = Double(ci.red)
            lg = Double(ci.green)
            lb = Double(ci.blue)
        }
        let L = relativeLuminanceSRGB(lr, lg, lb)
        let crWhite = (1.0 + 0.05) / (L + 0.05)
        let crBlack = (L + 0.05) / 0.05
        return crWhite >= crBlack ? .white : .black
    }
}

// MARK: - Conversion core

extension ColorValue {
    /// Convert this color from `origin` scheme to a counterpart in `target` scheme,
    /// preserving contrast vs. scheme background and roughly preserving hue/saturation.
    func converted(
        from origin: ColorScheme,
        to target: ColorScheme,
        options: DynamicColorConversionOptions = .iosDefaults
    ) -> ColorValue {
        
        // 1) Source luminance and background luminance
        let L_src = srgbLuminance()
        let L_bg_src = (origin == .light) ? options.lightBackgroundLuminance : options.darkBackgroundLuminance
        
        // 2) Contrast ratio of the source color vs its background
        // CR = (max(L1, L2) + 0.05) / (min(L1, L2) + 0.05)
        let CR = contrastRatio(L_src, L_bg_src)
        
        // 3) Choose the *opposite side* of the target background to maintain readability:
        // Dark text on light bg  -> light text on dark bg (and vice versa).
        let L_bg_tgt = (target == .light) ? options.lightBackgroundLuminance : options.darkBackgroundLuminance
        let srcIsLighterThanBg = L_src > L_bg_src
        let makeLighterThanTargetBg = !srcIsLighterThanBg
        
        // Solve for target luminance that yields the same contrast vs new background.
        // If target is lighter than bg:  L_t = CR*(L_bg + 0.05) - 0.05
        // If target is darker  than bg:  L_t = (L_bg + 0.05)/CR - 0.05
        var L_tgt: Double
        if makeLighterThanTargetBg {
            L_tgt = CR * (L_bg_tgt + 0.05) - 0.05
        } else {
            L_tgt = (L_bg_tgt + 0.05) / CR - 0.05
        }
        L_tgt = L_tgt.clamped(0, 1)
        
        // 4) Preserve hue & saturation as much as possible:
        // Convert to HSL, adjust only lightness to achieve target luminance using a small binary search.
        var (h, s, _) = rgbToHsl(r: red, g: green, b: blue)
        
        // Optional: mild saturation adjustment for dark mode to avoid neon on black.
        if target == .dark {
            s *= options.darkSaturationMultiplier
        } else {
            s *= options.lightSaturationMultiplier
        }
        s = s.clamped(0, 1)
        
        // Binary search over HSL L to match target relative luminance.
        let targetRGB = solveForLuminance(h: h, s: s, targetLuma: L_tgt, iterations: 16)
        
        // Safety clamps
        return ColorValue(
            red:   targetRGB.r.clamped(0, 1),
            green: targetRGB.g.clamped(0, 1),
            blue:  targetRGB.b.clamped(0, 1)
        )
    }
}

// MARK: - Options

struct DynamicColorConversionOptions {
    /// Approximate luminance of system backgrounds in linear sRGB space.
    /// Light is near white (≈1.0). Dark is near black; #121212 linear luminance ~0.01.
    let lightBackgroundLuminance: Double
    let darkBackgroundLuminance: Double
    
    /// Subtle saturation tweaks for better appearance in dark/light contexts.
    let darkSaturationMultiplier: Double
    let lightSaturationMultiplier: Double
    
    static let iosDefaults = DynamicColorConversionOptions(
        lightBackgroundLuminance: 1.0,
        darkBackgroundLuminance: 0.01,   // close to iOS dark surfaces
        darkSaturationMultiplier: 0.92,  // slightly tame saturation in dark mode
        lightSaturationMultiplier: 1.00
    )
}

// MARK: - Math helpers (sRGB, luminance, HSL, search)

private func relativeLuminanceSRGB(_ r: Double, _ g: Double, _ b: Double) -> Double {
    let R = linearizeSRGB(r), G = linearizeSRGB(g), B = linearizeSRGB(b)
    // WCAG 2.1 coefficients
    return 0.2126 * R + 0.7152 * G + 0.0722 * B
}

private extension ColorValue {
    func srgbLuminance() -> Double {
        relativeLuminanceSRGB(red, green, blue)
//        let r = linearizeSRGB(red), g = linearizeSRGB(green), b = linearizeSRGB(blue)
//        // WCAG 2.1 coefficients
//        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

private func linearizeSRGB(_ v: Double) -> Double {
    if v <= 0.04045 { return v / 12.92 }
    return pow((v + 0.055) / 1.055, 2.4)
}

private func delinearizeSRGB(_ v: Double) -> Double {
    if v <= 0.0031308 { return 12.92 * v }
    return 1.055 * pow(v, 1.0 / 2.4) - 0.055
}

private func contrastRatio(_ a: Double, _ b: Double) -> Double {
    let L1 = max(a, b), L2 = min(a, b)
    return (L1 + 0.05) / (L2 + 0.05)
}

// HSL conversions (sRGB 0...1)
private func rgbToHsl(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
    let maxV = max(r, max(g, b))
    let minV = min(r, min(g, b))
    let d = maxV - minV
    var h: Double = 0
    let l = (maxV + minV) / 2
    let s: Double = {
        if d == 0 { return 0 }
        return d / (1 - abs(2 * l - 1))
    }()
    if d != 0 {
        if maxV == r {
            h = ((g - b) / d).truncatingRemainder(dividingBy: 6)
        } else if maxV == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h /= 6
        if h < 0 { h += 1 }
    }
    return (h, s, l)
}

private func hslToRgb(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
    if s == 0 { return (l, l, l) }
    let q = l < 0.5 ? l * (1 + s) : (l + s - l * s)
    let p = 2 * l - q
    func hue2rgb(_ p: Double, _ q: Double, _ t: Double) -> Double {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1/6 { return p + (q - p) * 6 * t }
        if t < 1/2 { return q }
        if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
        return p
    }
    let r = hue2rgb(p, q, h + 1/3)
    let g = hue2rgb(p, q, h)
    let b = hue2rgb(p, q, h - 1/3)
    return (r, g, b)
}

/// Adjust HSL lightness (keeping H & S) until the sRGB relative luminance matches `targetLuma`.
private func solveForLuminance(h: Double, s: Double, targetLuma: Double, iterations: Int = 16) -> (r: Double, g: Double, b: Double) {
    var low = 0.0, high = 1.0
    var bestRGB: (Double, Double, Double) = (0,0,0)
    var bestDiff = Double.greatestFiniteMagnitude
    
    for _ in 0..<iterations {
        let mid = (low + high) / 2
        let rgb = hslToRgb(h: h, s: s, l: mid)
        let L = relativeLuminanceSRGB(rgb.r, rgb.g, rgb.b)
        let diff = abs(L - targetLuma)
        if diff < bestDiff {
            bestDiff = diff
            bestRGB = (rgb.r, rgb.g, rgb.b)
        }
        if L < targetLuma {
            // Need more luminance → raise lightness
            low = mid
        } else {
            high = mid
        }
    }
    return bestRGB
}

// MARK: - Utilities

private extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { min(max(self, lo), hi) }
}
