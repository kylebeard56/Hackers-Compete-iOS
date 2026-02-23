//
//  ScorecardPopupView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/26.
//

import SwiftUI

// MARK: - Sheet Height Tracking

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum ScorecardPopupLayout {
    static let bottomSafePadding: CGFloat = 20
    static let lowHeight: CGFloat = 170 + bottomSafePadding
    static let headerControlHeight: CGFloat = 44
    static let headerTopPadding: CGFloat = 16
    static let headerBottomPadding: CGFloat = 8
    static let contentVerticalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let midRowHeight: CGFloat = 44
    static let midRowDividerHeight: CGFloat = 8
    static let tileHeight: CGFloat = 72
    static let leaderboardBottomInset: CGFloat = 20

    static func midHeight(for playerCount: Int, isSpectator: Bool) -> CGFloat {
        let headerHeight = headerTopPadding + headerControlHeight + headerBottomPadding
        let staticContentHeight = headerHeight + contentVerticalPadding + tileHeight + contentVerticalPadding + bottomSafePadding
        guard !isSpectator else { return staticContentHeight }

        let rows = max(1, playerCount)
        let rowStackHeight =
            CGFloat(rows) * midRowHeight
            + CGFloat(max(0, rows - 1)) * midRowDividerHeight

        return staticContentHeight + sectionSpacing + rowStackHeight
    }
}

// MARK: - ScorecardPopupView

struct ScorecardPopupView: View {
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let coordinator: PageCoordinator
    let roundSession: RoundSession

    // MARK: Detents

    private var low: PresentationDetent { .height(effectiveLowHeight) }

    @Binding var currentDetent: PresentationDetent

    private func midDetentHeight(for playerCount: Int) -> CGFloat {
        ScorecardPopupLayout.midHeight(for: playerCount, isSpectator: viewModel.isSpectator)
    }

    private var mid: PresentationDetent {
        .height(midDetentHeight(for: viewModel.teeGroupParticipants.count))
    }

    private let high: PresentationDetent = .large

    private var isAtLow:  Bool { currentDetent == low }
    private var isAtHigh: Bool { currentDetent == high }

    private var normalizedSheetHeight: CGFloat {
        max(0, sheetHeight - detentHeightOffset)
    }

    /// 0 at low detent, 1 at mid detent. Interpolated during drag.
    private var lowToMidProgress: CGFloat {
        guard hasCalibratedDetentOffset else { return 0 }
        let lowH = effectiveLowHeight
        let midH = midDetentHeight(for: players.count)
        let range = midH - lowH
        guard range > 0 else { return 0 }
        return min(1, max(0, (normalizedSheetHeight - lowH) / range))
    }

    // MARK: Scoring state (high detent)

    @State private var currentGolferIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?
    /// Prevents auto-select from overriding an explicit player tap.
    @State private var wasExplicitSelection: Bool = false
    /// Continuously tracked sheet vertical position-derived height.
    @State private var sheetHeight: CGFloat = 0
    /// Constant offset between measured position height and detent height.
    @State private var detentHeightOffset: CGFloat = 0
    @State private var hasCalibratedDetentOffset: Bool = false
    /// Measured height of low content (tiles + swipe hint). 0 until GeometryReader reports.
    @State private var measuredLowContentHeight: CGFloat = 0

    // MARK: Helpers

    private static let lowDetentFallback: CGFloat = 220

    /// Snaps to 8pt grid to avoid rapid 1pt detent changes that trigger cyclic layout warnings.
    private static let detentSnapGrid: CGFloat = 8

    private var effectiveLowHeight: CGFloat {
        let fallback = min(ScorecardPopupLayout.lowHeight, Self.lowDetentFallback)
        guard measuredLowContentHeight > 0 else { return fallback }
        let headerH = ScorecardPopupLayout.headerTopPadding + ScorecardPopupLayout.headerControlHeight + ScorecardPopupLayout.headerBottomPadding
        let raw = headerH + 16 + measuredLowContentHeight + 16 + ScorecardPopupLayout.bottomSafePadding
        return (raw / Self.detentSnapGrid).rounded() * Self.detentSnapGrid
    }

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

    private var currentStrokesReceived: Int {
        guard let golfer = currentGolfer else { return 0 }
        return viewModel.strokesReceivedOnHole(participant: golfer, holeNumber: currentHoleNumber)
    }

    private func calibrateDetentOffset(for detent: PresentationDetent) {
        guard sheetHeight > 0 else { return }
        let detentHeight: CGFloat
        if detent == low {
            detentHeight = effectiveLowHeight
        } else if detent == mid {
            detentHeight = midDetentHeight(for: players.count)
        } else if detent == high {
            // `.large` varies by device/safe-area; using the measured height keeps math stable.
            detentHeight = sheetHeight
        } else {
            return
        }
        detentHeightOffset = sheetHeight - detentHeight
        hasCalibratedDetentOffset = true
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            holeNavigationHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if viewModel.holeNumbers.isEmpty {
                Text("No holes available.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            } else {
                PagedHoleScrollView(itemCount: viewModel.holeNumbers.count, coordinator: coordinator) { index in
                    let holeNumber = viewModel.holeNumbers[index]
                    holePageContent(for: holeNumber)
                }
                .scrollDisabled(isAtHigh)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: SheetHeightKey.self,
                    value: UIScreen.main.bounds.height - geo.frame(in: .global).minY
                )
            }
        }
        .onPreferenceChange(SheetHeightKey.self) { newHeight in
            sheetHeight = newHeight
            guard !hasCalibratedDetentOffset, newHeight > 0 else { return }
            calibrateDetentOffset(for: currentDetent)
        }
        .onPreferenceChange(ContentHeightKey.self) { newHeight in
            measuredLowContentHeight = newHeight
        }
        .presentationDetents([low, mid, high], selection: $currentDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: high))
        .interactiveDismissDisabled()
        .onChange(of: measuredLowContentHeight) { oldH, newH in
            guard oldH != newH, newH > 0 else { return }
            if isAtLow {
                currentDetent = low
            }
        }
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
            calibrateDetentOffset(for: newDetent)
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
//            let currentIndex = Int(coordinator.fractionalIndex.rounded())

