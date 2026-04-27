//
//  LiveHoleScoringView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/4/26.
//

import SwiftUI

struct LiveHoleScoringView: View, Loggable {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @CappedScaledMetric(relativeTo: .body) var playerCircleSize: CGFloat = 64
    @CappedScaledMetric(relativeTo: .body) var scoreInputHeight: CGFloat = 130
    @CappedScaledMetric(relativeTo: .caption) var handicapDotSize: CGFloat = 8

    @ObservedObject var viewModel: LiveRoundViewModel
    let scoringSession: ScoringSession

    @State private var currentGolferIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var didTrackScoringSheetOpen = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }
    private var effectiveAccentLabelColor: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.backgroundColor : .white
    }
    
    private enum NavigationDirection {
        case forward, backward
        
        var edge: Edge {
            switch self {
            case .forward: return .trailing
            case .backward: return .leading
            }
        }
    }

    private var holeNumber: Int {
        scoringSession.holeNumber
    }

    private var isSharedEntry: Bool {
        scoringSession.isSharedEntry
    }

    private var sessionParticipants: [RoundParticipant] {
        let participants = scoringSession.participants
        return participants.isPopulated ? participants : [scoringSession.participant]
    }

    private var scoringParticipants: [RoundParticipant] {
        isSharedEntry ? [scoringSession.participant] : sessionParticipants
    }

    private var displayParticipants: [RoundParticipant] {
        sessionParticipants
    }

    private var currentGolfer: RoundParticipant {
        scoringParticipants[safe: currentGolferIndex] ?? scoringSession.participant
    }

    private var hole: Hole? {
        viewModel.hole(for: holeNumber, teeID: viewModel.selectedTeeID)
    }

    private var holePar: Int { hole?.par ?? 4 }
    private var holeYards: Int { hole?.yardage ?? 0 }
    private var holeHandicap: Int? { hole?.handicap }

    private var isEditMode: Bool {
        if isSharedEntry {
            return savedScoreForCurrent != nil
        }
        return scoringParticipants.isPopulated
            && scoringParticipants.allSatisfy {
                viewModel.scoreInputValue(for: $0.id, holeNumber: holeNumber) != nil
            }
    }

    private var savedScoreForCurrent: Int? {
        if isSharedEntry {
            return viewModel.scoringUnitScoreInputValue(
                scoringUnitID: scoringSession.scoringUnitID,
                holeNumber: holeNumber
            )
        }
        return viewModel.scoreInputValue(for: currentGolfer.id, holeNumber: holeNumber)
    }

    private var isDraftChanged: Bool {
        guard let savedScore else { return false }
        return savedScore != draftScore
    }

    /// Sentinel value for "clear score" option in the carousel (must not collide with friendly relative values like -1 birdie).
    private static let clearScoreSentinel: Int = Int.min

    private var scoreOptions: [Int] {
        let scores: [Int]
        if viewModel.isFriendlyScoreInputMode {
            let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.friendlyMaxRelativeValue(for: holePar)
            let maxScore = max(configMax, savedScoreForCurrent ?? 0)
            scores = Array(-4...maxScore)
        } else {
            let minScore = holePar == 4 ? 1 : max(1, holePar - 2)
            let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: holePar)
            let maxScore = max(configMax, savedScoreForCurrent ?? 0)
            scores = Array(minScore...maxScore)
        }
        return [Self.clearScoreSentinel] + scores
    }

    private var teamTint: Color {
        viewModel.teamColor(for: currentGolfer) ?? palette.foregroundColor
    }
    
    private var isScored: Bool {
        viewModel.scoreInputValue(for: currentGolfer.id, holeNumber: holeNumber).exists
    }

    private var netScoreLabel: String? {
        guard !isSharedEntry else { return nil }
        guard viewModel.snapshot.configuration.useHandicaps else { return nil }
        guard draftScore != Self.clearScoreSentinel else { return nil }
        let strokesReceived = viewModel.strokesReceivedOnHole(
            participant: currentGolfer,
            holeNumber: holeNumber
        )
        guard strokesReceived > 0 else { return nil }
        if viewModel.isFriendlyScoreInputMode {
            let netRelative = draftScore - strokesReceived
            return "Net \(viewModel.friendlyScoreLabel(relativeToPar: netRelative, par: holePar, format: .full))"
        }
        let net = max(0, draftScore - strokesReceived)
        return "Net \(net)"
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                NavButton(style: .glass, background: palette.glassButtonColor, onTap: { dismiss() })
                    .alignLeading()
                
                holeInfo
                    .alignCenter()
                
                NavButton(style: .glass, icon: "f00c", background: palette.glassButtonColor, onTap: saveAndClose)
                    .alignTrailing()
            }
            .padding(.horizontal, 16)
            
            //holeInfo
            
            Spacer(minLength: 0)

            if isSharedEntry {
                sharedOwnerStrip
            } else {
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(scoringParticipants) { player in
                                    playerDot(for: player)
                                        .id(player.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minWidth: geo.size.width, maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                        }
                        .scrollClipDisabled()
                        .onAppear {
                            proxy.scrollTo(currentGolfer.id, anchor: .center)
                        }
                        .onChange(of: currentGolferIndex) { _, _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(currentGolfer.id, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: playerCircleSize * 1.5)
            }

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
        .onAppear {
            configureInitialState()
            trackScoringSheetOpenedIfNeeded()
        }
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
        Text(ownerTitle)
            .fontStyle(kFontName, size: 32, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .id(isSharedEntry ? scoringSession.scoringUnitID : currentGolfer.id)
            .transition(.asymmetric(
                insertion: .move(edge: navigationDirection.edge).combined(with: .opacity),
                removal: .move(edge: navigationDirection == .forward ? .leading : .trailing).combined(with: .opacity)
            ))
    }
    
    var holeInfo: some View {
        VStack(spacing: 2) {
            Text("Hole \(holeNumber)")
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
        let ratio: CGFloat = 1.2
        let isCurrent = player.id == currentGolfer.id
        let scale: CGFloat = isCurrent ? ratio : 1.0
        let isScored = viewModel.scoreInputValue(for: player.id, holeNumber: holeNumber).exists
        let teamColor = viewModel.teamColor(for: player)
        let hasTeams = viewModel.snapshot.requiresTeams
        let useHandicaps = viewModel.snapshot.configuration.useHandicaps
        let strokesReceived = viewModel.strokesReceivedOnHole(
            participant: player,
            holeNumber: holeNumber
        )
        let avatarTint: Color = hasTeams ? (teamColor ?? viewModel.theme.color) : viewModel.theme.color

        return VStack(spacing: 6) {
            ZStack {
                PlayerAvatarView(
                    initials: player.name.initials,
                    size: playerCircleSize,
                    glassTint: isCurrent
                        ? avatarTint.opacity(colorScheme.translucent)
                        : Color.neutral6,//avatarTint.opacity(colorScheme.isLight ? 0.3 : 0.5),
                    badgeIcon: isScored ? "checkmark.circle.fill" : nil,
                    badgeIconColor: teamColor ?? effectiveAccent,
                    badgeBackgroundColor: palette.backgroundColor
                )
            }
            .scaleEffect(scale, anchor: .bottom)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isCurrent)
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

    private var ownerTitle: String {
        if isSharedEntry {
            let names = displayParticipants
                .map(\.name.fullName)
                .filter(\.isPopulated)
            if names.isPopulated {
                return names.joined(separator: " + ")
            }
            return scoringSession.title ?? currentGolfer.name.fullName
        }
        return currentGolfer.name.fullName
    }

    private var ownerSubtitle: String? {
        if isSharedEntry,
           let label = viewModel.scoringUnitHandicapLabel(scoringUnitID: scoringSession.scoringUnitID) {
            return label
        }
        if let subtitle = scoringSession.subtitle, subtitle.isPopulated {
            return subtitle
        }
        guard isSharedEntry else { return nil }
        let names = displayParticipants
            .map { viewModel.formatDisplayName(for: $0) }
            .filter(\.isPopulated)
        return names.isPopulated ? names.joined(separator: ", ") : nil
    }

    private var sharedOwnerStrip: some View {
        HStack(spacing: 14) {
            sharedOwnerAvatars

            VStack(alignment: .leading, spacing: 4) {
                Text(ownerTitle)
                    .fontStyle(kFontName, size: 18, weight: .semibold)
                    .foregroundStyle(effectiveAccent)
                    .lineLimit(1)

                if let ownerSubtitle {
                    Text(ownerSubtitle)
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var sharedOwnerAvatars: some View {
        let members = Array(displayParticipants.prefix(4))

        return HStack(spacing: -12) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, participant in
                PlayerAvatarView(
                    initials: sharedInitial(for: participant),
                    size: playerCircleSize * 0.72,
                    fillColor: viewModel.teamColor(for: participant)?.opacity(0.8),
                    glassTint: Color.neutral6,
                    badgeIcon: savedScoreForCurrent != nil && index == 0 ? "checkmark.circle.fill" : nil,
                    badgeIconColor: effectiveAccent,
                    badgeBackgroundColor: palette.backgroundColor,
                    initialsColor: viewModel.teamColor(for: participant) == nil ? palette.foregroundColor : .white
                )
                .overlay {
                    Circle()
                        .stroke(palette.backgroundColor, lineWidth: 2)
                }
                .zIndex(Double(members.count - index))
            }

            if displayParticipants.count > members.count {
                Text("+\(displayParticipants.count - members.count)")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .glassCardEffect(shape: Capsule(), interactive: false, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                    .padding(.leading, 4)
            }
        }
    }

    private func sharedInitial(for participant: RoundParticipant) -> String {
        let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = given.first {
            return String(first).uppercased()
        }
        return String(participant.name.fullName.prefix(1)).uppercased()
    }

    @ViewBuilder
    func handicapDots(for player: RoundParticipant, strokesReceived: Int) -> some View {
        let teamColor = viewModel.teamColor(for: player)
        let dotColor: Color = (viewModel.snapshot.requiresTeams ? teamColor : nil) ?? effectiveAccent
        
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
        let initialScore = savedScoreForCurrent ?? (viewModel.isFriendlyScoreInputMode ? 0 : holePar)
        
        return VStack(spacing: 16) {
            ZStack {
                scoreSelectionDecoration(strokes: draftScore)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: draftScore)
                
                CarouselNumberPicker(
                    values: scoreOptions,
                    initialValue: initialScore,
                    labelForValue: { value in
                        if value == Self.clearScoreSentinel { return "−" }
                        if viewModel.isFriendlyScoreInputMode {
                            return value == 0 ? "0" : (value > 0 ? "+\(value)" : "\(value)")
                        }
                        return "\(value)"
                    },
                    leadingSignFontScale: viewModel.isFriendlyScoreInputMode ? 0.5 : nil
                ) { newValue in
                    if newValue == Self.clearScoreSentinel {
                        draftScore = Self.clearScoreSentinel
                        if savedScoreForCurrent != nil {
                            Task { await clearScore() }
                        } else {
                            Haptics.fire(.light)
                        }
                    } else {
                        draftScore = newValue
                        Haptics.fire(.light)
                    }
                }
                .id(currentGolfer.id) // Force recreation when golfer changes
            }
            .frame(height: scoreInputHeight)

            VStack(spacing: 4) {
                Text(draftScore == Self.clearScoreSentinel
                     ? "No score"
                     : (viewModel.isFriendlyScoreInputMode
                        ? viewModel.friendlyScoreLabel(relativeToPar: draftScore, par: holePar, format: .full)
                        : viewModel.friendlyScoreLabel(strokes: draftScore, par: holePar, format: .full)))
                    .fontStyle(kFontName, size: 28, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                if let netLabel = netScoreLabel {
                    Text(netLabel)
                        .fontStyle(kFontName, size: 17, weight: .medium)
                        .foregroundStyle(effectiveAccent)
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
        if strokes != Self.clearScoreSentinel {
            let diff = viewModel.isFriendlyScoreInputMode ? strokes : (strokes - holePar)
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
    }

    /// Indices that still lack a stored score after this CTA (current row is excluded when `shouldCommitScore()`).
    private var remainingUnscoredIndicesAfterAction: [Int] {
        scoringParticipants.indices.filter { index in
            if index == currentGolferIndex {
                if shouldCommitScore() { return false }
                return currentSavedScore(for: scoringParticipants[index]) == nil
            }
            return currentSavedScore(for: scoringParticipants[index]) == nil
        }
    }

    /// True when every player will have a score for this hole after the current action (non–edit flow only).
    private var holeWillCompleteAfterThisCTA: Bool {
        !isEditMode && remainingUnscoredIndicesAfterAction.isEmpty
    }

    /// Next roster index after this CTA when the hole is not yet complete.
    private func nextIndexAfterCTA() -> Int {
        let remaining = Set(remainingUnscoredIndicesAfterAction)
        guard !remaining.isEmpty else { return currentGolferIndex }

        for step in 1..<scoringParticipants.count {
            let idx = (currentGolferIndex + step) % scoringParticipants.count
            if remaining.contains(idx) { return idx }
        }

        return (currentGolferIndex + 1) % scoringParticipants.count
    }

    var ctaSection: some View {
        let isFinishing = !isEditMode && holeWillCompleteAfterThisCTA

        return VStack(spacing: 12) {
            PrimaryButton(
                title: ctaTitle,
                icon: isFinishing ? "checkmark" : nil,
                labelColor: isFinishing ? effectiveAccentLabelColor : palette.backgroundColor,
                buttonColor: isFinishing ? effectiveAccent : palette.foregroundColor,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTapAsync: { await handleCTA() }
            )

            Text(footerText)
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(isEditMode ? effectiveAccent : Color.neutral2)
        }
    }

    var ctaTitle: String {
        if isEditMode {
            return isDraftChanged ? "Confirm" : "Done"
        }

        if holeWillCompleteAfterThisCTA {
            return "Finish Hole \(holeNumber)"
        }

        if draftScore == Self.clearScoreSentinel {
            return "Next"
        }

        if savedScore == nil {
            return "Confirm & Next"
        }

        return isDraftChanged ? "Change & Next" : "Next"
    }

    var footerText: String {
        guard !isEditMode else { return "All scores entered" }
        guard !holeWillCompleteAfterThisCTA else { return "All scores entered" }
        let nextIndex = nextIndexAfterCTA()
        let next = scoringParticipants[nextIndex]
        return isSharedEntry ? "Shared score entry" : "Next: \(next.name.fullName)"
    }

    func configureInitialState() {
        if isSharedEntry {
            currentGolferIndex = 0
            syncDraftScore(resetDraft: true)
            return
        }

        if isEditMode {
            currentGolferIndex = scoringParticipants.firstIndex(where: { $0.id == scoringSession.participant.id }) ?? 0
        } else {
            let tappedIndex = scoringParticipants.firstIndex(where: { $0.id == scoringSession.participant.id })
            let firstUnscoredIndex = scoringParticipants.firstIndex { p in
                viewModel.scoreInputValue(for: p.id, holeNumber: holeNumber) == nil
            }
            // Open on whoever was tapped (e.g. last in tee order). CTA/footer/route use
            // `holeWillCompleteAfterThisCTA` and `nextIndexAfterCTA()` so unscored players
            // are still surfaced in order without jumping the initial selection.
            currentGolferIndex = tappedIndex ?? firstUnscoredIndex ?? 0
        }
        syncDraftScore(resetDraft: true)
    }

    func trackScoringSheetOpenedIfNeeded() {
        guard !didTrackScoringSheetOpen else { return }
        didTrackScoringSheetOpen = true

        let entryParticipantID = viewModel.currentParticipantID ?? scoringSession.participant.id
        addEvent(
            "live_round.scoring_sheet_opened",
            eventProps: telemetryRoundProperties(
                snapshot: viewModel.snapshot,
                participant: scoringSession.participant,
                teeID: scoringSession.participant.teeBoxID,
                extra: [
                    "hole_number": holeNumber,
                    "entry_participant_id": entryParticipantID,
                    "is_self_scored": entryParticipantID == scoringSession.participant.id,
                    "has_existing_score": savedScoreForCurrent != nil,
                    "is_shared_entry": isSharedEntry,
                    "scoring_unit_id": scoringSession.scoringUnitID
                ]
            )
        )
    }
    
    func jumpToPlayer(_ player: RoundParticipant) {
        guard !isSharedEntry else { return }
        guard let index = scoringParticipants.firstIndex(where: { $0.id == player.id }) else { return }
        guard index != currentGolferIndex else { return }
        
        let golfer = currentGolfer
        let score = draftScore
        let needsSave = shouldCommitScore()

        if needsSave {
            Task {
                await viewModel.setQuickScoreValue(participant: golfer, value: score, holeNumber: holeNumber)
            }
        }

        navigationDirection = index > currentGolferIndex ? .forward : .backward

        withAnimation(.easeInOut(duration: 0.2)) {
            currentGolferIndex = index
        }
    }

    func syncDraftScore(resetDraft: Bool) {
        let saved = savedScoreForCurrent
        savedScore = saved
        if resetDraft {
            let target = saved ?? (viewModel.isFriendlyScoreInputMode ? 0 : holePar)
            draftScore = target
        }
    }

    func syncSavedScore(_ newValue: Int?) {
        guard savedScore != newValue else { return }
        let defaultValue = viewModel.isFriendlyScoreInputMode ? 0 : holePar
        if draftScore == (savedScore ?? defaultValue) {
            draftScore = newValue ?? defaultValue
        }
        savedScore = newValue
    }

    func clearScore() async {
        if isSharedEntry {
            await viewModel.clearScore(
                scoringUnitID: scoringSession.scoringUnitID,
                participant: currentGolfer,
                holeNumber: holeNumber,
                entryMethod: .clear
            )
        } else {
            await viewModel.clearScore(participant: currentGolfer, holeNumber: holeNumber, entryMethod: .clear)
        }
        savedScore = nil
        draftScore = Self.clearScoreSentinel
    }

    private func saveScore(participant: RoundParticipant, value: Int, holeNumber: Int) async {
        if isSharedEntry {
            await viewModel.setScoreInputValue(
                scoringUnitID: scoringSession.scoringUnitID,
                participant: participant,
                holeNumber: holeNumber,
                value: value
            )
        } else {
            await viewModel.setQuickScoreValue(participant: participant, value: value, holeNumber: holeNumber)
        }
    }

    func saveAndClose() {
        let golfer = currentGolfer
        let score = draftScore
        let needsSave = shouldCommitScore()
        if needsSave {
            Task {
                await saveScore(participant: golfer, value: score, holeNumber: holeNumber)
                await MainActor.run { dismiss() }
            }
        } else {
            dismiss()
        }
    }

    func handleCTA() async {
        let golfer = currentGolfer
        let score = draftScore
        let hole = holeNumber
        let needsSave = shouldCommitScore()
        let autoAdvance = viewModel.autoAdvanceWhenHoleComplete
        let willComplete = holeWillCompleteAfterThisCTA
        let nextIdx = nextIndexAfterCTA()
        let simpleForward = currentGolferIndex + 1 < scoringParticipants.count && nextIdx == currentGolferIndex + 1

        if isEditMode {
            dismiss()

            if needsSave {
                Task.detached(priority: .background) {
                    await saveScore(
                        participant: golfer,
                        value: score,
                        holeNumber: hole
                    )
                }
            }
            return
        }

        if willComplete {
            dismiss()

            if needsSave {
                Task.detached(priority: .background) {
                    await saveScore(
                        participant: golfer,
                        value: score,
                        holeNumber: hole
                    )

                    if autoAdvance {
                        await MainActor.run {
                            viewModel.navigateToNextUnscoredHole()
                        }
                    }
                }
            } else if autoAdvance {
                viewModel.navigateToNextUnscoredHole()
            }

            return
        }

        if needsSave && !simpleForward {
            await saveScore(
                participant: golfer,
                value: score,
                holeNumber: hole
            )
        }

        Haptics.fire(.light)
        navigationDirection = .forward

        withAnimation(.easeInOut(duration: 0.2)) {
            currentGolferIndex = nextIdx
        }

        guard needsSave else { return }

        if simpleForward {
            Task.detached(priority: .background) {
                await saveScore(
                    participant: golfer,
                    value: score,
                    holeNumber: hole
                )
            }
        }
    }

    func shouldCommitScore() -> Bool {
        if draftScore == Self.clearScoreSentinel { return false }
        if savedScore == nil { return true }
        return isDraftChanged
    }

    private func currentSavedScore(for participant: RoundParticipant) -> Int? {
        if isSharedEntry {
            return viewModel.scoringUnitScoreInputValue(
                scoringUnitID: scoringSession.scoringUnitID,
                holeNumber: holeNumber
            )
        }
        return viewModel.scoreInputValue(for: participant.id, holeNumber: holeNumber)
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
        LiveHoleScoringView(
            viewModel: viewModel,
            scoringSession: ScoringSession(
                participant: participant,
                holeNumber: viewModel.currentHoleNumber
            )
        )
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

private struct LiveHoleScoringViewPreviewManyPlayers: View {
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant

    init() {
        var snapshot = MockLiveRound2v2.snapshot
        let base = snapshot.participants
        let extras: [RoundParticipant] = base.enumerated().map { index, p in
            var copy = p
            copy.id = "preview_many_\(p.id)"
            copy.userID = "user_preview_many_\(index)"
            copy.playerID = "player_preview_many_\(index)"
            copy.teeOrder = base.count + index + 1
            copy.isHost = false
            return copy
        }
        snapshot.participants = base + extras
        var round = snapshot.round
        round.players = snapshot.participants.compactMap(\.playerID)
        snapshot.round = round

        let appSession = AppSession()
        appSession.ephemeralParticipantID = base.first?.id

        let roundSession = RoundSession()
        roundSession.snapshot = snapshot

        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        vm.currentHoleIndex = 0

        _viewModel = StateObject(wrappedValue: vm)
        participant = base.first!
    }

    var body: some View {
        LiveHoleScoringView(
            viewModel: viewModel,
            scoringSession: ScoringSession(
                participant: participant,
                holeNumber: viewModel.currentHoleNumber
            )
        )
    }
}

#Preview("Live Hole Scoring - No Scores") {
    ZStack {
        BackgroundTheme(palette: .init(theme: .glass, scheme: .dark), theme: .purple)
            .sheet(isPresented: .true) {
            LiveHoleScoringViewPreview(withScores: false)
                .presentationDetents([.height(700)])
        }
    }
}

#Preview("Live Hole Scoring - With Scores") {
    ZStack {
        BackgroundTheme(palette: .init(theme: .glass, scheme: .dark), theme: .purple)
            .sheet(isPresented: .true) {
            LiveHoleScoringViewPreview(withScores: true)
                .presentationDetents([.height(700)])
        }
    }
}

#Preview("Live Hole Scoring - Many players") {
    ZStack {
        BackgroundTheme(palette: .init(theme: .glass, scheme: .dark), theme: .purple)
            .sheet(isPresented: .true) {
                LiveHoleScoringViewPreviewManyPlayers()
                    .presentationDetents([.height(700)])
            }
    }
}
