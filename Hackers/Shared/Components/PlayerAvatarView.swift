//
//  PlayerAvatarView.swift
//  Hackers
//
//  Created for GameLobby Tee Group & Team UX Refactor.
//

import SwiftUI

/// Reusable avatar circle with optional corner badge. Future-ready for profile photos.
struct PlayerAvatarView: View {
    var initials: String
    var size: CGFloat
    var fillColor: Color?
    var glassTint: Color
    var badgeIcon: String?
    var badgeIconColor: Color?
    var badgeBackgroundColor: Color
    var badgeBorderColor: Color
    var initialsColor: Color?

    init(
        initials: String,
        size: CGFloat,
        fillColor: Color? = nil,
        glassTint: Color = .neutral6,
        badgeIcon: String? = nil,
        badgeIconColor: Color? = nil,
        badgeBackgroundColor: Color,
        badgeBorderColor: Color,
        initialsColor: Color? = nil
    ) {
        self.initials = initials
        self.size = size
        self.fillColor = fillColor
        self.glassTint = glassTint
        self.badgeIcon = badgeIcon
        self.badgeIconColor = badgeIconColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeBorderColor = badgeBorderColor
        self.initialsColor = initialsColor
    }

    private var badgeSize: CGFloat { size * 0.34 }
    private var effectiveInitialsColor: Color {
        initialsColor ?? (fillColor != nil ? .white : .primary)
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

            if let badgeIcon {
                ZStack {
                    Circle()
                        .fill(badgeBackgroundColor)
                        .frame(width: badgeSize, height: badgeSize)
                        .overlay {
                            Circle()
                                .strokeBorder(badgeBorderColor, lineWidth: 1.5)
                        }

                    Icon(name: badgeIcon, size: badgeSize * 0.7, weight: .solid)
                        .foregroundStyle(badgeIconColor ?? .primary)
                }
                .alignTop()
                .alignTrailing()
                .padding(.top, -4)
                .padding(.trailing, -4)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("With badge") {
    HStack(spacing: 24) {
        PlayerAvatarView(
            initials: "KB",
            size: 36,
            fillColor: .systemBlue,
            badgeIcon: "1.circle.fill",
            badgeIconColor: .systemBlue,
            badgeBackgroundColor: .white,
            badgeBorderColor: .systemBlue
        )

        PlayerAvatarView(
            initials: "JD",
            size: 64,
            glassTint: .neutral6,
            badgeIcon: "checkmark.circle.fill",
            badgeIconColor: .accentGreen,
            badgeBackgroundColor: .white,
            badgeBorderColor: .gray.opacity(0.3)
        )
    }
    .padding(24)
    .background(Color.gray.opacity(0.2))
}