//            NavButton(style: .glass, icon: "f053", color: palette.foregroundColor) {
//                guard currentIndex > 0 else { return }
//                coordinator.scrollTo(index: currentIndex - 1)
//            }
            
            NavButton(style: .glass, icon: "f00a", weight: .regular) { print("show scorecard") }

            HoleWindowSelector(
                coordinator: coordinator,
                holes: viewModel.holeNumbers,
                visibleSlotCount: 3,
                accentColor: effectiveAccent,
                activeColor: palette.foregroundColor,
                inactiveColor: .neutral,
                fontSize: 14,
                slotSpacing: 10,
                itemSpacing: 4,
                indicatorHeight: 4,
                rowPadding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
                holeState: { viewModel.holeState(for: $0) }
            ) { hole in
                Haptics.fire(.light)
                guard let index = viewModel.holeNumbers.firstIndex(of: hole) else { return }
                coordinator.scrollTo(index: index)
            }
            .glassCardEffect(shape: .capsule)

            NavButton(style: .glass, icon: "f304", weight: .regular) { print("show hole picker") }
            
//            NavButton(style: .glass, icon: "f054", color: palette.foregroundColor) {
//                guard currentIndex < viewModel.holeNumbers.count - 1 else { return }
//                coordinator.scrollTo(index: currentIndex + 1)
//            }
        }
    }

    // MARK: - Per-hole Page

    @ViewBuilder
    private func holePageContent(for holeNumber: Int) -> some View {
        let sectionSpacing = ScorecardPopupLayout.sectionSpacing
        let enterScoreVisibility = max(0, 1 - lowToMidProgress)
        let playerRowOpacity = hasCalibratedDetentOffset ? lowToMidProgress : 0

        VStack(spacing: sectionSpacing) {
            VStack(spacing: sectionSpacing) {
                HoleDetailTilesView(viewModel: viewModel, palette: palette, holeNumber: holeNumber)

                VStack(spacing: 4) {
                    Text("Swipe up to enter scores")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .opacity(enterScoreVisibility)
                        .accessibilityHidden(enterScoreVisibility <= 0.01)
                }
            }
            .background(MeasureHeight())

            if !viewModel.isSpectator {
                playerRowsSection(for: holeNumber)
                    .opacity(playerRowOpacity)
                    .allowsHitTesting(playerRowOpacity > 0.5)
                    .accessibilityHidden(playerRowOpacity <= 0.01)

                scoreInputSection
                    .padding(.top, 24)
                    .opacity(isAtHigh ? 1 : 0)
                    .allowsHitTesting(isAtHigh)
                    .accessibilityHidden(!isAtHigh)
                    .animation(.easeInOut(duration: 0.25), value: isAtHigh)

                scoringCTASection
                    .padding(.top, 8)
                    .opacity(isAtHigh ? 1 : 0)
                    .allowsHitTesting(isAtHigh)
                    .accessibilityHidden(!isAtHigh)
                    .animation(.easeInOut(duration: 0.25), value: isAtHigh)
            }
        }
        .padding(16)
        .padding(.bottom, ScorecardPopupLayout.bottomSafePadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .containerRelativeFrame(.horizontal)
    }

    // MARK: - Unified Player Rows (mid + high)

    private func displayedPlayers() -> [(originalIndex: Int, participant: RoundParticipant)] {
        Array(players.enumerated())
            .map { (originalIndex: $0.offset, participant: $0.element) }
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
                        onRowTap: { _ in
                            if isAtHigh {
                                guard !active else { return }
                                commitCurrentDraftIfNeeded()
                            }
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
                        },
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

    // MARK: Score Input

    private var scoreInputSection: some View {
        let options      = scoreOptions(for: currentGolfer)
        let initialScore = savedScore ?? holePar

        return VStack(spacing: 16) {
            CarouselNumberPicker(
                values: options,
                initialValue: initialScore,
                resetID: AnyHashable(currentGolfer?.id ?? "")
            ) { newValue in
                draftScore = newValue
                Haptics.fire(.light)
            }
            .frame(height: 130)
            .background {
                scoreDecoration(strokes: draftScore, par: holePar)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: draftScore)
            }

            VStack(spacing: 4) {
                Text(viewModel.friendlyScoreLabel(
                    strokes: draftScore,
                    par: holePar,
                    format: LiveRoundViewModel.FriendlyScoreFormat.full
                ))
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

                if viewModel.snapshot.round.configuration.useHandicaps, currentStrokesReceived > 0 {
                    let netScore = max(0, draftScore - currentStrokesReceived)
                    Text("Net \(netScore)")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                }
            }
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
    @Previewable @State var currentDetent: PresentationDetent = .height(ScorecardPopupLayout.lowHeight)

    let snapshot   = MockLiveRound2v2.snapshot
    let appSession = AppSession()
    appSession.ephemeralParticipantID = snapshot.participants.first?.id

    let roundSession        = RoundSession()
    roundSession.snapshot   = snapshot

    let vm = LiveRoundViewModel()
    vm.bind(appSession: appSession, roundSession: roundSession)

    return BackgroundTheme(palette: .init(theme: .glass, scheme: .dark), theme: .purple)
        .ignoresSafeArea()
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
