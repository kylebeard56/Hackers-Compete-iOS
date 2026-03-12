//
//  DashboardPlayerRow.swift
//  Hackers
//
//  Player row for Recent/Top players section. Styled like PlayerScoringRow.
//

import SwiftUI

struct DashboardPlayerRow: View {
    let entry: PlayerHistoryEntry
    let palette: DesignPalette
    var embeddedInTile: Bool = false

    private var subtitle: String {
        guard let last = entry.lastPlayedAt else { return "No recent rounds" }
        let date = Date(timeIntervalSince1970: last.unix)
        return date.relativeTimeAgo
    }

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: entry.name.initials,
                size: 44,
                fillColor: .accentGreen.opacity(0.6),
                glassTint: .neutral6,
                badgeText: "\(entry.roundsPlayed)",
                badgeStyle: .whiteGlass(palette: palette)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name.fullName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(subtitle)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)
        }
        .padding(embeddedInTile ? 12 : 16)
        .modifier(DashboardEmbeddedTileModifier(embeddedInTile: embeddedInTile))
    }
}

private struct DashboardEmbeddedTileModifier: ViewModifier {
    let embeddedInTile: Bool
    func body(content: Content) -> some View {
        Group {
            if embeddedInTile {
                content
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentGreen.opacity(0.2), lineWidth: 1.5)
                    )
            } else {
                content.glassCardEffect()
            }
        }
    }
}
