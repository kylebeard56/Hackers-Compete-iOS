//
//  FontModule.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
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

let kFontName: FontModule.Name = .poppins
private let kDefaultWeight: FontModule.Weight = .regular
private let kDefaultDesign: Font.Design? = .default

struct FontModule {
    /// High-level enum for views
    enum Name: String {
        case awesome = "awesome"
        case system = "system"
        case fugaz = "fugaz-one"
        case poppins = "poppins"
        case openSans = "open-sans"
        case quicksand = "quicksand"
    }
    
    /// Controls the font name (which effectively implies the weight as well)
    enum Weight: String {
        case thin, extraLight, light, regular, medium
        case semibold, bold, extraBold, black
        case brand, solid
        
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
            case .thin:             return "FontAwesome7Pro-Thin"
            case .light:            return "FontAwesome7Pro-Light"
            case .regular:          return "FontAwesome7Pro-Regular"
            case .brand:            return "FontAwesome7Brands-Regular"
            case .solid:            return "FontAwesome7Pro-Solid"
            default:                return ""
            }
        }
        
        var toFugaz: String {
            switch self {
            case .regular:          return "FugazOne-Regular"
            default:                return ""
            }
        }
        
        var toQuicksand: String {
            switch self {
            case .light:            return "Quicksand-Light"
            case .regular:          return "Quicksand-Regular"
            case .medium:           return "Quicksand-Medium"
            case .semibold:         return "Quicksand-SemiBold"
            case .bold:             return "Quicksand-Bold"
            default:                return ""
            }
        }
        
        var toOpenSans: String {
            switch self {
            case .thin:             return "OpenSans-Thin"
            case .extraLight:       return "OpenSans-ExtraLight"
            case .light:            return "OpenSans-Light"
            case .regular:          return "OpenSans-Regular"
            case .medium:           return "OpenSans-Medium"
            case .semibold:         return "OpenSans-SemiBold"
            case .bold:             return "OpenSans-Bold"
            case .extraBold:        return "OpenSans-ExtraBold"
            case .black:            return "OpenSans-Black"
            default:                return ""
            }
        }
        
        var toPoppins: String {
            switch self {
            case .thin:             return "Poppins-Thin"
            case .extraLight:       return "Poppins-ExtraLight"
            case .light:            return "Poppins-Light"
            case .regular:          return "Poppins-Regular"
            case .medium:           return "Poppins-Medium"
            case .semibold:         return "Poppins-SemiBold"
            case .bold:             return "Poppins-Bold"
            case .extraBold:        return "Poppins-ExtraBold"
            case .black:            return "Poppins-Black"
            default:                return ""
            }
        }
        
        /// Custom weight mapping when user's System Settings apply Bold Text
        func boldAccessibleScaling(with legibilityWeight: LegibilityWeight?) -> FontModule.Weight {
            guard legibilityWeight == .bold else { return self }
            
            switch self {
            case .thin, .extraLight, .light:    return .medium
            case .regular:                      return .semibold
            case .medium, .semibold:            return .bold
            case .bold, .extraBold, .black:     return .extraBold
            default:                            return .semibold
            }
        }
    }
}

extension Font {
    static func system(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: FontModule.Weight = kDefaultWeight,
        design: Font.Design? = kDefaultDesign
    ) -> Font {
        if let maxSize {
            var font = UIFont.systemFont(ofSize: size, weight: weight.toSystemUI)
            switch design {
            case .rounded:      font = font.rounded()
            case .monospaced:   font = font.monospaced()
            case .serif:        font = font.serif()
            default:            break
            }
            return Font(UIFontMetrics.default.scaledFont(for: font, maximumPointSize: maxSize))
        } else {
            return Font.system(size: size, weight: weight.toSystem, design: design)
        }
    }
    
    /// Awesome font wrapper
    static func awesome(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = kDefaultWeight.toAwesome
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: weight)
    }
    
    /// Fugaz font wrapper
    static func fugaz(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = kDefaultWeight.toFugaz
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: weight)
    }
    
    /// Poppins font wrapper
    static func poppins(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = kDefaultWeight.toPoppins,
        italic: Bool = false
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: "\(weight)\(italic ? "Italic" : "")")
    }
    
    /// OpenSans font wrapper
    static func openSans(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = kDefaultWeight.toOpenSans,
        italic: Bool = false
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: "\(weight)\(italic ? "Italic" : "")")
    }
    
    /// Quicksand font wrapper
    static func quicksand(
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: String = kDefaultWeight.toQuicksand
    ) -> Font {
        buildFont(size: size, maxSize: maxSize, weight: weight)
    }
    
    private static func buildFont(
        size: CGFloat,
        maxSize: CGFloat?,
        weight: String
    ) -> Font {
        if let maxSize, let font = UIFont(name: weight, size: size) {
            return Font(UIFontMetrics.default.scaledFont(for: font, maximumPointSize: maxSize))
        } else {
            return Font.custom(weight, size: size)
        }
    }
}

extension UIFont {
    func apply(design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func serif() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.serif) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func monospaced() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.monospaced) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.legibilityWeight) var legibilityWeight
    
    var name: FontModule.Name
    var size: CGFloat
    var maxSize: CGFloat?
    var weight: FontModule.Weight
    var design: Font.Design? // Used only for System font
    var italic: Bool // Used only for OpenSans and Poppins
    
    /// NOTE:
    /// - Inter is used for text, System is used for SF Symbols, and Awesome is used for icons.
    /// - Bolded weight will only be applied to Inter since we don't want to change weight of symbols/icons.
    func body(content: Content) -> some View {
        let scaledSize = UIFontMetrics.default.scaledValue(for: size)
        
        /// Guardrail the upper bound font size growth as a multiplier of the originally set size.
        let cappedSize = min(scaledSize, size * 1.25)
        
        switch name {
        case .awesome:
            return content.font(
                .awesome(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.toAwesome
                )
            )
        case .system:
            return content.font(
                .system(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.boldAccessibleScaling(with: legibilityWeight),
                    design: design
                )
            )
        case .fugaz:
            return content.font(
                .fugaz(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.toFugaz
                )
            )
        case .openSans:
            return content.font(
                .openSans(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.toOpenSans,
                    italic: italic
                )
            )
        case .poppins:
            return content.font(
                .poppins(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.toPoppins,
                    italic: italic
                )
            )
        case .quicksand:
            return content.font(
                .quicksand(
                    size: scaledSize,
                    maxSize: maxSize ?? cappedSize,
                    weight: weight.toQuicksand
                )
            )
        }
        
    }
}

extension View {
    func fontStyle(
        _ name: FontModule.Name = kFontName,
        size: CGFloat = 17,
        maxSize: CGFloat? = nil,
        weight: FontModule.Weight = kDefaultWeight,
        design: Font.Design? = kDefaultDesign,
        italic: Bool = false
    ) -> some View {
        return self.modifier(
            ScaledFont(
                name: name,
                size: size,
                maxSize: maxSize,
                weight: weight,
                design: design,
                italic: italic
            )
        )
    }
    
//    func fontNavigationHeader() -> some View {
//        return self.font(.inter, size: 17, weight: .semibold)
//    }
}
