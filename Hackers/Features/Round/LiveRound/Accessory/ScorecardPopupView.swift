//
//  ScorecardPopupView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/26.
//

import SkeletonUI
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

    static let swipeHintTopSpacing: CGFloat = 24
    static let swipeHintCaretHeight: CGFloat = 14
    /// Height of the swipe hint block (spacing + caret + gap + text). Used to derive ultra-low from low.
    static var swipeHintBlockHeight: CGFloat {
        swipeHintTopSpacing + swipeHintCaretHeight + 4 + 20
    }

    /// Initial low detent height (matches effectiveLowHeight fallback). Use for initial binding so sheet opens at low.
    static var initialLowHeight: CGFloat {
        let headerH = headerTopPadding + headerControlHeight + headerBottomPadding
        let section1Content = tileHeight + swipeHintTopSpacing + swipeHintCaretHeight + 4 + 20
        return headerH + 16 + section1Content + sectionSpacing
    }
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
    var showSkeleton: Bool = false

    // MARK: Detents

    /// Low detent for hole 1 (tiles + swipe hint).
    private var low: PresentationDetent { .height(effectiveLowHeight) }
    /// Ultra-low detent for hole 2+ (tiles only, no swipe hint).
    private var lowUltra: PresentationDetent { .height(effectiveUltraLowHeight) }

    @Binding var currentDetent: PresentationDetent
    /// Reported to LiveRound for leaderboardBottomPadding. Updated when detent or measured heights change.
    @Binding var effectiveSheetHeightForPadding: CGFloat

    private func midDetentHeight(for playerCount: Int) -> CGFloat {
        guard !viewModel.isSpectator else { return effectiveLowHeight }
        if measuredSection2Height > 0 {
            let raw = effectiveLowHeight + measuredSection2Height + ScorecardPopupLayout.contentVerticalPadding + ScorecardPopupLayout.bottomSafePadding
            return (raw / Self.detentSnapGrid).rounded() * Self.detentSnapGrid
        }
        return ScorecardPopupLayout.midHeight(for: playerCount, isSpectator: false)
    }

    private var mid: PresentationDetent {
        .height(midDetentHeight(for: viewModel.teeGroupParticipants.count))
    }

    private let high: PresentationDetent = .large

    private var isAtLow:     Bool { currentDetent == low || currentDetent == lowUltra }
    private var isAtLowUltra: Bool { currentDetent == lowUltra }
    private var isAtHigh: Bool { currentDetent == high }

    private var normalizedSheetHeight: CGFloat {
        max(0, sheetHeight - detentHeightOffset)
    }

    /// 0 at low detent, 1 at mid detent. Interpolated during drag. Uses currentLowHeight (ultra-low on hole 2+).
    private var lowToMidProgress: CGFloat {
        guard hasCalibratedDetentOffset else { return 0 }
        let lowH = currentLowHeight
        let midH = midDetentHeight(for: players.count)
        let range = midH - lowH
        guard range > 0 else { return 0 }
        return min(1, max(0, (normalizedSheetHeight - lowH) / range))
    }

    /// 0 at mid detent, 1 at high detent. Interpolated during drag.
    private var midToHighProgress: CGFloat {
        guard hasCalibratedDetentOffset else { return 0 }
        let midH = midDetentHeight(for: players.count)
        guard sheetHeight > midH else { return 0 }
        return min(1, max(0, (normalizedSheetHeight - midH) / (sheetHeight - midH)))
    }

    // MARK: Scoring state (high detent)

    @State private var scoringPageHole: Int?
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
    /// Measured height of section 2 (player rows). 0 until reported. Spectator: always 0.
    @State private var measuredSection2Height: CGFloat = 0
    /// Tracks previous page index for hole-based detent switching.
    @State private var previousSettledPageIndex: Int = 0

    // MARK: Helpers

    /// Snaps to 8pt grid to avoid rapid 1pt detent changes that trigger cyclic layout warnings.
    private static let detentSnapGrid: CGFloat = 8

    private var effectiveLowHeight: CGFloat {
        let headerH = ScorecardPopupLayout.headerTopPadding + ScorecardPopupLayout.headerControlHeight + ScorecardPopupLayout.headerBottomPadding
        let fallback = ScorecardPopupLayout.initialLowHeight
        guard measuredLowContentHeight > 0 else { return (fallback / Self.detentSnapGrid).rounded() * Self.detentSnapGrid }
        let raw = headerH + 16 + measuredLowContentHeight + ScorecardPopupLayout.sectionSpacing
        return (raw / Self.detentSnapGrid).rounded() * Self.detentSnapGrid
    }

    /// Ultra-low height (tiles only). Used for hole 2+ where swipe hint is hidden.
    private var effectiveUltraLowHeight: CGFloat {
        let lowH = effectiveLowHeight
        let ultra = lowH - ScorecardPopupLayout.swipeHintBlockHeight
        return max(ScorecardPopupLayout.lowHeight, (ultra / Self.detentSnapGrid).rounded() * Self.detentSnapGrid)
    }

    /// Current page index from coordinator. 0 = hole 1.
    private var settledPageIndex: Int {
        Int(coordinator.fractionalIndex.rounded())
    }

    private var isOnHole1: Bool { settledPageIndex == 0 }

    /// The "low" baseline height for the current page. Hole 1 uses full low; hole 2+ uses ultra-low.
    private var currentLowHeight: CGFloat {
        isOnHole1 ? effectiveLowHeight : effectiveUltraLowHeight
    }

    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }

    private var players: [RoundParticipant] { viewModel.teeGroupParticipants }

    private var currentGolfer: RoundParticipant? { players[safe: currentGolferIndex] }

    private var currentHoleNumber: Int { viewModel.currentHoleNumber }
    /// Hole being scored in this popup; derived from coordinator page index to avoid drift from view model.
    private var effectiveHoleNumber: Int {
        viewModel.holeNumbers[safe: settledPageIndex] ?? viewModel.currentHoleNumber
    }

    private var currentHole: Hole? {
        viewModel.hole(for: effectiveHoleNumber, teeID: viewModel.selectedTeeID)
    }

    private var holePar: Int { currentHole?.par ?? 4 }

    private var savedScoreForCurrent: Int? {
        guard let p = currentGolfer else { return nil }
        return viewModel.grossStrokes(for: p.id, holeNumber: effectiveHoleNumber)
    }

    private var currentStrokesReceived: Int {
        guard let golfer = currentGolfer else { return 0 }
        return viewModel.strokesReceivedOnHole(participant: golfer, holeNumber: effectiveHoleNumber)
    }

    private func calibrateDetentOffset(for detent: PresentationDetent) {
        guard sheetHeight > 0 else { return }
        let detentHeight: CGFloat
        if detent == low {
            detentHeight = effectiveLowHeight
        } else if detent == lowUltra {
            detentHeight = effectiveUltraLowHeight
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

    /// Reports the effective sheet height to LiveRound for leaderboardBottomPadding.
    private func updateEffectiveSheetHeightForPadding() {
        let height: CGFloat
        if isAtHigh {
            height = effectiveLowHeight
        } else if isAtLowUltra {
            height = effectiveUltraLowHeight
        } else if isAtLow {
            height = effectiveLowHeight
        } else {
            height = midDetentHeight(for: players.count)
        }
        guard effectiveSheetHeightForPadding != height else { return }
        effectiveSheetHeightForPadding = height
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
                PagedHoleScrollView(
                    holeNumbers: viewModel.holeNumbers,
                    scoringPageHole: $scoringPageHole,
                    coordinator: coordinator
                ) { index in
                    let holeNumber = viewModel.holeNumbers[index]
                    holePageContent(for: holeNumber, pageIndex: index)
                }
                .scrollDisabled(isAtHigh)
                .clipped()
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
        .onPreferenceChange(Section2HeightKey.self) { newHeight in
            measuredSection2Height = viewModel.isSpectator ? 0 : newHeight
        }
        .presentationDetents(
            viewModel.isSpectator ? [lowUltra, low, high] : [lowUltra, low, mid, high],
            selection: $currentDetent
        )
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: high))
        .interactiveDismissDisabled()
        .onChange(of: measuredLowContentHeight) { oldH, newH in
            guard oldH != newH, newH > 0 else { return }
            calibrateDetentOffset(for: currentDetent)
            updateEffectiveSheetHeightForPadding()
            if isAtLow, abs(newH - oldH) >= Self.detentSnapGrid {
                currentDetent = isOnHole1 ? low : lowUltra
            }
        }
        .onChange(of: measuredSection2Height) { _, _ in
            calibrateDetentOffset(for: currentDetent)
            updateEffectiveSheetHeightForPadding()
        }
        .onChange(of: viewModel.teeGroupParticipants.count) { _, _ in
            updateEffectiveSheetHeightForPadding()
            guard !isAtHigh else { return }
            currentDetent = isAtLow ? (isOnHole1 ? low : lowUltra) : mid
        }
        .onChange(of: coordinator.fractionalIndex) { _, _ in
            let newIndex = settledPageIndex
            let oldIndex = previousSettledPageIndex
            defer { previousSettledPageIndex = newIndex }
            guard newIndex != oldIndex, isAtLow else { return }
            if oldIndex == 0, newIndex >= 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    currentDetent = lowUltra
                }
            } else if oldIndex >= 1, newIndex == 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    currentDetent = low
                }
            }
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
        .onAppear {
            currentDetent = low
            updateEffectiveSheetHeightForPadding()
        }
        .onChange(of: currentDetent) { _, newDetent in
            calibrateDetentOffset(for: newDetent)
            updateEffectiveSheetHeightForPadding()
            guard newDetent == high else { return }
            defer { wasExplicitSelection = false }
            guard !wasExplicitSelection else { return }
            // Auto-select the first unscored player when entering high without an explicit tap
            let firstUnscored = players.firstIndex {
                viewModel.grossStrokes(for: $0.id, holeNumber: effectiveHoleNumber) == nil
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
            
            NavButton(style: .glass, icon: "f00a", weight: .regular) {
                Haptics.fire(.light)
                guard let participant = players.first else { return }
                viewModel.presentedParticipant = participant
            }

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
                let distance = abs(index - Int(coordinator.fractionalIndex.rounded()))
                coordinator.scrollTo(index: index, duration: holeScrollDuration(for: distance))
            }
            .glassCardEffect(shape: .capsule)

            NavButton(style: .glass, icon: "f304", weight: .regular) {
                Haptics.fire(.light)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    currentDetent = high
                }
            }
            
