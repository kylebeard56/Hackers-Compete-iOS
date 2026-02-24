//
//  PlayerScoringRow.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct PlayerScoringRow: View {
    @Environment(\.colorScheme) var colorScheme
    @CappedScaledMetric(relativeTo: .body)    var pillSize: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body)    var activePillSize: CGFloat = 52
    @CappedScaledMetric(relativeTo: .body)    var rowSpacing: CGFloat = 12
    @CappedScaledMetric(relativeTo: .caption) var dotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body)    var buttonPaddingH: CGFloat = 16
    @CappedScaledMetric(relativeTo: .body)    var buttonPaddingV: CGFloat = 8
    @CappedScaledMetric(relativeTo: .caption) var badgeSize: CGFloat = 18

    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    let holeNumber: Int
    var requiresTeams: Bool
    /// When true: hides the "Enter score" button, grows the row, and shows active highlight.
    var isActive: Bool = false
    /// When true: we are in high-detent scoring mode. Inactive rows recede slightly.
    var isInScoringMode: Bool = false

    /// Intercepts score pill and name taps. When nil, opens the full scorecard.
    var onRowTap: ((RoundParticipant) -> Void)? = nil
    /// Intercepts the "Enter score" button tap. When nil, opens `LiveHoleScoringView`.
    var onEnterScoreTap: ((RoundParticipant) -> Void)? = nil

    private var effectivePillSize: CGFloat { isActive ? activePillSize : pillSize }
    private var effectiveScoreTextSize: CGFloat { isActive ? 24 : 20 }
    
    private var hole: Hole? { viewModel.hole(for: holeNumber) }
    private var holePar: Int { hole?.par ?? 4 }
    
    private var gross: Int? {
        viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber)
    }
    
    private var strokesReceived: Int {
        viewModel.strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
    }
    
    private var net: Int? {
        viewModel.netStrokesOnHole(participant: participant, holeNumber: holeNumber)
    }
    
    private var scoreToParLabel: String {
        viewModel.formattedScoreToPar(viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis))
    }

    private var useHandicaps: Bool { viewModel.snapshot.round.configuration.useHandicaps }
    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }
    
//    private var quickScores: [Int] {
//        // birdie, par, bogey / double, triple
//        [holePar - 1, holePar, holePar + 1, holePar + 2, holePar + 3]
//    }
    
    private var grid: [GridItem] {
        [
            GridItem(.fixed(32), spacing: 6),
            GridItem(.fixed(32), spacing: 6),
            GridItem(.fixed(32), spacing: 6)
        ]
    }
    
    private var glassButtonColor: Color {
        palette.glassButtonColor
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: rowSpacing) {
            Button {
                Haptics.fire(.light)
                if let onRowTap { onRowTap(participant) }
                else { viewModel.presentedParticipant = participant }
            } label: {
                scorePill
            }

            Button {
                Haptics.fire(.light)
                if let onRowTap { onRowTap(participant) }
                else { viewModel.presentedParticipant = participant }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    if isActive {
                        Text(participant.name.fullName)
                            .fontStyle(kFontName, size: 24, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            Text(participant.name.fullName)
                                .fontStyle(kFontName, size: 17, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .layoutPriority(1)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Text(compactParticipantName)
                                .fontStyle(kFontName, size: 17, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .lineLimit(1)
                        }
                    }

                    if useHandicaps {
                        handicapDisplay
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !isActive {
                enterScoreButton
            }
        }
        .padding(.vertical, isActive ? 10 : 0)
        .padding(.horizontal, isActive ? 10 : 0)
        .background {
            if isActive {
                Color.clear
                    .glassCardEffect(
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                        interactive: false,
                        tint: effectiveAccent.opacity(0.18),
                        shadowOpacity: 0.14
                    )
            }
        }
        .opacity(isInScoringMode && !isActive ? 0.75 : 1.0)
        .scaleEffect(isInScoringMode && !isActive ? 0.97 : 1.0, anchor: .leading)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isActive)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isInScoringMode)
    }
    
    @ViewBuilder
    private var scorePill: some View {
        let scp = viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)
        let isHoleScored = gross != nil
        let badgeColor = viewModel.teamColor(for: participant) ?? effectiveAccent

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
                    .fontStyle(kFontName, size: effectiveScoreTextSize, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(width: effectivePillSize, height: effectivePillSize)
            .glassCardEffect(shape: .circle, interactive: false, shadowOpacity: 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isActive)

            if isHoleScored {
                Icon(name: "f058", size: 14, weight: .solid)
                    .foregroundStyle(badgeColor)
                    .offset(x: 2, y: -2)
            }
        }
    }
    
    @ViewBuilder
    private var handicapDisplay: some View {
        let teamColor = viewModel.teamColor(for: participant)
        let dotColor: Color = requiresTeams ? (teamColor ?? .neutral2) : palette.foregroundColor

        if isActive && strokesReceived > 0 {
            let label = strokesReceived == 1 ? "1 stroke" : "\(strokesReceived) strokes"
            Text(label)
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(dotColor)
                .transition(.opacity)
        } else if !isActive {
            handicapDots
                .transition(.opacity)
        }
        // isActive && strokesReceived == 0 → nothing shown
    }

    @ViewBuilder
    private var handicapDots: some View {
        let teamColor = viewModel.teamColor(for: participant)
        let dotColor: Color = requiresTeams ? (teamColor ?? .neutral2) : palette.foregroundColor
        
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        dotColor,
                        lineWidth: index < strokesReceived ? 0 : 1
                    )
                    .background(
                        Circle()
                            .fill(index < strokesReceived ? dotColor : .clear)
                    )
                    .frame(width: dotSize, height: dotSize)
            }
        }

