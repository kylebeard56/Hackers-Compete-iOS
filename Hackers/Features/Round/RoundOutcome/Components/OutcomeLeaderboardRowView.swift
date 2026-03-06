//
//  OutcomeLeaderboardRowView.swift
//  Hackers
//
//  Leaderboard row for RoundOutcomeView with completion/attachment status icons.
//

import SwiftUI

struct OutcomeLeaderboardRowView: View {
    @CappedScaledMetric(relativeTo: .body) var placeWidth: CGFloat = 30
    @CappedScaledMetric(relativeTo: .caption) var teamDotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body) var scoreWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var thruWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var iconSize: CGFloat = 18
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 10

    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let nameDisplayFormat: NameDisplayFormat
    let isCompleted: Bool
    let hasAttachedScorecard: Bool
    let onTap: Callback

    var body: some View {
        Button {
            Haptics.fire(.light)
            onTap()
        } label: {
            HStack(spacing: rowSpacing) {
                Text(placeLabel)
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                    .frame(width: placeWidth, alignment: .center)

                if let teamColor {
                    Circle()
                        .fill(teamColor.opacity(0.9))
                        .frame(width: teamDotSize, height: teamDotSize)
                }

                HStack(spacing: 4) {
                    ViewThatFits(in: .horizontal) {
                        Text(fullParticipantName)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .layoutPriority(1)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Text(compactParticipantName)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                    }

                    statusIcons
                }

                Spacer(minLength: 0)

                Text(scoreLabel)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: scoreWidth, alignment: .center)

                Text("\(row.thru)")
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                    .frame(width: thruWidth, alignment: .center)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcons: some View {
        HStack(spacing: 4) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color.accentGreen)
            }
            if hasAttachedScorecard {
                Image(systemName: "paperclip")
                    .font(.system(size: iconSize - 2))
                    .foregroundStyle(Color.neutral2)
            }
        }
    }

    private var scoreLabel: String {
        if row.scoreToPar == 0 { return "E" }
        if row.scoreToPar > 0 { return "+\(row.scoreToPar)" }
        return "\(row.scoreToPar)"
    }

    private var fullParticipantName: String {
        row.participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compactParticipantName: String {
        let given = row.participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = row.participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard given.isPopulated || family.isPopulated else { return fullParticipantName }
        switch nameDisplayFormat {
        case .firstInitialLastName:
            guard let g = given.first else { return family }
            return "\(g). \(family)"
        case .firstNameLastInitial:
            guard let f = family.first else { return given }
            return "\(given) \(f)."
        }
    }
}
