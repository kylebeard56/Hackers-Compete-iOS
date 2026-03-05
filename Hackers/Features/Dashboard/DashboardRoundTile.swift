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
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
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

    private var chipColor: Color {
        switch status {
        case .lobby:                return .accentGreen
        case .live, .paused:        return .accentPurple
        case .complete, .archived:  return .accentYellow
        }
    }

    var body: some View {
        Group {
            if status == .live {
                LiveStatusView(
                    color: .accentPurple,
                    fontSize: 12,
                    label: "Live",
                    rippleColor: .white.opacity(0.3)
                )
            } else {
                Text(status.displayName)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(chipColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.2))
        .cornerRadius(radius: 8)
    }
}
