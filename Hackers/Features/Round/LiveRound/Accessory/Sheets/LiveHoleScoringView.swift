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

    @State private var currentScoringUnitIndex: Int = 0
    @State private var draftScore: Int = 0
    @State private var savedScore: Int?
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var didTrackScoringSheetOpen = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var effectiveAccent: Color {
        viewModel.theme.color
    }
    private var effectiveAccentLabelColor: Color {
        Color.accessibleLabelOnSolidBackground(background: effectiveAccent, colorScheme: colorScheme)
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

    private struct ScoringUnitItem: Identifiable {
        var id: String { scoringUnitID }

        let scoringUnitID: String
        let anchorParticipant: RoundParticipant
        let participants: [RoundParticipant]
        let isShared: Bool
        let accentColor: Color?
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

    private var scoringUnits: [ScoringUnitItem] {
        if isSharedEntry {
            let sharedUnits = viewModel.visibleSharedScoringSubjects.compactMap { subject -> ScoringUnitItem? in
                guard let session = viewModel.sharedScoringSession(for: subject, holeNumber: holeNumber) else {
                    return nil
                }
                return ScoringUnitItem(
                    scoringUnitID: session.scoringUnitID,
                    anchorParticipant: session.participant,
                    participants: session.participants,
                    isShared: true,
                    accentColor: subject.accentColor
                )
            }

            if sharedUnits.isPopulated {
                return sharedUnits
            }

            return [
                ScoringUnitItem(
                    scoringUnitID: scoringSession.scoringUnitID,
                    anchorParticipant: scoringSession.participant,
                    participants: sessionParticipants,
                    isShared: true,
                    accentColor: scoringSession.participant.teamID.flatMap { _ in viewModel.teamColor(for: scoringSession.participant) }
                )
            ]
        }

        let participants = viewModel.scoringParticipants(for: scoringSession)
        let resolvedParticipants = participants.isPopulated ? participants : sessionParticipants
        return resolvedParticipants.map { participant in
            ScoringUnitItem(
                scoringUnitID: participant.id,
                anchorParticipant: participant,
                participants: [participant],
                isShared: false,
                accentColor: viewModel.teamColor(for: participant)
            )
        }
    }

    private var currentScoringUnit: ScoringUnitItem {
        scoringUnits[safe: currentScoringUnitIndex]
            ?? ScoringUnitItem(
                scoringUnitID: scoringSession.scoringUnitID,
                anchorParticipant: scoringSession.participant,
                participants: sessionParticipants,
                isShared: isSharedEntry,
                accentColor: viewModel.teamColor(for: scoringSession.participant)
            )
    }

    private var currentGolfer: RoundParticipant {
        currentScoringUnit.anchorParticipant
    }

    private var hole: Hole? {
        viewModel.hole(for: holeNumber, teeID: viewModel.selectedTeeID)
    }

    private var holePar: Int { hole?.par ?? 4 }
    private var holeYards: Int { hole?.yardage ?? 0 }
    private var holeHandicap: Int? { hole?.handicap }

    private var isEditMode: Bool {
        scoringUnits.isPopulated && scoringUnits.allSatisfy { currentSavedScore(for: $0) != nil }
    }

    private var savedScoreForCurrent: Int? {
        if currentScoringUnit.isShared {
            return viewModel.scoringUnitScoreInputValue(
                scoringUnitID: currentScoringUnit.scoringUnitID,
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
            let minimumRelativeScore = max(-4, 1 - holePar)
            scores = Array(minimumRelativeScore...maxScore)
        } else {
            let minScore = holePar == 4 ? 1 : max(1, holePar - 2)
            let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: holePar)
            let maxScore = max(configMax, savedScoreForCurrent ?? 0)
            scores = Array(minScore...maxScore)
        }
        return [Self.clearScoreSentinel] + scores
    }

    private var netScoreLabel: String? {
        guard viewModel.snapshot.configuration.useHandicaps else { return nil }
        guard draftScore != Self.clearScoreSentinel else { return nil }
        let strokesReceived = currentScoringUnit.isShared
            ? viewModel.scoringUnitStrokesReceived(scoringUnitID: currentScoringUnit.scoringUnitID, holeNumber: holeNumber)
            : viewModel.strokesReceivedOnHole(participant: currentGolfer, holeNumber: holeNumber)
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

            scoringGroupSelector

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
        .onChange(of: savedScoreForCurrent) { _, newValue in
            syncSavedScore(newValue)
        }
    }
}

private extension LiveHoleScoringView {
    var playerName: some View {
        ViewThatFits(in: .horizontal) {
            playerNameText(title(for: currentScoringUnit, style: .full))
                .fixedSize(horizontal: true, vertical: false)

            playerNameText(title(for: currentScoringUnit, style: .compact))
        }
            .id(currentScoringUnit.id)
            .transition(.asymmetric(
                insertion: .move(edge: navigationDirection.edge).combined(with: .opacity),
                removal: .move(edge: navigationDirection == .forward ? .leading : .trailing).combined(with: .opacity)
            ))
    }

    private func playerNameText(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 32, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
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

    var scoringGroupSelector: some View {
        let units = scoringUnits

        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                            scoringUnitDot(for: unit, index: index)
                                .id(unit.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(
                        minWidth: max(0, geo.size.width),
                        maxWidth: .infinity,
                        minHeight: geo.size.height,
                        alignment: .center
                    )
                }
                .scrollClipDisabled()
                .onAppear {
                    proxy.scrollTo(currentScoringUnit.id, anchor: .center)
                }
                .onChange(of: currentScoringUnitIndex) { _, _ in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(currentScoringUnit.id, anchor: .center)
                    }
                }
            }
        }
        .frame(height: playerCircleSize * 1.65)
        .padding(.horizontal, 16)
    }

    private func scoringUnitDot(for unit: ScoringUnitItem, index: Int) -> some View {
        let ratio: CGFloat = 1.2
        let isCurrent = unit.id == currentScoringUnit.id
        let scale: CGFloat = isCurrent ? ratio : 1.0
        let isScored = currentSavedScore(for: unit) != nil
        let members = Array(unit.participants.prefix(4))
        let extraCount = max(0, unit.participants.count - members.count)
        let overlap = playerCircleSize * -0.22
        let groupWidth = playerCircleSize
            + CGFloat(max(0, members.count - 1)) * (playerCircleSize + overlap)
            + (extraCount > 0 ? playerCircleSize * 0.48 : 0)

        return VStack(spacing: 6) {
            HStack(spacing: overlap) {
                ForEach(Array(members.enumerated()), id: \.element.id) { memberIndex, participant in
                    let participantTint = viewModel.teamColor(for: participant) ?? unit.accentColor ?? effectiveAccent
                    let usesFill = unit.isShared && isCurrent
                    let fillColor = usesFill ? participantTint.opacity(0.9) : nil

                    PlayerAvatarView(
                        initials: initials(for: participant),
                        size: playerCircleSize,
                        fillColor: fillColor,
                        glassTint: isCurrent
                            ? participantTint.opacity(colorScheme.translucent)
                            : palette.playerAvatarGlassTint,
                        initialsColor: fillColor.map {
                            Color.accessibleLabelOnSolidBackground(background: $0, colorScheme: colorScheme)
                        } ?? palette.foregroundColor
                    )
                    .overlay {
                        if unit.participants.count > 1 {
                            Circle()
                                .stroke(palette.backgroundColor, lineWidth: 2)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isScored && memberIndex == members.count - 1 {
                            scoringUnitBadge(color: unit.accentColor ?? participantTint)
                        }
                    }
                    .zIndex(Double(members.count - memberIndex))
                }

                if extraCount > 0 {
                    Text("+\(extraCount)")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: playerCircleSize * 0.48, height: playerCircleSize * 0.48)
                        .glassCardEffect(shape: Circle(), interactive: false, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .padding(.leading, 4)
                }
            }
            .scaleEffect(scale, anchor: .bottom)
            .animation(.easeOut(duration: 0.12), value: isCurrent)
            .frame(width: groupWidth, height: playerCircleSize)
        }
        .onTapGesture {
            Haptics.fire(.light)
            jumpToScoringUnit(at: index)
        }
    }

    private func scoringUnitBadge(color: Color) -> some View {
        let badgeSize = playerCircleSize * 0.4

        return ZStack {
            Circle()
                .fill(palette.backgroundColor)
                .frame(width: badgeSize, height: badgeSize)

            Icon(name: "checkmark.circle.fill", size: badgeSize * 0.58, weight: .solid)
                .foregroundStyle(color)
        }
        .padding(.top, -1 * badgeSize / 4)
        .padding(.trailing, -1 * badgeSize / 4)
        .zIndex(10)
    }

    private enum ScoringUnitTitleStyle {
        case full, compact
    }

    private func title(for unit: ScoringUnitItem, style: ScoringUnitTitleStyle) -> String {
        let participants = unit.participants
        guard participants.isPopulated else {
            return scoringSession.title ?? unit.anchorParticipant.name.fullName
        }

        if participants.count >= 3 {
            let compactNames = participants
                .map(compactName(for:))
                .filter(\.isPopulated)
            return compactNames.isPopulated ? compactNames.joined(separator: ", ") : scoringSession.title ?? "Group Score"
        }

        let names = participants
            .map { participant in
                style == .full ? fullName(for: participant) : compactName(for: participant)
            }
            .filter(\.isPopulated)
        let separator = participants.count == 2 ? " + " : ""
        return names.isPopulated ? names.joined(separator: separator) : scoringSession.title ?? "Group Score"
    }

    private func fullName(for participant: RoundParticipant) -> String {
        let name = participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isPopulated ? name : compactName(for: participant)
    }

    private func compactName(for participant: RoundParticipant) -> String {
        let name = viewModel.nameDisplayFormat.displayName(for: participant.name)
        return name.isPopulated ? name : participant.name.fullName
    }

    private func initials(for participant: RoundParticipant) -> String {
        let initials = participant.name.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if initials.isPopulated {
            return initials.uppercased()
        }
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
        return VStack(spacing: 16) {
            ZStack {
                scoreSelectionDecoration(strokes: draftScore)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: draftScore)
                
                CarouselNumberPicker(
                    values: scoreOptions,
                    selectedValue: $draftScore,
                    labelForValue: { value in
                        if value == Self.clearScoreSentinel { return "−" }
                        let displayedStrokes = ScoreCarouselSelection.displayedStrokes(
                            for: value,
                            par: holePar,
                            isFriendlyMode: viewModel.isFriendlyScoreInputMode
                        )
                        return "\(displayedStrokes)"
                    },
                    leadingSignFontScale: nil
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

    /// Indices that still lack a stored score after this CTA (current unit is excluded when `shouldCommitScore()`).
    private var remainingUnscoredIndicesAfterAction: [Int] {
        scoringUnits.indices.filter { index in
            if index == currentScoringUnitIndex {
                if shouldCommitScore() { return false }
                return currentSavedScore(for: scoringUnits[index]) == nil
            }
            return currentSavedScore(for: scoringUnits[index]) == nil
        }
    }

    /// True when every scoring unit will have a score for this hole after the current action (non–edit flow only).
    private var holeWillCompleteAfterThisCTA: Bool {
        !isEditMode && remainingUnscoredIndicesAfterAction.isEmpty
    }

    /// Next roster index after this CTA when the hole is not yet complete.
    private func nextIndexAfterCTA() -> Int {
        let remaining = Set(remainingUnscoredIndicesAfterAction)
        guard !remaining.isEmpty else { return currentScoringUnitIndex }

        for step in 1..<scoringUnits.count {
            let idx = (currentScoringUnitIndex + step) % scoringUnits.count
            if remaining.contains(idx) { return idx }
        }

        return (currentScoringUnitIndex + 1) % scoringUnits.count
    }

    private var scoreProgressText: String {
        let total = scoringUnits.count
        guard total > 0 else { return "No scores entered" }
        let completedStored = scoringUnits.indices.filter { index in
            currentSavedScore(for: scoringUnits[index]) != nil
        }.count
        let completed = min(total, completedStored + (shouldCommitScore() && savedScore == nil ? 1 : 0))
        let scoreNoun = scoringUnits.contains { $0.isShared || $0.participants.count > 1 }
            ? "group scores"
            : "scores"
        return "\(completed) of \(total) \(scoreNoun) entered"
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
        return scoreProgressText
    }

    func configureInitialState() {
        let units = scoringUnits

        if isEditMode {
            currentScoringUnitIndex = initialScoringUnitIndex(in: units) ?? 0
        } else {
            let tappedIndex = initialScoringUnitIndex(in: units)
            let firstUnscoredIndex = units.firstIndex { unit in
                currentSavedScore(for: unit) == nil
            }
            // Open on the tapped scoring unit when possible while still surfacing unscored units in CTA order.
            currentScoringUnitIndex = tappedIndex ?? firstUnscoredIndex ?? 0
        }
        syncDraftScore(resetDraft: true)
    }

    private func initialScoringUnitIndex(in units: [ScoringUnitItem]) -> Int? {
        units.firstIndex { unit in
            unit.scoringUnitID == scoringSession.scoringUnitID
                || unit.participants.contains { $0.id == scoringSession.participant.id }
        }
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
    
    func moveToAdjacentUnit(direction: Int) {
        guard scoringUnits.count > 1 else { return }
        let next = (currentScoringUnitIndex + direction + scoringUnits.count) % scoringUnits.count
        jumpToScoringUnit(at: next)
    }

    func jumpToScoringUnit(at index: Int) {
        guard scoringUnits.indices.contains(index) else { return }
        guard index != currentScoringUnitIndex else { return }

        let unit = currentScoringUnit
        let score = draftScore
        let needsSave = shouldCommitScore()

        if needsSave {
            Task {
                await saveScore(unit: unit, value: score, holeNumber: holeNumber)
            }
        }

        navigationDirection = index > currentScoringUnitIndex ? .forward : .backward

        withAnimation(.easeOut(duration: 0.12)) {
            selectScoringUnit(at: index)
        }
    }

    func selectScoringUnit(at index: Int) {
        guard scoringUnits.indices.contains(index) else { return }
        let nextSavedScore = currentSavedScore(for: scoringUnits[index])
        currentScoringUnitIndex = index
        savedScore = nextSavedScore
        draftScore = ScoreCarouselSelection.initialValue(
            savedScore: nextSavedScore,
            par: holePar,
            isFriendlyMode: viewModel.isFriendlyScoreInputMode
        )
    }

    func syncDraftScore(resetDraft: Bool) {
        let saved = savedScoreForCurrent
        savedScore = saved
        if resetDraft {
            let target = ScoreCarouselSelection.initialValue(
                savedScore: saved,
                par: holePar,
                isFriendlyMode: viewModel.isFriendlyScoreInputMode
            )
            draftScore = target
        }
    }

    func syncSavedScore(_ newValue: Int?) {
        guard savedScore != newValue else { return }
        let defaultValue = ScoreCarouselSelection.initialValue(
            savedScore: nil,
            par: holePar,
            isFriendlyMode: viewModel.isFriendlyScoreInputMode
        )
        if draftScore == (savedScore ?? defaultValue) {
            draftScore = newValue ?? defaultValue
        }
        savedScore = newValue
    }

    func clearScore() async {
        let unit = currentScoringUnit
        if unit.isShared {
            await viewModel.clearScore(
                scoringUnitID: unit.scoringUnitID,
                participant: unit.anchorParticipant,
                holeNumber: holeNumber,
                entryMethod: .clear
            )
        } else {
            await viewModel.clearScore(participant: unit.anchorParticipant, holeNumber: holeNumber, entryMethod: .clear)
        }
        savedScore = nil
        draftScore = Self.clearScoreSentinel
    }

    private func saveScore(unit: ScoringUnitItem, value: Int, holeNumber: Int) async {
        if unit.isShared {
            await viewModel.setScoreInputValue(
                scoringUnitID: unit.scoringUnitID,
                participant: unit.anchorParticipant,
                holeNumber: holeNumber,
                value: value,
                participantIDs: unit.participants.map(\.id)
            )
        } else {
            await viewModel.setQuickScoreValue(participant: unit.anchorParticipant, value: value, holeNumber: holeNumber)
        }
    }

    func saveAndClose() {
        let unit = currentScoringUnit
        let score = draftScore
        let needsSave = shouldCommitScore()
        if needsSave {
            Task {
                await saveScore(unit: unit, value: score, holeNumber: holeNumber)
                await MainActor.run { dismiss() }
            }
        } else {
            dismiss()
        }
    }

    func handleCTA() async {
        let unit = currentScoringUnit
        let score = draftScore
        let hole = holeNumber
        let needsSave = shouldCommitScore()
        let autoAdvance = viewModel.autoAdvanceWhenHoleComplete

        if isEditMode {
            if needsSave {
                await saveScore(
                    unit: unit,
                    value: score,
                    holeNumber: hole
                )
            }
            dismiss()
            return
        }

        // Resolve navigation from the current draft before starting the write. This
        // keeps the roster deterministic without making the UI wait on Firestore.
        let willComplete = holeWillCompleteAfterThisCTA
        let nextIdx = nextIndexAfterCTA()

        if needsSave {
            Task {
                await saveScore(
                    unit: unit,
                    value: score,
                    holeNumber: hole
                )
            }
        }

        if willComplete {
            dismiss()

            if autoAdvance {
                viewModel.navigateToNextUnscoredHole()
            }
            return
        }

        Haptics.fire(.light)
        navigationDirection = .forward

        withAnimation(.easeOut(duration: 0.12)) {
            selectScoringUnit(at: nextIdx)
        }
    }

    func shouldCommitScore() -> Bool {
        if draftScore == Self.clearScoreSentinel { return false }
        if savedScore == nil { return true }
        return isDraftChanged
    }

    private func currentSavedScore(for unit: ScoringUnitItem) -> Int? {
        if unit.isShared {
            return viewModel.scoringUnitScoreInputValue(
                scoringUnitID: unit.scoringUnitID,
                holeNumber: holeNumber
            )
        }
        return viewModel.scoreInputValue(for: unit.anchorParticipant.id, holeNumber: holeNumber)
    }
}

// MARK: - Preview

private enum LiveHoleScoringPreviewMode {
    case individual
    case sharedPairs
    case sharedAll
}

private struct LiveHoleScoringViewPreview: View {
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant
    private let mode: LiveHoleScoringPreviewMode
    
    init(withScores: Bool = false, mode: LiveHoleScoringPreviewMode = .individual) {
        var snapshot = MockLiveRound2v2.snapshot
        Self.configureSnapshot(&snapshot, mode: mode)
        
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
        self.mode = mode
    }
    
    var body: some View {
        switch mode {
        case .individual:
            LiveHoleScoringView(
                viewModel: viewModel,
                scoringSession: ScoringSession(
                    participant: participant,
                    holeNumber: viewModel.currentHoleNumber
                )
            )
        case .sharedPairs, .sharedAll:
            if let subject = viewModel.visibleSharedScoringSubjects.first,
               let session = viewModel.sharedScoringSession(for: subject, holeNumber: viewModel.currentHoleNumber) {
                LiveHoleScoringView(viewModel: viewModel, scoringSession: session)
            } else {
                LiveHoleScoringView(
                    viewModel: viewModel,
                    scoringSession: ScoringSession(
                        participant: participant,
                        participants: [participant],
                        scoringUnitID: participant.id,
                        isSharedEntry: true,
                        holeNumber: viewModel.currentHoleNumber
                    )
                )
            }
        }
    }

    private static func configureSnapshot(_ snapshot: inout RoundSnapshot, mode: LiveHoleScoringPreviewMode) {
        switch mode {
        case .individual:
            return
        case .sharedPairs:
            var round = snapshot.round
            var configuration = round.configuration
            configuration.formatSummary = RoundFormatSummary(from: FormatTemplateRegistry.alternateShot)
            configuration.scoreOwnerScope = .partnership
            round.configuration = configuration
            snapshot.round = round

            let participants = snapshot.participants
                .filter(\.isPresenceActive)
                .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
            let firstPair = Array(participants.prefix(2))
            let secondPair = Array(participants.dropFirst(2).prefix(2))
            snapshot.scoringGroups = [
                scoringGroup(id: "preview_pair_1", participants: firstPair, roundID: snapshot.round.id),
                scoringGroup(id: "preview_pair_2", participants: secondPair, roundID: snapshot.round.id)
            ].compactMap(\.self)
        case .sharedAll:
            var round = snapshot.round
            var configuration = round.configuration
            configuration.formatSummary = RoundFormatSummary(from: FormatTemplateRegistry.captainsChoice)
            configuration.scoreOwnerScope = .individual
            round.configuration = configuration
            snapshot.round = round
            snapshot.teams = []
        }
    }

    private static func scoringGroup(
        id: String,
        participants: [RoundParticipant],
        roundID: String
    ) -> RoundScoringGroup? {
        let memberIDs = participants.map(\.id)
        guard memberIDs.count == 2 else { return nil }
        return RoundScoringGroup(
            id: id,
            teamID: participants.compactMap(\.teamID).first,
            teeGroupID: participants.compactMap(\.groupID).first,
            kind: .partnership,
            memberIDs: memberIDs,
            parentID: roundID
        )
    }

    private static func makePreviewScores(snapshot: RoundSnapshot) -> [ScoreEntry] {
        let holes = snapshot.defaultTee?.holes ?? snapshot.tees.first?.holes
        guard let holes else { return [] }
        let participants = snapshot.participants
        let segmentID = "segment_preview"

        if snapshot.isSharedScoreSource {
            return snapshot.sharedPreviewScoreAnchors.flatMap { anchor in
                holes.prefix(1).compactMap { hole in
                    let strokes = max(1, hole.par + 1)
                    return ScoreEntry(
                        id: ScoreEntry.makeID(hole: hole.number, segment: segmentID, scoringUnit: anchor.scoringUnitID),
                        holeNumber: hole.number,
                        segmentID: segmentID,
                        groupID: anchor.participants.first?.groupID ?? "group_1",
                        scoringUnitID: anchor.scoringUnitID,
                        participantIDs: anchor.participants.map(\.id),
                        strokes: strokes,
                        pickedUp: false,
                        entryID: anchor.participants.first?.id ?? anchor.scoringUnitID,
                        createdAt: .init(),
                        lastUpdatedAt: .init(),
                        parentID: snapshot.round.id
                    )
                }
            }
        }

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

private extension RoundSnapshot {
    var sharedPreviewScoreAnchors: [(scoringUnitID: String, participants: [RoundParticipant])] {
        let activeParticipants = participants
            .filter(\.isPresenceActive)
            .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }

        switch configuration.scoreOwnerScope {
        case .partnership:
            return scoringGroups.map { group in
                (
                    scoringUnitID: scoringUnitID(forPreviewScoringGroup: group),
                    participants: group.memberIDs.compactMap { id in
                        activeParticipants.first { $0.id == id }
                    }
                )
            }
        case .individual, .teeGroup:
            return [("shared_all", activeParticipants)]
        }
    }

    private func scoringUnitID(forPreviewScoringGroup group: RoundScoringGroup) -> String {
        if let unit = roundSegment?.scoringUnits.first(where: { $0.id == group.id }) {
            return unit.id
        }
        return group.id
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

#Preview("Live Hole Scoring - Shared pairs") {
    ZStack {
        BackgroundTheme(palette: .init(theme: .glass, scheme: .dark), theme: .purple)
            .sheet(isPresented: .true) {
                LiveHoleScoringViewPreview(mode: .sharedPairs)
                    .presentationDetents([.height(700)])
            }
    }
}

#Preview("Live Hole Scoring - Shared all") {
    ZStack {
        BackgroundTheme(palette: .init(theme: .glass, scheme: .dark), theme: .purple)
            .sheet(isPresented: .true) {
                LiveHoleScoringViewPreview(mode: .sharedAll)
                    .presentationDetents([.height(700)])
            }
    }
}
