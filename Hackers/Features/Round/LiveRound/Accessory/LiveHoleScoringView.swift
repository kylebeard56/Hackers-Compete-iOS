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

    @ObservedObject var viewModel: LiveRoundViewModel
    let initialParticipant: RoundParticipant

    @State private var currentGolferIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

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
        let minScore = min(2, holePar - 2)
        let maxScore = max(9, (savedScoreForCurrent ?? 0), holePar + 4)
        return Array(minScore...maxScore)
    }

    private var teamTint: Color {
        viewModel.teamColor(for: currentGolfer) ?? palette.foregroundColor
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
                
                Button {
                    Task { await clearScore() }
                } label: {
                    Text("Clear")
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(Color.systemError)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .glassCardEffect(shape: .capsule)
                }
                .alignTrailing()
            }
            
            topSection

            VStack(spacing: 8) {
                Text(currentGolfer.name.fullName)
                    .fontStyle(.poppins, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .id(currentGolfer.id)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                if savedScore.exists {
                    statusBanner
                }
            }

            scoreInput

            Spacer(minLength: 0)

            ctaSection
        }
        .padding(20)
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
    var topSection: some View {
        VStack(spacing: 10) {
            Text("Hole \(viewModel.currentHoleNumber)")
                .fontStyle(.poppins, size: 28, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            HStack(spacing: 8) {
                Text("Par \(holePar)")
                    .fontStyle(.poppins, size: 17, weight: .medium)
                    .foregroundStyle(Color.neutral)
                
                Dot(size: 4)
                
                Text("\(holeYards) yds")
                    .fontStyle(.poppins, size: 17, weight: .medium)
                    .foregroundStyle(Color.neutral)
                
                if let holeHandicap {
                    Dot(size: 4)
                    
                    Text("\(holeHandicap) HCP")
                        .fontStyle(.poppins, size: 17, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            }

            HStack(spacing: 12) {
                ForEach(players) { player in
                    playerDot(for: player)
                }
            }
        }
    }

    func playerDot(for player: RoundParticipant) -> some View {
        let isCurrent = player.id == currentGolfer.id
        let isScored = viewModel.grossStrokes(for: player.id, holeNumber: viewModel.currentHoleNumber).exists
        let teamColor = viewModel.teamColor(for: player)
        let hasTeams = viewModel.snapshot.requiresTeams
        
        // Border color for active state
        let activeBorderColor = hasTeams ? (teamColor ?? palette.foregroundColor) : Color.accentGreen
        
        // Background and text colors based on state
        let backgroundColor: Color = isScored ? (teamColor ?? Color.accentGreen) : Color.neutral6
        let initialsColor: Color = isScored ? .white : palette.foregroundColor
        
        return ZStack {
            // Main circle with background
            Circle()
                .fill(backgroundColor)
                .frame(width: 56, height: 56)
            
            // Initials text
            Text(player.name.initials.uppercased())
                .fontStyle(.poppins, size: 16, weight: .semibold)
                .foregroundStyle(initialsColor)
            
            // Active state border
            if isCurrent {
                Circle()
                    .stroke(activeBorderColor, lineWidth: 3)
                    .frame(width: 56, height: 56)
            }
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
        .onTapGesture {
            jumpToPlayer(player)
        }
    }

    var statusBanner: some View {
        let saved = savedScore ?? 0
        let label = viewModel.friendlyScoreSummary(strokes: saved, par: holePar)
        let draftLabel = viewModel.friendlyScoreSummary(strokes: draftScore, par: holePar)
        let isChanging = isDraftChanged
        let text = isChanging ? "Changing to \(draftLabel)" : "Scored as \(label)"

        return Text(text)
            .fontStyle(.poppins, size: 12, weight: .semibold)
            .foregroundStyle(teamTint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                teamTint.opacity(colorScheme.translucent),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .animation(.easeInOut(duration: 0.2), value: draftScore)
    }

    var scoreInput: some View {
        let initialScore = savedScoreForCurrent ?? holePar
        
        return VStack(spacing: 16) {
            CarouselNumberPicker(values: scoreOptions, initialValue: initialScore) { newValue in
                draftScore = newValue
                Haptics.fire(.light)
            }
            .id(currentGolfer.id) // Force recreation when golfer changes

            VStack(spacing: 4) {
                Text(viewModel.friendlyScoreLabel(strokes: draftScore, par: holePar))
                    .fontStyle(.poppins, size: 22, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)

                if let netLabel = netScoreLabel {
                    Text(netLabel)
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            }
            .frame(minHeight: 80)
            .id(draftScore)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: draftScore)
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
                .fontStyle(.poppins, size: 15, weight: .medium)
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
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGolferIndex = index
        }
        Haptics.fire(.light)
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
        Color.neutral.sheet(isPresented: .true) {
            LiveHoleScoringViewPreview()
                .presentationDetents([.height(700)])
        }
    }
}

#Preview("Live Hole Scoring - With Scores") {
    ZStack {
        Color.neutral.sheet(isPresented: .true) {
            LiveHoleScoringViewPreview(withScores: true)
                .presentationDetents([.height(700)])
        }
    }
}
