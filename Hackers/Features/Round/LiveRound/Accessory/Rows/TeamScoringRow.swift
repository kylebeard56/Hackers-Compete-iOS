//
//  TeamScoringRow.swift
//  Hackers
//
//  Created by Kyle Beard on 3/26/26.
//

import SwiftUI

/// Single score-entry row for an entire team (Captain's Choice / shared-score formats).
struct TeamScoringRow: View {
    @Environment(\.colorScheme) var colorScheme
    @CappedScaledMetric(relativeTo: .body) var pillSize: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 12
    @CappedScaledMetric(relativeTo: .body) var buttonPaddingH: CGFloat = 16
    @CappedScaledMetric(relativeTo: .body) var buttonPaddingV: CGFloat = 8

    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel
    let team: RoundTeam
    let participants: [RoundParticipant]
    let holeNumber: Int
    var onEnterScoreTap: (() -> Void)? = nil

    private var hole: Hole? { viewModel.hole(for: holeNumber) }
    private var holePar: Int { hole?.par ?? 4 }

    private var gross: Int? {
        viewModel.teamGrossStrokes(teamID: team.id, holeNumber: holeNumber)
    }

    private var scoreInputValue: Int? {
        viewModel.scoringUnitScoreInputValue(scoringUnitID: team.id, holeNumber: holeNumber)
    }

    private var teamScoreToPar: Int {
        viewModel.teamScoreToPar(teamID: team.id, basis: viewModel.scoreBasis)
    }

    private var memberNames: String {
        participants
            .map { viewModel.formatDisplayName(for: $0) }
            .joined(separator: ", ")
    }

    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }

    var body: some View {
        HStack(alignment: .center, spacing: rowSpacing) {
            scorePill

            Button {
                Haptics.fire(.light)
                onEnterScoreTap?()
            } label: {
                HStack(alignment: .center, spacing: rowSpacing) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .fontStyle(kFontName, size: 17, weight: .semibold)
                            .foregroundStyle(team.displaySwatchColor ?? effectiveAccent)
                            .lineLimit(1)

                        Text(memberNames)
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    enterScoreContent
                }
            }
        }
    }

    @ViewBuilder
    private var scorePill: some View {
        let scp = teamScoreToPar
        let isHoleScored = gross != nil
        let badgeColor = team.displaySwatchColor ?? effectiveAccent

        ZStack(alignment: .topTrailing) {
            HStack(spacing: 1) {
                if scp < 0 {
                    Text("-")
                        .fontStyle(kFontName, size: 12, weight: .bold)
                        .foregroundStyle(palette.foregroundColor)
                } else if scp > 0 {
                    Text("+")
                        .fontStyle(kFontName, size: 12, weight: .bold)
                        .foregroundStyle(palette.foregroundColor)
                }

                Text(viewModel.formattedScoreToPar(abs(scp)))
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(width: pillSize, height: pillSize)
            .glassCardEffect(
                shape: .circle,
                interactive: false,
                tint: palette.whiteGlassButtonColor,
                shadowOpacity: 0
            )
            .whiteGlassCardShadow(color: palette.shadowColor)

            if isHoleScored {
                Icon(name: "f058", size: 14, weight: .solid)
                    .foregroundStyle(badgeColor)
                    .offset(x: 2, y: -2)
            }
        }
    }

    @ViewBuilder
    private var enterScoreContent: some View {
        let isScored = gross != nil
        let color = team.displaySwatchColor ?? effectiveAccent
        let label = isScored
            ? (viewModel.isFriendlyScoreInputMode
                ? viewModel.friendlyScoreLabel(relativeToPar: scoreInputValue ?? 0, par: holePar, format: .short)
                : viewModel.friendlyScoreLabel(strokes: gross ?? 6, par: holePar, format: .shortWithStrokes))
            : "Enter score"
        let tint = isScored ? color.opacity(colorScheme.translucent(0.10, 0.14)) : palette.whiteGlassButtonColor
        let foreground: Color = isScored ? color : palette.foregroundColor

        Text(label)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(foreground)
            .padding(.horizontal, buttonPaddingH)
            .padding(.vertical, buttonPaddingV)
            .glassCardEffect(cornerRadius: 12, interactive: false, tint: tint, shadowOpacity: 0)
            .whiteGlassCardShadow(color: isScored ? Color.clear : palette.shadowColor)
    }
}

/// Shared score-entry row for partnership or tee-group score owners.
struct SharedScoreOwnerRow: View {
    @Environment(\.colorScheme) var colorScheme
    @CappedScaledMetric(relativeTo: .body) var pillSize: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 12
    @CappedScaledMetric(relativeTo: .body) var avatarSize: CGFloat = 30
    @CappedScaledMetric(relativeTo: .body) var buttonPaddingH: CGFloat = 16
    @CappedScaledMetric(relativeTo: .body) var buttonPaddingV: CGFloat = 8

    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel
    let title: String
    let subtitle: String?
    let participants: [RoundParticipant]
    let holeNumber: Int
    let scoringUnitID: String
    let accentColor: Color?
    var onEnterScoreTap: (() -> Void)? = nil