//            NavButton(style: .glass, icon: "f054", color: palette.foregroundColor) {
//                guard currentIndex < viewModel.holeNumbers.count - 1 else { return }
//                coordinator.scrollTo(index: currentIndex + 1)
//            }
        }
    }

    // MARK: - Per-hole Page

    @ViewBuilder
    private func holePageContent(for holeNumber: Int, pageIndex: Int = 0) -> some View {
        let sectionSpacing = ScorecardPopupLayout.sectionSpacing
        let enterScoreVisibility = max(0, 1 - lowToMidProgress)
        let playerRowOpacity = hasCalibratedDetentOffset ? lowToMidProgress : 0
        let isCanonicalPage = pageIndex == 0

        VStack(spacing: sectionSpacing) {
            VStack(spacing: ScorecardPopupLayout.swipeHintTopSpacing) {
                if showSkeleton {
                    holeDetailSkeleton
                } else {
                    HoleDetailTilesView(viewModel: viewModel, palette: palette, holeNumber: holeNumber)
                }

                if enterScoreVisibility > 0.01, holeNumber == viewModel.holeNumbers.first, !showSkeleton {
                    Button {
                        Haptics.fire(.light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            currentDetent = high
                        }
                    } label: {
                        VStack(spacing: 4) {
                            AnimatedSwipeCaret()
                            Text("Swipe up to enter scores")
                                .fontStyle(kFontName, size: 15, weight: .medium)
                                .foregroundStyle(Color.neutral2)
                                .frame(maxWidth: .infinity, minHeight: 20)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Enter scores")
                    .accessibilityHint("Opens scoring view")
                }
            }
            .background { if isCanonicalPage { MeasureHeight() } }

            if !viewModel.isSpectator {
                Group {
                    if showSkeleton {
                        playerRowsSkeleton
                    } else {
                        playerRowsSection(for: holeNumber)
                    }
                }
                .opacity(playerRowOpacity)
                .allowsHitTesting(playerRowOpacity > 0.5)
                .accessibilityHidden(playerRowOpacity <= 0.01)
                .background { if isCanonicalPage { MeasureSection2Height() } }

                scoreInputSection
                    .padding(.top, 24)
                    .opacity(midToHighProgress)
                    .allowsHitTesting(isAtHigh)
                    .accessibilityHidden(!isAtHigh)

                scoringCTASection
                    .padding(.top, 8)
                    .opacity(midToHighProgress)
                    .allowsHitTesting(isAtHigh)
                    .accessibilityHidden(!isAtHigh)
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

    // MARK: Skeleton Views

    private var holeDetailSkeleton: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .scorecardPopupSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: ScorecardPopupLayout.tileHeight)
            }
        }
    }

    private var playerRowsSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.clear)
                        .scorecardPopupSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 24)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .scorecardPopupSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 6)
                            .frame(maxWidth: .infinity)
                            .frame(height: 17)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.clear)
                            .scorecardPopupSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 5)
                            .frame(width: 90, height: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.clear)
                        .scorecardPopupSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 10)
                        .frame(width: 120, height: 32)
                }
                .padding(.vertical, 4)
                if index != 3 {
                    Divider().opacity(0.18)
                }
            }
        }
    }

    // MARK: Score Input

    private var scoreInputSection: some View {
        let preloadGolfer = players.first
        let displayGolfer = isAtHigh ? currentGolfer : preloadGolfer
        let options      = scoreOptions(for: displayGolfer)
        let initialScore: Int = {
            if isAtHigh {
                return savedScore ?? holePar
            }
            guard let p = preloadGolfer else { return holePar }
            return viewModel.grossStrokes(for: p.id, holeNumber: effectiveHoleNumber) ?? holePar
        }()

        return VStack(spacing: 16) {
            CarouselNumberPicker(
                values: options,
                initialValue: initialScore,
                resetID: AnyHashable(displayGolfer?.id ?? "")
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
            viewModel.grossStrokes(for: $0.id, holeNumber: effectiveHoleNumber) != nil
        }
        let isLast     = currentGolferIndex >= players.count - 1
        let isEditMode = isAllScored

        let ctaTitle: String = {
            if isEditMode { return "Done" }
            if isLast     { return "Finish Hole \(effectiveHoleNumber)" }
            if savedScore == nil { return "Confirm & Next" }
            return "Next"
        }()

        let isFinishAction = (isLast && !isEditMode) || isEditMode
        let ctaLabelColor: Color  = isFinishAction ? .white : palette.backgroundColor
        let ctaButtonColor: Color = isFinishAction ? effectiveAccent : palette.foregroundColor

        return VStack(spacing: 12) {
            PrimaryButton(
                title: ctaTitle,
                //icon: (isLast && !isEditMode) ? "checkmark" : nil,
                //iconWeight: .solid,
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
        let saved     = viewModel.grossStrokes(for: participant.id, holeNumber: effectiveHoleNumber)
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
            Task { await viewModel.setQuickScore(participant: golfer, strokes: score, holeNumber: effectiveHoleNumber) }
        }
    }

    private func handleScoringCTA() async {
        guard let golfer = currentGolfer else { return }
        let score     = draftScore
        let needsSave = savedScore == nil || savedScore != score

        let isAllScored = players.allSatisfy {
            viewModel.grossStrokes(for: $0.id, holeNumber: effectiveHoleNumber) != nil
        }
        let isLast     = currentGolferIndex >= players.count - 1
        let isEditMode = isAllScored

        if isEditMode {
            if needsSave { await viewModel.setQuickScore(participant: golfer, strokes: score, holeNumber: effectiveHoleNumber) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentDetent = isOnHole1 ? low : lowUltra
            }
            return
        }

        if isLast {
            if needsSave { await viewModel.setQuickScore(participant: golfer, strokes: score, holeNumber: effectiveHoleNumber) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentDetent = isOnHole1 ? low : lowUltra
            }
            if viewModel.autoAdvanceWhenHoleComplete {
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    await MainActor.run { viewModel.navigateToNextUnscoredHole() }
                }
            }
            return
        }

        if needsSave { await viewModel.setQuickScore(participant: golfer, strokes: score, holeNumber: effectiveHoleNumber) }
        Haptics.fire(.light)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { currentGolferIndex += 1 }
    }
}

