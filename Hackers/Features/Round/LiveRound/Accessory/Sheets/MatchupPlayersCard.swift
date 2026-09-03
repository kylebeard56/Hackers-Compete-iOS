//
//  MatchupPlayersCard.swift
//  Hackers
//

import SwiftUI

struct MatchupPlayersCard: View {
    let sides: [MatchupResultPresentation.Side]
    let scoreBasis: ScoreBasis
    let isPointsFormat: Bool
    let isFinal: Bool
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let onSelectParticipant: (RoundParticipant) -> Void

    private var includesNonScoringSubstitute: Bool {
        !viewModel.snapshot.configuration.substitutesScore
            && sides.flatMap(\.participants).contains(where: \.isSubstitute)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Players")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text("Tap a player for scorecard, scoring trend, projection, and radar")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(sides) { side in
                let accent = side.accentColor ?? palette.foregroundColor
                let finalStatuses = isFinal
                    ? viewModel.finalMatchupCountingStatuses(
                        for: side,
                        basis: scoreBasis,
                        isPointsFormat: isPointsFormat
                    )
                    : [:]
                let participants = side.participants.sorted {
                    if ($0.teeOrder ?? Int.max) != ($1.teeOrder ?? Int.max) {
                        return ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max)
                    }
                    return $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
                }

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(side.title.uppercased())
                            .fontStyle(kFontName, size: 11, weight: .semibold)
                            .foregroundStyle(Color.neutral2)
                        Spacer(minLength: 0)
                        if let scope = side.countingScope, side.teamScoringMode != .all {
                            Text(scope == .perRound ? "ROUND TOTAL" : "BY HOLE")
                                .fontStyle(kFontName, size: 9, weight: .medium)
                                .foregroundStyle(Color.neutral)
                        }
                    }
                    .padding(.bottom, 4)

                    ForEach(participants) { participant in
                        let isActive = side.isParticipantActive(participant)
                        let finalStatus = finalStatuses[participant.id]
                        let isHighlighted = finalStatus == .tiedAtCutoff
                            || finalStatus == .counted
                            || (!isFinal && isActive)
                        let gross = viewModel.scoreToParLabel(
                            viewModel.scoreToPar(for: participant, basis: .gross)
                        )
                        let net = viewModel.scoreToParLabel(
                            viewModel.scoreToPar(for: participant, basis: .net)
                        )
                        let holes = viewModel.holesPlayedCount(for: participant.id)

                        Button {
                            onSelectParticipant(participant)
                        } label: {
                            HStack(spacing: 12) {
                                PlayerAvatarView(
                                    initials: participant.name.initials,
                                    size: 40,
                                    fillColor: accent.opacity(0.22),
                                    glassTint: accent.opacity(0.14)
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text(participant.name.fullName)
                                            .fontStyle(kFontName, size: 14, weight: .semibold)
                                            .foregroundStyle(
                                                isHighlighted ? palette.foregroundColor : Color.neutral2
                                            )
                                            .lineLimit(1)

                                        if participant.isSubstitute {
                                            Text("*")
                                                .fontStyle(kFontName, size: 14, weight: .semibold)
                                                .foregroundStyle(Color.neutral2)
                                        }

                                        if side.countsByRoundTotal && !isFinal {
                                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isActive ? accent : Color.neutral2)
                                                .accessibilityLabel(
                                                    isActive ? "Currently counting" : "Outside the current counting group"
                                                )
                                        }
                                    }

                                    Text(playerDetail(holes: holes, gross: gross, net: net))
                                        .fontStyle(kFontName, size: 11, weight: .regular)
                                        .foregroundStyle(Color.neutral)
                                        .lineLimit(1)

                                    if let finalStatus {
                                        countingStatusBadge(finalStatus, accent: accent)
                                    }
                                }

                                Spacer(minLength: 8)

                                Text(scoreBasis == .net ? net : gross)
                                    .fontStyle(kFontName, size: 17, weight: .semibold)
                                    .foregroundStyle(isHighlighted ? accent : Color.neutral2)
                                    .contentTransition(.numericText())

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.neutral2)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows player insights and scorecard")

                        if participant.id != participants.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }

            if includesNonScoringSubstitute {
                Text("* Substitute players don’t count toward competitive scoring")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasFinalCutoffTie {
                Label(
                    "Equal cutoff scores share the position; the matchup total uses the configured number of scoring slots.",
                    systemImage: "equal.circle"
                )
                .fontStyle(kFontName, size: 11, weight: .regular)
                .foregroundStyle(Color.neutral)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    private func playerDetail(holes: Int, gross: String, net: String) -> String {
        if viewModel.handicapsEnabled {
            return "Thru \(holes) · Gross \(gross) · Net \(net)"
        }
        return "Thru \(holes) · Gross \(gross)"
    }

    private var hasFinalCutoffTie: Bool {
        guard isFinal else { return false }
        return sides.contains { side in
            viewModel.finalMatchupCountingStatuses(
                for: side,
                basis: scoreBasis,
                isPointsFormat: isPointsFormat
            ).values.contains(.tiedAtCutoff)
        }
    }

    private func countingStatusBadge(
        _ status: MatchupCountingDisplayStatus,
        accent: Color
    ) -> some View {
        let color: Color = switch status {
        case .counted: accent
        case .tiedAtCutoff: .systemOrange
        case .notCounted: Color.neutral2
        }

        return Text(status.label.uppercased())
            .fontStyle(kFontName, size: 9, weight: .semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}
