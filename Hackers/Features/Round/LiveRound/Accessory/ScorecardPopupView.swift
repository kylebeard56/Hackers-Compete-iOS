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

    private let low  = PresentationDetent.height(180)
    private let high = PresentationDetent.height(700)

    @State private var currentDetent: PresentationDetent = .height(180)

    private func midDetentHeight(for playerCount: Int) -> CGFloat {
        let headerHeight: CGFloat = 180
        let rowHeight:    CGFloat = 64
        let bottomPad:   CGFloat = 32
        return headerHeight + CGFloat(max(1, playerCount)) * rowHeight + bottomPad
    }

    private var mid: PresentationDetent {
        .height(midDetentHeight(for: viewModel.teeGroupParticipants.count))
    }

    private var isAtLow:  Bool { currentDetent == low }
    private var isAtHigh: Bool { currentDetent == high }

    // MARK: Scoring state (high detent)

    @State private var currentGolferIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?
    @State private var scoringDirection: ScoringDirection = .forward

    @CappedScaledMetric(relativeTo: .body)   private var playerCircleSize: CGFloat = 56
    @CappedScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 22
    @CappedScaledMetric(relativeTo: .caption) private var handicapDotSize: CGFloat = 8

    private enum ScoringDirection {
        case forward, backward
        var insertEdge: Edge  { self == .forward ? .trailing : .leading }
        var removalEdge: Edge { self == .forward ? .leading  : .trailing }
    }

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
            HoleDetailTilesView(viewModel: viewModel, palette: palette, holeNumber: holeNumber)

            if !viewModel.isSpectator {
                // Low detent: single quick-action CTA, collapses at mid/high
                PrimaryButton(
                    title: "Enter Scores",
                    labelColor: palette.backgroundColor,
                    buttonColor: palette.foregroundColor,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentDetent = mid
                        }
                    }
                )
                .frame(height: isAtLow ? 48 : 0)
                .opacity(isAtLow ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isAtLow)
                .clipped()

                // Mid / high: per-player scoring rows
                playerScoringSection(for: holeNumber)
                    .opacity(isAtLow ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isAtLow)

                // High: inline scoring UI stacked below
                if isAtHigh {
                    Divider().padding(.vertical, 4)
                    inlineScoringView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(16)
        .containerRelativeFrame(.horizontal)
    }

    // MARK: - Player Rows (mid)

    @ViewBuilder
    private func playerScoringSection(for holeNumber: Int) -> some View {
        if players.isEmpty {
            Text("No players in your tee group.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, participant in
                    PlayerScoringRow(
                        palette: palette,
                        viewModel: viewModel,
                        participant: participant,
                        holeNumber: holeNumber,
                        requiresTeams: roundSession.snapshot.requiresTeams,
                        onEnterScoreTap: { _ in
                            if let idx = players.firstIndex(where: { $0.id == participant.id }) {
                                currentGolferIndex = idx
                            }
                            syncDraftScore(resetDraft: true)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                currentDetent = high
                            }
                        }
                    )
                    if index < players.count - 1 {
                        Divider().opacity(0.18).padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Inline Scoring (high)

    private var inlineScoringView: some View {
        VStack(spacing: 20) {
            // Player circles
            HStack(spacing: 12) {
                ForEach(players) { player in
                    playerCircleView(for: player)
                }
            }

            // Player name — animated on golfer change
            if let golfer = currentGolfer {
                Text(golfer.name.fullName)
                    .fontStyle(kFontName, size: 28, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .id(golfer.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: scoringDirection.insertEdge).combined(with: .opacity),
                        removal:   .move(edge: scoringDirection.removalEdge).combined(with: .opacity)
                    ))
            }

            // Score picker + label
            scoreInputSection

            // CTA
            scoringCTASection
        }
        .padding(.top, 4)
        .onAppear {
            if currentGolferIndex >= players.count { currentGolferIndex = 0 }
            syncDraftScore(resetDraft: true)
        }
    }

    // MARK: Player Circle

    private func playerCircleView(for player: RoundParticipant) -> some View {
        let isCurrent  = player.id == currentGolfer?.id
        let isScored   = viewModel.grossStrokes(for: player.id, holeNumber: currentHoleNumber) != nil
        let teamColor  = viewModel.teamColor(for: player) ?? palette.foregroundColor
        let hasTeams   = viewModel.snapshot.requiresTeams
        let activeBorder: Color = hasTeams ? teamColor : effectiveAccent
        let strokesRx  = viewModel.strokesReceivedOnHole(participant: player, holeNumber: currentHoleNumber)
        let useHcp     = viewModel.snapshot.configuration.useHandicaps

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.neutral6)
                    .frame(width: playerCircleSize, height: playerCircleSize)

                Text(player.name.initials.uppercased())
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                if isCurrent {
                    Circle()
                        .stroke(activeBorder, lineWidth: 3)
                        .frame(width: playerCircleSize, height: playerCircleSize)
                }

                if isScored {
                    ZStack {
                        Circle()
                            .frame(width: badgeSize, height: badgeSize)
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

            if useHcp && strokesRx > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<strokesRx, id: \.self) { _ in
                        Circle()
                            .fill(hasTeams ? teamColor : palette.foregroundColor)
                            .frame(width: handicapDotSize, height: handicapDotSize)
                    }
                }
            }
        }
        .onTapGesture {
            guard let idx = players.firstIndex(where: { $0.id == player.id }),
                  idx != currentGolferIndex else { return }
            Haptics.fire(.light)
            commitCurrentDraftIfNeeded()
            scoringDirection = idx > currentGolferIndex ? .forward : .backward
            withAnimation(.easeInOut(duration: 0.2)) { currentGolferIndex = idx }
        }
    }

    // MARK: Score Input

    private var scoreInputSection: some View {
        let options      = scoreOptions(for: currentGolfer)
        let initialScore = savedScore ?? holePar

        return VStack(spacing: 16) {
            ZStack {
                scoreDecoration(strokes: draftScore, par: holePar)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: draftScore)

                CarouselNumberPicker(values: options, initialValue: initialScore) { newValue in
                    draftScore = newValue
                    Haptics.fire(.light)
                }
                .id(currentGolfer?.id ?? "")
            }
            .frame(height: 130)

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
        scoringDirection = .forward
        withAnimation(.easeInOut(duration: 0.2)) { currentGolferIndex += 1 }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var coordinator = PageCoordinator()

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
            roundSession: roundSession
        )
    }
}