    private var hole: Hole? { viewModel.hole(for: holeNumber) }
    private var holePar: Int { hole?.par ?? 4 }

    private var gross: Int? {
        viewModel.scoringUnitGrossStrokes(scoringUnitID: scoringUnitID, holeNumber: holeNumber)
    }

    private var scoreInputValue: Int? {
        viewModel.scoringUnitScoreInputValue(scoringUnitID: scoringUnitID, holeNumber: holeNumber)
    }

    private var ownerScoreToPar: Int {
        viewModel.scoringUnitScoreToPar(scoringUnitID: scoringUnitID, basis: viewModel.scoreBasis)
    }

    private var effectiveAccent: Color {
        accentColor
        ?? (viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color)
    }

    var body: some View {
        HStack(alignment: .center, spacing: rowSpacing) {
            scorePill

            Button {
                Haptics.fire(.light)
                onEnterScoreTap?()
            } label: {
                HStack(alignment: .center, spacing: rowSpacing) {
                    ownerIdentity

                    Spacer(minLength: 0)

                    enterScoreContent
                }
            }
        }
    }

    private var ownerIdentity: some View {
        HStack(alignment: .center, spacing: 10) {
            memberAvatarStrip

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(effectiveAccent)
                    .lineLimit(1)

                if let subtitle, subtitle.isPopulated {
                    Text(subtitleText(base: subtitle))
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(2)
                } else if let handicapLabel = viewModel.scoringUnitHandicapLabel(scoringUnitID: scoringUnitID) {
                    Text(handicapLabel)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                }
            }
        }
    }

    private func subtitleText(base: String) -> String {
        guard let handicapLabel = viewModel.scoringUnitHandicapLabel(scoringUnitID: scoringUnitID) else {
            return base
        }
        return "\(base) - \(handicapLabel)"
    }

    private var memberAvatarStrip: some View {
        let visibleParticipants = Array(participants.prefix(4))

        return HStack(spacing: -10) {
            ForEach(Array(visibleParticipants.enumerated()), id: \.element.id) { index, participant in
                PlayerAvatarView(
                    initials: participant.name.initials,
                    size: avatarSize,
                    fillColor: viewModel.teamColor(for: participant)?.opacity(0.8),
                    glassTint: Color.neutral6,
                    initialsColor: viewModel.teamColor(for: participant) == nil ? palette.foregroundColor : .white
                )
                .overlay {
                    Circle()
                        .stroke(palette.backgroundColor, lineWidth: 2)
                }
                .zIndex(Double(visibleParticipants.count - index))
            }

            if participants.count > visibleParticipants.count {
                Text("+\(participants.count - visibleParticipants.count)")
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .glassCardEffect(shape: Capsule(), interactive: false, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private var scorePill: some View {
        let scp = ownerScoreToPar
        let isHoleScored = gross != nil

        ZStack(alignment: .topTrailing) {
            HStack(spacing: 1) {
                if scp < 0 {
                    Text("-")
                        .fontStyle(kFontName, size: 12, weight: .bold)
                        .foregroundStyle(palette.foregroundColor)
                } else if scp > 0 {
                    Text("+")
                        .fontStyle(kFontName, size: 12, weight: .bold)
                        .foregroundStyle(palette.foregroundColor)
                }

                Text(viewModel.formattedScoreToPar(abs(scp)))
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(width: pillSize, height: pillSize)
            .glassCardEffect(
                shape: .circle,
                interactive: false,
                tint: palette.whiteGlassButtonColor,
                shadowOpacity: 0
            )
            .whiteGlassCardShadow(color: palette.shadowColor)

            if isHoleScored {
                Icon(name: "f058", size: 14, weight: .solid)
                    .foregroundStyle(effectiveAccent)
                    .offset(x: 2, y: -2)
            }
        }
    }

    @ViewBuilder
    private var enterScoreContent: some View {
        let isScored = gross != nil
        let label = isScored
            ? (viewModel.isFriendlyScoreInputMode
                ? viewModel.friendlyScoreLabel(relativeToPar: scoreInputValue ?? 0, par: holePar, format: .short)
                : viewModel.friendlyScoreLabel(strokes: gross ?? 6, par: holePar, format: .shortWithStrokes))
            : "Enter score"
        let tint = isScored ? effectiveAccent.opacity(colorScheme.translucent(0.10, 0.14)) : palette.whiteGlassButtonColor
        let foreground: Color = isScored ? effectiveAccent : palette.foregroundColor

        Text(label)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(foreground)
            .padding(.horizontal, buttonPaddingH)
            .padding(.vertical, buttonPaddingV)
            .glassCardEffect(cornerRadius: 12, interactive: false, tint: tint, shadowOpacity: 0)
            .whiteGlassCardShadow(color: isScored ? Color.clear : palette.shadowColor)
    }
}
