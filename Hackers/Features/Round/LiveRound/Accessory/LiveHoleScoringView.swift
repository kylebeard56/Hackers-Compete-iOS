//
//  LiveHoleScoringView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/4/26.
//

import SwiftUI

struct LiveHoleScoringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @CappedScaledMetric(relativeTo: .body) var playerCircleSize: CGFloat = 56
    @CappedScaledMetric(relativeTo: .caption) var badgeSize: CGFloat = 22
    @CappedScaledMetric(relativeTo: .body) var scoreInputHeight: CGFloat = 130
    @CappedScaledMetric(relativeTo: .caption) var handicapDotSize: CGFloat = 8

    @ObservedObject var viewModel: LiveRoundViewModel
    let initialParticipant: RoundParticipant

    @State private var currentGolferIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?
    @State private var navigationDirection: NavigationDirection = .forward

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private enum NavigationDirection {
        case forward, backward
        
        var edge: Edge {
            switch self {
            case .forward: return .trailing
            case .backward: return .leading
            }
        }
    }

    private var players: [RoundParticipant] {
        let roster = viewModel.teeGroupParticipants
        return roster.isPopulated ? roster : [initialParticipant]
    }

    private var currentGolfer: RoundParticipant {
        players[safe: currentGolferIndex] ?? initialParticipant
    }

    private var hole: Hole? {
        viewModel.hole(for: viewModel.currentHoleNumber, teeID: viewModel.selectedTeeID)
    }

    private var holePar: Int { hole?.par ?? 4 }
    private var holeYards: Int { hole?.yardage ?? 0 }
    private var holeHandicap: Int? { hole?.handicap }

    private var isEditMode: Bool {
        players.isPopulated
        && players.allSatisfy {
            viewModel.grossStrokes(for: $0.id, holeNumber: viewModel.currentHoleNumber) != nil
        }
    }

    private var savedScoreForCurrent: Int? {
        viewModel.grossStrokes(for: currentGolfer.id, holeNumber: viewModel.currentHoleNumber)
    }

    private var isDraftChanged: Bool {
        guard let savedScore else { return false }
        return savedScore != draftScore
    }

    private var scoreOptions: [Int] {
        let minScore = holePar == 4 ? 1 : max(1, holePar - 2)
        let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: holePar)
        let maxScore = max(9, (savedScoreForCurrent ?? 0), configMax)
        return Array(minScore...maxScore)
    }

    private var teamTint: Color {
        viewModel.teamColor(for: currentGolfer) ?? palette.foregroundColor
    }
    
    private var isScored: Bool {
        viewModel.grossStrokes(for: currentGolfer.id, holeNumber: viewModel.currentHoleNumber).exists
    }

    private var netScoreLabel: String? {
        guard viewModel.snapshot.configuration.useHandicaps else { return nil }
        let strokesReceived = viewModel.strokesReceivedOnHole(
            participant: currentGolfer,
            holeNumber: viewModel.currentHoleNumber
        )
        guard strokesReceived > 0 else { return nil }
        let net = max(0, draftScore - strokesReceived)
        return "Net \(net)"
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                NavButton(style: .glass, onTap: { dismiss() })
                    .alignLeading()
                
                holeInfo
                    .alignCenter()
                
                Button {
                    Task { await clearScore() }
                } label: {
                    Text("Clear")
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.systemError)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .glassCardEffect(shape: .capsule)
                }
                .alignTrailing()
                .opacity(isScored ? 1 : 0)
            }
            .padding(.horizontal, 16)
            
            //holeInfo
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                ForEach(players) { player in
                    playerDot(for: player)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 0)
            
            playerName
                .padding(.horizontal, 16)

            scoreInput

            Spacer(minLength: 0)

            ctaSection
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(palette.backgroundColor)
        .onAppear(perform: configureInitialState)
        .onChange(of: currentGolferIndex) {
            syncDraftScore(resetDraft: true)
        }
        .onChange(of: savedScoreForCurrent) { _, newValue in
            syncSavedScore(newValue)
        }
    }
}

