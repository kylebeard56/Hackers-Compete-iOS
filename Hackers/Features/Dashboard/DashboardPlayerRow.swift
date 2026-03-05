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

    private var subtitle: String {
        let count = entry.roundsPlayed
        let countStr = count == 1 ? "1 round" : "\(count) rounds"
        if let last = entry.lastPlayedAt {
            let date = Date(timeIntervalSince1970: last.unix)
            let rel = date.relativeTimeAgo
            return "\(countStr) together, last \(rel)"
        }
        return "\(countStr) together"
    }

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: entry.name.initials,
                size: 44,
                fillColor: .accentGreen.opacity(0.6),
                glassTint: .neutral6
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name.fullName)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(subtitle)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCardEffect()
    }
}
