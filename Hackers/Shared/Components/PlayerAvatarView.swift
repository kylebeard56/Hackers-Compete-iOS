//
//  PlayerAvatarView.swift
//  Hackers
//
//  Created for GameLobby Tee Group & Team UX Refactor.
//

import SwiftUI

// MARK: - AvatarBadgeStyle

/// Config for glass effect on text badge. Use `.whiteGlass(palette)` for score-pill style.
struct AvatarBadgeStyle {
    enum Shape { case circle; case capsule }
    let shape: Shape
    let tint: Color
    let shadowColor: Color
    let shadowRadius: CGFloat
    let foregroundColor: Color

    static func whiteGlass(palette: DesignPalette) -> AvatarBadgeStyle {
        AvatarBadgeStyle(
            shape: .circle,
            tint: palette.whiteGlassButtonColor,
            shadowColor: palette.shadowColor,
            shadowRadius: 12,
            foregroundColor: palette.foregroundColor
        )
    }
}

// MARK: - PlayerAvatarView

/// Reusable avatar circle with optional corner badge. Future-ready for profile photos.
struct PlayerAvatarView: View {
    var initials: String
    var size: CGFloat
    var fillColor: Color?
    var glassTint: Color
    var badgeIcon: String?
    var badgeIconColor: Color?
    var badgeBackgroundColor: Color?
    var badgeText: String?
    var badgeStyle: AvatarBadgeStyle?
//    var badgeBorderColor: Color = .clear
//    var badgeBorderUsesCutout: Bool = false
    var initialsColor: Color?

    init(
        initials: String,
        size: CGFloat,
        fillColor: Color? = nil,
        glassTint: Color = .neutral6,
        badgeIcon: String? = nil,
        badgeIconColor: Color? = nil,
        badgeBackgroundColor: Color? = nil,
        badgeText: String? = nil,
        badgeStyle: AvatarBadgeStyle? = nil,
//        badgeBorderColor: Color,
//        badgeBorderUsesCutout: Bool = false,
        initialsColor: Color? = nil
    ) {
        self.initials = initials
        self.size = size
        self.fillColor = fillColor
        self.glassTint = glassTint
        self.badgeIcon = badgeIcon
        self.badgeIconColor = badgeIconColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeText = badgeText
        self.badgeStyle = badgeStyle
//        self.badgeBorderColor = badgeBorderColor
//        self.badgeBorderUsesCutout = badgeBorderUsesCutout
        self.initialsColor = initialsColor
    }

    private var badgeSize: CGFloat { size * 0.4 }
    private var badgeTextFontSize: CGFloat { badgeSize * 0.7 }

    private var effectiveBadgeStyle: AvatarBadgeStyle {
        badgeStyle ?? AvatarBadgeStyle(
            shape: .circle,
            tint: .neutral6,
            shadowColor: .clear,
            shadowRadius: 0,
            foregroundColor: .foregroundPrimary
        )
    }

    @ViewBuilder
    private var textBadgeView: some View {
        if let badgeText {
        let style = effectiveBadgeStyle

        Group {
            if style.shape == .circle {
                Text(badgeText)
                    .fontStyle(kFontName, size: badgeTextFontSize, weight: .semibold)
                    .foregroundStyle(style.foregroundColor)
                    .frame(width: badgeSize, height: badgeSize)
                    .glassCardEffect(shape: Circle(), interactive: false, tint: style.tint)
                    .shadow(color: style.shadowColor, radius: style.shadowRadius, x: 0, y: 0)
            } else {
                Text(badgeText)
                    .fontStyle(kFontName, size: badgeTextFontSize, weight: .semibold)
                    .foregroundStyle(style.foregroundColor)
                    .padding(.horizontal, badgeSize * 0.3)
                    .padding(.vertical, badgeSize * 0.2)
                    .glassCardEffect(shape: Capsule(), interactive: false, tint: style.tint)
                    .shadow(color: style.shadowColor, radius: style.shadowRadius, x: 0, y: 0)
            }
        }
        .alignTop()
        .alignTrailing()
        .padding(.top, -1 * badgeSize / 4)
        .padding(.trailing, -1 * badgeSize / 4)
        }
    }

    private var effectiveInitialsColor: Color {
        initialsColor ?? (fillColor != nil ? Color.backgroundPrimary : Color.foregroundPrimary)
    }

    var body: some View {
        ZStack {
            if let fillColor {
                Circle()
                    .fill(fillColor)
                    .frame(width: size, height: size)
                    .overlay {
                        Text(initials.uppercased())
                            .fontStyle(kFontName, size: size * 0.42, weight: .semibold)
                            .foregroundStyle(effectiveInitialsColor)
                    }
            } else {
                ZStack {
                    Text(initials.uppercased())
                        .fontStyle(kFontName, size: size * 0.42, weight: .semibold)
                        .foregroundStyle(effectiveInitialsColor)
                }
                .frame(width: size, height: size)
                .glassCardEffect(
                    shape: .circle,
                    interactive: false,
                    tint: glassTint,
                    shadowOpacity: 0
                )
            }

            if let badgeText {
                textBadgeView
            } else if let badgeIcon {
                ZStack {
                    Circle()
                        .fill(badgeBackgroundColor ?? Color.clear)
                        .frame(width: badgeSize, height: badgeSize)

                    Icon(name: badgeIcon, size: badgeSize * 0.8, weight: .solid)
                        .foregroundStyle(badgeIconColor ?? .primary)
                }
                .alignTop()
                .alignTrailing()
                .padding(.top, -1 * badgeSize / 4)
                .padding(.trailing, -1 * badgeSize / 4)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("With badge") {
    let palette = DesignPalette(theme: .glass, scheme: .light)
    return ZStack {
        BackgroundTheme(palette: palette, theme: .green)
        HStack(spacing: 24) {
            PlayerAvatarView(
                initials: "KB",
                size: 36,
                fillColor: .systemBlue,
                badgeIcon: "1.circle.fill",
                badgeIconColor: .systemBlue,
                badgeBackgroundColor: .white
            )

            PlayerAvatarView(
                initials: "JD",
                size: 64,
                glassTint: .neutral6,
                badgeIcon: "checkmark.circle.fill",
                badgeIconColor: .accentGreen,
                badgeBackgroundColor: .white
            )

            PlayerAvatarView(
                initials: "JA",
                size: 44,
                fillColor: .accentGreen.opacity(0.6),
                glassTint: .neutral6,
                badgeText: "12",
                badgeStyle: .whiteGlass(palette: palette)
            )
        }
        .padding(24)
        .alignMiddle()
        .alignCenter()
    }
}
