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

    private var courseName: String? {
        round.configuration.courses.first?.courseInfo.name
    }

    private var holeCount: Int? {
        round.configuration.courses.first?.holeRange.count
    }

    private var title: String {
        round.displayTitle(courseName: courseName)
    }

    private var teeGroupLineCandidates: [String] {
        round.teeGroupLineCandidates(for: currentPlayerID)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let holeCount {
                    Text("\(holeCount) holes \(kDot) \(round.players.count) players")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                }

                if round.hasCustomDisplayName, let courseName, courseName.isPopulated {
                    Text(courseName)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                }

                if teeGroupLineCandidates.isPopulated {
                    ViewThatFits(in: .horizontal) {
                        ForEach(Array(teeGroupLineCandidates.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .fontStyle(kFontName, size: 13, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .lineLimit(1)
                        }
                    }
                }

                if showDate {
                    Text(showWeekdayFormat ? round.displayDate.weekdayShortMonthDay : round.displayDate.formattedDate)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            RoundStatusBadge(status: effectiveStatus, signedScorecard: hasSignedScorecard && round.status == .live)

            Icon(name: "chevron.right", size: 14, weight: .semibold)
                .foregroundStyle(Color.neutral3)
        }
        .padding(.vertical, 10)
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
