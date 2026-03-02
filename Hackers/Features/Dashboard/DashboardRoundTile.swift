//
//  DashboardRoundTile.swift
//  Hackers
//
//  Shared round tile and status badge for Dashboard tabs.
//

import SwiftUI

struct DashboardRoundTile: View {
    let round: Round
    let palette: DesignPalette
    var showDate: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let course = round.configuration.courses.first {
                    Text(course.courseInfo.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                    Text("\(course.holeRange.count) holes \(kDot) \(round.players.count) players")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                if showDate {
                    Text(round.lastUpdatedAt.formattedDate)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                }
            }

            Spacer(minLength: 0)

            RoundStatusBadge(status: round.status)

            Icon(name: "chevron.right", size: 14, weight: .semibold)
                .foregroundStyle(Color.neutral3)
        }
        .padding(16)
        .glassCardEffect()
    }
}

struct RoundStatusBadge: View {
    let status: RoundStatus

    var body: some View {
        Text(status.displayName)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(status == .live ? Color.accentGreen : Color.accentPurple)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status == .live ? Color.accentGreen.opacity(0.2) : Color.accentPurple.opacity(0.2))
            .cornerRadius(radius: 8)
    }
}
