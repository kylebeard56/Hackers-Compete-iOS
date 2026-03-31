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
    var showWeekdayFormat: Bool = false
    var currentPlayerID: String? = nil

    private var hasSignedScorecard: Bool {
        guard let playerID = currentPlayerID else { return false }
        return round.completedPlayers.contains { $0.playerID == playerID }
    }

    private var effectiveStatus: RoundStatus {
        if round.status == .live, hasSignedScorecard { return .complete }
        return round.status
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let course = round.configuration.courses.first {
                    Text(course.courseInfo.name)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(course.holeRange.count) holes \(kDot) \(round.players.count) players")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                if showDate {
                    Text(showWeekdayFormat ? round.lastUpdatedAt.weekdayShortMonthDay : round.lastUpdatedAt.formattedDate)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                }
            }

            Spacer(minLength: 0)

            RoundStatusBadge(status: effectiveStatus, signedScorecard: hasSignedScorecard && round.status == .live)

            Icon(name: "chevron.right", size: 14, weight: .semibold)
                .foregroundStyle(Color.neutral3)
        }
        .padding(16)
    }
}

struct RoundStatusBadge: View {
    let status: RoundStatus
    var signedScorecard: Bool = false

    private var chipColor: Color {
        switch status {
        case .lobby:                return .accentGreen
        case .live, .paused:        return .accentPurple
        case .complete, .archived:  return .accentYellow
        }
    }

    private var label: String {
        if signedScorecard { return "Signed" }
        return status.displayName
    }

    var body: some View {
        Group {
            if status == .live, !signedScorecard {
                LiveStatusView(
                    color: .accentPurple,
                    fontSize: 12,
                    label: "Live",
                    rippleColor: .accentPurple.opacity(0.3)
                )
            } else {
                Text(label)
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
