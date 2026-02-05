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
        NavigationStack {
            VStack(spacing: 24) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavButton(
                        style: .glass,
                        icon: "f00d",
                        size: 14,
                        weight: .solid,
                        color: palette.foregroundColor
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if savedScoreForCurrent.exists {
                        Button("Clear") {
                            Task { await clearScore() }
                        }
                        .fontStyle(.poppins, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    }
                }
            }
            .onAppear(perform: configureInitialState)
            .onChange(of: currentGolferIndex) {
                syncDraftScore(resetDraft: true)
            }
            .onChange(of: savedScoreForCurrent) { _, newValue in
                syncSavedScore(newValue)
            }
        }
    }
}

private extension LiveHoleScoringView {
    var topSection: some View {
        VStack(spacing: 10) {
            Text("Hole \(viewModel.currentHoleNumber)")
                .fontStyle(.poppins, size: 28, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            let hcpLabel = holeHandicap.map(String.init) ?? "—"
            Text("Par \(holePar) • \(holeYards) yds • HCP \(hcpLabel)")
                .fontStyle(.poppins, size: 12, weight: .medium)
                .foregroundStyle(Color.neutral2)

            HStack(spacing: 8) {
                ForEach(players) { player in
                    playerDot(for: player)
                }
            }
        }
    }

    func playerDot(for player: RoundParticipant) -> some View {
        let isCurrent = player.id == currentGolfer.id
        let isScored = viewModel.grossStrokes(for: player.id, holeNumber: viewModel.currentHoleNumber).exists
        let tint = viewModel.teamColor(for: player) ?? palette.foregroundColor

        return ZStack {
            Circle()
                .fill(isScored ? tint.opacity(0.85) : Color.clear)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(tint.opacity(isScored ? 0.2 : 0.6), lineWidth: 1.4)
                }

            if isCurrent {
                Circle()
                    .stroke(tint, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 16, height: 16)
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
                Text("\(draftScore)")
                    .fontStyle(.poppins, size: 28, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text(viewModel.friendlyScoreLabel(strokes: draftScore, par: holePar))
                    .fontStyle(.poppins, size: 14, weight: .medium)
                    .foregroundStyle(Color.neutral2)

                if let netLabel = netScoreLabel {
                    Text(netLabel)
                        .fontStyle(.poppins, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral3)
                }
            }
            .id(draftScore)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: draftScore)
        }
    }

    var ctaSection: some View {
        VStack(spacing: 8) {
            PrimaryButton(
                title: ctaTitle,
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTapAsync: handleCTA
            )

            Text(footerText)
                .fontStyle(.poppins, size: 11, weight: .medium)
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