//        Group {
//            if strokesReceived > 0 {
//                let teamColor = viewModel.teamColor(for: participant)
//                let dotColor: Color = requiresTeams ? (teamColor ?? Color.neutral2) : Color.neutral3
//                
//                HStack(spacing: 3) {
//                    ForEach(0..<strokesReceived, id: \.self) { _ in
//                        Circle()
//                            .fill(dotColor)
//                            .frame(width: 5, height: 5)
//                    }
//                }
//            } else {
//                EmptyView()
//            }
//        }
    }
    
//    @ViewBuilder
//    private func scoreButton(value: Int) -> some View {
//        let selected = gross == value
//        let selectedTint = viewModel.teamColor(for: participant) ?? palette.foregroundColor
//        let background = selected ? selectedTint : palette.buttonColor
//        let foreground = selected ? palette.buttonColor : palette.foregroundColor
//        
//        Button {
//            Haptics.fire(.light)
//            Task {
//                if selected {
//                    await viewModel.clearScore(participant: participant)
//                } else {
//                    await viewModel.setQuickScore(participant: participant, strokes: value)
//                }
//            }
//        } label: {
//            if selected {
//                Text("\(value)")
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .background(background)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            } else {
//                Text("\(value)")
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .glassCardEffect(cornerRadius: 10, tint: background)
//            }
//        }
//    }
    
//    @ViewBuilder
//    private var customButton: some View {
//        let selected = gross.exists && !quickScores.contains(gross ?? 0)
//        let label = selected ? "\(gross ?? 0)" : "+"
//        let selectedTint = viewModel.teamColor(for: participant) ?? palette.foregroundColor
//        let background = selected ? selectedTint : Color.clear
//        let foreground = selected ? palette.buttonColor : palette.foregroundColor
//        
//        Button {
//            viewModel.promptCustomScore(for: participant, holeNumber: holeNumber)
//        } label: {
//            if selected {
//                Text(label)
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .background(background)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            } else {
//                Text(label)
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .glassCardEffect(cornerRadius: 10, tint: background)
//            }
//        }
//    }

    private var compactParticipantName: String {
        viewModel.formatDisplayName(for: participant)
    }

    private var enterScoreButton: some View {
        let isScored = gross.exists
        let color = (viewModel.teamColor(for: participant) ?? effectiveAccent)
        let label = isScored
        ? viewModel.friendlyScoreLabel(strokes: gross ?? 6, par: holePar, format: LiveRoundViewModel.FriendlyScoreFormat.shortWithStrokes)
        : "Enter score"
        let tint = isScored ? color.opacity(colorScheme.translucent(0.10, 0.14)) : nil
        let foreground: Color = isScored ? color : palette.foregroundColor

        return Button {
            Haptics.fire(.light)
            if let onEnterScoreTap {
                onEnterScoreTap(participant)
            } else {
                viewModel.presentedScoringSession = ScoringSession(participant: participant, holeNumber: holeNumber)
            }
        } label: {
            Text(label)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, buttonPaddingH)
        .padding(.vertical, buttonPaddingV)
        .glassCardEffect(cornerRadius: 12, interactive: false, tint: tint, shadowOpacity: 0)
    }
}

#Preview("Player Scoring Row") {
    ZStack {
        GolfTopology()
            .frame(width: UIScreen.main.bounds.width)
        PlayerScoringRowPreview()
    }
}

private struct PlayerScoringRowPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant
    private let requiresTeams: Bool
    
    init() {
        let snapshot = MockLiveRound2v2.snapshot
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id
        
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        
        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first!
        requiresTeams = snapshot.requiresTeams
    }
    
    var body: some View {
        let palette = DesignPalette(theme: .primary, scheme: colorScheme)
        
        return PlayerScoringRow(
            palette: palette,
            viewModel: viewModel,
            participant: participant,
            holeNumber: viewModel.currentHoleNumber,
            requiresTeams: requiresTeams
        )
        .padding(16)
        .glassCardEffect()
        .padding(16)
        //.background(palette.backgroundColor)
    }
}
