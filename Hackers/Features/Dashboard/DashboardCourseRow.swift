//
//  DashboardCourseRow.swift
//  Hackers
//
//  Course row for Recent/Top courses section with "Play again" chip.
//

import SwiftUI

struct DashboardCourseRow: View {
    let entry: CourseHistoryEntry
    let palette: DesignPalette
    var rank: Int? = nil
    var embeddedInTile: Bool = false
    var onPlayAgain: () -> Void

    private var subtitle: String {
        if let rank {
            return "\(entry.roundsPlayed) round\(entry.roundsPlayed.pluralized)"
        }
        let date = Date(timeIntervalSince1970: entry.lastPlayedAt.unix)
        return date.relativeTimeAgo
    }

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                rankBadge(rank)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(subtitle)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.fire(.light)
                onPlayAgain()
            } label: {
                Text("Play again")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentGreen)
                    .cornerRadius(radius: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(embeddedInTile ? 12 : 16)
        .modifier(CourseRowEmbeddedTileModifier(embeddedInTile: embeddedInTile))
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .fontStyle(kFontName, size: 17, weight: .bold)
            .foregroundStyle(palette.foregroundColor)
            .frame(width: 44, height: 44)
            .background(Color.accentGreen.opacity(0.2))
            .clipShape(Circle())
    }
}

private struct CourseRowEmbeddedTileModifier: ViewModifier {
    let embeddedInTile: Bool
    func body(content: Content) -> some View {
        Group {
            if embeddedInTile {
                content
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(Color.accentGreen.opacity(0.2), lineWidth: 1.5)
//                    )
            } else {
                content.glassCardEffect()
            }
        }
    }
}