private extension LiveHoleScoringView {
    var playerName: some View {
        Text(currentGolfer.name.fullName)
            .fontStyle(kFontName, size: 32, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .id(currentGolfer.id)
            .transition(.asymmetric(
                insertion: .move(edge: navigationDirection.edge).combined(with: .opacity),
                removal: .move(edge: navigationDirection == .forward ? .leading : .trailing).combined(with: .opacity)
            ))
    }
    
    var holeInfo: some View {
        VStack(spacing: 2) {
            Text("Hole \(viewModel.currentHoleNumber)")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            HStack(spacing: 6) {
                Text("Par \(holePar)")
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral)
                
                Dot(size: 3)
                
                Text("\(holeYards) yds")
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral)
                
                if let holeHandicap {
                    Dot(size: 3)
                    
                    Text("\(holeHandicap) HCP")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
    }

    func playerDot(for player: RoundParticipant) -> some View {
        let isCurrent = player.id == currentGolfer.id
        let isScored = viewModel.grossStrokes(for: player.id, holeNumber: viewModel.currentHoleNumber).exists
        let teamColor = viewModel.teamColor(for: player) ?? palette.foregroundColor
        let hasTeams = viewModel.snapshot.requiresTeams
        let useHandicaps = viewModel.snapshot.configuration.useHandicaps
        let strokesReceived = viewModel.strokesReceivedOnHole(
            participant: player,
            holeNumber: viewModel.currentHoleNumber
        )
        
        // Border color for active state
        let activeBorderColor = hasTeams ? teamColor : Color.accentGreen
        
        // Background and text colors based on state
//        let backgroundColor: Color = isScored ? (teamColor ?? Color.accentGreen) : Color.neutral6
//        let initialsColor: Color = isScored ? .white : palette.foregroundColor
        let backgroundColor = Color.neutral6
        let initialsColor = palette.foregroundColor
        
        return VStack(spacing: 6) {
            ZStack {
                // Main circle with background
                Circle()
                    .fill(backgroundColor)
                    .frame(width: playerCircleSize, height: playerCircleSize)
                
                // Initials text
                Text(player.name.initials.uppercased())
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(initialsColor)
                
                // Active state border
                if isCurrent {
                    Circle()
                        .stroke(activeBorderColor, lineWidth: 3)
                        .frame(width: playerCircleSize, height: playerCircleSize)
                }
                
                if isScored {
                    ZStack {
                        Circle()
                            .frame(width: badgeSize, height: badgeSize, alignment: .center)
                            .foregroundStyle(palette.backgroundColor)
                        
                        Icon(name: "f058", size: 16, weight: .solid)
                            .foregroundStyle(teamColor)
                    }
                    .alignTop()
                    .alignTrailing()
                    .padding(.top, -4)
                    .padding(.trailing, -4)
                }
            }
            .frame(width: playerCircleSize, height: playerCircleSize)
            
            if useHandicaps {
                handicapDots(for: player, strokesReceived: strokesReceived)
            }
        }
        .onTapGesture {
            Haptics.fire(.light)
            jumpToPlayer(player)
        }
    }

    @ViewBuilder
    func handicapDots(for player: RoundParticipant, strokesReceived: Int) -> some View {
        let teamColor = viewModel.teamColor(for: player)
        let dotColor: Color = viewModel.snapshot.requiresTeams ? (teamColor ?? .neutral2) : palette.foregroundColor
        
        HStack(spacing: 4) {
            // Replace strokesReceived with 4 if you need empty dots
            ForEach(0..<strokesReceived, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        dotColor,
                        lineWidth: index < strokesReceived ? 0 : 1
                    )
                    .background(
                        Circle()
                            .fill(index < strokesReceived ? dotColor : .clear)
                    )
                    .frame(width: handicapDotSize, height: handicapDotSize)
            }
        }
    }

    var scoreInput: some View {
        let initialScore = savedScoreForCurrent ?? holePar
        
        return VStack(spacing: 16) {
            ZStack {
                scoreSelectionDecoration(strokes: draftScore)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: draftScore)
                
                CarouselNumberPicker(values: scoreOptions, initialValue: initialScore) { newValue in
                    draftScore = newValue
                    Haptics.fire(.light)
                }
                .id(currentGolfer.id) // Force recreation when golfer changes
            }
            .frame(height: scoreInputHeight)

            VStack(spacing: 4) {
                Text(viewModel.friendlyScoreLabel(strokes: draftScore, par: holePar, format: LiveRoundViewModel.FriendlyScoreFormat.full))
                    .fontStyle(kFontName, size: 28, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                if let netLabel = netScoreLabel {
                    Text(netLabel)
                        .fontStyle(kFontName, size: 17, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            }
            .frame(minHeight: 80)
            .id(draftScore)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: draftScore)
        }
    }
    
    @ViewBuilder
    func scoreSelectionDecoration(strokes: Int) -> some View {
        let diff = strokes - holePar
        let strokeColor = Color.neutral3.opacity(0.45)
        let fillColor = Color.neutral3.opacity(0.2)
        let circle: CGFloat = 120
        let square: CGFloat = 120
        
        if diff <= -2 {
            Circle()
                .fill(fillColor)
                .frame(width: circle, height: circle)
        } else if diff == -1 {
            Circle()
                .stroke(strokeColor, lineWidth: 3)
                .frame(width: circle, height: circle)
        } else if diff == 1 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(strokeColor, lineWidth: 3)
                .frame(width: square, height: square)
        } else if diff >= 2 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(fillColor)
                .frame(width: square, height: square)
        }
    }

