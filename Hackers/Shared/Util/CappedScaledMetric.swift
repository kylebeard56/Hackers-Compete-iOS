//
//  CappedScaledMetric.swift
//  Hackers
//
//  Scales with Dynamic Type but caps at the same multipliers as ScaledFont
//  (1.25x for normal sizes, 1.5x for accessibility1+) to keep layout consistent
//  with capped text.
//

import SwiftUI

private func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
    switch style {
    case .largeTitle: return .largeTitle
    case .title: return .title1
    case .title2: return .title2
    case .title3: return .title3
    case .headline: return .headline
    case .body: return .body
    case .callout: return .callout
    case .subheadline: return .subheadline
    case .footnote: return .footnote
    case .caption: return .caption1
    case .caption2: return .caption2
    @unknown default: return .body
    }
}

/// Scales with Dynamic Type but caps at the same multipliers as `ScaledFont`:
/// 1.25x for normal sizes, 1.5x for `.accessibility1` and up.
/// Keeps layout (padding, sizes) consistent with capped font scaling.
@propertyWrapper
struct CappedScaledMetric: DynamicProperty {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    private let base: CGFloat
    private let textStyle: Font.TextStyle

    init(wrappedValue: CGFloat, relativeTo textStyle: Font.TextStyle = .body) {
        self.base = wrappedValue
        self.textStyle = textStyle
    }

    var wrappedValue: CGFloat {
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle(for: textStyle))
        let scaled = metrics.scaledValue(for: base)
        let maxMultiplier: CGFloat = dynamicTypeSize >= .accessibility1 ? 1.5 : 1.25
        return min(scaled, base * maxMultiplier)
    }
}
