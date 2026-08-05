//
//  SeriesRoundCardSummaryView.swift
//  Hackers
//

import SwiftUI

struct SeriesRoundCardSummaryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: SeriesRoundCardViewState
    let palette: DesignPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            context

            Divider()

            competitionSummary

            if state.viewer?.label != nil || state.participantCountLabel != nil {
                Divider()
                participation
            }

            if state.isAdjusted || state.setupDiffers {
                adjustmentChips
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                statusChip

                Text(state.title)
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            Color.clear.frame(width: 40, height: 40)
        }
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(state.courseName) \(kDot) \(state.scheduleLabel)")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
                .lineLimit(2)

            Text(formatContextLabel)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var competitionSummary: some View {
        if state.sides.isPopulated {
            VStack(spacing: 12) {
                ForEach(state.sides) { side in
                    sideSummary(side)
                }
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: state.presentationKind == .leaderboard ? "list.number" : "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
                    .frame(width: 40, height: 40)
                    .background(Color.accentGreen.opacity(colorScheme.translucent))
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.presentationKind == .leaderboard ? "Field leaderboard" : "Shared score")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text(state.scoringRuleLabel)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func sideSummary(_ side: SeriesRoundCardSide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(side.title)
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(sideForeground(side))
                            .lineLimit(2)

                        if let resultLabel = resultLabel(side.result) {
                            Text(resultLabel.uppercased())
                                .fontStyle(kFontName, size: 10, weight: .semibold)
                                .foregroundStyle(sideForeground(side))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(sideForeground(side).opacity(0.12))
                                .clipShape(.capsule)
                        }
                    }

                    if let subtitle = side.subtitle, subtitle.isPopulated {
                        Text(subtitle)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                Text(side.scoreLabel ?? "—")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(sideForeground(side))
                    .monospacedDigit()
                    .accessibilityLabel("Score \(side.scoreLabel ?? "not available")")
            }

            if side.contributors.isPopulated {
                VStack(spacing: 0) {
                    ForEach(Array(side.contributors.enumerated()), id: \.element.id) { index, contributor in
                        contributorRow(contributor)
                        if index < side.contributors.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(palette.cardEmbeddedRowBackground)
                .clipShape(.rect(cornerRadius: 10))
            }

            if side.hiddenContributorCount > 0 {
                Text("+\(side.hiddenContributorCount) more in full results")
                    .fontStyle(kFontName, size: 11, weight: .medium)
                    .foregroundStyle(Color.neutral)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardEmbeddedRowBackground.opacity(0.55))
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }

    private func contributorRow(_ contributor: SeriesRoundCardContributor) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(contributor.name)
                        .fontStyle(kFontName, size: 13, weight: contributor.isViewer ? .semibold : .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                    if contributor.isViewer {
                        Text("YOU")
                            .fontStyle(kFontName, size: 9, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                    }
                    if contributor.isSubstitute {
                        Text("SUB")
                            .fontStyle(kFontName, size: 9, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                    }
                }

                if let roleLabel = contributorRoleLabel(contributor.role) {
                    Text(roleLabel)
                        .fontStyle(kFontName, size: 10, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let handicap = contributor.handicapLabel {
                metric(label: "HCP", value: handicap)
            }
            if let score = contributor.scoreLabel {
                metric(label: state.scoreBasis == .net ? "NET" : "GROSS", value: score)
            }
            if let progress = contributor.progressLabel {
                metric(label: "THRU", value: progress)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .fontStyle(kFontName, size: 9, weight: .medium)
                .foregroundStyle(Color.neutral)
            Text(value)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .monospacedDigit()
        }
        .frame(minWidth: 40, alignment: .trailing)
    }

    private var participation: some View {
        HStack(spacing: 8) {
            if let label = state.viewer?.label {
                Label(label, systemImage: viewerIcon)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(viewerTint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(viewerTint.opacity(0.12))
                    .clipShape(.capsule)
            }

            Spacer(minLength: 0)

            if let participantCountLabel = state.participantCountLabel {
                Text(participantCountLabel)
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
            }
        }
    }

    private var adjustmentChips: some View {
        HStack(spacing: 8) {
            if state.isAdjusted {
                detailChip("Adjusted")
            }
            if state.setupDiffers {
                detailChip("Setup differs")
            }
        }
    }

    private func detailChip(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 10, weight: .semibold)
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12))
            .clipShape(.capsule)
    }

    private var statusChip: some View {
        Text(state.statusLabel.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(statusTint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusTint.opacity(0.12))
            .clipShape(.capsule)
            .accessibilityLabel(state.statusLabel)
    }

    private var formatContextLabel: String {
        var values = [state.formatLabel]
        values.append(state.scoreBasis == .net ? "Net" : "Gross")
        values.append(state.scoringRuleLabel)
        return values.joined(separator: " \(kDot) ")
    }

    private var statusTint: Color {
        switch state.lifecycle {
        case .upcoming: return .neutral
        case .lobby: return .accentGreen
        case .live: return .accentPurple
        case .completed, .finalized: return .accentYellow
        case .needsReview: return .orange
        case .canceled, .archived: return .systemError
        }
    }

    private var viewerTint: Color {
        switch state.viewer?.participation {
        case .declined, .didNotPlay: return .systemError
        case .pending, .unknown, .none: return .neutral
        case .playing, .played: return .accentGreen
        }
    }

    private var viewerIcon: String {
        switch state.viewer?.participation {
        case .declined, .didNotPlay: return "person.slash"
        case .pending, .unknown, .none: return "questionmark.circle"
        case .playing, .played: return "person.fill.checkmark"
        }
    }

    private func sideForeground(_ side: SeriesRoundCardSide) -> Color {
        switch side.result {
        case .winner, .leading: return .accentGreen
        case .loser, .trailing: return .systemError
        case .tied: return .accentYellow
        case .none: return palette.foregroundColor
        }
    }

    private func resultLabel(_ result: SeriesRoundCardResult) -> String? {
        switch result {
        case .leading: return "Leading"
        case .trailing: return "Trailing"
        case .winner: return "Winner"
        case .loser: return nil
        case .tied: return "Tie"
        case .none: return nil
        }
    }

    private func contributorRoleLabel(_ role: SeriesRoundCardContributorRole) -> String? {
        switch role {
        case .selectedForRound: return "Counts toward team score"
        case .variablePerHole: return "Leaders · contributors vary by hole"
        case .allScoresCount: return "All scores count"
        case .leaderOnly: return nil
        case .sharedScoreMember: return "Shared score"
        }
    }
}
