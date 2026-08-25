//
//  Font.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/24.
//  Copyright © 2024 Tiger Mind Labs, Inc. All rights reserved.
//

import Foundation
import SwiftUI

// https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
/// NAME            SIZE      WEIGHT
/// .largeTitle     34        .regular
/// .title          28        .regular
/// .title2         22        .regular
/// .title3         20        .regular
/// .headline       17        .semibold
/// .body           17        .regular
/// .callout        16        .regular
/// .subheadline    15        .regular
/// .footnote       13        .regular
/// .caption        12        .regular
/// .caption2       11        .regular

struct FontModule {
    /// High-level enum for views
    enum Name: String {
        case awesome = "awesome"
        case inter = "inter"
        case dmSans = "dmsans"
        case system = "system"
    }
    
    /// Controls the font name (which effectively implies the weight as well)
    enum Weight: String {
        case thin
        case extraLight
        case light
        case regular
        case medium
        case semibold
        case bold
        case extraBold
        case black
        case brand
        case solid
        
        /// Module weight representation for the System font
        var toSystem: Font.Weight {
            switch self {
            case .thin:             return .ultraLight
            case .extraLight:       return .thin
            case .light:            return .light
            case .regular:          return .regular
            case .medium:           return .medium
            case .semibold:         return .semibold
            case .bold:             return .bold
            case .extraBold:        return .black
            case .black:            return .black
            default:                return .regular
            }
        }
        
        /// Module weight representation for the System font
        var toSystemUI: UIFont.Weight {
            switch self {
            case .thin:             return .ultraLight
            case .extraLight:       return .thin
            case .light:            return .light
            case .regular:          return .regular
            case .medium:           return .medium
            case .semibold:         return .semibold
            case .bold:             return .bold
            case .extraBold:        return .black
            case .black:            return .black
            default:                return .regular
            }
        }
        
        /// Module weight representation for the Awesome font
        var toAwesome: String {
            switch self {
            case .thin:             return "FontAwesome6Pro-Thin"
            case .light:            return "FontAwesome6Pro-Light"
            case .regular:          return "FontAwesome6Pro-Regular"
            case .brand:            return "FontAwesome6Brands-Regular"
            case .solid:            return "FontAwesome6Pro-Solid"
            default:                return ""
            }
        }
        
        /// Module weight representation for the DM Sans font
        var toDMSans: String {
            switch self {
            case .regular:          return "DM Sans Regular"//\(italics ? "Italic" : "")"
            case .medium:           return "DM Sans Medium"//\(italics ? "Italic" : "")"
            case .bold:             return "DM Sans Bold"//\(italics ? "Italic" : "")"
            default:                return ""
            }
        }
        
        var toInter: String {
            switch self {
            case .thin:             return "Inter Thin"
            case .extraLight:       return "Inter ExtraLight"
            case .light:            return "Inter Light"
            case .regular:          return "Inter Regular"
            case .medium:           return "Inter Medium"
            case .semibold:         return "Inter SemiBold"
            case .bold:             return "Inter Bold"
            case .extraBold:        return "Inter ExtraBold"
            case .black:            return "Inter Black"
            default:                return ""
            }
        }
        
        /// Custom weight mapping when user's System Settings apply Bold Text
        func boldAccessibleScaling(with legibilityWeight: LegibilityWeight?) -> FontModule.Weight {
            if legibilityWeight != .bold { return self }
            
            var w: FontModule.Weight
            
            switch self {
            case .thin, .extraLight, .light:            w = .medium
            case .regular:                              w = .semibold
            case .medium, .semibold:                    w = .bold
            case .bold, .extraBold, .black:             w = .extraBold
            default:                                    w = .semibold
            }
            
            return w
        }
    }
}

extension UIFont {
    static func dmSans(size: CGFloat = 17, weight: FontModule.Weight = .regular) -> UIFont {
        return UIFont(name: weight.toDMSans, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.toSystemUI)
    }
    
    static func inter(size: CGFloat = 17, weight: FontModule.Weight = .regular) -> UIFont {
        return UIFont(name: weight.toInter, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.toSystemUI)
    }
}

extension Font {
    /// System font wrapper to handle max size for Dynamic Type scaling.
    fileprivate static func system(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: FontModule.Weight = .regular
    ) -> Font {
        if let maxSize {
            let font = UIFont.systemFont(ofSize: size, weight: weight.toSystemUI)
            return Font(UIFontMetrics.default.scaledFont(for: font, maximumPointSize: maxSize))
        } else {
            return Font.system(size: size, weight: weight.toSystem)
        }
    }
    
    /// Awesome font wrapper
    fileprivate static func awesome(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = FontModule.Weight.regular.toAwesome
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: weight)
    }

    /// DM Sans normal font wrapper
    fileprivate static func dmSans(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = FontModule.Weight.regular.toDMSans
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: weight)
    }
    
    /// DM Sans italicized font wrapper
//    fileprivate static func dmSansItalics(
//        size: CGFloat = 17,
//        maxSize: CGFloat? = nil,
//        weight: String = FontModule.Weight.regular.toDMSans(true)
//    ) -> Font {
//        buildFont(size: size, maxSize: maxSize, weight: weight)
//    }
    
    /// Inter font wrapper
    fileprivate static func inter(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = FontModule.Weight.regular.toInter
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: weight)
    }
    
    private static func buildFont(size: CGFloat, maxSize: CGFloat?, weight: String) -> Font {
        if let maxSize, let font = UIFont(name: weight, size: size) {
            return Font(UIFontMetrics.default.scaledFont(for: font, maximumPointSize: maxSize))
        } else {
            return Font.custom(weight, size: size)
        }
    }
}

struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.legibilityWeight) var legibilityWeight
    
    var name: FontModule.Name
    var size: CGFloat
    var maxSize: CGFloat?
    var weight: FontModule.Weight
    
    /// NOTE:
    /// - Inter is used for text, System is used for SF Symbols, and Awesome is used for icons.
    /// - Bolded weight will only be applied to Inter since we don't want to change weight of symbols/icons.
    func body(content: Content) -> some View {
        let scaledSize = UIFontMetrics.default.scaledValue(for: size)
        
        /// Guardrail the upper bound font size growth as a multiplier of the originally set size.
        let cappedSize = size * 1.6
        
/// ----> Uncomment this block if you want to get console printouts of font size rendering.
//        if scaledSize > cappedSize {
//            print("FONT | \(size) capped at \(cappedSize) for \(dynamicTypeSize)")
//        } else {
//            print("FONT | \(size) scaled to \(scaledSize) for \(dynamicTypeSize)")
//        }
        
        switch name {
        case .awesome:
            return content.font(
                .awesome(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.toAwesome
                )
            )
        case .dmSans:
            return content.font(
                .dmSans(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.boldAccessibleScaling(with: legibilityWeight).toDMSans
                )
            )
        case .inter:
            return content.font(
                .inter(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.boldAccessibleScaling(with: legibilityWeight).toInter
                )
            )
        case .system:
            return content.font(
                .system(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.boldAccessibleScaling(with: legibilityWeight)
                )
            )
        }
    }
}

extension View {
    func font(
        _ name: FontModule.Name,
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: FontModule.Weight = .regular
    ) -> some View {
        return self.modifier(
            ScaledFont(
                name: name,
                size: size,
                maxSize: maxSize,
                weight: weight
            )
        )
    }
    
    func fontNavigationHeader() -> some View {
        return self.font(.inter, size: 17, weight: .semibold)
    }
}
