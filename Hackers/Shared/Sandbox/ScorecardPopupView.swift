//
//  ScorecardPopupView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/26.
//

import SwiftUI

// MARK: - ScorecardPopupView

struct ScorecardPopupView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let coordinator: PageCoordinator
    let roundSession: RoundSession

    // MARK: Detents

    private let low = PresentationDetent.height(232)

    @Binding var currentDetent: PresentationDetent

    private func midDetentHeight(for playerCount: Int) -> CGFloat {
        let headerHeight: CGFloat = 180
        let rowHeight:    CGFloat = 64
        let bottomPad:    CGFloat = 32
        return headerHeight + CGFloat(max(1, playerCount)) * rowHeight + bottomPad
    }

    /// header(63) + padding(32) + GROSS+spacing(28) + active row(90) + carousel(280)
    /// + per-inactive-player: row(52) + divider spacing(8)
    private func highDetentHeight(for playerCount: Int) -> CGFloat {
        let base: CGFloat = 493
        let inactiveRows = CGFloat(max(0, playerCount - 1)) * 60
        return base + inactiveRows
    }

    private var mid: PresentationDetent {
        .height(midDetentHeight(for: viewModel.teeGroupParticipants.count))
    }

    private var high: PresentationDetent {
        .height(highDetentHeight(for: viewModel.teeGroupParticipants.count))
    }

    private var isAtLow:  Bool { currentDetent == low }
    private var isAtMid:  Bool { currentDetent == mid }
    private var isAtHigh: Bool { currentDetent == high }

    // MARK: Scoring state (high detent)

    @State private var currentGolferIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?
    /// Prevents auto-select from overriding an explicit player tap.
    @State private var wasExplicitSelection: Bool = false

    // MARK: Helpers

    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }

    private var players: [RoundParticipant] { viewModel.teeGroupParticipants }

    private var currentGolfer: RoundParticipant? { players[safe: currentGolferIndex] }

    private var currentHoleNumber: Int { viewModel.currentHoleNumber }

    private var currentHole: Hole? {
        viewModel.hole(for: currentHoleNumber, teeID: viewModel.selectedTeeID)
    }

    private var holePar: Int { currentHole?.par ?? 4 }

    private var savedScoreForCurrent: Int? {
        guard let p = currentGolfer else { return nil }
        return viewModel.grossStrokes(for: p.id, holeNumber: currentHoleNumber)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            holeNavigationHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            PagedHoleScrollView(itemCount: viewModel.holeNumbers.count, coordinator: coordinator) { index in
                let holeNumber = viewModel.holeNumbers[index]
                holePageContent(for: holeNumber)
            }
            .scrollDisabled(isAtHigh)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([low, mid, high], selection: $currentDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: high))
        .interactiveDismissDisabled()
        .onChange(of: viewModel.teeGroupParticipants.count) { _, _ in
            guard !isAtHigh else { return }
            currentDetent = isAtLow ? low : mid
        }
        .onChange(of: currentGolferIndex) {
            syncDraftScore(resetDraft: true)
        }
        .onChange(of: savedScoreForCurrent) { _, newValue in
            guard savedScore != newValue else { return }
            if draftScore == (savedScore ?? holePar) {
                draftScore = newValue ?? holePar
            }
            savedScore = newValue
        }
        .onChange(of: currentDetent) { _, newDetent in
            guard newDetent == high else { return }
            defer { wasExplicitSelection = false }
            guard !wasExplicitSelection else { return }
            // Auto-select the first unscored player when entering high without an explicit tap
            let firstUnscored = players.firstIndex {
                viewModel.grossStrokes(for: $0.id, holeNumber: currentHoleNumber) == nil
            } ?? 0
            currentGolferIndex = firstUnscored
            syncDraftScore(resetDraft: true)
        }
    }

    // MARK: - Header

    private var holeNavigationHeader: some View {
        HStack(spacing: 8) {
            let currentIndex = Int(coordinator.fractionalIndex.rounded())

            NavButton(style: .glass, icon: "f053", color: palette.foregroundColor) {
                guard currentIndex > 0 else { return }
                coordinator.scrollTo(index: currentIndex - 1)
            }

            HoleWindowSelector(
                holes: viewModel.holeNumbers,
                fractionalIndex: coordinator.fractionalIndex,
                visibleSlotCount: 3,
                accentColor: effectiveAccent,
                activeColor: palette.foregroundColor,
                inactiveColor: .neutral2,
                fontSize: 14,
                slotSpacing: 10,
                itemSpacing: 4,
                indicatorHeight: 4,
                rowPadding: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
                holeState: { viewModel.holeState(for: $0) }
            ) { hole in
                Haptics.fire(.light)
                guard let index = viewModel.holeNumbers.firstIndex(of: hole) else { return }
                coordinator.scrollTo(index: index)
            }

            NavButton(style: .glass, icon: "f054", color: palette.foregroundColor) {
                guard currentIndex < viewModel.holeNumbers.count - 1 else { return }
                coordinator.scrollTo(index: currentIndex + 1)
            }
        }
    }

    // MARK: - Per-hole Page

    @ViewBuilder
    private func holePageContent(for holeNumber: Int) -> some View {
        VStack(spacing: 12) {
            // Tiles: always in hierarchy — collapse at high detent
            HoleDetailTilesView(viewModel: viewModel, palette: palette, holeNumber: holeNumber)
                .opacity(isAtHigh ? 0 : 1)
                .frame(maxHeight: isAtHigh ? 0 : .infinity)
                .clipped()

            if !viewModel.isSpectator {
                // Low: Enter Scores button — always present, collapse at mid/high
                GlassButton(
                    title: "Enter Scores",
                    labelColor: palette.foregroundColor,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {
                        wasExplicitSelection = true
                        let firstUnscored = players.firstIndex {
                            viewModel.grossStrokes(for: $0.id, holeNumber: currentHoleNumber) == nil
                        } ?? 0
                        currentGolferIndex = firstUnscored
                        syncDraftScore(resetDraft: true)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            currentDetent = high
                        }
                    }
                )
                .frame(height: isAtLow ? 48 : 0)
                .opacity(isAtLow ? 1 : 0)
                .clipped()

                // Mid + high: GROSS header + player rows
                VStack(spacing: 8) {
                    Text("GROSS")
                        .fontStyle(kFontName, size: 11, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    playerRowsSection(for: holeNumber)
                }
                .opacity(isAtLow ? 0 : 1)
                .frame(maxHeight: isAtLow ? 0 : .infinity)
                .clipped()

                // High: carousel — always in hierarchy, collapse at mid/low
                VStack(spacing: 20) {
                    scoringCarouselSection
                        .onAppear { syncDraftScore(resetDraft: true) }
                }
                .opacity(isAtHigh ? 1 : 0)
                .frame(maxHeight: isAtHigh ? .infinity : 0)
                .clipped()
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isAtHigh)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isAtLow)
        .padding(16)
        .containerRelativeFrame(.horizontal)
    }

    // MARK: - Unified Player Rows (mid + high)

    private func displayedPlayers() -> [(originalIndex: Int, participant: RoundParticipant)] {
        var items = Array(players.enumerated())
            .map { (originalIndex: $0.offset, participant: $0.element) }
        guard isAtHigh,
              let activeIdx = items.firstIndex(where: { $0.originalIndex == currentGolferIndex })
        else { return items }
        let active = items.remove(at: activeIdx)
        items.append(active)
        return items
    }

    @ViewBuilder
    private func playerRowsSection(for holeNumber: Int) -> some View {
        if players.isEmpty {
            Text("No players in your tee group.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .padding(.vertical, 12)
        } else {
            let orderedPlayers = displayedPlayers()
            VStack(spacing: 0) {
                ForEach(orderedPlayers, id: \.participant.id) { item in
                    let active = isAtHigh && item.originalIndex == currentGolferIndex
                    PlayerScoringRow(
                        palette: palette,
                        viewModel: viewModel,
                        participant: item.participant,
                        holeNumber: holeNumber,
                        requiresTeams: roundSession.snapshot.requiresTeams,
                        isActive: active,
                        isInScoringMode: isAtHigh,
                        onRowTap: isAtHigh ? { _ in
                            guard !active else { return }
                            commitCurrentDraftIfNeeded()
                            wasExplicitSelection = true
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                currentGolferIndex = item.originalIndex
                            }
                            syncDraftScore(resetDraft: true)
                        } : nil,
                        onEnterScoreTap: { _ in
                            wasExplicitSelection = true
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                currentGolferIndex = item.originalIndex
                            }
                            syncDraftScore(resetDraft: true)
                            if !isAtHigh {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                    currentDetent = high
                                }
                            }
                        }
                    )
                    if item.originalIndex != orderedPlayers.last?.originalIndex {
                        Divider().opacity(0.18).padding(.vertical, 4)
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: currentGolferIndex)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isAtHigh)
        }
    }

    // MARK: - Scoring Carousel (high detent)

    private var scoringCarouselSection: some View {
        VStack(spacing: 20) {
            scoreInputSection
            scoringCTASection
        }
        .padding(.top, 4)
    }

    // MARK: Score Input

    private var scoreInputSection: some View {
        let options      = scoreOptions(for: currentGolfer)
        let initialScore = savedScore ?? holePar

        return VStack(spacing: 16) {
            CarouselNumberPicker(values: options, initialValue: initialScore) { newValue in
                draftScore = newValue
                Haptics.fire(.light)
            }
            .id(currentGolfer?.id ?? "")
            .frame(height: 130)
            .background {
                scoreDecoration(strokes: draftScore, par: holePar)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: draftScore)
            }

            Text(viewModel.friendlyScoreLabel(
                strokes: draftScore,
                par: holePar,
                format: LiveRoundViewModel.FriendlyScoreFormat.full
            ))
            .fontStyle(kFontName, size: 24, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(minHeight: 60)
            .id(draftScore)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: draftScore)
        }
    }

    // MARK: Scoring CTA

    private var scoringCTASection: some View {
        let isAllScored = players.allSatisfy {
            viewModel.grossStrokes(for: $0.id, holeNumber: currentHoleNumber) != nil
        }
        let isLast     = currentGolferIndex >= players.count - 1
        let isEditMode = isAllScored

        let ctaTitle: String = {
            if isEditMode { return "Done" }
            if isLast     { return "Finish Hole \(currentHoleNumber)" }
            if savedScore == nil { return "Confirm & Next" }
            return "Next"
        }()

        let isFinishAction = (isLast && !isEditMode) || isEditMode
        let ctaLabelColor: Color  = isFinishAction ? .white : palette.backgroundColor
        let ctaButtonColor: Color = isFinishAction ? effectiveAccent : palette.foregroundColor

        return VStack(spacing: 12) {
            PrimaryButton(
                title: ctaTitle,
                icon: (isLast && !isEditMode) ? "checkmark" : nil,
                iconWeight: .solid,
                labelColor: ctaLabelColor,
                buttonColor: ctaButtonColor,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTapAsync: handleScoringCTA
            )

            if !isEditMode, let next = players[safe: currentGolferIndex + 1] {
                Text("Next: \(next.name.fullName)")
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral2)
            }
        }
    }

    // MARK: Score Decoration

    @ViewBuilder
    private func scoreDecoration(strokes: Int, par: Int) -> some View {
        let diff        = strokes - par
        let strokeColor = Color.neutral3.opacity(0.45)
        let fillColor   = Color.neutral3.opacity(0.2)
        let size: CGFloat = 120

        if diff <= -2 {
            Circle()
                .fill(fillColor)
                .frame(width: size, height: size)
        } else if diff == -1 {
            Circle()
                .stroke(strokeColor, lineWidth: 3)
                .frame(width: size, height: size)
        } else if diff == 1 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(strokeColor, lineWidth: 3)
                .frame(width: size, height: size)
        } else if diff >= 2 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(fillColor)
                .frame(width: size, height: size)
        }
    }

    // MARK: - Scoring Logic

    private func scoreOptions(for participant: RoundParticipant?) -> [Int] {
        guard let participant else { return Array(1...9) }
        let minScore  = holePar == 4 ? 1 : max(1, holePar - 2)
        let saved     = viewModel.grossStrokes(for: participant.id, holeNumber: currentHoleNumber)
        let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: holePar)
        let maxScore  = max(9, saved ?? 0, configMax)
        return Array(minScore...maxScore)
    }

    private func syncDraftScore(resetDraft: Bool) {
        let saved = savedScoreForCurrent
        savedScore = saved
        if resetDraft {
            draftScore = saved ?? holePar
        }
    }

    private func commitCurrentDraftIfNeeded() {
        guard let golfer = currentGolfer else { return }
        let score = draftScore
        let needsSave = savedScore == nil || savedScore != score
        if needsSave {
            Task { await viewModel.setQuickScore(participant: golfer, strokes: score) }
        }
    }

    private func handleScoringCTA() async {
        guard let golfer = currentGolfer else { return }
        let score     = draftScore
        let needsSave = savedScore == nil || savedScore != score

        let isAllScored = players.allSatisfy {
            viewModel.grossStrokes(for: $0.id, holeNumber: currentHoleNumber) != nil
        }
        let isLast     = currentGolferIndex >= players.count - 1
        let isEditMode = isAllScored

        if isEditMode {
            if needsSave { await viewModel.setQuickScore(participant: golfer, strokes: score) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentDetent = low }
            return
        }

        if isLast {
            if needsSave { await viewModel.setQuickScore(participant: golfer, strokes: score) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentDetent = low }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                await MainActor.run { viewModel.navigateToNextUnscoredHole() }
            }
            return
        }

        if needsSave { await viewModel.setQuickScore(participant: golfer, strokes: score) }
        Haptics.fire(.light)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { currentGolferIndex += 1 }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var coordinator = PageCoordinator()
    @Previewable @State var currentDetent: PresentationDetent = .height(232)

    let snapshot   = MockLiveRound2v2.snapshot
    let appSession = AppSession()
    appSession.ephemeralParticipantID = snapshot.participants.first?.id

    let roundSession        = RoundSession()
    roundSession.snapshot   = snapshot

    let vm = LiveRoundViewModel()
    vm.bind(appSession: appSession, roundSession: roundSession)

    return ZStack {
        Color.neutral6.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        ScorecardPopupView(
            viewModel: vm,
            palette: DesignPalette(theme: .glass, scheme: .dark),
            coordinator: coordinator,
            roundSession: roundSession,
            currentDetent: $currentDetent
        )
    }
}