// MARK: - Skeleton Modifier

private struct ScorecardPopupSkeletonModifier: ViewModifier {
    let palette: DesignPalette
    let themeColor: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let color = themeColor.map { $0.opacity(0.4) } ?? palette.skeletonColor
        let background = themeColor.map { $0.opacity(0.12) } ?? palette.skeletonBackground
        return content.skeleton(
            with: true,
            animation: .linear(duration: 2.0),
            appearance: .solid(color: color, background: background),
            shape: .rounded(.radius(cornerRadius)),
            lines: 1,
            scales: [1: 0.125]
        )
    }
}

private extension View {
    func scorecardPopupSkeleton(
        palette: DesignPalette,
        themeColor: Color? = nil,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(ScorecardPopupSkeletonModifier(
            palette: palette,
            themeColor: themeColor,
            cornerRadius: cornerRadius
        ))
    }
}

// MARK: - Animated Swipe Caret

private struct AnimatedSwipeCaret: View {
    @State private var isUp = false

    var body: some View {
        Image(systemName: "chevron.up")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.neutral2)
            .offset(y: isUp ? -6 : 0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: isUp)
            .onAppear { isUp = true }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var coordinator = PageCoordinator()
    @Previewable @State var currentDetent: PresentationDetent = .height(ScorecardPopupLayout.initialLowHeight)
    @Previewable @State var effectiveSheetHeightForPadding: CGFloat = ScorecardPopupLayout.initialLowHeight

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
                currentDetent: $currentDetent,
                effectiveSheetHeightForPadding: $effectiveSheetHeightForPadding
            )
        }
}
