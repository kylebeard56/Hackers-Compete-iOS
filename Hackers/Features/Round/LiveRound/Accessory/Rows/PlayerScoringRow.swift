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

    /// Intercepts name/handicap taps. When nil, opens the full scorecard. Score pill always opens full scorecard.
    var onRowTap: ((RoundParticipant) -> Void)? = nil
    /// Intercepts the "Enter score" button tap. When nil, opens `LiveHoleScoringView`.
    var onEnterScoreTap: ((RoundParticipant) -> Void)? = nil

    private var hole: Hole? { viewModel.hole(for: holeNumber) }
    private var holePar: Int { hole?.par ?? 4 }
    
    private var gross: Int? {
        viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber)
    }

    private var scoreInputValue: Int? {
        viewModel.scoreInputValue(for: participant.id, holeNumber: holeNumber)
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
    private var presenceStatus: RoundParticipantPresenceStatus {
        viewModel.effectivePresenceStatus(for: participant)
    }
    private var canScoreParticipant: Bool { viewModel.isPresenceActive(participant) }
    private var canEditPresence: Bool { viewModel.canEditPresence(participant: participant) }
    private var nameColor: Color {
        canScoreParticipant ? palette.foregroundColor : Color.neutral
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
            if canScoreParticipant {
                Button {
                    Haptics.fire(.light)
                    viewModel.presentedParticipant = participant
                } label: {
                    scorePill
                }
            } else {
                scorePill
                    .opacity(presenceStatus == .noShow ? 0.55 : 0.7)
            }

            if canScoreParticipant {
                Button {
                    Haptics.fire(.light)
                    if let onRowTap { onRowTap(participant) }
                    else if let onEnterScoreTap { onEnterScoreTap(participant) }
                    else {
                        let s = ScoringSession(participant: participant, holeNumber: holeNumber)
                        viewModel.presentedScoringSession = s
                    }
                } label: {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .opacity(presenceStatus == .noShow ? 0.82 : 1)
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
    private var handicapDots: some View {
        let teamColor = viewModel.teamColor(for: participant)
        let dotColor: Color = canScoreParticipant
            ? ((requiresTeams ? teamColor : nil) ?? effectiveAccent)
            : Color.neutral3
        
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
            
            if let net, let gross, net != gross {
                Text("Net \(net)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(canScoreParticipant ? ((requiresTeams ? teamColor : nil) ?? effectiveAccent) : Color.neutral2)
            }
        }
    }

    @ViewBuilder
    private var enterScoreContent: some View {
        let isScored = gross.exists
        let color = (viewModel.teamColor(for: participant) ?? effectiveAccent)
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

    private var rowContent: some View {
        HStack(alignment: .center, spacing: rowSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                LiveRoundAdaptiveNameText(
                    name: participant.name,
                    format: viewModel.nameDisplayFormat,
                    fontSize: 17,
                    weight: .semibold,
                    color: nameColor
                )

                if useHandicaps {
                    handicapDots
                } else if presenceStatus == .unconfirmed {
                    Text("Waiting on status")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                } else if presenceStatus == .noShow {
                    Text("Not here for this round")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                }
            }

            Spacer(minLength: 0)

            trailingControl
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch presenceStatus {
        case .active:
            enterScoreContent
        case .unconfirmed:
            if canEditPresence {
                presenceMenuButton(title: "RSVP", tint: palette.whiteGlassButtonColor, foreground: palette.foregroundColor)
            } else {
                statusChip(title: "RSVP", tint: palette.whiteGlassButtonColor, foreground: palette.foregroundColor)
            }
        case .noShow:
            if canEditPresence {
                presenceMenuButton(title: "Not here", tint: Color.neutral6.opacity(colorScheme.translucent(0.14, 0.18)), foreground: Color.neutral2)
            } else {
                statusChip(title: "Not here", tint: Color.neutral6.opacity(colorScheme.translucent(0.14, 0.18)), foreground: Color.neutral2)
            }
        }
    }

    private func presenceMenuButton(title: String, tint: Color, foreground: Color) -> some View {
        Menu {
            if presenceStatus != .active {
                Button {
                    Task { await viewModel.markParticipantPlaying(participant) }
                } label: {
                    Label("They're here", systemImage: "checkmark.circle")
                }
            }

            if presenceStatus != .noShow {
                Button {
                    Task { await viewModel.markParticipantNoShow(participant) }
                } label: {
                    Label("Not here", systemImage: "person.crop.circle.badge.xmark")
                }
            }

            if viewModel.canResetPresenceToUnconfirmed(participant: participant),
               presenceStatus != .unconfirmed {
                Button {
                    Task { await viewModel.resetParticipantToUnconfirmed(participant) }
                } label: {
                    Label("Set back to unconfirmed", systemImage: "questionmark.circle")
                }
            }
        } label: {
            statusChip(title: title, tint: tint, foreground: foreground)
        }
    }

    private func statusChip(title: String, tint: Color, foreground: Color) -> some View {
        Text(title)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(foreground)
            .padding(.horizontal, buttonPaddingH)
            .padding(.vertical, buttonPaddingV)
            .glassCardEffect(cornerRadius: 12, interactive: false, tint: tint, shadowOpacity: 0)
            .whiteGlassCardShadow(color: Color.clear)
    }
}

private struct AccentPressStyle: ButtonStyle {
    let accentColor: Color
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accentColor.opacity(configuration.isPressed ? 0.15 : 0))
            }
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
        //.glassCardEffect()
        //.padding(16)
        //.background(palette.backgroundColor)
    }
}
