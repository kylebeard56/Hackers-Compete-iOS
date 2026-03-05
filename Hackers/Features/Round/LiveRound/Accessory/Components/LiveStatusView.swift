//
//  LiveStatusView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/24/26.
//

import SwiftUI

struct LiveStatusView: View {
    /// Primary color for core dot and text
    var color: Color
    /// Font size drives all other dimensions via ratios. Default 15.
    var fontSize: CGFloat = 15
    /// Label text (e.g. "LIVE", "Lobby"). Default "LIVE".
    var label: String = "LIVE"
    /// Ripple fill color. If nil, uses color.opacity(0.2). Use .white or .black for chip backgrounds.
    var rippleColor: Color? = nil
    /// Whether to animate the ripple. Default true for "LIVE", false for static badges.
    var animated: Bool = true

    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var circleSize: CGFloat { fontSize * 0.65 }
    private var coreSize: CGFloat { fontSize * 0.4 }
    private var spacing: CGFloat { fontSize * 0.53 }
    private var effectiveRippleColor: Color { rippleColor ?? color.opacity(0.2) }

    var body: some View {
        HStack(spacing: spacing) {
            ZStack {
                // Ripple
                Circle()
                    .fill(effectiveRippleColor)
                    .frame(width: circleSize, height: circleSize)
                    .scaleEffect(animated && animate ? 2.6 : 1)
                    .opacity(animated && animate ? 0 : 1)
                    .animation(
                        animated && !reduceMotion
                            ? .easeOut(duration: 3).repeatForever(autoreverses: false)
                            : .default,
                        value: animate
                    )

                // Core dot
                Circle()
                    .fill(color)
                    .frame(width: coreSize, height: coreSize)
            }

            Text(label)
                .fontStyle(kFontName, size: fontSize, weight: .semibold)
                .foregroundStyle(color)
        }
        .onAppear { animate = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack(spacing: 24) {
        LiveStatusView(color: .accentPurple, fontSize: 12, rippleColor: .white)
        LiveStatusView(color: .accentPurple)
    }
}