    var ctaSection: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                title: ctaTitle,
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTapAsync: handleCTA
            )

            Text(footerText)
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(Color.neutral2)
        }
    }

    var ctaTitle: String {
        if isEditMode {
            return isDraftChanged ? "Confirm" : "Done"
        }

        if currentGolferIndex >= players.count - 1 {
            return "Complete Hole"
        }

        if savedScore == nil {
            return "Confirm & Next"
        }

        return isDraftChanged ? "Change & Next" : "Next"
    }

    var footerText: String {
        guard !isEditMode else { return "All scores entered" }
        guard currentGolferIndex < players.count - 1 else { return "All scores entered" }
        let next = players[currentGolferIndex + 1]
        return "Next: \(next.name.fullName)"
    }

    func configureInitialState() {
        currentGolferIndex = players.firstIndex(where: { $0.id == initialParticipant.id }) ?? 0
        syncDraftScore(resetDraft: true)
    }
    
    func jumpToPlayer(_ player: RoundParticipant) {
        guard let index = players.firstIndex(where: { $0.id == player.id }) else { return }
        guard index != currentGolferIndex else { return }
        
        // Set direction based on whether we're moving forward or backward
        navigationDirection = index > currentGolferIndex ? .forward : .backward
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGolferIndex = index
        }
    }

    func syncDraftScore(resetDraft: Bool) {
        let saved = savedScoreForCurrent
        savedScore = saved
        if resetDraft {
            let target = saved ?? holePar
            draftScore = target
        }
    }

    func syncSavedScore(_ newValue: Int?) {
        guard savedScore != newValue else { return }
        if draftScore == (savedScore ?? holePar) {
            draftScore = newValue ?? holePar
        }
        savedScore = newValue
    }

    func clearScore() async {
        await viewModel.clearScore(participant: currentGolfer)
        savedScore = nil
        draftScore = holePar
    }

    func handleCTA() async {
        if isEditMode {
            if shouldCommitScore() {
                await viewModel.setQuickScore(participant: currentGolfer, strokes: draftScore)
                Haptics.fire(.light)
            }
            dismiss()
            return
        }

        if shouldCommitScore() {
            await viewModel.setQuickScore(participant: currentGolfer, strokes: draftScore)
            Haptics.fire(.light)
        }

        if currentGolferIndex >= players.count - 1 {
            dismiss()
            return
        }

        navigationDirection = .forward
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGolferIndex += 1
        }
    }

    func shouldCommitScore() -> Bool {
        if savedScore == nil { return true }
        return isDraftChanged
    }
}

// MARK: - Preview

private struct LiveHoleScoringViewPreview: View {
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant
    
    init(withScores: Bool = false) {
        var snapshot = MockLiveRound2v2.snapshot
        
        // Add scoring data if requested
        if withScores {
            snapshot.scoring = Self.makePreviewScores(snapshot: snapshot)
        }
        
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id
        
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        vm.currentHoleIndex = 0 // Start at hole 1
        
        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first!
    }
    
    var body: some View {
        LiveHoleScoringView(viewModel: viewModel, initialParticipant: participant)
    }
    
    private static func makePreviewScores(snapshot: RoundSnapshot) -> [ScoreEntry] {
        let holes = snapshot.defaultTee?.holes ?? snapshot.tees.first?.holes
        guard let holes else { return [] }
        let participants = snapshot.participants
        let segmentID = "segment_preview"
        
        // Score holes 1-3 for variety:
        // - Hole 1: All players scored
        // - Hole 2: First 2 players scored
        // - Hole 3: No players scored (current hole)
        return participants.enumerated().flatMap { index, participant in
            holes.prefix(2).compactMap { hole in
                // Skip hole 2 for players 3 and 4
                if hole.number == 2 && index >= 2 { return nil }
                
                let offset = ((index + hole.number) % 4) - 1
                let strokes = max(1, hole.par + offset)
                return ScoreEntry(
                    id: ScoreEntry.makeID(hole: hole.number, segment: segmentID, scoringUnit: participant.id),
                    holeNumber: hole.number,
                    segmentID: segmentID,
                    groupID: participant.groupID ?? "group_1",
                    scoringUnitID: participant.id,
                    participantIDs: [participant.id],
                    strokes: strokes,
                    pickedUp: false,
                    entryID: participant.id,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: snapshot.round.id
                )
            }
        }
    }
}

#Preview("Live Hole Scoring - No Scores") {
    ZStack {
        Color.neutral6
            .ignoresSafeArea()
            .sheet(isPresented: .true) {
            LiveHoleScoringViewPreview()
                .presentationDetents([.height(700)])
        }
    }
}

#Preview("Live Hole Scoring - With Scores") {
    ZStack {
        Color.neutral6
            .ignoresSafeArea()
            .sheet(isPresented: .true) {
            LiveHoleScoringViewPreview(withScores: true)
                .presentationDetents([.height(700)])
        }
    }
}
