//
//  OutcomeLeaderboardRowView.swift
//  Hackers
//
//  Leaderboard row for RoundOutcomeView.
//

import SwiftUI

struct OutcomeLeaderboardRowView: View {
    @CappedScaledMetric(relativeTo: .body) var placeWidth: CGFloat = 44
    @CappedScaledMetric(relativeTo: .caption) var teamDotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body) var handicapWidth: CGFloat = 38
    @CappedScaledMetric(relativeTo: .body) var scoreWidth: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body) var thruWidth: CGFloat = 42
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 10

    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let nameDisplayFormat: NameDisplayFormat
    var usesFormatDisplay: Bool = false
    var isHighestWinsFormat: Bool = false
    var showsHandicap: Bool = false
    let onTap: Callback

    private var showsSubstituteMarker: Bool {
        row.participant.isSubstitute && row.memberNames == nil && !row.isSharedScoreUnit
    }

    var body: some View {
        Button {
            Haptics.fire(.light)
            onTap()
        } label: {
            HStack(spacing: rowSpacing) {
                Text(placeLabel)
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: placeWidth, alignment: .center)

                if let teamColor {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(showsSubstituteMarker ? Color.clear : teamColor.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(teamColor.opacity(0.9), lineWidth: showsSubstituteMarker ? 1.5 : 0)
                        )
                        .frame(width: row.memberNames != nil ? 4 : teamDotSize,
                               height: row.memberNames != nil ? (row.isSharedScoreUnit ? 36 : 28) : teamDotSize)
                }

                VStack(alignment: .leading, spacing: 2) {
                    ViewThatFits(in: .horizontal) {
                        Text(displayName)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .layoutPriority(1)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Text(compactDisplayName)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                    }

                    if let names = row.memberNames {
                        Text(names)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(row.isSharedScoreUnit ? 3 : 1)
                    }

                    if let statusLabel = row.scoreCompleteness?.outcomeStatusTitle {
                        Text(statusLabel)
                            .fontStyle(kFontName, size: 11, weight: .medium)
                            .foregroundStyle(Color.neutral2)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if showsHandicap {
                    Text(handicapLabel)
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(isValidOutcomeScore ? Color.neutral2 : Color.neutral3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: handicapWidth, alignment: .center)
                }

                Text(scoreLabel)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(isValidOutcomeScore ? palette.foregroundColor : Color.neutral3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: scoreWidth, alignment: .center)

                Text(holesLabel)
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: thruWidth, alignment: .center)
            }
        }
        .buttonStyle(.plain)
    }

    private var isValidOutcomeScore: Bool {
        row.scoreCompleteness?.isComplete ?? true
    }

    private var scoreLabel: String {
        guard isValidOutcomeScore else { return "—" }
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

    private var holesLabel: String {
        guard isValidOutcomeScore else {
            guard let status = row.scoreCompleteness else { return "—" }
            return "\(status.scoredCount)/\(status.requiredCount)"
        }
        return "\(row.thru)"
    }

    private var handicapLabel: String {
        if let label = row.sharedHandicapLabel, label.isPopulated {
            return label
        }
        return "\(row.participant.adjustedHandicap)"
    }

    private var fullParticipantName: String {
        row.participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var markedFullParticipantName: String {
        row.participant.isSubstitute ? "\(fullParticipantName)*" : fullParticipantName
    }

    private var displayName: String {
        if row.isSharedScoreUnit {
            return markedFullParticipantName
        }
        if let teamName = row.teamName, teamName.isPopulated {
            return teamName
        }
        return markedFullParticipantName
    }

    private var compactDisplayName: String {
        if row.isSharedScoreUnit {
            return compactParticipantName
        }
        if let teamName = row.teamName, teamName.isPopulated {
            return teamName
        }
        return compactParticipantName
    }

    private var compactParticipantName: String {
        let given = row.participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = row.participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard given.isPopulated || family.isPopulated else { return fullParticipantName }
        let compact: String
        switch nameDisplayFormat {
        case .firstInitialLastName:
            if let g = given.first {
                compact = "\(g). \(family)"
            } else {
                compact = family
            }
        case .firstNameLastInitial:
            if let f = family.first {
                compact = "\(given) \(f)."
            } else {
                compact = given
            }
        }
        return row.participant.isSubstitute ? "\(compact)*" : compact
    }
}
