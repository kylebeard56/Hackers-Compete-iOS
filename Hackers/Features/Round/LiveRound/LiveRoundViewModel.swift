//
//  LiveRoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/30/26.
//

import Combine
import SwiftUI

enum NameDisplayFormat: String, CaseIterable {
    /// "J. Smith"
    case firstInitialLastName
    /// "John S."
    case firstNameLastInitial
}

@MainActor
final class LiveRoundViewModel: ObservableObject, Loggable {
    struct SeriesAccessOverride {
        let seriesID: String?
        let isCommissioner: Bool
    }

    struct VisibleGroupSwitchRequest: Equatable {
        let groupID: String
        let targetHoleNumber: Int
        let revisionID: UUID
    }
    
    // MARK: - State
    
    @Published private(set) var snapshot: RoundSnapshot = .init()
    @Published private(set) var currentParticipantID: String?
    @Published private(set) var visibleTeeGroupID: String?
    @Published private(set) var visibleGroupSwitchRequest: VisibleGroupSwitchRequest?
    @Published private(set) var resolvedSeriesID: String?
    @Published private(set) var isSeriesCommissioner: Bool = false
    @Published var selectedTeeID: String?
    @Published var nameDisplayFormat: NameDisplayFormat = .firstNameLastInitial
    @Published var theme: GolfTheme = .purple
    @Published var isSpectator: Bool = false
    
    /// The hole last explicitly selected (tap on HoleWindowSelector or navigateToNextUnscoredHole).
    /// Used for programmatic pager scroll. Does not sync with user scroll—scoringPageHole is the
    /// source of truth for "which hole is being viewed."
    @Published var currentHoleIndex: Int = 0
    @Published var scoreBasis: ScoreBasis = .gross
    @Published var leaderboardMode: LeaderboardMode = .individual
    
    var handicapsEnabled: Bool {
        snapshot.configuration.useHandicaps
    }

    var isCurrentUserHost: Bool {
        guard let id = currentParticipantID else { return false }
        return snapshot.participants.first(where: { $0.id == id })?.isHost == true
    }
    
    /// Pin/favorite players to top of leaderboard
    @Published var pinnedParticipantIDs: Set<String> = []
    
    /// Custom entry
    @Published var showCustomScorePrompt: Bool = false
    @Published var customScoreText: String = ""
    @Published var customScoreParticipant: RoundParticipant?
    /// Hole for custom score entry; set when prompting, used when submitting.
    private var customScoreHoleNumber: Int?
    
    /// Scorecard sheet
    @Published var presentedParticipant: RoundParticipant?

    /// Live hole scoring sheet
    @Published var presentedScoringSession: ScoringSession?
    @Published var presenceErrorMessage: String?
    
    /// Scorecard visibility: which participants appear in FullScorecardView
    @Published var visibleParticipantIDs: Set<String> = []
    private var lastAppliedVisibleParticipantIDs: Set<String> = []
    /// When true, user has intentionally configured visibility (including "hide all"). Prevents auto-fill from overwriting.
    private var hasInitializedVisibilitySelection: Bool = false
    
    /// When true, auto-navigate to next hole when current hole is fully scored (user or realtime).
    /// Persisted; useful when following along as others score.
    @Published var autoAdvanceWhenHoleComplete: Bool = true

    /// Set when we auto-navigate; view shows "Jumped to Hole #" toast. Cleared after delay.
    @Published var jumpedToHoleNumber: Int?
    
    /// When this device last successfully wrote a score (setScore or clearScore).
    @Published private(set) var lastLocalScoreAt: Date?
    /// When true, "Mark as max score" is in progress.
    @Published private(set) var isApplyingMaxScores: Bool = false
    /// When we last received snapshot data from any Firebase listener. Synced from RoundSession.
    @Published private(set) var lastSnapshotReceivedAt: Date?
    private(set) var usedMaxScoreFill = false
    
    // MARK: - Wiring
    
    private weak var appSession: AppSession?
    private weak var roundSession: RoundSession?
    private var cancellables: Set<AnyCancellable> = []
    
    /// O(1) lookup by (participantID, holeNumber). Rebuilt when snapshot changes.
    private var scoreIndex: [String: ScoreEntry] = [:]
    /// Cached engine result, invalidated when snapshot changes.
    private var cachedEngineResult: ScoringResult?
    private var hasPerformedInitialHoleNudge = false
    private var loadedSeriesAccessRoundID: String?
    private var isLoadingSeriesAccess = false

    var seriesAccessOverride: SeriesAccessOverride?
    
    func bind(appSession: AppSession, roundSession: RoundSession) {
        // Avoid duplicate bindings
        if self.roundSession === roundSession { return }
        
        self.appSession = appSession
        self.roundSession = roundSession
        self.isSpectator = appSession.isSpectating

        resetRoundScopedStateIfNeeded(for: roundSession.snapshot.round.id)
        snapshot = roundSession.snapshot
        lastSnapshotReceivedAt = roundSession.lastSnapshotReceivedAt
        usedMaxScoreFill = false
        rebuildScoreIndex()
        syncVisibleTeeGroupIfNeeded()
        updateSelectedTeeIfNeeded()
        
        if snapshot.configuration.useHandicaps {
            scoreBasis = .net
        }
        
        roundSession.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                guard let self else { return }
                let currentHole = self.currentHoleNumber
                let wasIncomplete = self.holeCompletionProgress(holeNumber: currentHole) < 1

                self.resetRoundScopedStateIfNeeded(for: s.round.id)

                self.snapshot = s
                self.rebuildScoreIndex()
                self.syncVisibleTeeGroupIfNeeded()
                self.ensureHoleIndexInBounds()
                self.updateSelectedTeeIfNeeded()

                let modes = self.availableLeaderboardModes
                if !modes.contains(self.leaderboardMode) {
                    self.leaderboardMode = .individual
                }

                if !s.configuration.useHandicaps {
                    self.scoreBasis = .gross
                }

                if !self.hasInitializedVisibilitySelection && self.visibleParticipantIDs.isEmpty && !s.participants.isEmpty {
                    self.visibleParticipantIDs = Set(s.participants.map(\.id))
                    self.lastAppliedVisibleParticipantIDs = self.visibleParticipantIDs
                    self.hasInitializedVisibilitySelection = true
                }

                if wasIncomplete && self.holeCompletionProgress(holeNumber: currentHole) >= 1 && self.autoAdvanceWhenHoleComplete {
                    self.navigateToNextUnscoredHole()
                }

                Task {
                    await self.clearStaleSpectatorSessionFlagIfPlayingThisRound()
                    await self.resolveCurrentParticipantIDIfNeeded()
                    await self.loadSeriesAccessIfNeeded()
                    self.syncVisibleTeeGroupIfNeeded()
                    self.scheduleInitialHoleNudgeIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        roundSession.$lastSnapshotReceivedAt
            .receive(on: RunLoop.main)
            .sink { [weak self] date in
                self?.lastSnapshotReceivedAt = date
            }
            .store(in: &cancellables)

        $scoreBasis
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.cachedEngineResult = nil
            }
            .store(in: &cancellables)
        
        Task {
            await clearStaleSpectatorSessionFlagIfPlayingThisRound()
            await resolveCurrentParticipantIDIfNeeded()
            await loadSeriesAccessIfNeeded()
            syncVisibleTeeGroupIfNeeded()
            scheduleInitialHoleNudgeIfNeeded()
        }
    }
    
    func ensureParticipantResolved() async {
        await resolveCurrentParticipantIDIfNeeded()
    }

    func set(snapshot: RoundSnapshot) {
        resetRoundScopedStateIfNeeded(for: snapshot.round.id)
        self.snapshot = snapshot
        rebuildScoreIndex()
        syncVisibleTeeGroupIfNeeded()
        updateSelectedTeeIfNeeded()
        if !hasInitializedVisibilitySelection && visibleParticipantIDs.isEmpty && !snapshot.participants.isEmpty {
            visibleParticipantIDs = Set(snapshot.participants.map(\.id))
            lastAppliedVisibleParticipantIDs = visibleParticipantIDs
            hasInitializedVisibilitySelection = true
        }
    }
    
    // MARK: - Holes

    /// Course order (hole range only). Used for aggregates and completion counts where order does not matter.
    private func courseHoleNumbers(for snap: RoundSnapshot) -> [Int] {
        LiveRoundHoleOrdering.courseHoleNumbers(holeRange: snap.holeRange)
    }

