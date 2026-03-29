//
//  OutcomeLeaderboardRowView.swift
//  Hackers
//
//  Leaderboard row for RoundOutcomeView.
//

import SwiftUI

struct OutcomeLeaderboardRowView: View {
    @CappedScaledMetric(relativeTo: .body) var placeWidth: CGFloat = 30
    @CappedScaledMetric(relativeTo: .caption) var teamDotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body) var scoreWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var thruWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 10

    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let nameDisplayFormat: NameDisplayFormat
    var usesFormatDisplay: Bool = false
    var isHighestWinsFormat: Bool = false
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

    private var scoreLabel: String {
        if usesFormatDisplay, let total = row.totalPoints {
            if isHighestWinsFormat {
                let formatted = String(format: "%.1f", total)
                return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
            }
            let intVal = Int(total)
            if intVal == 0 { return "E" }
            if intVal > 0 { return "+\(intVal)" }
            return "\(intVal)"
        }
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