    /// Play order for the visible tee group (tab bar, pager, navigation).
    var holeNumbers: [Int] {
        LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: snapshot.holeRange,
            teeGroupID: visibleTeeGroupID,
            teeGroups: snapshot.teeGroups
        )
    }

    /// Course numeric order (e.g. full scorecard columns). Ignores tee group `startingHole` rotation.
    var courseOrderHoleNumbers: [Int] {
        courseHoleNumbers(for: snapshot)
    }
    
    var currentHoleNumber: Int {
        let holes = holeNumbers
        guard !holes.isEmpty else { return 1 }
        let idx = min(max(0, currentHoleIndex), holes.count - 1)
        return holes[idx]
    }
    
    func swipeHole(direction: Int) {
        // direction: -1 previous, +1 next
        let next = currentHoleIndex + direction
        currentHoleIndex = min(max(0, next), max(0, holeNumbers.count - 1))
    }
    
    func selectHole(_ holeNumber: Int) {
        guard let idx = holeNumbers.firstIndex(of: holeNumber) else { return }
        currentHoleIndex = idx
    }

    var nextUnscoredHoleNumber: Int? {
        let players = activeTeeGroupParticipants
        guard players.isPopulated else { return nil }
        return holeNumbers.first { hole in
            holeCompletionProgress(holeNumber: hole) < 1
        }
    }

    func navigateToNextUnscoredHole() {
        if let next = nextUnscoredHoleNumber, next != currentHoleNumber {
            withAnimation {
                selectHole(next)
                jumpedToHoleNumber = next
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                jumpedToHoleNumber = nil
            }
        }
        // All holes scored → stay on current hole
    }
    
    enum HoleDisplayState {
        case current
        case completed
        case error
        case unscored
    }
    
    func holeState(for holeNumber: Int) -> HoleDisplayState {
        holeState(for: holeNumber, currentHoleOverride: nil)
    }

    /// Same as holeState(for:) but uses currentHoleOverride for "current" and "error" (skipped) logic
    /// when the displayed hole differs from currentHoleNumber (e.g. user scrolled without syncing).
    func holeState(for holeNumber: Int, currentHoleOverride: Int?) -> HoleDisplayState {
        let current = currentHoleOverride ?? currentHoleNumber
        if holeNumber == current { return .current }
        let progress = holeCompletionProgress(holeNumber: holeNumber)
        if progress >= 1 { return .completed }
        let order = holeNumbers
        if LiveRoundHoleOrdering.isIncompletePastInPlayOrder(
            playOrder: order,
            holeNumber: holeNumber,
            currentHole: current
        ) {
            return .error
        }
        return .unscored
    }
    
    private func ensureHoleIndexInBounds() {
        let maxIdx = max(0, holeNumbers.count - 1)
        currentHoleIndex = min(max(0, currentHoleIndex), maxIdx)
    }
    
    // MARK: - Tee Group

    var orderedTeeGroups: [TeeTimeGroup] {
        snapshot.teeGroups.sorted { $0.index < $1.index }
    }

    var actualParticipant: RoundParticipant? {
        guard let id = currentParticipantID else { return nil }
        return snapshot.participants.first(where: { $0.id == id })
    }

    var currentParticipant: RoundParticipant? { actualParticipant }

    var actualTeeGroupID: String? { actualParticipant?.groupID }
    var currentTeeGroupID: String? { actualTeeGroupID }

    var visibleTeeGroupParticipants: [RoundParticipant] {
        participantsInTeeGroup(in: snapshot, groupID: visibleTeeGroupID)
    }

    var teeGroupParticipants: [RoundParticipant] { visibleTeeGroupParticipants }

    var activeTeeGroupParticipants: [RoundParticipant] {
        activeParticipantsInTeeGroup(in: snapshot, groupID: visibleTeeGroupID)
    }

    var actualTeeGroupParticipants: [RoundParticipant] {
        participantsInTeeGroup(in: snapshot, groupID: actualTeeGroupID)
    }

    var activeActualTeeGroupParticipants: [RoundParticipant] {
        activeParticipantsInTeeGroup(in: snapshot, groupID: actualTeeGroupID)
    }

    var isViewingAlternateGroup: Bool {
        guard let actualTeeGroupID,
              let visibleTeeGroupID else { return false }
        return actualTeeGroupID != visibleTeeGroupID
    }

    var canEditActualGroupScores: Bool {
        !isSpectator && actualParticipant != nil
    }

    private var canProxySeriesGroupScoring: Bool {
        isSeriesCommissioner && resolvedSeriesID?.isPopulated == true
    }

    var canProxyVisibleGroupScoring: Bool {
        canProxySeriesGroupScoring && visibleTeeGroupID?.isPopulated == true
    }

    var canScoreVisibleGroup: Bool {
        canEditActualGroupScores || canProxyVisibleGroupScoring
    }

    var canCompleteActualGroup: Bool {
        canEditActualGroupScores && !isViewingAlternateGroup
    }

    var canChangeVisibleGroup: Bool {
        isSeriesCommissioner && resolvedSeriesID?.isPopulated == true && orderedTeeGroups.count > 1
    }

    func canEditScorecard(participant: RoundParticipant) -> Bool {
        canEditActualGroupScores
            && participant.isPresenceActive
            && activeActualTeeGroupParticipants.contains(where: { $0.id == participant.id })
    }

    func canEditPresence(participant: RoundParticipant) -> Bool {
        canScoreVisibleGroup && visibleTeeGroupParticipants.contains(where: { $0.id == participant.id })
    }

    func canMarkParticipantNoShow(participant: RoundParticipant) -> Bool {
        canEditPresence(participant: participant) && !hasRecordedScores(for: participant)
    }

    func canResetPresenceToUnconfirmed(participant: RoundParticipant) -> Bool {
        canEditPresence(participant: participant) && !hasRecordedScores(for: participant)
    }

    func selectVisibleTeeGroup(_ groupID: String) {
        guard orderedTeeGroups.contains(where: { $0.id == groupID }) else { return }
        let targetHoleNumber = targetHoleNumber(forVisibleGroupID: groupID)
        visibleTeeGroupID = groupID
        selectHole(targetHoleNumber)
        ensureHoleIndexInBounds()
        updateSelectedTeeIfNeeded(force: true)
        visibleGroupSwitchRequest = VisibleGroupSwitchRequest(
            groupID: groupID,
            targetHoleNumber: targetHoleNumber,
            revisionID: UUID()
        )
    }

    func groupMenuSubtitle(for group: TeeTimeGroup) -> String {
        participantsInTeeGroup(in: snapshot, groupID: group.id)
            .map { formatDisplayName(for: $0) }
            .filter { $0.isPopulated }
            .joined(separator: ", ")
    }

    struct TeamSection: Identifiable {
        let id: String
        let team: RoundTeam?
        let participants: [RoundParticipant]
    }

    var expectedMatchupMode: MatchupMode {
        snapshot.configuration.scoreOwnerScope == .individual
            ? (snapshot.requiresTeams ? .team : .individual)
            : .scoreOwner
    }
    
    func team(for participant: RoundParticipant) -> RoundTeam? {
        guard let id = participant.teamID else { return nil }
        return snapshot.teams.first(where: { $0.id == id })
    }
    
    func teamColor(for participant: RoundParticipant) -> Color? {
        snapshot.teamColor(for: participant)
    }
    
    /// True when any team's color matches the theme color (e.g. Purple team + purple theme).
    /// Use palette.foregroundColor for general UI in this case to avoid confusing team-specific vs neutral actions.
    var hasTeamColorMatchingTheme: Bool {
        guard snapshot.requiresTeams, snapshot.teams.isPopulated else { return false }
        return snapshot.teams.contains { $0.displaySwatchColor == theme.color }
    }
    
    /// Groups the tee group by team, when the round requires teams.
    var teeGroupTeamSections: [TeamSection] {
        let players = teeGroupParticipants
        guard snapshot.requiresTeams, snapshot.teams.isPopulated else {
            return [TeamSection(id: "all", team: nil, participants: players)]
        }
        
        let grouped = Dictionary(grouping: players, by: { $0.teamID })
        
        // Order by team index, with unassigned last.
        let orderedTeams = snapshot.teams.sorted(by: { $0.index < $1.index })
        var sections: [TeamSection] = []
        
        for team in orderedTeams {
            let members = (grouped[team.id] ?? [])
                .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
            if members.isPopulated {
                sections.append(TeamSection(id: team.id, team: team, participants: members))
            }
        }
        
        if let unassigned = grouped[nil], unassigned.isPopulated {
            sections.append(
                TeamSection(
                    id: "unassigned",
                    team: nil,
                    participants: unassigned.sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
                )
            )
        }
        
        if sections.isEmpty {
            return [TeamSection(id: "all", team: nil, participants: players)]
        }
        
        return sections
    }

    func participants(for scoringGroup: RoundScoringGroup) -> [RoundParticipant] {
        scoringGroup.memberIDs
            .compactMap { id in snapshot.participants.first(where: { $0.id == id }) }
            .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
    }

    func partnershipGroup(for participant: RoundParticipant) -> RoundScoringGroup? {
        snapshot.scoringGroups.first {
            $0.kind == .partnership && $0.memberIDs.contains(participant.id)
        }
    }

    func partnershipGroups(in participants: [RoundParticipant]) -> [RoundScoringGroup] {
        let participantIDs = Set(participants.map(\.id))
        return snapshot.scoringGroups
            .filter { $0.kind == .partnership && Set($0.memberIDs).isSubset(of: participantIDs) }
            .sorted { lhs, rhs in
                let lhsOrder = self.participants(for: lhs).first?.teeOrder ?? Int.max
                let rhsOrder = self.participants(for: rhs).first?.teeOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return scoringGroupLabel(lhs) < scoringGroupLabel(rhs)
            }
    }

    func scoringGroupLabel(_ scoringGroup: RoundScoringGroup) -> String {
        if let label = scoringGroup.label, label.isPopulated {
            return label
        }

        let memberNames = participants(for: scoringGroup)
            .map { formatDisplayName(for: $0) }
            .filter(\.isPopulated)
        if memberNames.isPopulated {
            return memberNames.joined(separator: " + ")
        }

        switch scoringGroup.kind {
        case .partnership:
            return "Partnership"
        case .teeGroup:
            return "Group Score"
        }
    }

    func scoringGroupSubtitle(_ scoringGroup: RoundScoringGroup) -> String? {
        let members = participants(for: scoringGroup)
            .map { $0.name.fullName }
            .filter(\.isPopulated)
        guard members.isPopulated else { return nil }
        return members.joined(separator: ", ")
    }

    func scoringGroupAccentColor(_ scoringGroup: RoundScoringGroup) -> Color? {
        if let teamID = scoringGroup.teamID,
           let team = snapshot.teams.first(where: { $0.id == teamID }) {
            return team.displaySwatchColor
        }

        let teamIDs = Set(participants(for: scoringGroup).compactMap(\.teamID))
        guard teamIDs.count == 1,
              let teamID = teamIDs.first,
              let team = snapshot.teams.first(where: { $0.id == teamID }) else {
            return nil
        }
        return team.displaySwatchColor
    }

    func countedBallLabel(for scoringGroup: RoundScoringGroup, holeNumber: Int) -> String? {
        let members = participants(for: scoringGroup)
        guard scoringGroup.kind == .partnership, members.count == 2 else { return nil }
        let scores: [(participant: RoundParticipant, value: Int)] = members.compactMap { participant in
            let value: Int?
            switch scoreBasis {
            case .gross:
                value = grossStrokes(for: participant.id, holeNumber: holeNumber)
            case .net:
                value = netStrokesOnHole(participant: participant, holeNumber: holeNumber)
            }
            guard let value else { return nil }
            return (participant, value)
        }

        guard scores.count == members.count else { return nil }
        guard let best = scores.map(\.value).min() else { return nil }
        let counted = scores.filter { $0.value == best }.map(\.participant)
        if counted.count == 1, let participant = counted.first {
            return "\(formatDisplayName(for: participant)) counting"
        }
        return "Best ball tied"
    }

    func scoringSession(
        for participant: RoundParticipant,
        holeNumber: Int,
        roster: [RoundParticipant]? = nil
    ) -> ScoringSession {
        let resolvedRoster = (roster?.isPopulated == true ? roster! : activeTeeGroupParticipants)
            .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
        return ScoringSession(
            participant: participant,
            participants: resolvedRoster,
            scoringUnitID: participant.id,
            title: nil,
            subtitle: nil,
            teamID: participant.teamID,
            scoringGroupID: partnershipGroup(for: participant)?.id,
            isSharedEntry: false,
            holeNumber: holeNumber
        )
    }

    func sharedScoringSession(
        anchorParticipant: RoundParticipant,
        participants: [RoundParticipant],
        scoringUnitID: String,
        holeNumber: Int,
        title: String,
        subtitle: String? = nil,
        teamID: String? = nil,
        scoringGroupID: String? = nil
    ) -> ScoringSession {
        ScoringSession(
            participant: anchorParticipant,
            participants: participants.sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) },
            scoringUnitID: scoringUnitID,
            title: title,
            subtitle: subtitle,
            teamID: teamID,
            scoringGroupID: scoringGroupID,
            isSharedEntry: true,
            holeNumber: holeNumber
        )
    }

    func sharedScoringSession(
        for scoringGroup: RoundScoringGroup,
        holeNumber: Int
    ) -> ScoringSession? {
        let members = participants(for: scoringGroup).filter(\.isPresenceActive)
        guard let anchor = members.first else { return nil }
        return sharedScoringSession(
            anchorParticipant: anchor,
            participants: members,
            scoringUnitID: scoringGroup.id,
            holeNumber: holeNumber,
            title: scoringGroupLabel(scoringGroup),
            subtitle: scoringGroupSubtitle(scoringGroup),
            teamID: scoringGroup.teamID,
            scoringGroupID: scoringGroup.id
        )
    }

    func sharedTeamScoringSession(
        team: RoundTeam,
        participants: [RoundParticipant],
        holeNumber: Int
    ) -> ScoringSession? {
        guard let anchor = participants.first else { return nil }
        let memberNames = participants
            .map { formatDisplayName(for: $0) }
            .filter(\.isPopulated)
            .joined(separator: ", ")
        return sharedScoringSession(
            anchorParticipant: anchor,
            participants: participants,
            scoringUnitID: team.id,
            holeNumber: holeNumber,
            title: team.name,
            subtitle: memberNames.isPopulated ? memberNames : nil,
            teamID: team.id
        )
    }
    
    // MARK: - Course / Hole data
    
    var defaultTee: Tee? { snapshot.defaultTee ?? snapshot.tees.first }
    var selectedTee: Tee? {
        guard let id = selectedTeeID else { return nil }
        return snapshot.tees.first(where: { $0.id == id })
    }
    var selectedTeeName: String { selectedTee?.name ?? defaultTee?.name ?? "—" }
    
    struct TeeSelectionOption: Identifiable {
        let id: String
        let tee: Tee
        let participantNames: String
        let yardage: Int
    }
    
    var teeSelectionOptions: [TeeSelectionOption] {
        let players = teeGroupParticipants
        guard players.isPopulated else { return [] }
        
        let grouped = Dictionary(grouping: players) { $0.teeBoxID }
        let range = snapshot.holeRange ?? HoleRange(startHole: 1, endHole: 18)
        
        let options = grouped.compactMap { teeID, members -> TeeSelectionOption? in
            guard teeID.isPopulated,
                  let tee = snapshot.tees.first(where: { $0.id == teeID }) else { return nil }
            
            let names = members
                .map { $0.name.givenName.isPopulated ? $0.name.givenName : $0.name.fullName }
                .filter { $0.isPopulated }
                .joined(separator: ", ")
            
            return TeeSelectionOption(
                id: teeID,
                tee: tee,
                participantNames: names,
                yardage: yardage(for: tee, range: range)
            )
        }
        
        return options.sorted { lhs, rhs in
            if lhs.yardage != rhs.yardage { return lhs.yardage > rhs.yardage }
            return lhs.tee.name < rhs.tee.name
        }
    }
    
    /// Tee options for the menu. Always shows all course tees; participant names as subtitle when available.
    var teeOptionsForMenu: [TeeSelectionOption] {
        let range = snapshot.holeRange ?? HoleRange(startHole: 1, endHole: 18)
        let grouped = Dictionary(grouping: teeGroupParticipants) { $0.teeBoxID }
        
        return snapshot.tees.map { tee in
            let members = grouped[tee.id] ?? []
            let names = members
                .map { formatDisplayName(for: $0) }
                .filter { $0.isPopulated }
                .joined(separator: ", ")
            return TeeSelectionOption(
                id: tee.id,
                tee: tee,
                participantNames: names,
                yardage: yardage(for: tee, range: range)
            )
        }
        .sorted { lhs, rhs in
            if lhs.yardage != rhs.yardage { return lhs.yardage > rhs.yardage }
            return lhs.tee.name < rhs.tee.name
        }
    }

    var teeOptionsForMenuMale: [TeeSelectionOption] {
        teeOptionsForMenu.filter { $0.tee.gender == Gender.male.rawValue }
    }

    var teeOptionsForMenuFemale: [TeeSelectionOption] {
        teeOptionsForMenu.filter { $0.tee.gender == Gender.female.rawValue }
    }

    var teeOptionsForMenuOther: [TeeSelectionOption] {
        teeOptionsForMenu.filter {
            $0.tee.gender != Gender.male.rawValue && $0.tee.gender != Gender.female.rawValue
        }
    }

    func formatDisplayName(for participant: RoundParticipant) -> String {
        let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard given.isPopulated || family.isPopulated else { return participant.name.fullName }
        switch nameDisplayFormat {
        case .firstInitialLastName:
            guard let g = given.first else { return family }
            return "\(g). \(family)"
        case .firstNameLastInitial:
            guard let f = family.first else { return given }
            return "\(given) \(f)."
        }
    }
    
    func hole(for holeNumber: Int) -> Hole? {
        guard let tee = defaultTee else { return nil }
        return tee.holes.first(where: { $0.number == holeNumber })
    }
    
    func hole(for holeNumber: Int, teeID: String?) -> Hole? {
        let tee = snapshot.tees.first(where: { $0.id == teeID }) ?? defaultTee
        return tee?.holes.first(where: { $0.number == holeNumber })
    }

    func quickScores(for holeNumber: Int) -> [Int] {
        let par = hole(for: holeNumber)?.par ?? 4
        return [par - 1, par, par + 1, par + 2, par + 3]
    }
    
    // MARK: - Scoring lookups
    
    private static func scoreIndexKey(participantID: String, holeNumber: Int) -> String {
        "\(participantID)_\(holeNumber)"
    }
    
    private func rebuildScoreIndex() {
        var index: [String: ScoreEntry] = [:]
        for entry in snapshot.scoring {
            let key = Self.scoreIndexKey(participantID: entry.scoringUnitID, holeNumber: entry.holeNumber)
            if index[key] == nil { index[key] = entry }
            for pid in entry.participantIDs where pid != entry.scoringUnitID {
                let pk = Self.scoreIndexKey(participantID: pid, holeNumber: entry.holeNumber)
                if index[pk] == nil { index[pk] = entry }
            }
        }
        scoreIndex = index
        cachedEngineResult = nil
    }
    
    func scoreEntry(for participantID: String, holeNumber: Int) -> ScoreEntry? {
        scoreIndex[Self.scoreIndexKey(participantID: participantID, holeNumber: holeNumber)]
    }
    
    func grossStrokes(for participantID: String, holeNumber: Int) -> Int? {
        scoreEntry(for: participantID, holeNumber: holeNumber)?.strokes
    }
    
    func pickedUp(for participantID: String, holeNumber: Int) -> Bool {
        scoreEntry(for: participantID, holeNumber: holeNumber)?.pickedUp ?? false
    }
    
    func holesPlayedCount(for participantID: String) -> Int {
        holesPlayedCount(for: participantID, in: snapshot)
    }

    func holeCompletionProgress(holeNumber: Int) -> Double {
        holeCompletionProgress(
            holeNumber: holeNumber,
            in: snapshot,
            groupID: visibleTeeGroupID
        )
    }

    private func holeNumbers(in snapshot: RoundSnapshot) -> [Int] {
        courseHoleNumbers(for: snapshot)
    }

    private func scoreEntry(
        in snapshot: RoundSnapshot,
        participantID: String,
        holeNumber: Int
    ) -> ScoreEntry? {
        snapshot.scoring.first { entry in
            entry.holeNumber == holeNumber
                && (entry.scoringUnitID == participantID || entry.participantIDs.contains(participantID))
        }
    }

    private func participantsInTeeGroup(in snapshot: RoundSnapshot, groupID: String?) -> [RoundParticipant] {
        let participants = snapshot.participants.filter { participant in
            guard let groupID, groupID.isPopulated else { return true }
            return participant.groupID == groupID
        }

        return participants.sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
    }

    private func activeParticipantsInTeeGroup(in snapshot: RoundSnapshot, groupID: String?) -> [RoundParticipant] {
        participantsInTeeGroup(in: snapshot, groupID: groupID).filter(\.isPresenceActive)
    }

    private func holesPlayedCount(for participantID: String, in snapshot: RoundSnapshot) -> Int {
        guard let participant = snapshot.participants.first(where: { $0.id == participantID }),
              participant.isPresenceActive else {
            return 0
        }
        return holeNumbers(in: snapshot).filter { holeNumber in
            guard let entry = scoreEntry(in: snapshot, participantID: participantID, holeNumber: holeNumber) else {
                return false
            }
            return entry.strokes != nil || entry.pickedUp
        }.count
    }

    private func participantCompletionPercentage(participantID: String, in snapshot: RoundSnapshot) -> Double {
        TelemetryEventProps.completionPercentage(
            completedCount: holesPlayedCount(for: participantID, in: snapshot),
            totalCount: holeNumbers(in: snapshot).count
        )
    }

    private func holeCompletionProgress(
        holeNumber: Int,
        in snapshot: RoundSnapshot,
        groupID: String?
    ) -> Double {
        let players = activeParticipantsInTeeGroup(in: snapshot, groupID: groupID)
        guard players.isPopulated else { return 0 }

        let completed = players.filter { participant in
            guard let entry = scoreEntry(in: snapshot, participantID: participant.id, holeNumber: holeNumber) else {
                return false
            }
            return entry.strokes != nil || entry.pickedUp
        }.count

        return Double(completed) / Double(players.count)
    }

    private func scoringUnit(
        for participantID: String,
        holeNumber: Int
    ) -> ScoringUnit? {
        snapshot.scoringUnits(forHole: holeNumber).first { scoringUnit in
            scoringUnit.id == participantID || scoringUnit.ownerIDs.contains(participantID)
        }
    }

    private func scoringParticipantIDs(for scoringUnit: ScoringUnit) -> [String] {
        switch scoringUnit.owner {
        case .participant:
            return scoringUnit.ownerIDs.isPopulated ? scoringUnit.ownerIDs : [scoringUnit.id]
        case .team:
            guard let teamID = scoringUnit.ownerIDs.first else { return [] }
            return snapshot.participants
                .filter { $0.teamID == teamID }
                .map(\.id)
        case .scoreOwner:
            if let scoringGroup = snapshot.scoringGroup(id: scoringUnit.id) {
                return scoringGroup.memberIDs
            }
            return scoringUnit.ownerIDs
        }
    }
    
    // MARK: - Handicap / Net
    
    func strokesReceivedOnHole(participant: RoundParticipant, holeNumber: Int) -> Int {
        ScoringEngine.strokesReceived(
            handicap: participant.adjustedHandicap,
            holeNumber: holeNumber,
            holes: defaultTee?.holes ?? [],
            playedHoleNumbers: snapshot.holeRange?.holeNumbers ?? Array(1...18),
            useHandicaps: snapshot.configuration.useHandicaps
        )
    }
    
    func netStrokesOnHole(participant: RoundParticipant, holeNumber: Int) -> Int? {
        guard let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else { return nil }
        let received = strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
        return max(0, gross - received)
    }
    
    // MARK: - Team scoring helpers (shared-score formats)

    func scoringUnitGrossStrokes(scoringUnitID: String, holeNumber: Int) -> Int? {
        scoreIndex[Self.scoreIndexKey(participantID: scoringUnitID, holeNumber: holeNumber)]?.strokes
    }

    func scoringUnitScoreToPar(scoringUnitID: String, basis: ScoreBasis) -> Int {
        let holes = holeNumbers
        var sum = 0
        for holeNumber in holes {
            guard let par = hole(for: holeNumber)?.par else { continue }
            guard let gross = scoringUnitGrossStrokes(scoringUnitID: scoringUnitID, holeNumber: holeNumber) else { continue }
            sum += (gross - par)
        }
        return sum
    }

    func teamGrossStrokes(teamID: String, holeNumber: Int) -> Int? {
        scoringUnitGrossStrokes(scoringUnitID: teamID, holeNumber: holeNumber)
    }

    func teamScoreToPar(teamID: String, basis: ScoreBasis) -> Int {
        scoringUnitScoreToPar(scoringUnitID: teamID, basis: basis)
    }

    // MARK: - Aggregates (Stroke play MVP)

    func scoreToPar(for participant: RoundParticipant, basis: ScoreBasis) -> Int {
        guard participant.isPresenceActive else { return 0 }
        let holes = holeNumbers
        var sum = 0
        
        for holeNumber in holes {
            guard let par = hole(for: holeNumber)?.par else { continue }
            guard let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else { continue }
            
            switch basis {
            case .gross:
                sum += (gross - par)
            case .net:
                let received = strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
                sum += ((gross - received) - par)
            }
        }
        
        return sum
    }
    
    func formattedScoreToPar(_ value: Int) -> String {
        if value == 0 { return "E" }
        //if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    /// Formats a matchup total (points or score to par) for display.
    func formattedMatchupTotal(_ total: Double, isPointsFormat: Bool) -> String {
        if isPointsFormat {
            let formatted = String(format: "%.1f", total)
            return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        }
        let intVal = Int(total)
        if intVal == 0 { return "E" }
        if intVal > 0 { return "+\(intVal)" }
        return "\(intVal)"
    }

    /// Whether this participant's score contributes to the team total (e.g. best ball count, best 2 of 4).
    /// For best ball, all players can contribute per hole. For best 2 of 4, only top 2 per hole count.
    func doesParticipantScoreCount(participantID: String, teamID: String, matchup: TeamMatchup) -> Bool {
        if (matchup.mode ?? expectedMatchupMode) == .scoreOwner {
            if let row = engineResult.matchupResults
                .first(where: { $0.matchup.id == matchup.id })?
                .rows
                .first(where: { $0.scoringUnitID == teamID }) {
                if row.countingParticipantIDs.isPopulated {
                    return row.countingParticipantIDs.contains(participantID)
                }
                return row.participantIDs.contains(participantID)
            }
            return false
        }

        guard snapshot.configuration.primaryFormat.configuration.requiresTeams else {
            return participantID == teamID
        }

        if let row = engineResult.matchupResults
            .first(where: { $0.matchup.id == matchup.id })?
            .rows
            .first(where: { $0.scoringUnitID == teamID }) {
            if row.countingParticipantIDs.isPopulated {
                return row.countingParticipantIDs.contains(participantID)
            }
            return row.participantIDs.contains(participantID)
        }

        if let row = engineResult.rows.first(where: { $0.scoringUnitID == teamID }) {
            if row.countingParticipantIDs.isPopulated {
                return row.countingParticipantIDs.contains(participantID)
            }
            return row.participantIDs.contains(participantID)
        }

        return false
    }

    enum FriendlyScoreFormat {
        case short
        case full
        case shortWithStrokes
        case fullWithStrokes
    }

    func friendlyScoreLabel(strokes: Int, par: Int, format: FriendlyScoreFormat = .short) -> String {
        let diff = strokes - par
        let useFull = (format == .full || format == .fullWithStrokes)
        let base: String
        switch diff {
        case ...(-3): base = "Albatross"
        case -2: base = par == 3 ? (useFull ? "Hole-in-one" : "HIO") : "Eagle"
        case -1: base = "Birdie"
        case 0: base = "Par"
        case 1: base = "Bogey"
        case 2: base = useFull ? "Double Bogey" : "D Bogey"
        case 3: base = useFull ? "Triple Bogey" : "T Bogey"
        case 4: base = useFull ? "Quad Bogey" : "Q Bogey"
        case 5: base = useFull ? "Quint Bogey" : "5x Bogey"
        case 6: base = useFull ? "Sext Bogey" : "6x Bogey"
        default:
            base = diff > 0 ? "\(diff)x Bogey" : "\(abs(diff)) Under"
        }
        let withStrokes = (format == .shortWithStrokes || format == .fullWithStrokes)
        return withStrokes ? "\(base) (\(strokes))" : base
    }

    /// Primary options: birdie through triple. More options: albatross, eagle, quad, quint, etc. up to hole max.
    func scoreMenuOptions(for holeNumber: Int) -> (primary: [Int], more: [Int]) {
        let par = hole(for: holeNumber)?.par ?? 4
        let configMax = snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: par)
        let minScore: Int
        if par == 4 {
            minScore = 1
        } else {
            minScore = max(1, par - 2)
        }
        let primary = [par - 1, par, par + 1, par + 2, par + 3]
        let allScores = Array(minScore...configMax)
        let primarySet = Set(primary)
        let more = allScores.filter { !primarySet.contains($0) }
        return (primary, more)
    }
    
    // MARK: - Leaderboard

    /// Chip for switching between scoring views (Strokes vs format-specific).
    enum LeaderboardScoringChip: String, CaseIterable {
        case strokes
        case stableford
        case bestBall

        var label: String {
            switch self {
            case .strokes: "Strokes"
            case .stableford: "Stableford"
            case .bestBall: "Best Ball"
            }
        }
    }

    @Published var selectedLeaderboardChip: LeaderboardScoringChip = .strokes

    var availableLeaderboardChips: [LeaderboardScoringChip] {
        let template = snapshot.resolvedActiveTemplate
        let isMatchupScope = snapshot.configuration.resolvedCompetitionScope == .matchup
            && !(snapshot.roundSegment?.matchups ?? []).filter(\.isValid).isEmpty

        var chips: [LeaderboardScoringChip] = [.strokes]
        if !isMatchupScope && !template.pipeline.isEmpty {
            switch template.id {
            case "stableford":
                chips.append(.stableford)
            case "best_ball":
                chips.append(.bestBall)
            default:
                break
            }
        }
        return chips
    }

    /// The chip to use for display; falls back to .strokes if selected chip is no longer available.
    var effectiveLeaderboardChip: LeaderboardScoringChip {
        availableLeaderboardChips.contains(selectedLeaderboardChip) ? selectedLeaderboardChip : .strokes
    }

    /// Subtitle explaining the rank selection and/or format name.
    var leaderboardRankSelectionSubtitle: String? {
        let isShared = snapshot.isSharedScoreSource
        let templateName = isShared ? snapshot.resolvedActiveTemplate.name : nil

        var rankPart: String? = nil
        if snapshot.configuration.primaryFormat.configuration.requiresTeams {
            let scoring = snapshot.configuration.teamScoring
            switch scoring.mode {
            case .all:
                break
            case .bestN, .worstN:
                let qualifier = scoring.mode == .worstN ? "Worst" : "Best"
                let scopeTitle = scoring.scope == .perRound ? "Round" : "Hole"
                rankPart = "\(qualifier) \(scoring.count) by \(scopeTitle)"
            }
        }

        switch (rankPart, templateName) {
        case (.some(let r), .some(let t)): return "\(r) · \(t)"
        case (.some(let r), .none):        return r
        case (.none, .some(let t)):        return t
        case (.none, .none):               return nil
        }
    }

    enum LeaderboardMode: String, CaseIterable {
        case individual, team, teeGroup
        
        var label: String {
            switch self {
            case .individual: "Solo"
            case .team: "Team"
            case .teeGroup: "Group"
            }
        }
    }
    
    struct GroupedLeaderboardSection: Identifiable {
        let id: String
        let name: String
        let color: Color?
        let bestScoreToPar: Int
        let avgScoreToPar: Double
        /// Sum of each row's `totalPoints ?? Double(scoreToPar)` (same basis as `avgScoreToPar`).
        let sumAggregatedScore: Double
        let rows: [LeaderboardRow]
    }

    struct OutcomeGroupedSectionSet: Identifiable {
        let id: String
        let title: String
        let sections: [GroupedLeaderboardSection]
    }

    struct OutcomePersonalSummary {
        let participant: RoundParticipant
        let tee: Tee
        let grossScoreToPar: Int
        let netScoreToPar: Int
        let adjustedIndex: Double?
    }

    struct OutcomeMatchupStatus {
        let title: String
        let detail: String
        let winningScoringUnitID: String?

        var isTie: Bool { winningScoringUnitID == nil }
    }

    enum OutcomeHoleSort: String, CaseIterable {
        case holeNumber
        case difficulty

        var label: String {
            switch self {
            case .holeNumber: "Hole #"
            case .difficulty: "Difficulty"
            }
        }
    }

    enum OutcomeHoleMetricMode: String, CaseIterable {
        case total
        case diff

        var label: String { rawValue.capitalized }
    }

    struct OutcomeHolePerformanceRow: Identifiable {
        let holeNumber: Int
        let par: Int?
        let yardage: Int?
        let handicap: Int?
        let bestGross: Int?
        let averageGross: Double?
        let worstGross: Int?
        let bestDiff: Double?
        let averageDiff: Double?
        let worstDiff: Double?

        var id: Int { holeNumber }
    }

    /// When false, section headers omit **Tot** (shared-score and match-play formats where summed row metrics are misleading).
    var showsGroupedLeaderboardSectionTotal: Bool {
        guard !snapshot.isSharedScoreSource else { return false }
        let isMatchPlayPipeline = snapshot.resolvedActiveTemplate.pipeline.contains { stage in
            if case .compare(let rule) = stage { return rule.mode == .matchPlay }
            return false
        }
        return !isMatchPlayPipeline
    }
    
    var availableLeaderboardModes: [LeaderboardMode] {
        if snapshot.isSharedScoreSource {
            return [.individual]
        }
        let hasTeams = snapshot.requiresTeams && snapshot.teams.isPopulated
        let hasMultipleGroups = snapshot.teeGroups.count > 1
        
        switch (hasTeams, hasMultipleGroups) {
        case (true, true):   return [.individual, .team, .teeGroup]
        case (true, false):  return [.individual, .team]
        case (false, true):  return [.individual, .teeGroup]
        case (false, false): return [.individual]
        }
    }
    
    struct LeaderboardRow: Identifiable {
        var id: String { teamID ?? participant.id }
        let participant: RoundParticipant
        let thru: Int
        let scoreToPar: Int
        let totalPoints: Double?
        let isPinned: Bool
        let placeLabel: String
        let teamID: String?
        let teamName: String?
        let teamColor: Color?
        let memberNames: String?

        init(
            participant: RoundParticipant,
            thru: Int,
            scoreToPar: Int,
            totalPoints: Double? = nil,
            isPinned: Bool,
            placeLabel: String,
            teamID: String? = nil,
            teamName: String? = nil,
            teamColor: Color? = nil,
            memberNames: String? = nil
        ) {
            self.participant = participant
            self.thru = thru
            self.scoreToPar = scoreToPar
            self.totalPoints = totalPoints
            self.isPinned = isPinned
            self.placeLabel = placeLabel
            self.teamID = teamID
            self.teamName = teamName
            self.teamColor = teamColor
            self.memberNames = memberNames
        }
    }
    
    /// Rows to display in the leaderboard; switches between stroke play and format-specific based on selected chip.
    var effectiveLeaderboardRows: [LeaderboardRow] {
        effectiveLeaderboardChip == .strokes ? leaderboardRows : engineLeaderboardRows
    }

    var leaderboardRows: [LeaderboardRow] {
        let basis = scoreBasis
        let baseRows = snapshot.participants.filter(\.isPresenceActive).map { p in
            LeaderboardRow(
                participant: p,
                thru: holesPlayedCount(for: p.id),
                scoreToPar: scoreToPar(for: p, basis: basis),
                isPinned: pinnedParticipantIDs.contains(p.id),
                placeLabel: ""
            )
        }

        let placeLabels = leaderboardPlaceLabels(for: baseRows)
        let rows = baseRows.map { row in
            LeaderboardRow(
                participant: row.participant,
                thru: row.thru,
                scoreToPar: row.scoreToPar,
                isPinned: row.isPinned,
                placeLabel: placeLabels[row.participant.id] ?? "-"
            )
        }
        
        // Pinned first, then best score, then name
        return rows.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
            return $0.participant.alphabeticName < $1.participant.alphabeticName
        }
    }
    
    var scorecardParticipants: [LeaderboardRow] {
        let ids = visibleParticipantIDs
        if ids.isEmpty {
            if hasInitializedVisibilitySelection {
                return []  // User chose "Hide all"
            }
            return leaderboardRows  // Not yet initialized, show all
        }
        let filtered = leaderboardRows.filter { ids.contains($0.participant.id) }
        if filtered.isEmpty && !leaderboardRows.isEmpty {
            return leaderboardRows  // Stale IDs or misconfiguration, show all
        }
        return filtered
    }
    
    func toggleScorecardVisibility(participantID: String) {
        if visibleParticipantIDs.contains(participantID) {
            visibleParticipantIDs.remove(participantID)
        } else {
            visibleParticipantIDs.insert(participantID)
        }
    }
    
    func selectAllScorecardVisibility() {
        visibleParticipantIDs = Set(snapshot.participants.map(\.id))
    }
    
    func deselectAllScorecardVisibility() {
        visibleParticipantIDs = []
    }
    
    func applyScorecardVisibility() {
        lastAppliedVisibleParticipantIDs = visibleParticipantIDs
        hasInitializedVisibilitySelection = true
    }
    
    func resetScorecardVisibility() {
        visibleParticipantIDs = lastAppliedVisibleParticipantIDs
    }

    func visibleParticipantIDsLabel() -> String {
        let ids = visibleParticipantIDs
        let allIDs = Set(snapshot.participants.map(\.id))
        if ids == allIDs { return "All shown" }

        for group in snapshot.teeGroups.sorted(by: { $0.index < $1.index }) {
            let groupIDs = Set(snapshot.participants.filter { $0.groupID == group.id }.map(\.id))
            if ids == groupIDs { return "Tee Group #\(group.index + 1)" }
        }
        for team in snapshot.teams {
            let teamIDs = Set(snapshot.participants.filter { $0.teamID == team.id }.map(\.id))
            if ids == teamIDs { return team.name }
        }
        return "Custom"
    }

    private func leaderboardPlaceLabels(for rows: [LeaderboardRow]) -> [String: String] {
        let ordered = rows.sorted {
            if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
            return $0.participant.alphabeticName < $1.participant.alphabeticName
        }
        
        var labels: [String: String] = [:]
        var place = 1
        var index = 0
        
        while index < ordered.count {
            let score = ordered[index].scoreToPar
            var group: [LeaderboardRow] = []
            
            while index < ordered.count, ordered[index].scoreToPar == score {
                group.append(ordered[index])
                index += 1
            }
            
            let label = group.count > 1 ? "T-\(place)." : "\(place)."
            for row in group {
                labels[row.participant.id] = label
            }
            
            place += group.count
        }
        
        return labels
    }
    
    func togglePinned(_ participant: RoundParticipant) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if pinnedParticipantIDs.contains(participant.id) {
                pinnedParticipantIDs.remove(participant.id)
            } else {
                pinnedParticipantIDs.insert(participant.id)
            }
        }
    }
    
    // MARK: - Grouped Leaderboard
    
    var teamLeaderboardSections: [GroupedLeaderboardSection] {
        let rows = effectiveLeaderboardRows
        let grouped = Dictionary(grouping: rows) { $0.teamID ?? $0.participant.teamID }
        let orderedTeams = snapshot.teams.sorted { $0.index < $1.index }
        
        var sections: [GroupedLeaderboardSection] = []
        
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        for team in orderedTeams {
            let teamRows = (grouped[team.id] ?? []).sorted {
                let a = $0.totalPoints ?? Double($0.scoreToPar)
                let b = $1.totalPoints ?? Double($1.scoreToPar)
                if a != b { return isHighestWins ? a > b : a < b }
                return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
            }
            guard teamRows.isPopulated else { continue }
            sections.append(makeGroupedSection(
                id: team.id,
                name: team.name,
                color: team.displaySwatchColor,
                rows: teamRows
            ))
        }
        
        if let unassigned = grouped[nil], unassigned.isPopulated {
            let sorted = unassigned.sorted {
                let a = $0.totalPoints ?? Double($0.scoreToPar)
                let b = $1.totalPoints ?? Double($1.scoreToPar)
                if a != b { return isHighestWins ? a > b : a < b }
                return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
            }
            sections.append(makeGroupedSection(
                id: "unassigned",
                name: "Unassigned",
                color: nil,
                rows: sorted
            ))
        }
        
        return sections.sorted {
            isHighestWins ? $0.bestScoreToPar > $1.bestScoreToPar : $0.bestScoreToPar < $1.bestScoreToPar
        }
    }

    var teeGroupLeaderboardSections: [GroupedLeaderboardSection] {
        let rows = effectiveLeaderboardRows
        let grouped = Dictionary(grouping: rows) { $0.participant.groupID }
        let orderedGroups = snapshot.teeGroups.sorted { $0.index < $1.index }
        
        var sections: [GroupedLeaderboardSection] = []
        
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        for group in orderedGroups {
            let groupRows = (grouped[group.id] ?? []).sorted {
                let a = $0.totalPoints ?? Double($0.scoreToPar)
                let b = $1.totalPoints ?? Double($1.scoreToPar)
                if a != b { return isHighestWins ? a > b : a < b }
                return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
            }
            guard groupRows.isPopulated else { continue }
            sections.append(makeGroupedSection(
                id: group.id,
                name: group.name,
                color: nil,
                rows: groupRows
            ))
        }
        
        if let ungrouped = grouped[nil], ungrouped.isPopulated {
            let sorted = ungrouped.sorted {
                let a = $0.totalPoints ?? Double($0.scoreToPar)
                let b = $1.totalPoints ?? Double($1.scoreToPar)
                if a != b { return isHighestWins ? a > b : a < b }
                return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
            }
            sections.append(makeGroupedSection(
                id: "ungrouped",
                name: "Ungrouped",
                color: nil,
                rows: sorted
            ))
        }
        
        return sections.sorted {
            isHighestWins ? $0.bestScoreToPar > $1.bestScoreToPar : $0.bestScoreToPar < $1.bestScoreToPar
        }
    }

    private func makeGroupedSection(
        id: String,
        name: String,
        color: Color?,
        rows: [LeaderboardRow]
    ) -> GroupedLeaderboardSection {
        let values = rows.map { $0.totalPoints ?? Double($0.scoreToPar) }
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        let best = values.isEmpty ? 0 : (isHighestWins ? values.max()! : values.min()!)
        let sum = values.reduce(0, +)
        let avg = values.isEmpty ? 0 : sum / Double(values.count)
        return GroupedLeaderboardSection(
            id: id,
            name: name,
            color: color,
            bestScoreToPar: Int(best),
            avgScoreToPar: avg,
            sumAggregatedScore: sum,
            rows: rows
        )
    }
    
    var overallBestScoreToPar: Int {
        leaderboardRows.map(\.scoreToPar).min() ?? 0
    }
    
    var overallAvgScoreToPar: Double {
        let scores = leaderboardRows.map(\.scoreToPar)
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    func formattedAvgScore(_ value: Double) -> String {
        if abs(value) < 0.05 { return "E" }
        
        let formatted = String(format: "%+.1f", value)
        
        // Remove trailing ".0" (e.g. "+1.0" → "+1")
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }

    /// Formats **Tot** for grouped section headers (sum of row metrics). Strokes: integer vs par; format chips: points-style.
    func formattedGroupedSectionSum(_ sum: Double) -> String {
        if effectiveLeaderboardChip == .strokes {
            let rounded = Int(sum.rounded())
            if rounded == 0 { return "E" }
            if rounded > 0 { return "+\(rounded)" }
            return "\(rounded)"
        }
        let formatted = String(format: "%.1f", sum)
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }
    
    /// Average value for the avg breakline, based on effective leaderboard chip.
    /// Strokes: average scoreToPar. Format chips: average totalPoints.
    var overallAvgForDisplay: Double {
        let rows = effectiveLeaderboardRows
        guard !rows.isEmpty else { return 0 }
        if effectiveLeaderboardChip == .strokes {
            return Double(rows.map(\.scoreToPar).reduce(0, +)) / Double(rows.count)
        }
        let values = rows.map { $0.totalPoints ?? Double($0.scoreToPar) }
        return values.reduce(0, +) / Double(values.count)
    }
    
    /// Formats the avg value for display in the avg breakline.
    /// Strokes: "+1" style. Format chips: "2.5" or "6" style.
    func formattedAvgForDisplay(_ value: Double) -> String {
        if effectiveLeaderboardChip == .strokes {
            return formattedAvgScore(value)
        }
        let formatted = String(format: "%.1f", value)
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }

    var outcomeParticipant: RoundParticipant? {
        currentParticipant
    }

    func resolvedPlayedTee(for participant: RoundParticipant?) -> Tee? {
        if let teeID = participant?.teeBoxID,
           teeID.isPopulated,
           let participantTee = snapshot.courseSegment?.tee(from: teeID) ?? snapshot.tees.first(where: { $0.id == teeID }) {
            return participantTee
        }
        return snapshot.defaultTee ?? snapshot.tees.first
    }

    func scoreToParLabel(_ value: Int) -> String {
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    var outcomePersonalSummary: OutcomePersonalSummary? {
        guard let participant = outcomeParticipant,
              let tee = resolvedPlayedTee(for: participant) else { return nil }
        return OutcomePersonalSummary(
            participant: participant,
            tee: tee,
            grossScoreToPar: scoreToPar(for: participant, basis: .gross),
            netScoreToPar: scoreToPar(for: participant, basis: .net),
            adjustedIndex: derivedRoundHandicapIndex(for: participant)
        )
    }

    func derivedRoundHandicapIndex(for participant: RoundParticipant) -> Double? {
        guard let tee = resolvedPlayedTee(for: participant),
              let rating = tee.rating(for: snapshot.holeSegment),
              let slope = tee.slope(for: snapshot.holeSegment),
              slope > 0 else {
            return nil
        }
        let par = Double(tee.par(for: snapshot.holeSegment))
        let courseHandicap = Double(participant.adjustedHandicap)
        let value = ((courseHandicap - rating + par) * 113.0) / Double(slope)
        return (value * 10.0).rounded(.toNearestOrAwayFromZero) / 10.0
    }

    func outcomeAdjustedIndexSubtitle(for participant: RoundParticipant) -> String? {
        guard let tee = resolvedPlayedTee(for: participant),
              let rating = tee.prettyRating(for: snapshot.holeSegment),
              let slope = tee.slope(for: snapshot.holeSegment) else {
            return resolvedPlayedTee(for: participant)?.name
        }
        return "\(tee.name) \(kDot) CR \(rating) \(kDot) Slope \(slope)"
    }

    func outcomeHolePerformanceRows(sortedBy sort: OutcomeHoleSort) -> [OutcomeHolePerformanceRow] {
        let tee = resolvedPlayedTee(for: outcomeParticipant)
        let activeParticipants = snapshot.participants.filter(\.isPresenceActive)

        let rows = courseOrderHoleNumbers.map { holeNumber -> OutcomeHolePerformanceRow in
            let hole = tee?.holes.first(where: { $0.number == holeNumber })
            let par = hole?.par
            let strokes = activeParticipants.compactMap { participant in
                grossStrokes(for: participant.id, holeNumber: holeNumber)
            }

            let bestGross = strokes.min()
            let worstGross = strokes.max()
            let averageGross = strokes.isEmpty
                ? nil
                : Double(strokes.reduce(0, +)) / Double(strokes.count)

            return OutcomeHolePerformanceRow(
                holeNumber: holeNumber,
                par: par,
                yardage: hole?.yardage,
                handicap: hole?.handicap,
                bestGross: bestGross,
                averageGross: averageGross,
                worstGross: worstGross,
                bestDiff: bestGross.flatMap { gross in
                    par.map { Double(gross - $0) }
                },
                averageDiff: averageGross.flatMap { gross in
                    par.map { gross - Double($0) }
                },
                worstDiff: worstGross.flatMap { gross in
                    par.map { Double(gross - $0) }
                }
            )
        }

        switch sort {
        case .holeNumber:
            return rows.sorted { $0.holeNumber < $1.holeNumber }
        case .difficulty:
            return rows.sorted { lhs, rhs in
                switch (lhs.averageDiff, rhs.averageDiff) {
                case let (l?, r?) where l != r:
                    return l > r
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    return lhs.holeNumber < rhs.holeNumber
                }
            }
        }
    }

    func formattedOutcomeHoleMetric(
        _ value: Double?,
        mode: OutcomeHoleMetricMode,
        prefersInteger: Bool
    ) -> String {
        guard let value else { return "—" }

        switch mode {
        case .total:
            if prefersInteger {
                return String(Int(value.rounded()))
            }
            return trimmedOutcomeMetricString(value, maxFractionDigits: 2, alwaysShowSign: false)
        case .diff:
            return trimmedOutcomeMetricString(value, maxFractionDigits: 2, alwaysShowSign: true)
        }
    }

    private var outcomeUsesAggregateRows: Bool {
        effectiveLeaderboardRows.contains {
            ($0.teamName?.isPopulated ?? false) || ($0.memberNames?.isPopulated ?? false)
        }
    }

    private var partnershipLeaderboardSections: [GroupedLeaderboardSection] {
        let partnershipGroups = snapshot.scoringGroups
            .filter { $0.kind == .partnership && $0.memberIDs.isPopulated }
            .sorted { lhs, rhs in
                let lhsOrder = participants(for: lhs).first?.teeOrder ?? Int.max
                let rhsOrder = participants(for: rhs).first?.teeOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return scoringGroupLabel(lhs) < scoringGroupLabel(rhs)
            }

        let rowsByParticipantID = Dictionary(uniqueKeysWithValues: effectiveLeaderboardRows.map { ($0.participant.id, $0) })
        return partnershipGroups.compactMap { group in
            let rows = participants(for: group).compactMap { rowsByParticipantID[$0.id] }
            guard rows.isPopulated else { return nil }
            return makeGroupedSection(
                id: group.id,
                name: scoringGroupLabel(group),
                color: scoringGroupAccentColor(group),
                rows: rows
            )
            }
    }

    private func trimmedOutcomeMetricString(
        _ value: Double,
        maxFractionDigits: Int,
        alwaysShowSign: Bool
    ) -> String {
        let threshold = 1.0 / pow(10.0, Double(maxFractionDigits + 1))
        let normalized = abs(value) < threshold ? 0 : value
        var formatted = String(format: "%.\(maxFractionDigits)f", normalized)

        if maxFractionDigits > 0, formatted.contains(".") {
            while formatted.last == "0" {
                formatted.removeLast()
            }
            if formatted.last == "." {
                formatted.removeLast()
            }
        }

        if alwaysShowSign, !formatted.hasPrefix("-") {
            formatted = "+\(formatted)"
        }

        return formatted
    }

    var outcomeGroupedSectionSets: [OutcomeGroupedSectionSet] {
        guard !outcomeUsesAggregateRows else { return [] }

        var sets: [OutcomeGroupedSectionSet] = []

        if snapshot.requiresTeams && teamLeaderboardSections.isPopulated {
            sets.append(.init(
                id: "teams",
                title: "Teams",
                sections: teamLeaderboardSections
            ))
        }

        if snapshot.configuration.scoreOwnerScope == .partnership,
           partnershipLeaderboardSections.isPopulated {
            sets.append(.init(
                id: "partnerships",
                title: "Partnerships",
                sections: partnershipLeaderboardSections
            ))
        }

        if snapshot.teeGroups.count > 1 && teeGroupLeaderboardSections.isPopulated {
            sets.append(.init(
                id: "tee_groups",
                title: "Tee Groups",
                sections: teeGroupLeaderboardSections
            ))
        }

        return sets
    }

    func outcomeMatchupStatus(for section: MatchupLeaderboardSection) -> OutcomeMatchupStatus {
        guard section.rows.count >= 2 else {
            return OutcomeMatchupStatus(
                title: "Matchup pending",
                detail: "Waiting for both sides to post scores",
                winningScoringUnitID: nil
            )
        }

        let isPointsFormat = engineResult.template.leaderboardSort == .highestWins
        let lhs = section.rows[0]
        let rhs = section.rows[1]
        let lhsTotal = lhs.total
        let rhsTotal = rhs.total

        if lhsTotal == rhsTotal {
            let tiedAt = formattedMatchupTotal(lhsTotal, isPointsFormat: isPointsFormat)
            let detail = isPointsFormat ? "Tied at \(tiedAt) pts" : "Tied at \(tiedAt)"
            return OutcomeMatchupStatus(title: "Match tied", detail: detail, winningScoringUnitID: nil)
        }

        let matchupRows = isPointsFormat ? (lhsTotal > rhsTotal ? (lhs, rhs) : (rhs, lhs)) :
            (lhsTotal < rhsTotal ? (lhs, rhs) : (rhs, lhs))
        let winningRow = matchupRows.0
        let losingRow = matchupRows.1

        let winningName = outcomeMatchupSideName(scoringUnitID: winningRow.scoringUnitID, matchup: section.matchup)
        let margin = abs(winningRow.total - losingRow.total)
        let formattedMargin = String(format: isPointsFormat ? "%.1f" : "%.0f", margin)
        let trimmedMargin = formattedMargin.hasSuffix(".0") ? String(formattedMargin.dropLast(2)) : formattedMargin
        let unit = isPointsFormat ? (margin == 1 ? "pt" : "pts") : (margin == 1 ? "stroke" : "strokes")

        return OutcomeMatchupStatus(
            title: "\(winningName) wins",
            detail: "Won by \(trimmedMargin) \(unit)",
            winningScoringUnitID: winningRow.scoringUnitID
        )
    }

    func outcomeMatchupSideName(scoringUnitID: String, matchup: TeamMatchup) -> String {
        switch matchup.mode ?? expectedMatchupMode {
        case .team:
            return snapshot.teams.first(where: { $0.id == scoringUnitID })?.name ?? "Team"
        case .individual:
            return snapshot.participants.first(where: { $0.id == scoringUnitID })?.name.fullName ?? "Player"
        case .scoreOwner:
            if let group = snapshot.scoringGroup(id: scoringUnitID) {
                return scoringGroupLabel(group)
            }
            return "Side"
        }
    }
    
    // MARK: - Scoring Engine Bridge

    /// Runs the new ScoringEngine against the current snapshot.
    /// Uses computeWithPipeline when template has a non-empty pipeline (field or matchup scope).
    /// Uses computeStrokePlay only when pipeline is empty (plain stroke play).
    var engineResult: ScoringResult {
        if let cached = cachedEngineResult { return cached }
        let segment = snapshot.roundSegment ?? RoundSegment()
        let template = snapshot.resolvedActiveTemplate
        let holes = defaultTee?.holes ?? []
        let scoreLookupIDs = snapshot.segmentScoreLookupSegmentIDs
        let usesScoreOwners = snapshot.configuration.scoreOwnerScope != .individual || snapshot.scoringGroups.isPopulated

        let result: ScoringResult
        if snapshot.configuration.primaryFormat.configuration.requiresTeams && !usesScoreOwners {
            result = ScoringEngine.computeWithTeamScoring(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                teams: snapshot.teams,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                template: template,
                teamScoring: snapshot.configuration.teamScoring,
                matchupResolutionStyle: snapshot.configuration.matchupResolutionStyle,
                scoreLookupSegmentIDs: scoreLookupIDs.isEmpty ? nil : scoreLookupIDs,
                resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope
            )
        } else if !template.pipeline.isEmpty {
            result = ScoringEngine.computeWithPipeline(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                teams: snapshot.teams,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                template: template,
                scoreLookupSegmentIDs: scoreLookupIDs.isEmpty ? nil : scoreLookupIDs,
                resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope,
                scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
                scoringGroups: snapshot.scoringGroups,
                perHoleWinPoints: snapshot.configuration.resolvedHoleWinPoints
            )
        } else {
            result = ScoringEngine.computeStrokePlay(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                template: template,
                scoreLookupSegmentIDs: scoreLookupIDs.isEmpty ? nil : scoreLookupIDs
            )
        }
        cachedEngineResult = result
        return result
    }

    /// Matchup sections for the Matchups tab. Empty when not matchup scope or no valid matchups. Only includes sections matching the current mode (requiresTeams).
    var matchupSections: [MatchupLeaderboardSection] {
        let result = engineResult
        guard !result.matchupResults.isEmpty else { return [] }
        let expectedMode: MatchupMode = snapshot.configuration.scoreOwnerScope == .individual
            ? (snapshot.requiresTeams ? .team : .individual)
            : .scoreOwner
        return LeaderboardBuilder.buildMatchupSections(
            result: result,
            teams: snapshot.teams,
            participants: snapshot.participants,
            scoringGroups: snapshot.scoringGroups
        )
        .filter { ($0.matchup.mode ?? .team) == expectedMode }
    }

    /// Engine-derived leaderboard rows, bridged to the ViewModel's LeaderboardRow type.
    /// Supports both participant rows (Stableford, stroke play) and team rows (best ball).
    var engineLeaderboardRows: [LeaderboardRow] {
        let result = engineResult
        let participantMap = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        let teamMap = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })
        let scoringGroupMap = Dictionary(uniqueKeysWithValues: snapshot.scoringGroups.map { ($0.id, $0) })

        let isHighestWins = result.template.leaderboardSort == .highestWins

        let rows: [LeaderboardRow] = result.rows.compactMap { row in
            let participant: RoundParticipant?
            let teamID: String?
            let teamName: String?
            let teamColor: Color?

            var names: String? = nil

            if let p = participantMap[row.scoringUnitID] {
                guard p.isPresenceActive else { return nil }
                participant = p
                teamID = nil
                teamName = nil
                teamColor = nil
            } else if let team = teamMap[row.scoringUnitID],
                      let p = row.participantIDs.compactMap({ participantMap[$0] }).first(where: \.isPresenceActive) {
                participant = p
                teamID = team.id
                teamName = team.name
                teamColor = team.displaySwatchColor
                names = row.participantIDs
                    .compactMap { participantMap[$0] }
                    .filter(\.isPresenceActive)
                    .map { formatDisplayName(for: $0) }
                    .joined(separator: ", ")
            } else if let scoringGroup = scoringGroupMap[row.scoringUnitID],
                      let p = row.participantIDs.compactMap({ participantMap[$0] }).first(where: \.isPresenceActive) {
                participant = p
                teamID = scoringGroup.teamID
                teamName = scoringGroup.label ?? row.participantIDs
                    .compactMap { participantMap[$0] }
                    .filter(\.isPresenceActive)
                    .map { formatDisplayName(for: $0) }
                    .joined(separator: " + ")
                teamColor = scoringGroup.teamID.flatMap { teamMap[$0]?.displaySwatchColor }
                names = row.participantIDs
                    .compactMap { participantMap[$0] }
                    .filter(\.isPresenceActive)
                    .map { formatDisplayName(for: $0) }
                    .joined(separator: ", ")
            } else {
                return nil
            }

            guard let p = participant else { return nil }

            return LeaderboardRow(
                participant: p,
                thru: row.holesPlayed,
                scoreToPar: Int(row.total),
                totalPoints: row.total,
                isPinned: pinnedParticipantIDs.contains(row.scoringUnitID),
                placeLabel: "",
                teamID: teamID,
                teamName: teamName,
                teamColor: teamColor,
                memberNames: names
            )
        }

        let sorted = rows.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if $0.totalPoints != $1.totalPoints {
                return isHighestWins ? ($0.totalPoints ?? 0) > ($1.totalPoints ?? 0) : ($0.totalPoints ?? 0) < ($1.totalPoints ?? 0)
            }
            let nameA = $0.teamName ?? $0.participant.alphabeticName
            let nameB = $1.teamName ?? $1.participant.alphabeticName
            return nameA < nameB
        }

        let placeLabels = engineLeaderboardPlaceLabels(for: sorted, isHighestWins: isHighestWins)
        return sorted.map { row in
            LeaderboardRow(
                participant: row.participant,
                thru: row.thru,
                scoreToPar: row.scoreToPar,
                totalPoints: row.totalPoints,
                isPinned: row.isPinned,
                placeLabel: placeLabels[row.id] ?? "-",
                teamID: row.teamID,
                teamName: row.teamName,
                teamColor: row.teamColor,
                memberNames: row.memberNames
            )
        }
    }

    private func engineLeaderboardPlaceLabels(for rows: [LeaderboardRow], isHighestWins: Bool) -> [String: String] {
        let ordered = rows.sorted {
            let a = $0.totalPoints ?? Double($0.scoreToPar)
            let b = $1.totalPoints ?? Double($1.scoreToPar)
            if a != b { return isHighestWins ? a > b : a < b }
            return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
        }
        var labels: [String: String] = [:]
        var place = 1
        var index = 0
        while index < ordered.count {
            let val = ordered[index].totalPoints ?? Double(ordered[index].scoreToPar)
            var group: [LeaderboardRow] = []
            while index < ordered.count, (ordered[index].totalPoints ?? Double(ordered[index].scoreToPar)) == val {
                group.append(ordered[index])
                index += 1
            }
            let label = group.count > 1 ? "T-\(place)." : "\(place)."
            for row in group { labels[row.id] = label }
            place += group.count
        }
        return labels
    }

    // MARK: - Score entry actions
    
    func promptCustomScore(for participant: RoundParticipant, holeNumber: Int) {
        customScoreParticipant = participant
        customScoreHoleNumber = holeNumber
        customScoreText = ""
        showCustomScorePrompt = true
    }
    
    func submitCustomScore() async {
        guard let participant = customScoreParticipant else { return }
        guard let holeNumber = customScoreHoleNumber else { return }
        guard let value = Int(customScoreText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        
        if grossStrokes(for: participant.id, holeNumber: holeNumber) == value {
            await clearScore(participant: participant, holeNumber: holeNumber, entryMethod: .clear)
            showCustomScorePrompt = false
            return
        }
        
        let quick = quickScores(for: holeNumber)
        if quick.contains(value) {
            await setQuickScore(
                participant: participant,
                strokes: value,
                holeNumber: holeNumber,
                entryMethod: .customPrompt
            )
        } else {
            await setScore(
                participant: participant,
                holeNumber: holeNumber,
                strokes: value,
                entryMethod: .customPrompt
            )
        }
        showCustomScorePrompt = false
    }
    
    func setQuickScore(
        participant: RoundParticipant,
        strokes: Int,
        holeNumber: Int,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        await setScore(
            participant: participant,
            holeNumber: holeNumber,
            strokes: strokes,
            entryMethod: entryMethod
        )
    }
    
    func clearScore(
        participant: RoundParticipant,
        holeNumber: Int,
        entryMethod: LiveRoundEntryMethod = .clear
    ) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        guard var entry = scoreEntry(for: participant.id, holeNumber: holeNumber) else { return }
        let beforeSnapshot = roundSession.snapshot
        let beforeProgress = holeCompletionProgress(
            holeNumber: holeNumber,
            in: beforeSnapshot,
            groupID: participant.groupID
        )
        
        let previousEntry = entry
        entry.parentID = snapshot.round.id
        entry.entryID = actualParticipant?.id ?? entry.entryID
        entry.pickedUp = false
        entry.value = nil
        entry.strokes = nil
        
        var updatedSnapshot = roundSession.snapshot
        updatedSnapshot.scoring.upsert(entry)
        roundSession.snapshot = updatedSnapshot
        
        do {
            _ = try await entry.put().get()
            lastLocalScoreAt = Date()
            emitScoreClearedTelemetry(
                participant: participant,
                holeNumber: holeNumber,
                previousEntry: previousEntry,
                entryMethod: entryMethod,
                beforeProgress: beforeProgress,
                afterSnapshot: updatedSnapshot
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to clear score for participant \(participant.id)", error: error)
            var rollbackSnapshot = roundSession.snapshot
            rollbackSnapshot.scoring.upsert(previousEntry)
            roundSession.snapshot = rollbackSnapshot
        }
    }
    
    func setScore(
        participant: RoundParticipant,
        holeNumber: Int,
        strokes: Int,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        addBreadcrumb()

        guard participant.isPresenceActive else { return }
        
        guard let roundSession else { return }
        let beforeSnapshot = roundSession.snapshot
        let beforeProgress = holeCompletionProgress(
            holeNumber: holeNumber,
            in: beforeSnapshot,
            groupID: participant.groupID
        )
        
        let roundID = snapshot.round.id
        let resolved = snapshot.segment(forHole: holeNumber)
        let segmentID = resolved?.id.isPopulated == true ? resolved!.id : snapshot.roundSegment?.id ?? "seg0"
        let resolvedScoringUnit = scoringUnit(for: participant.id, holeNumber: holeNumber)

        let isShared = snapshot.isSharedScoreSource
        let teamID = participant.teamID
        let scoringUnitID = resolvedScoringUnit?.id
            ?? ((isShared && teamID != nil) ? teamID! : participant.id)
        let participantIDs: [String] = {
            if let resolvedScoringUnit {
                return scoringParticipantIDs(for: resolvedScoringUnit)
            }
            if isShared, let teamID {
                return snapshot.participants.filter { $0.teamID == teamID }.map(\.id)
            }
            return [participant.id]
        }()

        let id = ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: scoringUnitID)

        let lookupKey = resolvedScoringUnit?.id ?? ((isShared && teamID != nil) ? teamID! : participant.id)
        var entry = scoreEntry(for: lookupKey, holeNumber: holeNumber) ?? ScoreEntry(
            id: id,
            holeNumber: holeNumber,
            segmentID: segmentID,
            groupID: participant.groupID ?? "",
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            strokes: nil,
            value: nil,
            pickedUp: false,
            entryID: actualParticipant?.id ?? participant.id,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )

        entry.id = id
        entry.parentID = roundID
        entry.segmentID = segmentID
        entry.groupID = participant.groupID ?? entry.groupID
        entry.scoringUnitID = scoringUnitID
        entry.participantIDs = participantIDs
        entry.entryID = actualParticipant?.id ?? entry.entryID
        entry.pickedUp = false
        entry.value = nil
        entry.strokes = strokes
        
        let previousEntry = scoreEntry(for: lookupKey, holeNumber: holeNumber)
        if previousEntry?.strokes == strokes, previousEntry?.pickedUp == false {
            return
        }
        
        var updatedSnapshot = roundSession.snapshot
        updatedSnapshot.scoring.upsert(entry)
        roundSession.snapshot = updatedSnapshot
        
        do {
            _ = try await entry.put().get()
            lastLocalScoreAt = Date()
            emitScoreSavedTelemetry(
                participant: participant,
                holeNumber: holeNumber,
                strokes: strokes,
                entryMethod: entryMethod,
                beforeProgress: beforeProgress,
                afterSnapshot: updatedSnapshot
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set score for participant \(participant.id)", error: error)
            var rollbackSnapshot = roundSession.snapshot
            if let prev = previousEntry {
                rollbackSnapshot.scoring.upsert(prev)
            } else {
                rollbackSnapshot.scoring.removeAll { $0.id == entry.id }
            }
            roundSession.snapshot = rollbackSnapshot
        }
    }

    func hasRecordedScores(for participant: RoundParticipant) -> Bool {
        holesPlayedCount(for: participant.id, in: snapshot) > 0
    }

    func markParticipantPlaying(_ participant: RoundParticipant) async {
        await updatePresence(for: participant, status: .active)
    }

    func markParticipantNoShow(_ participant: RoundParticipant) async {
        guard canMarkParticipantNoShow(participant: participant) else {
            if hasRecordedScores(for: participant) {
                presenceErrorMessage = "Clear this player's scores before marking them as not here."
            }
            return
        }
        await updatePresence(for: participant, status: .noShow)
    }

    func resetParticipantToUnconfirmed(_ participant: RoundParticipant) async {
        guard canResetPresenceToUnconfirmed(participant: participant) else {
            if hasRecordedScores(for: participant) {
                presenceErrorMessage = "Clear this player's scores before changing their status."
            }
            return
        }
        await updatePresence(for: participant, status: .unconfirmed)
    }

    private func updatePresence(
        for participant: RoundParticipant,
        status: RoundParticipantPresenceStatus
    ) async {
        guard canEditPresence(participant: participant) else { return }
        guard let roundSession else { return }
        if participant.resolvedPresenceStatus == status { return }

        var updated = participant
        updated.presenceStatus = status
        updated.lastUpdatedAt = .init()

        do {
            try await roundSession.update(participant: updated)
        } catch {
            presenceErrorMessage = "Couldn't update this player's status right now."
            addBreadcrumb(level: .error, message: "Failed to update participant presence", error: error)
        }
    }
    
    // MARK: - Current participant resolution

    /// `AppSession.isSpectating` is only cleared from `FindRoundView` join completion. If the user
    /// spectated one round then opens another as a player via lobby/series/deep link, the flag can
    /// stay true and hide scoring UI until app relaunch. Clear it when this round includes them as a participant.
    private func clearStaleSpectatorSessionFlagIfPlayingThisRound() async {
        guard let appSession, appSession.isSpectating else { return }
        let participants = snapshot.participants
        guard participants.isPopulated else { return }

        if let ephemeral = appSession.ephemeralParticipantID, ephemeral.isPopulated,
           participants.contains(where: { $0.id == ephemeral }) {
            appSession.isSpectating = false
            isSpectator = false
            return
        }

        guard let user = await AppData.shared.user else { return }
        if participants.contains(where: { $0.userID == user.id }) {
            appSession.isSpectating = false
            isSpectator = false
            return
        }
        if let primary = await AppData.shared.getPrimaryPlayer(),
           participants.contains(where: { $0.playerID == primary.id }) {
            appSession.isSpectating = false
            isSpectator = false
        }
    }
    
    private func resolveCurrentParticipantIDIfNeeded() async {
        // If guest is spectating/playing without auth, we use ephemeral participant id.
        if let ephemeral = appSession?.ephemeralParticipantID, ephemeral.isPopulated {
            currentParticipantID = ephemeral
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded()
            return
        }
        
        if currentParticipantID.exists { return }
        
        guard let primary = await AppData.shared.getPrimaryPlayer() else { return }
        if let p = snapshot.participants.first(where: { $0.playerID == primary.id }) {
            currentParticipantID = p.id
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded()
        }
    }
    
    private func resetRoundScopedStateIfNeeded(for roundID: String) {
        guard loadedSeriesAccessRoundID != roundID else { return }
        currentParticipantID = nil
        visibleTeeGroupID = nil
        resolvedSeriesID = nil
        isSeriesCommissioner = false
        loadedSeriesAccessRoundID = nil
        isLoadingSeriesAccess = false
        selectedTeeID = nil
        hasPerformedInitialHoleNudge = false
        currentHoleIndex = 0
    }

    private func defaultVisibleTeeGroupID() -> String? {
        if let actualTeeGroupID,
           orderedTeeGroups.contains(where: { $0.id == actualTeeGroupID }) {
            return actualTeeGroupID
        }

        if canProxySeriesGroupScoring {
            return orderedTeeGroups.first?.id
        }

        return nil
    }

    private func syncVisibleTeeGroupIfNeeded() {
        let validGroupIDs = Set(orderedTeeGroups.map(\.id))
        if let visibleTeeGroupID, validGroupIDs.contains(visibleTeeGroupID) {
            return
        }

        visibleTeeGroupID = defaultVisibleTeeGroupID()
    }

    private func loadSeriesAccessIfNeeded() async {
        let roundID = snapshot.round.id
        guard roundID.isPopulated else { return }
        guard loadedSeriesAccessRoundID != roundID else { return }
        guard !isLoadingSeriesAccess else { return }

        if let seriesAccessOverride {
            resolvedSeriesID = seriesAccessOverride.seriesID
            isSeriesCommissioner = seriesAccessOverride.isCommissioner
            loadedSeriesAccessRoundID = roundID
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded(force: true)
            return
        }

        isLoadingSeriesAccess = true
        defer {
            isLoadingSeriesAccess = false
            loadedSeriesAccessRoundID = roundID
        }

        guard let seriesID = await resolveSeriesIDForRound(),
              seriesID.isPopulated else {
            resolvedSeriesID = nil
            isSeriesCommissioner = false
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded(force: true)
            return
        }

        resolvedSeriesID = seriesID

        let series = await resolveSeries(seriesID: seriesID)
        let members = await FirebaseService.shared.fetchSeriesMembers(seriesID: seriesID)
        let activeMembers = members.filter(\.isActive)
        let (currentUserID, currentPlayerID) = await currentUserAndPlayerIDs()

        let isOwnerCommissioner = currentUserID?.isPopulated == true && series?.commissionerUserID == currentUserID
        let isPlayerCommissioner = currentPlayerID?.isPopulated == true
            && (series?.commissionerPlayerID == currentPlayerID
                || activeMembers.first(where: { $0.playerID == currentPlayerID })?.role == .commissioner)

        isSeriesCommissioner = isOwnerCommissioner || isPlayerCommissioner
        syncVisibleTeeGroupIfNeeded()
        updateSelectedTeeIfNeeded(force: true)
    }

    private func resolveSeriesIDForRound() async -> String? {
        if let activeSeriesID = appSession?.activeSeriesID, activeSeriesID.isPopulated {
            return activeSeriesID
        }

        let seriesMemberID = snapshot.participants
            .compactMap(\.seriesMemberID)
            .first(where: { $0.isPopulated })

        guard let seriesMemberID else { return nil }

        guard case .success(let member) = await FirebaseService.shared.fetchSeriesMember(memberID: seriesMemberID),
              member.parentID.isPopulated else {
            return nil
        }

        return member.parentID
    }

    private func resolveSeries(seriesID: String) async -> Series? {
        if let cached = appSession?.seriesList.first(where: { $0.id == seriesID }) {
            return cached
        }

        guard case .success(let series) = await FirebaseService.shared.fetchSeries(id: seriesID) else {
            return nil
        }

        return series
    }

    private func currentUserAndPlayerIDs() async -> (String?, String?) {
        let user = await AppData.shared.user
        let primaryPlayer = await AppData.shared.getPrimaryPlayer()
        let userID = user?.id ?? actualParticipant?.userID
        let playerID = primaryPlayer?.id ?? actualParticipant?.playerID
        return (userID, playerID)
    }

    private func scheduleInitialHoleNudgeIfNeeded() {
        guard !hasPerformedInitialHoleNudge else { return }
        guard activeTeeGroupParticipants.isPopulated else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
            self.navigateToNextUnscoredHole()
            self.hasPerformedInitialHoleNudge = true
        })
    }

    private func updateSelectedTeeIfNeeded(force: Bool = false) {
        let options = teeOptionsForMenu
        guard options.isPopulated else { return }
        
        if !force, let selectedTeeID, options.contains(where: { $0.id == selectedTeeID }) {
            return
        }
        
        let fromParticipants = teeSelectionOptions
        if fromParticipants.isPopulated {
            selectedTeeID = preferredTeeID(options: fromParticipants)
        } else {
            selectedTeeID = snapshot.defaultTee?.id ?? options.first?.id
        }
    }

    private func targetHoleNumber(forVisibleGroupID groupID: String) -> Int {
        let courseHoles = courseHoleNumbers(for: snapshot)
        guard courseHoles.isPopulated else { return 1 }

        guard let group = orderedTeeGroups.first(where: { $0.id == groupID }) else {
            return courseHoles.first ?? 1
        }

        if courseHoles.contains(group.startingHole) {
            return group.startingHole
        }

        return LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: snapshot.holeRange,
            teeGroupID: groupID,
            teeGroups: snapshot.teeGroups
        ).first ?? courseHoles.first ?? 1
    }
    
    private func preferredTeeID(options: [TeeSelectionOption]) -> String? {
        guard options.isPopulated else { return nil }
        if options.count == 1 { return options.first?.id }
        return options.max(by: { $0.yardage < $1.yardage })?.id ?? options.first?.id
    }
    
    private func yardage(for tee: Tee, range: HoleRange) -> Int {
        tee.holes.reduce(0) { result, hole in
            range.contains(hole.number) ? result + hole.yardage : result
        }
    }

    // MARK: - Round Completion Helpers

    /// Holes in the tee group where at least one player has no score.
    var unscoredHoleNumbers: [Int] {
        unscoredHoleNumbers(in: snapshot, groupID: actualTeeGroupID)
    }

    /// Sets the max allowed score for every unscored player on every unscored hole.
    /// Uses a single Firestore batch write instead of N individual writes.
    func applyMaxScoresToUnscoredHoles() async {
        guard let roundSession else { return }

        let players = actualTeeGroupParticipants
        guard players.isPopulated else { return }
        let maxScoreRule = snapshot.gameFormat.configuration.maxScoreOverPar
        let roundID = snapshot.round.id
        let resolved = snapshot.segment(forHole: 1)
        let segmentID = resolved?.id.isPopulated == true ? resolved!.id : snapshot.roundSegment?.id ?? "seg0"
        let beforeSnapshot = roundSession.snapshot
        let groupID = players.first?.groupID
        let entryParticipantID = actualParticipant?.id ?? players.first?.id ?? ""
        let unscoredHolesBefore = unscoredHoleNumbers(in: beforeSnapshot, groupID: groupID)
        let holeProgressBefore = Dictionary(
            uniqueKeysWithValues: unscoredHolesBefore.map { holeNumber in
                (
                    holeNumber,
                    holeCompletionProgress(
                        holeNumber: holeNumber,
                        in: beforeSnapshot,
                        groupID: groupID
                    )
                )
            }
        )

        var entriesToWrite: [ScoreEntry] = []
        var filledRecords: [(participant: RoundParticipant, entry: ScoreEntry)] = []
        var updatedSnapshot = roundSession.snapshot

        for holeNumber in unscoredHoleNumbers {
            let par = hole(for: holeNumber)?.par ?? 4
            let max = maxScoreRule.maxScore(for: par)
            for participant in players {
                let isScored = scoreEntry(for: participant.id, holeNumber: holeNumber).map {
                    $0.strokes != nil || $0.pickedUp
                } ?? false
                guard !isScored else { continue }

                let entrySegmentID = snapshot.segment(forHole: holeNumber)?.id.isPopulated == true
                    ? snapshot.segment(forHole: holeNumber)!.id
                    : segmentID
                let id = ScoreEntry.makeID(hole: holeNumber, segment: entrySegmentID, scoringUnit: participant.id)

                var entry = scoreEntry(for: participant.id, holeNumber: holeNumber) ?? ScoreEntry(
                    id: id,
                    holeNumber: holeNumber,
                    segmentID: entrySegmentID,
                    groupID: participant.groupID ?? "",
                    scoringUnitID: participant.id,
                    participantIDs: [participant.id],
                    strokes: nil,
                    value: nil,
                    pickedUp: false,
                    entryID: actualParticipant?.id ?? participant.id,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: roundID
                )
                entry.id = id
                entry.parentID = roundID
                entry.segmentID = entrySegmentID
                entry.groupID = participant.groupID ?? entry.groupID
                entry.scoringUnitID = participant.id
                entry.participantIDs = [participant.id]
                entry.entryID = actualParticipant?.id ?? participant.id
                entry.pickedUp = false
                entry.value = nil
                entry.strokes = max

                entriesToWrite.append(entry)
                filledRecords.append((participant, entry))
                updatedSnapshot.scoring.upsert(entry)
            }
        }

        guard !entriesToWrite.isEmpty else { return }

        isApplyingMaxScores = true
        defer { isApplyingMaxScores = false }

        let previousSnapshot = roundSession.snapshot
        roundSession.snapshot = updatedSnapshot

        do {
            _ = try await entriesToWrite.batchPut().get()
            lastLocalScoreAt = Date()
            usedMaxScoreFill = true

            var telemetrySnapshot = beforeSnapshot
            let sortedRecords = filledRecords.sorted { lhs, rhs in
                if lhs.entry.holeNumber != rhs.entry.holeNumber {
                    return lhs.entry.holeNumber < rhs.entry.holeNumber
                }
                return (lhs.participant.teeOrder ?? Int.max) < (rhs.participant.teeOrder ?? Int.max)
            }

            for record in sortedRecords {
                telemetrySnapshot.scoring.upsert(record.entry)
                emitScoreSavedTelemetry(
                    participant: record.participant,
                    holeNumber: record.entry.holeNumber,
                    strokes: record.entry.strokes ?? 0,
                    entryMethod: .maxScoreFill,
                    beforeProgress: holeProgressBefore[record.entry.holeNumber] ?? 0,
                    afterSnapshot: telemetrySnapshot,
                    emitHoleTransition: false
                )
            }

            for (holeNumber, beforeProgress) in holeProgressBefore {
                emitHoleTransitionTelemetry(
                    snapshot: updatedSnapshot,
                    groupID: groupID,
                    teeID: players.first?.teeBoxID,
                    holeNumber: holeNumber,
                    beforeProgress: beforeProgress,
                    entryParticipantID: entryParticipantID
                )
            }

            let unscoredHolesAfter = unscoredHoleNumbers(in: updatedSnapshot, groupID: groupID)
            var props = telemetryRoundProperties(
                snapshot: updatedSnapshot,
                teeID: players.first?.teeBoxID,
                extra: [
                    "entries_filled": filledRecords.count,
                    "holes_filled": Set(filledRecords.map { $0.entry.holeNumber }).count,
                    "unscored_holes_before": unscoredHolesBefore.count,
                    "unscored_holes_after": unscoredHolesAfter.count,
                    "entry_participant_id": entryParticipantID
                ]
            )
            if let groupID, groupID.isPopulated {
                props["group_id"] = groupID
            }
            addEvent("live_round.max_scores_applied", eventProps: props)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to batch apply max scores", error: error)
            roundSession.snapshot = previousSnapshot
        }
    }

    func roundCompletionTelemetryProps(extra: [String: Any] = [:]) -> [String: Any] {
        let participant: RoundParticipant?
        if let currentParticipant {
            participant = currentParticipant
        } else if let currentParticipantID {
            participant = snapshot.participants.first(where: { $0.id == currentParticipantID })
        } else {
            participant = nil
        }
        var props = telemetryRoundProperties(
            snapshot: snapshot,
            participant: participant,
            teeID: participant?.teeBoxID,
            extra: completionSummaryProps(snapshot: snapshot, participant: participant)
        )
        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    private func completionSummaryProps(
        snapshot: RoundSnapshot,
        participant: RoundParticipant?
    ) -> [String: Any] {
        let totalHoles = holeNumbers(in: snapshot).count
        let holesScoredCount = participant.map { holesPlayedCount(for: $0.id, in: snapshot) } ?? 0
        let participantCompletionPct = participant.map {
            participantCompletionPercentage(participantID: $0.id, in: snapshot)
        } ?? 0

        return [
            "holes_scored_count": holesScoredCount,
            "total_holes": totalHoles,
            "participant_completion_pct": participantCompletionPct,
            "unscored_holes_count": max(0, totalHoles - holesScoredCount),
            "used_max_score_fill": usedMaxScoreFill
        ]
    }

    private func unscoredHoleNumbers(in snapshot: RoundSnapshot, groupID: String?) -> [Int] {
        holeNumbers(in: snapshot).filter { holeNumber in
            holeCompletionProgress(holeNumber: holeNumber, in: snapshot, groupID: groupID) < 1
        }
    }

    private func emitScoreSavedTelemetry(
        participant: RoundParticipant,
        holeNumber: Int,
        strokes: Int,
        entryMethod: LiveRoundEntryMethod,
        beforeProgress: Double,
        afterSnapshot: RoundSnapshot,
        emitHoleTransition: Bool = true
    ) {
        let participantHolesScoredCount = holesPlayedCount(for: participant.id, in: afterSnapshot)
        let totalHoles = holeNumbers(in: afterSnapshot).count
        let participantCompletionPct = TelemetryEventProps.completionPercentage(
            completedCount: participantHolesScoredCount,
            totalCount: totalHoles
        )
        let entryParticipantID = actualParticipant?.id ?? participant.id

        addEvent(
            "live_round.score_saved",
            eventProps: TelemetryEventProps.scoring(
                snapshot: afterSnapshot,
                participant: participant,
                entryParticipantID: entryParticipantID,
                holeNumber: holeNumber,
                strokes: strokes,
                entryMethod: entryMethod,
                participantHolesScoredCount: participantHolesScoredCount,
                totalHoles: totalHoles,
                participantCompletionPct: participantCompletionPct
            )
        )

        if emitHoleTransition {
            emitHoleTransitionTelemetry(
                snapshot: afterSnapshot,
                groupID: participant.groupID,
                teeID: participant.teeBoxID,
                holeNumber: holeNumber,
                beforeProgress: beforeProgress,
                entryParticipantID: entryParticipantID,
                triggerParticipantID: participant.id
            )
        }
    }

    private func emitScoreClearedTelemetry(
        participant: RoundParticipant,
        holeNumber: Int,
        previousEntry: ScoreEntry,
        entryMethod: LiveRoundEntryMethod,
        beforeProgress: Double,
        afterSnapshot: RoundSnapshot
    ) {
        let participantHolesScoredCount = holesPlayedCount(for: participant.id, in: afterSnapshot)
        let totalHoles = holeNumbers(in: afterSnapshot).count
        let participantCompletionPct = TelemetryEventProps.completionPercentage(
            completedCount: participantHolesScoredCount,
            totalCount: totalHoles
        )
        let entryParticipantID = actualParticipant?.id ?? participant.id
        var extra: [String: Any] = [:]
        if let previousStrokes = previousEntry.strokes {
            extra["previous_strokes"] = previousStrokes
        }

        addEvent(
            "live_round.score_cleared",
            eventProps: TelemetryEventProps.scoring(
                snapshot: afterSnapshot,
                participant: participant,
                entryParticipantID: entryParticipantID,
                holeNumber: holeNumber,
                entryMethod: entryMethod,
                participantHolesScoredCount: participantHolesScoredCount,
                totalHoles: totalHoles,
                participantCompletionPct: participantCompletionPct,
                extra: extra
            )
        )

        emitHoleTransitionTelemetry(
            snapshot: afterSnapshot,
            groupID: participant.groupID,
            teeID: participant.teeBoxID,
            holeNumber: holeNumber,
            beforeProgress: beforeProgress,
            entryParticipantID: entryParticipantID,
            triggerParticipantID: participant.id
        )
    }

    private func emitHoleTransitionTelemetry(
        snapshot: RoundSnapshot,
        groupID: String?,
        teeID: String?,
        holeNumber: Int,
        beforeProgress: Double,
        entryParticipantID: String,
        triggerParticipantID: String? = nil
    ) {
        let afterProgress = holeCompletionProgress(
            holeNumber: holeNumber,
            in: snapshot,
            groupID: groupID
        )

        let transition = TelemetryEventProps.holeCompletionTransition(
            before: beforeProgress,
            after: afterProgress
        )
        guard transition != .none else { return }

        var props = telemetryRoundProperties(
            snapshot: snapshot,
            teeID: teeID,
            extra: [
                "hole_number": holeNumber,
                "entry_participant_id": entryParticipantID,
                "hole_completion_before_pct": beforeProgress * 100,
                "hole_completion_after_pct": afterProgress * 100
            ]
        )
        if let groupID, groupID.isPopulated {
            props["group_id"] = groupID
        }
        if let triggerParticipantID, triggerParticipantID.isPopulated {
            props["trigger_participant_id"] = triggerParticipantID
        }

        addEvent(
            transition == .completed ? "live_round.hole_completed" : "live_round.hole_reopened",
            eventProps: props
        )
    }
}
