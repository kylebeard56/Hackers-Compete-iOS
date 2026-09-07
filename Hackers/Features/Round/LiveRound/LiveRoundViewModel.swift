//
//  LiveRoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/30/26.
//

import Combine
import SwiftUI

enum NameDisplayFormat: String, CaseIterable {
    static let defaultsKey = "live_round_name_display_format_v1"

    /// "J. Smith"
    case firstInitialLastName
    /// "John S."
    case firstNameLastInitial

    func displayName(for name: Name) -> String {
        let given = name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard given.isPopulated || family.isPopulated else { return name.fullName }

        switch self {
        case .firstInitialLastName:
            guard let g = given.first else { return family }
            return "\(g). \(family)"
        case .firstNameLastInitial:
            guard let f = family.first else { return given }
            return "\(given) \(f)."
        }
    }

    static var persisted: Self {
        UserDefaults.standard.string(forKey: defaultsKey)
            .flatMap(Self.init(rawValue:))
            ?? .firstNameLastInitial
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

struct LiveRoundAdaptiveNameText: View {
    let name: Name
    let format: NameDisplayFormat
    let fontSize: CGFloat
    let weight: FontModule.Weight
    let color: Color

    private var fullName: String {
        name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compactName: String {
        format.displayName(for: name)
    }

    init(
        name: Name,
        format: NameDisplayFormat,
        fontSize: CGFloat,
        weight: FontModule.Weight,
        color: Color
    ) {
        self.name = name
        self.format = format
        self.fontSize = fontSize
        self.weight = weight
        self.color = color
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            nameText(fullName.isPopulated ? fullName : compactName)
                .fixedSize(horizontal: true, vertical: false)

            nameText(compactName)
        }
        .layoutPriority(1)
    }

    private func nameText(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: fontSize, weight: weight)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

struct HandicapStrokeAllocation: Equatable, Sendable {
    let holeNumber: Int
    let strokes: Int
}

struct HandicapStrokeUsage: Equatable, Sendable {
    let used: Int
    let remaining: Int
    let remainingAllocations: [HandicapStrokeAllocation]

    var total: Int { used + remaining }
}

enum GrossScoreOutcomeBucket: Int, CaseIterable, Hashable, Sendable {
    case birdieOrBetter
    case par
    case bogey
    case doubleBogey
    case tripleBogey

    /// Hexagonal chart order, clockwise from north, from best to worst outcome.
    static let qualityRadarOrder: [Self] = [
        .birdieOrBetter,
        .par,
        .bogey,
        .doubleBogey,
        .tripleBogey,
    ]

    var label: String {
        switch self {
        case .birdieOrBetter: "Birdie or better"
        case .par: "Par"
        case .bogey: "Bogey"
        case .doubleBogey: "Double"
        case .tripleBogey: "Triple+"
        }
    }

    static func resolve(relativeToPar: Int) -> GrossScoreOutcomeBucket {
        switch relativeToPar {
        case ...(-1): .birdieOrBetter
        case 0: .par
        case 1: .bogey
        case 2: .doubleBogey
        default: .tripleBogey
        }
    }
}

struct GrossScoreOutcomeCount: Identifiable, Equatable, Sendable {
    let bucket: GrossScoreOutcomeBucket
    let count: Int

    var id: Int { bucket.rawValue }
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
    @Published private(set) var roundManagementAccess: RoundManagementAccess = .none
    @Published private(set) var seriesScoreboardSnapshot: SeriesScoreboardSnapshot?
    @Published private(set) var matchupProbabilities: [String: MatchupProbability] = [:]
    @Published private(set) var loadingMatchupProbabilityIDs: Set<String> = []
    @Published private(set) var isOverviewVisible = false
    @Published private(set) var isLoadingOverview = false
    private var overviewRefreshTask: Task<Void, Never>?
    private var restoredHole: Int?

    /// Called only after the critical snapshot is ready, before score controls appear.
    func restoreCurrentHole(_ hole: Int?) {
        hasPerformedInitialHoleNudge = true
        hasSelectedInitialVisibleGroupStartingHole = true
        visibleGroupSwitchRequest = nil
        let target = hole.flatMap { holeNumbers.contains($0) ? $0 : nil } ?? currentHoleNumber
        restoredHole = target
        selectHole(target)
    }

    func setOverviewVisible(_ visible: Bool) {
        isOverviewVisible = visible
        guard visible else { return }
        if !availableLeaderboardModes.contains(leaderboardMode) { leaderboardMode = .individual }
        refreshSeriesScoreboardProjection()
        guard overviewRefreshTask == nil else { return }
        overviewRefreshTask = Task { [weak self] in
            guard let self else { return }
            self.isLoadingOverview = true
            let startedAt = Date()
            defer {
                self.isLoadingOverview = false
                self.overviewRefreshTask = nil
                self.addEvent("live_round.overview_loaded", eventProps: [
                    "round_id": self.snapshot.round.id,
                    "duration_ms": Int(Date().timeIntervalSince(startedAt) * 1_000)
                ])
            }
            await self.loadSeriesAccessIfNeeded()
            guard self.isOverviewVisible, let seriesID = self.resolvedSeriesID else { return }
            await self.loadLiveSeriesScoreboardContext(seriesID: seriesID)
        }
    }

    @Published var selectedTeeID: String?
    @Published var nameDisplayFormat: NameDisplayFormat = .persisted {
        didSet {
            nameDisplayFormat.persist()
        }
    }
    @Published var theme: GolfTheme = .purple
    @Published var isSpectator: Bool = false
    @Published var showScorelessLeaderboardRows: Bool = true
    
    /// The hole last explicitly selected (tap on HoleWindowSelector or navigateToNextUnscoredHole).
    /// Used for programmatic pager scroll. Does not sync with user scroll—scoringPageHole is the
    /// source of truth for "which hole is being viewed."
    @Published var currentHoleIndex: Int = 0
    @Published var scoreBasis: ScoreBasis = .gross
    /// Presentation basis for matchup scores. Probability always follows the configured
    /// competition basis and is intentionally independent from this display control.
    @Published var matchupScoreBasis: ScoreBasis = .gross
    @Published var leaderboardMode: LeaderboardMode = .individual
    
    var handicapsEnabled: Bool {
        snapshot.configuration.useHandicaps
    }

    /// Matchup odds describe the actual competition. In a handicapped round that is always Net,
    /// even while the user temporarily views Gross scores for context.
    var matchupProbabilityScoreBasis: ScoreBasis {
        handicapsEnabled ? .net : .gross
    }

    var isAttendanceConfirmationEnabled: Bool {
        snapshot.round.configuration.attendanceConfirmationEnabled == true
    }

    func effectivePresenceStatus(for participant: RoundParticipant) -> RoundParticipantPresenceStatus {
        isAttendanceConfirmationEnabled ? participant.resolvedPresenceStatus : .active
    }

    func isPresenceActive(_ participant: RoundParticipant) -> Bool {
        effectivePresenceStatus(for: participant) != .noShow
    }

    var isCurrentUserHost: Bool {
        roundManagementAccess.isHost
    }

    var canManageRound: Bool { roundManagementAccess.canManageRound }
    
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
    /// Cached engine results, keyed by the score basis each result was computed with.
    private var cachedEngineResults: [String: ScoringResult] = [:]
    /// Participant-level format results for Solo leaderboard contribution views.
    private var cachedIndividualContributionEngineResults: [String: ScoringResult] = [:]
    private var cachedPlayerSimulations: [String: (revision: String, simulation: PlayerProjectionSimulation)] = [:]
    private var cachedMatchupProbabilityTimelines: [
        String: (revision: String, timeline: MatchupProbabilityTimeline)
    ] = [:]
    private var matchupProbabilityTask: Task<Void, Never>?
    private var matchupProbabilityTaskRevision: String?
    private var matchupProbabilityResultRevisions: [String: String] = [:]
    private var matchupProbabilityRoundID: String?
    private var isMatchupProbabilityPrecomputationEnabled = false
    private var predictionContextRoundID: String?
    private static let liveProjectionIterationCount = 1_000
    private static let matchupTimelineProjectionIterationCount = 100
    private var hasPerformedInitialHoleNudge = false
    private var hasSelectedInitialVisibleGroupStartingHole = false
    private var scopedRoundID: String?
    private var loadedSeriesAccessRoundID: String?
    private var isLoadingSeriesAccess = false
    private var liveSeriesScoreboardContext: LiveSeriesScoreboardContext?

    var seriesAccessOverride: SeriesAccessOverride?

    private struct LiveSeriesScoreboardContext {
        let series: Series
        let rounds: [SeriesRound]
        let scoringProfiles: [SeriesScoringProfile]
        let pointAwards: [SeriesPointAward]
        let teams: [SeriesTeam]
        let members: [SeriesMember]
        let currentSeriesRound: SeriesRound?
        let currentRoundMappings: [SeriesRoundMapping]
        let canonicalResults: [SeriesRoundResult]
    }
    
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
        applySeriesAccessOverrideIfAvailable()
        syncVisibleTeeGroupIfNeeded()
        updateSelectedTeeIfNeeded()
        
        applyScoreBasisDefaultsForCurrentSnapshot(force: true)
        
        roundSession.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                guard let self else { return }
                let currentHole = self.currentHoleNumber
                let wasIncomplete = self.holeCompletionProgress(holeNumber: currentHole) < 1

                self.resetRoundScopedStateIfNeeded(for: s.round.id)

                let previousVisibleGroupID = self.visibleTeeGroupID
                let previousStartingHole = self.visibleGroupStartingHole

                self.snapshot = s
                self.rebuildScoreIndex()
                self.applySeriesAccessOverrideIfAvailable()
                self.syncVisibleTeeGroupIfNeeded()
                if let restoredHole = self.restoredHole {
                    self.selectHole(restoredHole)
                }
                self.ensureHoleIndexInBounds()
                self.selectVisibleGroupStartingHoleIfNeeded(
                    previousVisibleGroupID: previousVisibleGroupID,
                    previousStartingHole: previousStartingHole
                )
                self.updateSelectedTeeIfNeeded()
                self.refreshSeriesScoreboardProjection()

                if self.isOverviewVisible && !self.availableLeaderboardModes.contains(self.leaderboardMode) {
                    self.leaderboardMode = .individual
                }

                self.applyScoreBasisDefaultsForCurrentSnapshot(force: false)
                self.scheduleMatchupProbabilityRefresh()

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
        applySeriesAccessOverrideIfAvailable()
        syncVisibleTeeGroupIfNeeded()
        updateSelectedTeeIfNeeded()
        refreshSeriesScoreboardProjection()
        applyScoreBasisDefaultsForCurrentSnapshot(force: true)
        // Direct snapshots are complete fixtures/previews and do not have an asynchronous
        // series-context load to wait for.
        predictionContextRoundID = snapshot.round.id
        scheduleMatchupProbabilityRefresh()
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
        if let restoredHole, holes.contains(restoredHole) { return restoredHole }
        let idx = min(max(0, currentHoleIndex), holes.count - 1)
        return holes[idx]
    }
    
    func swipeHole(direction: Int) {
        // direction: -1 previous, +1 next
        let next = currentHoleIndex + direction
        let index = min(max(0, next), max(0, holeNumbers.count - 1))
        if holeNumbers.indices.contains(index) { selectHole(holeNumbers[index]) }
    }
    
    func selectHole(_ holeNumber: Int) {
        guard let idx = holeNumbers.firstIndex(of: holeNumber) else { return }
        currentHoleIndex = idx
        if restoredHole != nil { restoredHole = holeNumber }
    }

    private var visibleGroupStartingHole: Int? {
        guard let visibleTeeGroupID else { return nil }
        return orderedTeeGroups.first(where: { $0.id == visibleTeeGroupID })?.startingHole
    }

    private func selectVisibleGroupStartingHoleIfNeeded(
        previousVisibleGroupID: String?,
        previousStartingHole: Int?
    ) {
        guard restoredHole == nil else { return }
        let currentStartingHole = visibleGroupStartingHole

        guard let visibleTeeGroupID,
              previousVisibleGroupID == visibleTeeGroupID,
              let currentStartingHole,
              currentStartingHole != previousStartingHole,
              holeNumbers.contains(currentStartingHole) else {
            return
        }

        selectHole(currentStartingHole)
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

    var visibleTeeGroup: TeeTimeGroup? {
        guard let visibleTeeGroupID else { return nil }
        return orderedTeeGroups.first(where: { $0.id == visibleTeeGroupID })
    }

    var visibleStartingHole: Int? {
        visibleTeeGroup?.startingHole
    }

    var startingHoleMenuNumbers: [Int] {
        snapshot.holeRange?.holeNumbers ?? Array(1...18)
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

    private var canProxyManagedGroupScoring: Bool {
        !isSpectator && canManageRound
    }

    var canProxyVisibleGroupScoring: Bool {
        canProxyManagedGroupScoring && visibleTeeGroupID?.isPopulated == true
    }

    var canScoreVisibleGroup: Bool {
        canEditActualGroupScores || canProxyVisibleGroupScoring
    }

    var canCompleteActualGroup: Bool {
        canEditActualGroupScores && !isViewingAlternateGroup
    }

    var canChangeVisibleGroup: Bool {
        !isSpectator && canManageRound && orderedTeeGroups.count > 1
    }

    var canChangeVisibleGroupStartingHole: Bool {
        !isSpectator && (currentParticipantID != nil || canManageRound) && visibleTeeGroup != nil
    }

    func canEditScorecard(participant: RoundParticipant) -> Bool {
        canEditActualGroupScores
            && isPresenceActive(participant)
            && activeActualTeeGroupParticipants.contains(where: { $0.id == participant.id })
    }

    func canEditPresence(participant: RoundParticipant) -> Bool {
        isAttendanceConfirmationEnabled
            && canScoreVisibleGroup
            && visibleTeeGroupParticipants.contains(where: { $0.id == participant.id })
    }

    func canMarkParticipantNoShow(participant: RoundParticipant) -> Bool {
        canEditPresence(participant: participant) && !hasRecordedScores(for: participant)
    }

    func canResetPresenceToUnconfirmed(participant: RoundParticipant) -> Bool {
        canEditPresence(participant: participant) && !hasRecordedScores(for: participant)
    }

    func selectVisibleTeeGroup(_ groupID: String) {
        guard canChangeVisibleGroup || groupID == actualTeeGroupID else { return }
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

    func changeVisibleTeeGroupStartingHole(to hole: Int) async {
        guard canChangeVisibleGroupStartingHole,
              let roundSession,
              var group = visibleTeeGroup else { return }

        let validHoles = startingHoleMenuNumbers
        let resolvedHole = validHoles.contains(hole) ? hole : (validHoles.first ?? 1)
        guard group.startingHole != resolvedHole else {
            selectHole(resolvedHole)
            return
        }

        group.startingHole = resolvedHole
        do {
            try await roundSession.update(group)
            selectHole(resolvedHole)
            visibleGroupSwitchRequest = VisibleGroupSwitchRequest(
                groupID: group.id,
                targetHoleNumber: resolvedHole,
                revisionID: UUID()
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update visible tee group starting hole", error: error)
        }
    }

    struct TeamSection: Identifiable {
        let id: String
        let team: RoundTeam?
        let participants: [RoundParticipant]
    }

    struct SharedScoringSubject: Identifiable {
        var id: String { scoringUnitID }

        let scoringUnitID: String
        let title: String
        let subtitle: String?
        let participants: [RoundParticipant]
        let teamID: String?
        let scoringGroupID: String?
        let teeGroupID: String?
        let accentColor: Color?
    }

    var expectedMatchupMode: MatchupMode {
        snapshot.expectedMatchupMode
    }
    
    func team(for participant: RoundParticipant) -> RoundTeam? {
        guard let id = participant.teamID else { return nil }
        return snapshot.teams.first(where: { $0.id == id })
    }
    
    func teamColor(for participant: RoundParticipant) -> Color? {
        snapshot.teamColor(for: participant)
    }
    
    /// Groups the tee group by team, when the round requires teams.
    var teeGroupTeamSections: [TeamSection] {
        let players = teeGroupParticipants
        guard snapshot.requiresTeams, snapshot.teams.isPopulated else {
            return [TeamSection(id: "all", team: nil, participants: players)]
        }
        
        let grouped = Dictionary(grouping: players, by: { $0.teamID })
        
        let orderedTeams = snapshot.teams.sorted(by: { $0.index < $1.index })
        var sections: [TeamSection] = []
        
        for team in orderedTeams {
            let members = (grouped[team.id] ?? [])
                .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
            if members.isPopulated {
                sections.append(TeamSection(id: team.id, team: team, participants: members))
            }
        }

        sections.sort {
            let lhsOrder = $0.participants.map { $0.teeOrder ?? Int.max }.min() ?? Int.max
            let rhsOrder = $1.participants.map { $0.teeOrder ?? Int.max }.min() ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return ($0.team?.index ?? Int.max) < ($1.team?.index ?? Int.max)
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

    var sharedScoringSubjects: [SharedScoringSubject] {
        guard snapshot.isSharedScoreSource else { return [] }

        switch snapshot.configuration.scoreOwnerScope {
        case .individual:
            return teamSharedScoringSubjects()
        case .partnership:
            return partnershipSharedScoringSubjects()
        case .teeGroup:
            return teeGroupSharedScoringSubjects()
        }
    }

    var visibleSharedScoringSubjects: [SharedScoringSubject] {
        guard let visibleTeeGroupID, visibleTeeGroupID.isPopulated else {
            return sharedScoringSubjects
        }
        return sharedScoringSubjects.filter { subject in
            subject.teeGroupID == visibleTeeGroupID
                || subject.participants.contains { $0.groupID == visibleTeeGroupID }
        }
    }

    private func teamSharedScoringSubjects() -> [SharedScoringSubject] {
        let activeParticipants = snapshot.participants.filter(isPresenceActive)
        let participantSort: (RoundParticipant, RoundParticipant) -> Bool = { lhs, rhs in
            self.participantDisplaySort(lhs: lhs, rhs: rhs)
        }

        if snapshot.teams.isPopulated {
            let grouped = Dictionary(grouping: activeParticipants, by: { $0.teamID })
            let subjects = snapshot.teams
                .sorted { $0.index < $1.index }
                .compactMap { team -> SharedScoringSubject? in
                    let members = (grouped[team.id] ?? []).sorted(by: participantSort)
                    guard members.isPopulated else { return nil }
                    let subtitle = members
                        .map { formatDisplayName(for: $0) }
                        .filter(\.isPopulated)
                        .joined(separator: ", ")
                    return SharedScoringSubject(
                        scoringUnitID: scoringUnitID(forTeamID: team.id),
                        title: team.name,
                        subtitle: subtitle.isPopulated ? subtitle : nil,
                        participants: members,
                        teamID: team.id,
                        scoringGroupID: nil,
                        teeGroupID: sharedTeeGroupID(for: members),
                        accentColor: team.displaySwatchColor
                    )
                }
            if subjects.isPopulated {
                return subjects
            }
        }

        if snapshot.shouldAutoMirrorTeeGroupsToTeams, snapshot.teeGroups.isPopulated {
            return snapshot.teeGroups
                .sorted { $0.index < $1.index }
                .compactMap { group -> SharedScoringSubject? in
                    let members = activeParticipants
                        .filter { $0.groupID == group.id }
                        .sorted(by: participantSort)
                    guard members.isPopulated else { return nil }
                    let subtitle = members
                        .map { formatDisplayName(for: $0) }
                        .filter(\.isPopulated)
                        .joined(separator: ", ")
                    return SharedScoringSubject(
                        scoringUnitID: group.id,
                        title: group.name,
                        subtitle: subtitle.isPopulated ? subtitle : nil,
                        participants: members,
                        teamID: nil,
                        scoringGroupID: nil,
                        teeGroupID: group.id,
                        accentColor: nil
                    )
                }
        }

        let members = activeParticipants.sorted(by: participantSort)
        guard members.isPopulated else { return [] }
        let subtitle = members
            .map { formatDisplayName(for: $0) }
            .filter(\.isPopulated)
            .joined(separator: ", ")
        return [
            SharedScoringSubject(
                scoringUnitID: "shared_all",
                title: "Group Score",
                subtitle: subtitle.isPopulated ? subtitle : nil,
                participants: members,
                teamID: nil,
                scoringGroupID: nil,
                teeGroupID: nil,
                accentColor: nil
            )
        ]
    }

    private func partnershipSharedScoringSubjects() -> [SharedScoringSubject] {
        let persistedGroups = snapshot.scoringGroups
            .filter { $0.kind == .partnership && $0.memberIDs.isPopulated }
            .sorted { lhs, rhs in
                let lhsOrder = participants(for: lhs).first?.teeOrder ?? Int.max
                let rhsOrder = participants(for: rhs).first?.teeOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return scoringGroupLabel(lhs) < scoringGroupLabel(rhs)
            }
            .compactMap { group -> SharedScoringSubject? in
                let members = participants(for: group).filter(isPresenceActive)
                guard members.isPopulated else { return nil }
                return SharedScoringSubject(
                    scoringUnitID: scoringUnitID(for: group),
                    title: scoringGroupLabel(group),
                    subtitle: scoringGroupSubtitle(group),
                    participants: members,
                    teamID: group.teamID,
                    scoringGroupID: group.id,
                    teeGroupID: group.teeGroupID,
                    accentColor: scoringGroupAccentColor(group)
                )
            }

        if persistedGroups.isPopulated {
            return persistedGroups
        }

        let scoringUnitSubjects = scoreOwnerScoringUnitSubjects(kind: .partnership, requiresExactPair: true)
        if scoringUnitSubjects.isPopulated {
            return scoringUnitSubjects
        }

        let teeGroupSubjects = teeGroupSharedScoringSubjects()
        if teeGroupSubjects.isPopulated {
            return teeGroupSubjects
        }

        return teamSharedScoringSubjects()
    }

    private func teeGroupSharedScoringSubjects() -> [SharedScoringSubject] {
        let participantSort: (RoundParticipant, RoundParticipant) -> Bool = { lhs, rhs in
            self.participantDisplaySort(lhs: lhs, rhs: rhs)
        }
        let groups = snapshot.scoringGroups
            .filter { $0.kind == .teeGroup && $0.memberIDs.isPopulated }
            .sorted { lhs, rhs in
                let lhsOrder = participants(for: lhs).first?.teeOrder ?? Int.max
                let rhsOrder = participants(for: rhs).first?.teeOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return scoringGroupLabel(lhs) < scoringGroupLabel(rhs)
            }
            .compactMap { group -> SharedScoringSubject? in
                let members = participants(for: group).filter(isPresenceActive)
                guard members.isPopulated else { return nil }
                return SharedScoringSubject(
                    scoringUnitID: scoringUnitID(for: group),
                    title: scoringGroupLabel(group),
                    subtitle: scoringGroupSubtitle(group),
                    participants: members,
                    teamID: group.teamID,
                    scoringGroupID: group.id,
                    teeGroupID: group.teeGroupID,
                    accentColor: scoringGroupAccentColor(group)
                )
            }
        if groups.isPopulated {
            return groups
        }

        let scoringUnitSubjects = scoreOwnerScoringUnitSubjects(kind: .teeGroup, requiresExactPair: false)
        if scoringUnitSubjects.isPopulated {
            return scoringUnitSubjects
        }

        return snapshot.teeGroups
            .sorted { $0.index < $1.index }
            .compactMap { teeGroup -> SharedScoringSubject? in
                let members = snapshot.participants
                    .filter { isPresenceActive($0) && $0.groupID == teeGroup.id }
                    .sorted(by: participantSort)
                guard members.isPopulated else { return nil }
                let subtitle = members
                    .map { formatDisplayName(for: $0) }
                    .filter(\.isPopulated)
                    .joined(separator: ", ")
                return SharedScoringSubject(
                    scoringUnitID: teeGroup.id,
                    title: teeGroup.name,
                    subtitle: subtitle.isPopulated ? subtitle : nil,
                    participants: members,
                    teamID: nil,
                    scoringGroupID: nil,
                    teeGroupID: teeGroup.id,
                    accentColor: nil
                )
            }
    }

    private func scoreOwnerScoringUnitSubjects(
        kind: RoundScoringGroupKind,
        requiresExactPair: Bool
    ) -> [SharedScoringSubject] {
        allScoringUnits
            .filter { unit in
                unit.owner == .scoreOwner
                    && unit.ownerIDs.isPopulated
                    && (!requiresExactPair || unit.ownerIDs.count == 2)
            }
            .compactMap { scoringUnitSubject(for: $0, kind: kind) }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.participants.first?.teeOrder ?? Int.max
                let rhsOrder = rhs.participants.first?.teeOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.title < rhs.title
            }
    }

    private func scoringUnitSubject(
        for scoringUnit: ScoringUnit,
        kind: RoundScoringGroupKind
    ) -> SharedScoringSubject? {
        let memberByID = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        let members = scoringUnit.ownerIDs
            .compactMap { memberByID[$0] }
            .filter(isPresenceActive)
            .sorted(by: participantDisplaySort)
        guard members.isPopulated else { return nil }

        let teamIDs = Set(members.compactMap(\.teamID).filter(\.isPopulated))
        let teamID = teamIDs.count == 1 ? teamIDs.first : nil
        let team = teamID.flatMap { id in snapshot.teams.first { $0.id == id } }
        let teeGroupIDs = Set(members.compactMap(\.groupID).filter(\.isPopulated))
        let teeGroupID = teeGroupIDs.count == 1 ? teeGroupIDs.first : nil
        let teeGroup = teeGroupID.flatMap { id in snapshot.teeGroups.first { $0.id == id } }
        let memberNames = members
            .map { formatDisplayName(for: $0) }
            .filter(\.isPopulated)
        let title: String
        let subtitle: String?

        switch kind {
        case .partnership:
            title = memberNames.isPopulated ? memberNames.joined(separator: " + ") : "Partnership"
            subtitle = team?.name
        case .teeGroup:
            title = teeGroup?.name ?? "Group Score"
            subtitle = memberNames.isPopulated ? memberNames.joined(separator: ", ") : nil
        }

        return SharedScoringSubject(
            scoringUnitID: scoringUnit.id,
            title: title,
            subtitle: subtitle,
            participants: members,
            teamID: teamID,
            scoringGroupID: snapshot.scoringGroup(id: scoringUnit.id)?.id,
            teeGroupID: teeGroupID,
            accentColor: team?.displaySwatchColor
        )
    }

    private func sharedTeeGroupID(for participants: [RoundParticipant]) -> String? {
        let ids = Set(participants.compactMap(\.groupID).filter(\.isPopulated))
        return ids.count == 1 ? ids.first : nil
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

    private var allScoringUnits: [ScoringUnit] {
        snapshot.segments.flatMap(\.scoringUnits)
    }

    private func scoringUnit(id scoringUnitID: String) -> ScoringUnit? {
        allScoringUnits.first { $0.id == scoringUnitID }
    }

    func scoringUnitID(forTeamID teamID: String) -> String {
        allScoringUnits.first { scoringUnit in
            scoringUnit.owner == .team
                && (scoringUnit.id == teamID || scoringUnit.ownerIDs.contains(teamID))
        }?.id ?? teamID
    }

    func scoringUnitID(for scoringGroup: RoundScoringGroup) -> String {
        let groupMemberIDs = Set(scoringGroup.memberIDs)
        return allScoringUnits.first { scoringUnit in
            guard scoringUnit.owner == .scoreOwner else { return false }
            if scoringUnit.id == scoringGroup.id { return true }
            return Set(scoringUnit.ownerIDs) == groupMemberIDs
        }?.id ?? scoringGroup.id
    }

    private func scoringGroup(for scoringUnit: ScoringUnit) -> RoundScoringGroup? {
        if let group = snapshot.scoringGroup(id: scoringUnit.id) {
            return group
        }

        let ownerIDs = Set(scoringUnit.ownerIDs)
        return snapshot.scoringGroups.first { group in
            Set(group.memberIDs) == ownerIDs
        }
    }

    private func scoringGroup(for row: ScoringRow) -> RoundScoringGroup? {
        if let group = snapshot.scoringGroup(id: row.scoringUnitID) {
            return group
        }
        if let scoringUnit = scoringUnit(id: row.scoringUnitID),
           let group = scoringGroup(for: scoringUnit) {
            return group
        }
        let participantIDs = Set(row.participantIDs)
        return snapshot.scoringGroups.first { group in
            group.memberIDs.isPopulated && Set(group.memberIDs) == participantIDs
        }
    }

    private func team(for row: ScoringRow, teamMap: [String: RoundTeam]) -> RoundTeam? {
        if let team = teamMap[row.scoringUnitID] {
            return team
        }
        if let scoringUnit = scoringUnit(id: row.scoringUnitID),
           scoringUnit.owner == .team,
           let teamID = scoringUnit.ownerIDs.first,
           let team = teamMap[teamID] {
            return team
        }

        guard row.owner == .team else { return nil }

        let teamIDs = Set(row.participantIDs.compactMap { participantID in
            snapshot.participants.first(where: { $0.id == participantID })?.teamID
        })
        guard teamIDs.count == 1,
              let teamID = teamIDs.first else {
            return nil
        }
        return teamMap[teamID]
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
        let members = participants(for: scoringGroup).filter(isPresenceActive)
        guard let anchor = members.first else { return nil }
        return sharedScoringSession(
            anchorParticipant: anchor,
            participants: members,
            scoringUnitID: scoringUnitID(for: scoringGroup),
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
            scoringUnitID: scoringUnitID(forTeamID: team.id),
            holeNumber: holeNumber,
            title: team.name,
            subtitle: memberNames.isPopulated ? memberNames : nil,
            teamID: team.id
        )
    }

    func sharedScoringSession(
        for subject: SharedScoringSubject,
        holeNumber: Int
    ) -> ScoringSession? {
        guard let anchor = subject.participants.first else { return nil }
        return sharedScoringSession(
            anchorParticipant: anchor,
            participants: subject.participants,
            scoringUnitID: subject.scoringUnitID,
            holeNumber: holeNumber,
            title: subject.title,
            subtitle: subject.subtitle,
            teamID: subject.teamID,
            scoringGroupID: subject.scoringGroupID
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
        nameDisplayFormat.displayName(for: participant.name)
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

    var isFriendlyScoreInputMode: Bool {
        snapshot.configuration.scoreInputMode == .friendlyRelativeToPar
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
        cachedEngineResults.removeAll()
        cachedIndividualContributionEngineResults.removeAll()
    }
    
    func scoreEntry(for participantID: String, holeNumber: Int) -> ScoreEntry? {
        scoreIndex[Self.scoreIndexKey(participantID: participantID, holeNumber: holeNumber)]
    }
    
    func grossStrokes(for participantID: String, holeNumber: Int) -> Int? {
        guard let entry = scoreEntry(for: participantID, holeNumber: holeNumber) else { return nil }
        return resolvedGrossStrokes(from: entry, holeNumber: holeNumber)
    }

    func grossRelativeToPar(for participantID: String, holeNumber: Int) -> Int? {
        guard let entry = scoreEntry(for: participantID, holeNumber: holeNumber) else { return nil }
        return resolvedRelativeToPar(from: entry, holeNumber: holeNumber)
    }

    func scoreInputValue(for participantID: String, holeNumber: Int) -> Int? {
        if isFriendlyScoreInputMode {
            return grossRelativeToPar(for: participantID, holeNumber: holeNumber)
        }
        return grossStrokes(for: participantID, holeNumber: holeNumber)
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
        participantsInTeeGroup(in: snapshot, groupID: groupID).filter(isPresenceActive)
    }

    private func holesPlayedCount(for participantID: String, in snapshot: RoundSnapshot) -> Int {
        guard let participant = snapshot.participants.first(where: { $0.id == participantID }),
              isPresenceActive(participant) else {
            return 0
        }
        return holeNumbers(in: snapshot).filter { holeNumber in
            guard let entry = scoreEntry(in: snapshot, participantID: participantID, holeNumber: holeNumber) else {
                return false
            }
            return entry.hasRecordedScore
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
            return entry.hasRecordedScore
        }.count

        return Double(completed) / Double(players.count)
    }

    private func resolvedGrossStrokes(from entry: ScoreEntry, holeNumber: Int) -> Int? {
        if let strokes = entry.strokes {
            return strokes
        }
        guard let relative = entry.relativeToPar else { return nil }
        let par = hole(for: holeNumber)?.par ?? 4
        return max(1, par + relative)
    }

    private func resolvedRelativeToPar(from entry: ScoreEntry, holeNumber: Int) -> Int? {
        if let relative = entry.relativeToPar {
            return relative
        }
        guard let gross = entry.strokes else { return nil }
        let par = hole(for: holeNumber)?.par ?? 4
        return gross - par
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

    private func participantIDsForScoreEntry(
        participant: RoundParticipant,
        scoringUnitIDOverride: String?,
        participantIDsOverride: [String]? = nil,
        explicitScoringUnit: ScoringUnit?,
        resolvedScoringUnit: ScoringUnit?
    ) -> [String] {
        if let participantIDsOverride {
            let normalized = participantIDsOverride.filter(\.isPopulated)
            if normalized.isPopulated { return normalized }
        }

        if let explicitScoringUnit {
            return scoringParticipantIDs(for: explicitScoringUnit)
        }

        if let scoringUnitIDOverride {
            if let group = snapshot.scoringGroup(id: scoringUnitIDOverride) {
                return group.memberIDs
            }

            if let team = snapshot.teams.first(where: { $0.id == scoringUnitIDOverride }) {
                return snapshot.participants
                    .filter { $0.teamID == team.id }
                    .map(\.id)
            }

            if let subject = sharedScoringSubjects.first(where: { $0.scoringUnitID == scoringUnitIDOverride }) {
                return subject.participants.map(\.id)
            }
        }

        if let resolvedScoringUnit {
            return scoringParticipantIDs(for: resolvedScoringUnit)
        }

        if snapshot.isSharedScoreSource, let teamID = participant.teamID {
            return snapshot.participants.filter { $0.teamID == teamID }.map(\.id)
        }

        if snapshot.shouldAutoMirrorTeeGroupsToTeams,
           let groupID = participant.groupID,
           groupID.isPopulated {
            let groupMembers = snapshot.participants.filter { $0.groupID == groupID }.map(\.id)
            if groupMembers.isPopulated {
                return groupMembers
            }
        }

        return [participant.id]
    }
    
    // MARK: - Handicap / Net
    
    func strokesReceivedOnHole(participant: RoundParticipant, holeNumber: Int) -> Int {
        ScoringEngine.strokesReceived(
            handicap: participant.lockedHandicapAllowance,
            holeNumber: holeNumber,
            holes: defaultTee?.holes ?? [],
            playedHoleNumbers: snapshot.holeRange?.holeNumbers ?? Array(1...18),
            useHandicaps: snapshot.configuration.useHandicaps,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
    }

    private func resolvedScoringUnit(for scoringUnitID: String) -> ScoringUnit? {
        if let scoringUnit = scoringUnit(id: scoringUnitID) {
            return scoringUnit
        }

        if let team = snapshot.teams.first(where: { $0.id == scoringUnitID }) {
            let resolvedID = self.scoringUnitID(forTeamID: team.id)
            if resolvedID != scoringUnitID, let scoringUnit = scoringUnit(id: resolvedID) {
                return scoringUnit
            }
            return ScoringUnit(
                id: team.id,
                owner: .team,
                ownerIDs: [team.id],
                scoringMethod: .aggregate
            )
        }

        if let scoringGroup = snapshot.scoringGroup(id: scoringUnitID) {
            let resolvedID = self.scoringUnitID(for: scoringGroup)
            if resolvedID != scoringUnitID, let scoringUnit = scoringUnit(id: resolvedID) {
                return scoringUnit
            }
            return ScoringUnit(
                id: scoringGroup.id,
                owner: .scoreOwner,
                ownerIDs: scoringGroup.memberIDs,
                scoringMethod: .aggregate
            )
        }

        if let subject = sharedScoringSubject(matching: scoringUnitID) {
            if let teamID = subject.teamID {
                let resolvedID = self.scoringUnitID(forTeamID: teamID)
                if resolvedID != scoringUnitID, let scoringUnit = scoringUnit(id: resolvedID) {
                    return scoringUnit
                }
                return ScoringUnit(
                    id: subject.scoringUnitID,
                    owner: .team,
                    ownerIDs: [teamID],
                    scoringMethod: .aggregate
                )
            }
            return ScoringUnit(
                id: subject.scoringUnitID,
                owner: .scoreOwner,
                ownerIDs: subject.participants.map(\.id),
                scoringMethod: .aggregate
            )
        }

        return nil
    }

    private func scoringUnitParticipants(scoringUnitID: String) -> [RoundParticipant] {
        let participantByID = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        if let scoringUnit = resolvedScoringUnit(for: scoringUnitID) {
            let participants = scoringParticipantIDs(for: scoringUnit).compactMap { participantByID[$0] }
            if participants.isPopulated { return participants }
        }
        return sharedScoringSubject(matching: scoringUnitID)?.participants ?? []
    }

    private func sharedScoringHandicapConfig(for scoringUnit: ScoringUnit) -> HandicapConfiguration? {
        guard scoringUnit.owner != .participant else { return nil }
        return snapshot.configuration.sharedScoreHandicapConfig
            ?? snapshot.resolvedActiveTemplate.requirements.defaultHandicapConfig
    }

    private func scoringUnitHandicapStrokes(scoringUnitID: String) -> Double? {
        guard snapshot.configuration.useHandicaps,
              let scoringUnit = resolvedScoringUnit(for: scoringUnitID) else {
            return nil
        }

        return ScoringEngine.scoringUnitHandicapStrokes(
            for: scoringUnit,
            participants: scoringUnitParticipants(scoringUnitID: scoringUnitID),
            sharedScoreHandicapConfig: sharedScoringHandicapConfig(for: scoringUnit)
        )
    }
    
    func netStrokesOnHole(participant: RoundParticipant, holeNumber: Int) -> Int? {
        guard let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else { return nil }
        let received = strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
        return max(0, gross - received)
    }

    func netRelativeToParOnHole(participant: RoundParticipant, holeNumber: Int) -> Int? {
        guard let relative = grossRelativeToPar(for: participant.id, holeNumber: holeNumber) else { return nil }
        let received = strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
        return relative - received
    }
    
    // MARK: - Team scoring helpers (shared-score formats)

    private func scoreEntryForScoringUnit(scoringUnitID: String, holeNumber: Int) -> ScoreEntry? {
        if let entry = scoreEntry(for: scoringUnitID, holeNumber: holeNumber) {
            return entry
        }

        if let scoringUnit = scoringUnit(id: scoringUnitID) {
            for participantID in scoringParticipantIDs(for: scoringUnit) {
                if let entry = scoreEntry(for: participantID, holeNumber: holeNumber) {
                    return entry
                }
            }
        }

        if let team = snapshot.teams.first(where: { $0.id == scoringUnitID }) {
            let canonicalID = self.scoringUnitID(forTeamID: team.id)
            if canonicalID != scoringUnitID,
               let entry = scoreEntry(for: canonicalID, holeNumber: holeNumber) {
                return entry
            }
            for participant in snapshot.participants where participant.teamID == team.id {
                if let entry = scoreEntry(for: participant.id, holeNumber: holeNumber) {
                    return entry
                }
            }
        }

        if let scoringGroup = snapshot.scoringGroup(id: scoringUnitID) {
            let canonicalID = self.scoringUnitID(for: scoringGroup)
            if canonicalID != scoringUnitID,
               let entry = scoreEntry(for: canonicalID, holeNumber: holeNumber) {
                return entry
            }
            for participantID in scoringGroup.memberIDs {
                if let entry = scoreEntry(for: participantID, holeNumber: holeNumber) {
                    return entry
                }
            }
        }

        if let subject = sharedScoringSubjects.first(where: { $0.scoringUnitID == scoringUnitID }) {
            for participant in subject.participants {
                if let entry = scoreEntry(for: participant.id, holeNumber: holeNumber) {
                    return entry
                }
            }
        }

        return nil
    }

    func scoringUnitGrossStrokes(scoringUnitID: String, holeNumber: Int) -> Int? {
        guard let entry = scoreEntryForScoringUnit(scoringUnitID: scoringUnitID, holeNumber: holeNumber) else {
            return nil
        }
        return resolvedGrossStrokes(from: entry, holeNumber: holeNumber)
    }

    func scoringUnitScoreInputValue(scoringUnitID: String, holeNumber: Int) -> Int? {
        guard let entry = scoreEntryForScoringUnit(scoringUnitID: scoringUnitID, holeNumber: holeNumber) else {
            return nil
        }
        if isFriendlyScoreInputMode {
            return resolvedRelativeToPar(from: entry, holeNumber: holeNumber)
        }
        return resolvedGrossStrokes(from: entry, holeNumber: holeNumber)
    }

    func scoringUnitNetStrokes(scoringUnitID: String, holeNumber: Int) -> Int? {
        if let net = engineResult(for: .net).rows
            .first(where: { $0.scoringUnitID == scoringUnitID })?
            .holeValues[holeNumber]?
            .netStrokes {
            return net
        }

        guard let gross = scoringUnitGrossStrokes(scoringUnitID: scoringUnitID, holeNumber: holeNumber) else {
            return nil
        }
        return max(0, gross - scoringUnitStrokesReceived(scoringUnitID: scoringUnitID, holeNumber: holeNumber))
    }

    func scoringUnitStrokesReceived(scoringUnitID: String, holeNumber: Int) -> Int {
        guard snapshot.configuration.useHandicaps,
              let scoringUnit = resolvedScoringUnit(for: scoringUnitID) else {
            return 0
        }
        let handicap = ScoringEngine.scoringUnitHandicap(
            for: scoringUnit,
            participants: scoringUnitParticipants(scoringUnitID: scoringUnitID),
            sharedScoreHandicapConfig: sharedScoringHandicapConfig(for: scoringUnit)
        )
        return ScoringEngine.strokesReceived(
            handicap: handicap,
            holeNumber: holeNumber,
            holes: defaultTee?.holes ?? [],
            playedHoleNumbers: snapshot.holeRange?.holeNumbers ?? Array(1...18),
            useHandicaps: snapshot.configuration.useHandicaps,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
    }

    func scoringUnitHandicapLabel(scoringUnitID: String) -> String? {
        guard let unitStrokes = scoringUnitHandicapStrokes(scoringUnitID: scoringUnitID) else {
            return nil
        }
        return "HCP \(Int(unitStrokes.rounded(.toNearestOrAwayFromZero)))"
    }

    func scoringUnitHandicapDecimalLabel(scoringUnitID: String) -> String? {
        guard let unitStrokes = scoringUnitHandicapStrokes(scoringUnitID: scoringUnitID) else {
            return nil
        }
        let rounded = (unitStrokes * 10).rounded() / 10
        let value = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        return "HCP \(value)"
    }

    func scoringUnitScoreToPar(scoringUnitID: String, basis: ScoreBasis) -> Int {
        if let row = engineResult(for: basis).rows.first(where: { $0.scoringUnitID == scoringUnitID }) {
            return Int(row.total.rounded())
        }

        let holes = holeNumbers
        var sum = 0
        for holeNumber in holes {
            if basis == .gross {
                guard let grossRelative = scoreEntryForScoringUnit(scoringUnitID: scoringUnitID, holeNumber: holeNumber)
                    .flatMap({ resolvedRelativeToPar(from: $0, holeNumber: holeNumber) }) else {
                    continue
                }
                sum += grossRelative
            } else {
                guard let grossRelative = scoreEntryForScoringUnit(scoringUnitID: scoringUnitID, holeNumber: holeNumber)
                    .flatMap({ resolvedRelativeToPar(from: $0, holeNumber: holeNumber) }) else {
                    continue
                }
                sum += grossRelative - scoringUnitStrokesReceived(scoringUnitID: scoringUnitID, holeNumber: holeNumber)
            }
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
        guard isPresenceActive(participant) else { return 0 }
        let holes = holeNumbers
        var sum = 0
        
        for holeNumber in holes {
            switch basis {
            case .gross:
                guard let grossRelative = grossRelativeToPar(for: participant.id, holeNumber: holeNumber) else {
                    continue
                }
                sum += grossRelative
            case .net:
                guard let netRelative = netRelativeToParOnHole(participant: participant, holeNumber: holeNumber) else {
                    continue
                }
                sum += netRelative
            }
        }
        
        return sum
    }

    func actualScoreTrend(
        for participant: RoundParticipant,
        basis: ScoreBasis
    ) -> [ProjectionTrendPoint] {
        var cumulative = 0
        return courseOrderHoleNumbers.compactMap { holeNumber in
            guard let hole = hole(for: holeNumber, teeID: participant.teeBoxID),
                  let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else {
                return nil
            }
            let strokes = basis == .net
                ? gross - strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
                : gross
            cumulative += strokes - hole.par
            return ProjectionTrendPoint(holeNumber: holeNumber, value: cumulative)
        }
    }

    func cumulativeStrokeTrend(
        for participant: RoundParticipant,
        basis: ScoreBasis
    ) -> [CumulativeStrokeTrendPoint] {
        var cumulative = 0
        var holesCompleted = 0
        return courseOrderHoleNumbers.compactMap { holeNumber in
            guard let gross = grossStrokes(
                for: participant.id,
                holeNumber: holeNumber
            ) else { return nil }

            holesCompleted += 1
            cumulative += basis == .net
                ? gross - strokesReceivedOnHole(
                    participant: participant,
                    holeNumber: holeNumber
                )
                : gross
            return CumulativeStrokeTrendPoint(
                holesCompleted: holesCompleted,
                holeNumber: holeNumber,
                strokes: cumulative
            )
        }
    }

    func finalMatchupCountingStatuses(
        for side: MatchupResultPresentation.Side,
        basis: ScoreBasis,
        isPointsFormat: Bool
    ) -> [String: MatchupCountingDisplayStatus] {
        guard side.countsByRoundTotal else { return [:] }

        let eligibleParticipants = side.participants.filter {
            side.substitutesScore || !$0.isSubstitute
        }
        let eligibleParticipantIDs = Set(eligibleParticipants.map(\.id))
        let rowsByParticipantID = Dictionary(
            uniqueKeysWithValues: projectedIndividualLeaderboardRows(for: basis).map {
                ($0.participant.id, $0)
            }
        )
        let totals = eligibleParticipants.reduce(into: [String: Double]()) { values, participant in
            guard let row = rowsByParticipantID[participant.id] else { return }
            values[participant.id] = isPointsFormat
                ? (row.totalPoints ?? Double(row.scoreToPar))
                : Double(row.scoreToPar)
        }

        var statuses = MatchupCountingStatusResolver.resolve(
            participantIDs: eligibleParticipants.map(\.id),
            countingParticipantIDs: side.countingParticipantIDs,
            totalsByParticipantID: totals
        )
        for participant in side.participants where !eligibleParticipantIDs.contains(participant.id) {
            statuses[participant.id] = .notCounted
        }
        return statuses
    }

    func completedAveragePaceTrend(
        for participant: RoundParticipant,
        basis: ScoreBasis
    ) -> [ProjectionTrendPoint]? {
        let trend = actualScoreTrend(for: participant, basis: basis)
        guard trend.count == courseOrderHoleNumbers.count,
              let firstHole = courseOrderHoleNumbers.first,
              let finalPoint = trend.last else { return nil }
        return [
            ProjectionTrendPoint(holeNumber: max(0, firstHole - 1), value: 0),
            ProjectionTrendPoint(holeNumber: finalPoint.holeNumber, value: finalPoint.value),
        ]
    }

    func handicapStrokeUsage(for participant: RoundParticipant) -> HandicapStrokeUsage {
        var used = 0
        var remaining = 0
        var remainingAllocations: [HandicapStrokeAllocation] = []

        for holeNumber in courseOrderHoleNumbers {
            let strokes = strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
            guard strokes != 0 else { continue }
            if grossStrokes(for: participant.id, holeNumber: holeNumber) != nil {
                used += strokes
            } else {
                remaining += strokes
                remainingAllocations.append(
                    HandicapStrokeAllocation(holeNumber: holeNumber, strokes: strokes)
                )
            }
        }

        return HandicapStrokeUsage(
            used: used,
            remaining: remaining,
            remainingAllocations: remainingAllocations
        )
    }

    func grossScoreOutcomeCounts(for participant: RoundParticipant) -> [GrossScoreOutcomeCount] {
        var counts = Dictionary(
            uniqueKeysWithValues: GrossScoreOutcomeBucket.allCases.map { ($0, 0) }
        )
        for holeNumber in courseOrderHoleNumbers {
            guard let relative = grossRelativeToPar(
                for: participant.id,
                holeNumber: holeNumber
            ) else { continue }
            counts[GrossScoreOutcomeBucket.resolve(relativeToPar: relative), default: 0] += 1
        }
        return GrossScoreOutcomeBucket.allCases.map {
            GrossScoreOutcomeCount(bucket: $0, count: counts[$0, default: 0])
        }
    }

    func matchupParticipantDisplaySort(
        lhs: RoundParticipant,
        rhs: RoundParticipant,
        isPointsFormat: Bool
    ) -> Bool {
        let basis = matchupScoreBasis
        let lhsScore = scoreToPar(for: lhs, basis: basis)
        let rhsScore = scoreToPar(for: rhs, basis: basis)

        if lhsScore != rhsScore {
            return isPointsFormat ? lhsScore > rhsScore : lhsScore < rhsScore
        }
        if (lhs.teeOrder ?? Int.max) != (rhs.teeOrder ?? Int.max) {
            return (lhs.teeOrder ?? Int.max) < (rhs.teeOrder ?? Int.max)
        }
        let nameComparison = lhs.name.fullName.localizedCaseInsensitiveCompare(rhs.name.fullName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.id < rhs.id
    }
    
    func formattedScoreToPar(_ value: Int) -> String {
        if value == 0 { return "E" }
        //if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    /// Formats a matchup total (points or score to par) for display.
    func formattedMatchupTotal(_ total: Double, isPointsFormat: Bool) -> String {
        MatchupResultPresentationBuilder.scoreLabel(for: total, isPointsFormat: isPointsFormat)
    }

    /// Whether this participant's score contributes to the team total (e.g. best ball count, best 2 of 4).
    /// For best ball, all players can contribute per hole. For best 2 of 4, only top 2 per hole count.
    func doesParticipantScoreCount(participantID: String, teamID: String, matchup: TeamMatchup) -> Bool {
        if snapshot.configuration.teamScoring.mode != .all,
           snapshot.configuration.teamScoring.scope == .perHole {
            return true
        }

        if matchup.effectiveMode.usesScoringGroupIDs {
            if let row = matchupEngineResult.matchupResults
                .first(where: { $0.matchup.id == matchup.id })?
                .rows
                .first(where: {
                    scoringRowIdentityMatches(
                        scoringUnitID: $0.scoringUnitID,
                        owner: $0.owner,
                        participantIDs: $0.participantIDs,
                        sideID: teamID,
                        mode: matchup.effectiveMode
                    )
                }) {
                if row.countingParticipantIDs.isPopulated {
                    return row.countingParticipantIDs.contains(participantID)
                }
                return row.participantIDs.contains(participantID)
            }
            return false
        }

        let segment = snapshot.roundSegment ?? RoundSegment()
        guard expectedMatchupMode == .team
            || ScoringEngine.shouldUseTeamAggregateScoring(snapshot: snapshot, segment: segment) else {
            return participantID == teamID
        }

        if let row = matchupEngineResult.matchupResults
            .first(where: { $0.matchup.id == matchup.id })?
            .rows
            .first(where: {
                scoringRowIdentityMatches(
                    scoringUnitID: $0.scoringUnitID,
                    owner: $0.owner,
                    participantIDs: $0.participantIDs,
                    sideID: teamID,
                    mode: .team
                )
            }) {
            if row.countingParticipantIDs.isPopulated {
                return row.countingParticipantIDs.contains(participantID)
            }
            return row.participantIDs.contains(participantID)
        }

        if let row = matchupEngineResult.rows.first(where: {
            scoringRowIdentityMatches(
                scoringUnitID: $0.scoringUnitID,
                owner: $0.owner,
                participantIDs: $0.participantIDs,
                sideID: teamID,
                mode: .team
            )
        }) {
            if row.countingParticipantIDs.isPopulated {
                return row.countingParticipantIDs.contains(participantID)
            }
            return row.participantIDs.contains(participantID)
        }

        return false
    }

    func scoringParticipants(for session: ScoringSession) -> [RoundParticipant] {
        let sessionIDs = Set(session.participants.map(\.id))
        let visibleIDs = Set(teeGroupParticipants.map(\.id))

        if sessionIDs.isPopulated,
           sessionIDs != visibleIDs,
           session.participants.count > 1 {
            return session.participants
                .filter(isPresenceActive)
                .sorted(by: participantDisplaySort)
        }

        let orderedRows = teeGroupTeamSections.flatMap(\.participants).filter(isPresenceActive)
        if orderedRows.isPopulated {
            return orderedRows
        }

        let fallback = session.participants.filter(isPresenceActive)
        return (fallback.isPopulated ? fallback : session.participants)
            .sorted(by: participantDisplaySort)
    }

    func matchupSidePresentation(
        in section: MatchupLeaderboardSection,
        sideID: String
    ) -> MatchupResultPresentation.Side? {
        matchupPresentation(in: section).side(id: sideID)
    }

    func matchupPresentation(in section: MatchupLeaderboardSection) -> MatchupResultPresentation {
        MatchupResultPresentationBuilder.build(
            snapshot: snapshot,
            result: matchupEngineResult,
            section: section,
            basis: matchupScoreBasis
        )
    }

    func liveMatchupResultChipTitle(
        for sideID: String,
        in section: MatchupLeaderboardSection,
        presentation: MatchupResultPresentation? = nil
    ) -> String? {
        let presentation = presentation ?? matchupPresentation(in: section)
        guard presentation.hasCompleteSides else { return nil }

        if presentation.minimumCountStatus?.hasUnderMinimumSide == true {
            guard shouldResolveMinimumCountResult(presentation) else { return nil }
            if presentation.isAutoWin, presentation.winningSideID == sideID {
                return "Auto-win"
            }
            if presentation.isTie {
                return "Tie"
            }
        }

        let isFullyScored = isLiveMatchupFullyScored(section)
        if presentation.winningSideID == sideID {
            return isFullyScored ? "Winner" : "Leader"
        }
        if isFullyScored, presentation.isTie {
            return "Tie"
        }
        return nil
    }

    private func shouldResolveMinimumCountResult(_ presentation: MatchupResultPresentation) -> Bool {
        guard let status = presentation.minimumCountStatus,
              status.hasUnderMinimumSide else {
            return true
        }
        return shouldResolveMinimumCountResult(status)
    }

    private func shouldResolveMinimumCountResult(_ status: MatchupMinimumCountStatus?) -> Bool {
        guard let status, status.hasUnderMinimumSide else {
            return true
        }
        return status.hasStructuralShortage || snapshot.round.status == .complete
    }

    private static func minimumCountResolvedRows(
        _ rows: [ScoringRow],
        matchup: TeamMatchup,
        status: MatchupMinimumCountStatus,
        highestWins: Bool
    ) -> [ScoringRow] {
        let pairingOrder = matchup.pairingIDs()
        let rowByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.scoringUnitID, $0) })
        if let winnerID = status.autoWinnerSideID,
           let winner = rowByID[winnerID] {
            let losers = pairingOrder
                .filter { $0 != winnerID }
                .compactMap { rowByID[$0] }
            let extras = rows.filter { row in
                row.scoringUnitID != winnerID && !pairingOrder.contains(row.scoringUnitID)
            }
            return [winner] + losers + extras
        }
        if status.bothSidesUnderMinimum {
            let ordered = pairingOrder.compactMap { rowByID[$0] }
            let extras = rows.filter { !pairingOrder.contains($0.scoringUnitID) }
            return ordered + extras
        }
        return rows.sorted {
            if $0.total != $1.total {
                return highestWins ? $0.total > $1.total : $0.total < $1.total
            }
            return $0.scoringUnitID < $1.scoringUnitID
        }
    }

    func isLiveMatchupFullyScored(_ section: MatchupLeaderboardSection) -> Bool {
        let holes = liveMatchupRequiredHoleNumbers(for: section)
        guard holes.isPopulated else { return false }

        let sideIDs = section.matchup.pairingIDs()
        guard sideIDs.count >= 2 else { return false }

        return sideIDs.allSatisfy {
            isLiveMatchupSideFullyScored(
                sideID: $0,
                matchup: section.matchup,
                holes: holes
            )
        }
    }

    private func liveMatchupRequiredHoleNumbers(for section: MatchupLeaderboardSection) -> [Int] {
        if let segment = snapshot.segments.first(where: { $0.matchups?.contains(where: { $0.id == section.matchup.id }) == true }) {
            return segment.holeRange.holeNumbers
        }
        if let segment = snapshot.roundSegment {
            return segment.holeRange.holeNumbers
        }
        return courseOrderHoleNumbers
    }

    private func isLiveMatchupSideFullyScored(
        sideID: String,
        matchup: TeamMatchup,
        holes: [Int]
    ) -> Bool {
        let directLookupIDs = liveMatchupDirectScoreLookupIDs(sideID: sideID, matchup: matchup)
        let hasDirectScores = snapshot.scoring.contains {
            directLookupIDs.contains($0.scoringUnitID) && $0.hasRecordedScore
        }

        if snapshot.isSharedScoreSource || hasDirectScores {
            return holes.allSatisfy { holeNumber in
                liveMatchupDirectScoreEntry(
                    sideID: sideID,
                    matchup: matchup,
                    holeNumber: holeNumber
                )?.hasRecordedScore == true
            }
        }

        let participants = matchupSideParticipants(scoringUnitID: sideID, matchup: matchup)
            .filter(isPresenceActive)
        guard participants.isPopulated else { return false }

        return holes.allSatisfy { holeNumber in
            participants.allSatisfy {
                scoreEntry(for: $0.id, holeNumber: holeNumber)?.hasRecordedScore == true
            }
        }
    }

    private func liveMatchupDirectScoreEntry(
        sideID: String,
        matchup: TeamMatchup,
        holeNumber: Int
    ) -> ScoreEntry? {
        let lookupIDs = liveMatchupDirectScoreLookupIDs(sideID: sideID, matchup: matchup)
        return snapshot.scoring.first {
            lookupIDs.contains($0.scoringUnitID)
                && $0.holeNumber == holeNumber
                && $0.hasRecordedScore
        }
    }

    private func liveMatchupDirectScoreLookupIDs(
        sideID: String,
        matchup: TeamMatchup
    ) -> Set<String> {
        var ids = Set([sideID].filter(\.isPopulated))
        let participants = matchupSideParticipants(scoringUnitID: sideID, matchup: matchup)
        let participantIDs = Set(participants.map(\.id))

        if let subject = sharedScoringSubject(matching: sideID) {
            ids.insert(subject.scoringUnitID)
            if let teamID = subject.teamID { ids.insert(teamID) }
            if let scoringGroupID = subject.scoringGroupID { ids.insert(scoringGroupID) }
            if let teeGroupID = subject.teeGroupID { ids.insert(teeGroupID) }
        }

        switch matchup.effectiveMode {
        case .individual:
            break
        case .team:
            ids.insert(scoringUnitID(forTeamID: sideID))
            allScoringUnits
                .filter { $0.owner == .team && ($0.id == sideID || $0.ownerIDs.contains(sideID)) }
                .forEach { ids.insert($0.id) }
        case .partnership, .teeGroup, .scoreOwner:
            if let group = snapshot.scoringGroup(id: sideID) {
                ids.insert(group.id)
                ids.insert(scoringUnitID(for: group))
                if let teamID = group.teamID { ids.insert(teamID) }
            }
            snapshot.scoringGroups
                .filter { group in
                    group.id == sideID || (participantIDs.isPopulated && Set(group.memberIDs) == participantIDs)
                }
                .forEach { group in
                    ids.insert(group.id)
                    ids.insert(scoringUnitID(for: group))
                    if let teamID = group.teamID { ids.insert(teamID) }
                }
            allScoringUnits
                .filter { unit in
                    unit.owner == .scoreOwner
                        && (
                            unit.id == sideID
                                || unit.ownerIDs.contains(sideID)
                                || (participantIDs.isPopulated && Set(unit.ownerIDs) == participantIDs)
                        )
                }
                .forEach { ids.insert($0.id) }
        }

        return ids.filter(\.isPopulated)
    }

    var matchupCountingScopeLabel: String? {
        let scoring = snapshot.configuration.teamScoring
        guard scoring.mode != .all else { return nil }
        let qualifier = scoring.mode == .worstN ? "Worst" : "Best"
        let scope = scoring.scope == .perRound ? "round" : "hole"
        return "\(qualifier) \(scoring.count) per \(scope)"
    }

    enum FriendlyScoreFormat {
        case short
        case full
        case shortWithStrokes
        case fullWithStrokes
    }

    func friendlyScoreLabel(relativeToPar value: Int, par: Int = 4, format: FriendlyScoreFormat = .short) -> String {
        let useFull = (format == .full || format == .fullWithStrokes)
        let base: String
        switch value {
        case ...(-4): base = value == -4 ? "Condor" : "Albatross"
        case -3: base = "Albatross"
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
            base = value > 0 ? "\(value)x Bogey" : "\(abs(value)) Under"
        }
        let withStrokes = (format == .shortWithStrokes || format == .fullWithStrokes)
        let grossStrokes = max(1, par + value)
        return withStrokes ? "\(base) (\(grossStrokes))" : base
    }

    func friendlyScoreLabel(strokes: Int, par: Int, format: FriendlyScoreFormat = .short) -> String {
        friendlyScoreLabel(relativeToPar: strokes - par, par: par, format: format)
    }

    /// Primary options: birdie through triple. More options: albatross, eagle, quad, quint, etc. up to hole max.
    func scoreMenuOptions(for holeNumber: Int) -> (primary: [Int], more: [Int]) {
        let par = hole(for: holeNumber)?.par ?? 4
        if isFriendlyScoreInputMode {
            let configMax = snapshot.gameFormat.configuration.maxScoreOverPar.friendlyMaxRelativeValue(for: par)
            let primary = [-1, 0, 1, 2, 3]
            let allScores = Array(-4...configMax)
            let primarySet = Set(primary)
            let more = allScores.filter { !primarySet.contains($0) }
            return (primary, more)
        }
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

    func leaderboardModeLabel(for mode: LeaderboardMode) -> String {
        if mode == .individual,
           snapshot.isSharedScoreSource,
           snapshot.configuration.scoreOwnerScope == .partnership {
            return "Pairs"
        }
        return mode.label
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
        let isTie: Bool
    }

    struct OrderedMatchupSection: Identifiable {
        let originalIndex: Int
        let section: MatchupLeaderboardSection

        var id: String { section.id }
        var displayIndex: Int { originalIndex + 1 }
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

    struct VegasPartnershipBreakdown: Identifiable {
        let id: String
        let title: String
        let total: Int
    }

    struct VegasTeamStanding: Identifiable {
        let id: String
        let teamID: String
        let teamName: String
        let memberNames: String
        let placeLabel: String
        let total: Int
        let thru: Int
        let color: Color?
        let breakdowns: [VegasPartnershipBreakdown]
    }

    struct VegasLiveSummary {
        let basis: ScoreBasis
        let standings: [VegasTeamStanding]
        let leaderText: String
        let thru: Int
        let mode: RoundVegasMode
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
        let rows = effectiveLeaderboardRows
        let teamSections = teamLeaderboardSections
        let teeGroupSections = teeGroupLeaderboardSections
        let hasTeams = snapshot.requiresTeams
            && snapshot.teams.isPopulated
            && teamSections.isPopulated
        let hasTeeGroups = snapshot.teeGroups.count > 1
            && teeGroupSections.isPopulated

        var modes: [LeaderboardMode] = [.individual]

        let canShowTeam = hasTeams
            && (!snapshot.isSharedScoreSource || groupedLeaderboardSectionsAreMeaningful(teamSections, rowCount: rows.count))
        if canShowTeam {
            modes.append(.team)
        }

        let canShowTeeGroup = hasTeeGroups
            && (!snapshot.isSharedScoreSource || groupedLeaderboardSectionsAreMeaningful(teeGroupSections, rowCount: rows.count))
        if canShowTeeGroup {
            let duplicatesTeamGrouping = canShowTeam
                && leaderboardPartitionSignature(teamSections) == leaderboardPartitionSignature(teeGroupSections)
            if !duplicatesTeamGrouping {
                modes.append(.teeGroup)
            }
        }

        return modes
    }
    
    struct LeaderboardRow: Identifiable {
        var id: String { scoringUnitID }
        let participant: RoundParticipant
        let participants: [RoundParticipant]
        let scoringUnitID: String
        let thru: Int
        let scoreToPar: Int
        let totalPoints: Double?
        let isPinned: Bool
        let placeLabel: String
        let teamID: String?
        let teamName: String?
        let teamColor: Color?
        let memberNames: String?
        let sharedHandicapLabel: String?
        let isSharedScoreUnit: Bool
        let scoreCompleteness: ParticipantScoreCompleteness?

        init(
            participant: RoundParticipant,
            participants: [RoundParticipant]? = nil,
            scoringUnitID: String? = nil,
            thru: Int,
            scoreToPar: Int,
            totalPoints: Double? = nil,
            isPinned: Bool,
            placeLabel: String,
            teamID: String? = nil,
            teamName: String? = nil,
            teamColor: Color? = nil,
            memberNames: String? = nil,
            sharedHandicapLabel: String? = nil,
            isSharedScoreUnit: Bool = false,
            scoreCompleteness: ParticipantScoreCompleteness? = nil
        ) {
            self.participant = participant
            self.participants = participants ?? [participant]
            self.scoringUnitID = scoringUnitID ?? teamID ?? participant.id
            self.thru = thru
            self.scoreToPar = scoreToPar
            self.totalPoints = totalPoints
            self.isPinned = isPinned
            self.placeLabel = placeLabel
            self.teamID = teamID
            self.teamName = teamName
            self.teamColor = teamColor
            self.memberNames = memberNames
            self.sharedHandicapLabel = sharedHandicapLabel
            self.isSharedScoreUnit = isSharedScoreUnit
            self.scoreCompleteness = scoreCompleteness
        }

        func withPlaceLabel(_ placeLabel: String) -> LeaderboardRow {
            LeaderboardRow(
                participant: participant,
                participants: participants,
                scoringUnitID: scoringUnitID,
                thru: thru,
                scoreToPar: scoreToPar,
                totalPoints: totalPoints,
                isPinned: isPinned,
                placeLabel: placeLabel,
                teamID: teamID,
                teamName: teamName,
                teamColor: teamColor,
                memberNames: memberNames,
                sharedHandicapLabel: sharedHandicapLabel,
                isSharedScoreUnit: isSharedScoreUnit,
                scoreCompleteness: scoreCompleteness
            )
        }

        func withScoreCompleteness(_ scoreCompleteness: ParticipantScoreCompleteness?) -> LeaderboardRow {
            LeaderboardRow(
                participant: participant,
                participants: participants,
                scoringUnitID: scoringUnitID,
                thru: thru,
                scoreToPar: scoreToPar,
                totalPoints: totalPoints,
                isPinned: isPinned,
                placeLabel: placeLabel,
                teamID: teamID,
                teamName: teamName,
                teamColor: teamColor,
                memberNames: memberNames,
                sharedHandicapLabel: sharedHandicapLabel,
                isSharedScoreUnit: isSharedScoreUnit,
                scoreCompleteness: scoreCompleteness
            )
        }
    }

    /// Rows to display in the leaderboard; switches between stroke play and format-specific based on selected chip.
    var effectiveLeaderboardRows: [LeaderboardRow] {
        if snapshot.isSharedScoreSource {
            return sharedLeaderboardRows
        }
        return effectiveLeaderboardChip == .strokes ? leaderboardRows : engineLeaderboardRows
    }

    private var individualLeaderboardRowsForDisplay: [LeaderboardRow] {
        guard usesIndividualContributionLeaderboardRows else { return effectiveLeaderboardRows }
        return individualContributionLeaderboardRows
    }

    private var activeLeaderboardRowsForDisplay: [LeaderboardRow] {
        leaderboardMode == .individual ? individualLeaderboardRowsForDisplay : effectiveLeaderboardRows
    }

    var displayLeaderboardRows: [LeaderboardRow] {
        let rows = activeLeaderboardRowsForDisplay
        guard !showScorelessLeaderboardRows else { return rows }
        return rows.filter { $0.thru > 0 }
    }

    var outcomeLeaderboardRows: [LeaderboardRow] {
        let rowsWithCompleteness = effectiveLeaderboardRows.map { row in
            row.withScoreCompleteness(outcomeScoreCompleteness(for: row))
        }
        let completeRows = rowsWithCompleteness.filter { $0.scoreCompleteness?.isComplete == true }
        let invalidRows = rowsWithCompleteness.filter { $0.scoreCompleteness?.isComplete != true }
        let labels = outcomeLeaderboardPlaceLabels(for: completeRows)

        let rankedRows = completeRows.map { row in
            row.withPlaceLabel(labels[row.id] ?? "-")
        }
        let unrankedRows = invalidRows
            .sorted { lhs, rhs in
                let lhsName = lhs.teamName ?? lhs.participant.alphabeticName
                let rhsName = rhs.teamName ?? rhs.participant.alphabeticName
                return lhsName < rhsName
            }
            .map { $0.withPlaceLabel("—") }
        return rankedRows + unrankedRows
    }

    var displayTeamLeaderboardSections: [GroupedLeaderboardSection] {
        filterScorelessRows(in: teamLeaderboardSections)
    }

    var displayTeeGroupLeaderboardSections: [GroupedLeaderboardSection] {
        filterScorelessRows(in: teeGroupLeaderboardSections)
    }

    var rowsEligibleForAverageDisplay: [LeaderboardRow] {
        displayLeaderboardRows.filter { $0.thru > 0 }
    }

    func averageForDisplay(rows: [LeaderboardRow]) -> Double? {
        guard rows.isPopulated else { return nil }
        if effectiveLeaderboardChip == .strokes {
            return Double(rows.map(\.scoreToPar).reduce(0, +)) / Double(rows.count)
        }
        let values = rows.map { $0.totalPoints ?? Double($0.scoreToPar) }
        return values.reduce(0, +) / Double(values.count)
    }

    private func filterScorelessRows(in sections: [GroupedLeaderboardSection]) -> [GroupedLeaderboardSection] {
        guard !showScorelessLeaderboardRows else { return sections }
        return sections.compactMap { section in
            let rows = section.rows.filter { $0.thru > 0 }
            guard rows.isPopulated else { return nil }
            return makeGroupedSection(
                id: section.id,
                name: section.name,
                color: section.color,
                rows: rows
            )
        }
    }

    var leaderboardRows: [LeaderboardRow] {
        projectedPlayerLeaderboardRows(for: scoreBasis)
    }

    /// Builds stroke standings directly from the round's active participants.
    ///
    /// Unlike the scoring-engine projections, this list is intentionally independent of the
    /// round's competition scope so player standings remain available during matchup rounds.
    func projectedPlayerLeaderboardRows(for basis: ScoreBasis) -> [LeaderboardRow] {
        let baseRows = snapshot.participants.filter(isPresenceActive).map { p in
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
        let baseRows = snapshot.isSharedScoreSource ? sharedLeaderboardRows : leaderboardRows
        let ids = visibleParticipantIDs
        if ids.isEmpty {
            if hasInitializedVisibilitySelection {
                return []  // User chose "Hide all"
            }
            return baseRows  // Not yet initialized, show all
        }
        let filtered = baseRows.filter { row in
            row.participants.contains { ids.contains($0.id) }
        }
        if filtered.isEmpty && !baseRows.isEmpty {
            return baseRows  // Stale IDs or misconfiguration, show all
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

    private func outcomeScoreCompleteness(for row: LeaderboardRow) -> ParticipantScoreCompleteness {
        let statuses = row.participants.map {
            RoundScoreCompleteness.classify(participantID: $0.id, snapshot: snapshot)
        }
        if statuses.allSatisfy(\.isComplete) {
            return .complete(scored: statuses.map(\.scoredCount).max() ?? 0)
        }
        if statuses.contains(where: { status in
            if case .incomplete = status { return true }
            return false
        }) {
            return .incomplete(
                scored: statuses.map(\.scoredCount).max() ?? 0,
                required: statuses.map(\.requiredCount).max() ?? 0
            )
        }
        return .noScores(required: statuses.map(\.requiredCount).max() ?? 0)
    }

    private func outcomeLeaderboardPlaceLabels(for rows: [LeaderboardRow]) -> [String: String] {
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
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
            let value = ordered[index].totalPoints ?? Double(ordered[index].scoreToPar)
            var group: [LeaderboardRow] = []

            while index < ordered.count,
                  (ordered[index].totalPoints ?? Double(ordered[index].scoreToPar)) == value {
                group.append(ordered[index])
                index += 1
            }

            let label = group.count > 1 ? "T-\(place)." : "\(place)."
            for row in group {
                labels[row.id] = label
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
        let grouped = Dictionary(grouping: rows) { leaderboardTeamID(for: $0) }
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
        let grouped = Dictionary(grouping: rows) { leaderboardTeeGroupID(for: $0) }
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

    private func leaderboardTeamID(for row: LeaderboardRow) -> String? {
        if let teamID = row.teamID, teamID.isPopulated {
            return teamID
        }

        let teamIDs = Set(row.participants.compactMap(\.teamID).filter(\.isPopulated))
        return teamIDs.count == 1 ? teamIDs.first : nil
    }

    private func leaderboardTeeGroupID(for row: LeaderboardRow) -> String? {
        let teeGroupIDs = Set(row.participants.compactMap(\.groupID).filter(\.isPopulated))
        return teeGroupIDs.count == 1 ? teeGroupIDs.first : nil
    }

    private func groupedLeaderboardSectionsAreMeaningful(
        _ sections: [GroupedLeaderboardSection],
        rowCount: Int
    ) -> Bool {
        rowCount > sections.count && sections.contains { $0.rows.count > 1 }
    }

    private func leaderboardPartitionSignature(
        _ sections: [GroupedLeaderboardSection]
    ) -> Set<Set<String>> {
        Set(sections.map { Set($0.rows.map(\.id)) })
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

    func formattedVegasTotal(_ total: Int) -> String {
        String(total)
    }

    var vegasLiveSummary: VegasLiveSummary? {
        guard snapshot.isVegasFormat else { return nil }

        let result = engineResult
        let teamMap = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })
        let participantMap = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })

        let standings: [VegasTeamStanding] = result.rows.compactMap { row in
            guard row.owner == .team else { return nil }
            let teamName = teamMap[row.scoringUnitID]?.name ?? "Team"
            let memberNames = row.participantIDs
                .compactMap { participantMap[$0] }
                .map { formatDisplayName(for: $0) }
                .joined(separator: ", ")
            let breakdowns = vegasBreakdowns(for: row, participantMap: participantMap)
            return VegasTeamStanding(
                id: row.scoringUnitID,
                teamID: row.scoringUnitID,
                teamName: teamName,
                memberNames: memberNames,
                placeLabel: "",
                total: Int(row.total.rounded()),
                thru: row.holesPlayed,
                color: teamMap[row.scoringUnitID]?.displaySwatchColor,
                breakdowns: breakdowns
            )
        }

        guard standings.isPopulated else { return nil }
        let ordered = standings.sorted {
            if $0.total != $1.total { return $0.total < $1.total }
            return $0.teamName < $1.teamName
        }

        var withPlaces: [VegasTeamStanding] = []
        var index = 0
        var place = 1
        while index < ordered.count {
            let currentTotal = ordered[index].total
            let start = index
            while index < ordered.count, ordered[index].total == currentTotal {
                index += 1
            }
            let label = (index - start) > 1 ? "T-\(place)." : "\(place)."
            withPlaces.append(contentsOf: ordered[start..<index].map {
                VegasTeamStanding(
                    id: $0.id,
                    teamID: $0.teamID,
                    teamName: $0.teamName,
                    memberNames: $0.memberNames,
                    placeLabel: label,
                    total: $0.total,
                    thru: $0.thru,
                    color: $0.color,
                    breakdowns: $0.breakdowns
                )
            })
            place += (index - start)
        }

        let thru = withPlaces.map(\.thru).min() ?? 0
        let leaderText: String
        if withPlaces.count == 1 {
            leaderText = "\(withPlaces[0].teamName) sets the pace"
        } else if withPlaces[0].total == withPlaces[1].total {
            let tiedCount = withPlaces.prefix { $0.total == withPlaces[0].total }.count
            if tiedCount > 2 {
                leaderText = "\(tiedCount)-way tie at \(formattedVegasTotal(withPlaces[0].total))"
            } else {
                leaderText = "\(withPlaces[0].teamName) and \(withPlaces[1].teamName) tied at \(formattedVegasTotal(withPlaces[0].total))"
            }
        } else {
            let margin = withPlaces[1].total - withPlaces[0].total
            leaderText = "\(withPlaces[0].teamName) leads by \(margin)"
        }

        return VegasLiveSummary(
            basis: scoreBasis,
            standings: withPlaces,
            leaderText: leaderText,
            thru: thru,
            mode: snapshot.configuration.resolvedVegasMode
        )
    }

    private func vegasBreakdowns(
        for row: ScoringRow,
        participantMap: [String: RoundParticipant]
    ) -> [VegasPartnershipBreakdown] {
        var totals: [String: Int] = [:]
        var titles: [String: String] = [:]

        for holeValue in row.holeValues.values {
            for pair in holeValue.vegasPairs ?? [] {
                let key = pair.partnershipID ?? pair.participantIDs.sorted().joined(separator: "_")
                totals[key, default: 0] += pair.composite
                if titles[key] == nil {
                    titles[key] = pair.participantIDs
                        .compactMap { participantMap[$0] }
                        .map { formatDisplayName(for: $0) }
                        .joined(separator: "/")
                }
            }
        }

        return totals.keys.sorted().map { key in
            VegasPartnershipBreakdown(
                id: key,
                title: titles[key] ?? "Pair",
                total: totals[key] ?? 0
            )
        }
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
        let sharedSubject = sharedOutcomeSubject(for: participant)
        let grossScoreToPar = sharedSubject
            .map { scoringUnitScoreToPar(scoringUnitID: $0.scoringUnitID, basis: .gross) }
            ?? scoreToPar(for: participant, basis: .gross)
        let netScoreToPar = sharedSubject
            .map { scoringUnitScoreToPar(scoringUnitID: $0.scoringUnitID, basis: .net) }
            ?? scoreToPar(for: participant, basis: .net)
        return OutcomePersonalSummary(
            participant: participant,
            tee: tee,
            grossScoreToPar: grossScoreToPar,
            netScoreToPar: netScoreToPar,
            adjustedIndex: derivedRoundHandicapIndex(for: participant)
        )
    }

    private func sharedOutcomeSubject(for participant: RoundParticipant) -> SharedScoringSubject? {
        guard snapshot.isSharedScoreSource else { return nil }
        return sharedScoringSubjects.first { subject in
            subject.participants.contains { $0.id == participant.id }
        }
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
        let activeParticipants = snapshot.participants.filter(isPresenceActive)

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
        if let mismatch = snapshot.primarySegmentHoleRangeMismatch {
            return OutcomeMatchupStatus(
                title: mismatch.diagnosticTitle,
                detail: mismatch.diagnosticDetail,
                winningScoringUnitID: nil,
                isTie: false
            )
        }

        let presentation = matchupPresentation(in: section)
        if presentation.minimumCountStatus?.hasUnderMinimumSide == true,
           !shouldResolveMinimumCountResult(presentation) {
            return OutcomeMatchupStatus(
                title: "Matchup pending",
                detail: "Waiting for required scores to count",
                winningScoringUnitID: nil,
                isTie: false
            )
        }
        guard presentation.hasCompleteSides else {
            return OutcomeMatchupStatus(
                title: "Matchup pending",
                detail: "Waiting for both sides to post scores",
                winningScoringUnitID: nil,
                isTie: false
            )
        }

        return OutcomeMatchupStatus(
            title: presentation.title,
            detail: presentation.marginDetail,
            winningScoringUnitID: presentation.winningSideID,
            isTie: presentation.isTie
        )
    }

    func outcomeMatchupSideName(scoringUnitID: String, matchup: TeamMatchup) -> String {
        switch matchup.effectiveMode {
        case .team:
            if let team = snapshot.teams.first(where: { $0.id == scoringUnitID }) {
                return team.name
            }
            if let subject = sharedScoringSubject(matching: scoringUnitID) {
                return subject.title
            }
            if let scoringUnit = scoringUnit(id: scoringUnitID),
               scoringUnit.owner == .team,
               let teamID = scoringUnit.ownerIDs.first,
               let team = snapshot.teams.first(where: { $0.id == teamID }) {
                return team.name
            }
            return "Team"
        case .individual:
            return snapshot.participants.first(where: { $0.id == scoringUnitID })?.name.fullName ?? "Player"
        case .partnership, .teeGroup, .scoreOwner:
            if let group = snapshot.scoringGroup(id: scoringUnitID) {
                return scoringGroupLabel(group)
            }
            if let scoringUnit = scoringUnit(id: scoringUnitID),
               let group = scoringGroup(for: scoringUnit) {
                return scoringGroupLabel(group)
            }
            if let subject = sharedScoringSubject(matching: scoringUnitID) {
                return subject.title
            }
            return "Side"
        }
    }
    
    // MARK: - Scoring Engine Bridge

    /// Runs the new ScoringEngine against the current snapshot.
    /// Uses computeWithPipeline when template has a non-empty pipeline (field or matchup scope).
    /// Uses computeStrokePlay only when pipeline is empty (plain stroke play).
    var engineResult: ScoringResult {
        engineResult(for: scoreBasis)
    }

    var matchupEngineResult: ScoringResult {
        engineResult(for: matchupScoreBasis)
    }

    private var usesIndividualContributionLeaderboardRows: Bool {
        let template = snapshot.resolvedActiveTemplate
        return effectiveLeaderboardChip != .strokes
            && !snapshot.isSharedScoreSource
            && !snapshot.isVegasFormat
            && template.subject == .participant
            && template.scoreSource == .individual
            && template.pipeline.isPopulated
    }

    func engineResult(for basis: ScoreBasis) -> ScoringResult {
        if let cached = cachedEngineResults[basis.rawValue] {
            return cached
        }

        let segment = snapshot.roundSegment ?? RoundSegment()
        let holes = defaultTee?.holes ?? []
        let scoreLookupIDs = snapshot.segmentScoreLookupSegmentIDs
        let result = ScoringEngine.computeSnapshotResult(
            snapshot: snapshot,
            segment: segment,
            holes: holes,
            basis: basis,
            scoreLookupSegmentIDs: scoreLookupIDs.isEmpty ? nil : scoreLookupIDs
        )
        cachedEngineResults[basis.rawValue] = result
        return result
    }

    func projectedLeaderboardRows(for basis: ScoreBasis) -> [LeaderboardRow] {
        leaderboardRows(from: engineResult(for: basis))
    }

    func projectedIndividualLeaderboardRows(for basis: ScoreBasis) -> [LeaderboardRow] {
        leaderboardRows(from: individualContributionEngineResult(for: basis))
    }

    private func individualContributionEngineResult(for basis: ScoreBasis) -> ScoringResult {
        if let cached = cachedIndividualContributionEngineResults[basis.rawValue] {
            return cached
        }

        let segment = snapshot.roundSegment ?? RoundSegment()
        let holes = defaultTee?.holes ?? []
        let scoreLookupIDs = snapshot.segmentScoreLookupSegmentIDs
        let handicapNormalizationMode = basis == .net ? snapshot.configuration.handicapNormalizationMode : .off
        let eligibleParticipants = ScoringEngine.scoringEligibleParticipants(
            snapshot.participants,
            substitutesScore: snapshot.configuration.substitutesScore,
            attendanceConfirmationEnabled: snapshot.configuration.attendanceConfirmationEnabled == true
        )
        let scoringParticipants = handicapNormalizationMode == .field
            ? HandicapCalculator.normalizedParticipantsForField(eligibleParticipants)
            : eligibleParticipants

        let result = ScoringEngine.computeWithPipeline(
            scores: snapshot.scoring,
            participants: scoringParticipants,
            unnormalizedParticipants: eligibleParticipants,
            teams: snapshot.teams,
            segment: segment,
            holes: holes,
            basis: basis,
            scoreInputMode: snapshot.configuration.scoreInputMode,
            template: snapshot.resolvedActiveTemplate,
            scoreLookupSegmentIDs: scoreLookupIDs.isEmpty ? nil : scoreLookupIDs,
            resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope,
            scoreOwnerScope: .individual,
            selectionDomain: .participant,
            teamScoring: .init(),
            scoringGroups: snapshot.scoringGroups,
            perHoleWinPoints: snapshot.configuration.resolvedHoleWinPoints,
            sharedScoreHandicapConfig: snapshot.configuration.sharedScoreHandicapConfig,
            handicapNormalizationMode: handicapNormalizationMode,
            handicapStrokeBasis: snapshot.handicapStrokeBasis,
            substitutesScore: snapshot.configuration.substitutesScore,
            attendanceConfirmationEnabled: snapshot.configuration.attendanceConfirmationEnabled == true
        )
        cachedIndividualContributionEngineResults[basis.rawValue] = result
        return result
    }

    /// Matchup sections for the Matchups tab. Empty when not matchup scope or no valid matchups. Only includes sections matching the current mode (requiresTeams).
    var matchupSections: [MatchupLeaderboardSection] {
        let result = matchupEngineResult
        let builtSections = LeaderboardBuilder.buildMatchupSections(
            result: result,
            teams: snapshot.teams,
            participants: snapshot.participants,
            scoringGroups: snapshot.scoringGroups
        )
        .filter { shouldDisplayMatchup($0.matchup) }
        .map(reorderedMatchupSection)

        let builtIDs = Set(builtSections.map(\.id))
        let expectedMatchups = (snapshot.roundSegment?.matchups ?? [])
            .filter { shouldDisplayMatchup($0) && $0.isValid && !builtIDs.contains($0.id) }
            .map { matchup in
                MatchupLeaderboardSection(
                    id: matchup.id,
                    matchup: matchup,
                    name: matchupSectionName(for: matchup),
                    rows: []
                )
            }

        return (builtSections + expectedMatchups)
    }

    var orderedMatchupSections: [OrderedMatchupSection] {
        orderedMatchupSections(from: matchupSections, promotingParticipantID: currentParticipantID)
    }

    func orderedMatchupSections(
        from sections: [MatchupLeaderboardSection],
        promotingParticipantID participantID: String?
    ) -> [OrderedMatchupSection] {
        let indexed = sections.enumerated().map { index, section in
            OrderedMatchupSection(originalIndex: index, section: section)
        }

        guard let participantID, participantID.isPopulated else { return indexed }

        return indexed.sorted { lhs, rhs in
            let lhsContains = matchupSection(lhs.section, containsParticipantID: participantID)
            let rhsContains = matchupSection(rhs.section, containsParticipantID: participantID)
            if lhsContains != rhsContains { return lhsContains }
            return lhs.originalIndex < rhs.originalIndex
        }
    }

    func matchupSection(
        _ section: MatchupLeaderboardSection,
        containsParticipantID participantID: String
    ) -> Bool {
        guard participantID.isPopulated else { return false }
        return section.matchup.pairingIDs().contains { sideID in
            matchupSideParticipants(scoringUnitID: sideID, matchup: section.matchup)
                .contains { $0.id == participantID }
        }
    }

    private func shouldDisplayMatchup(_ matchup: TeamMatchup) -> Bool {
        let mode = matchup.effectiveMode
        if mode == expectedMatchupMode {
            return true
        }
        guard snapshot.isSharedScoreSource,
              mode.usesScoringGroupIDs,
              matchup.isValid else {
            return false
        }
        return matchup.pairingIDs().allSatisfy(canResolveScoreOwnerMatchupSide)
    }

    private func canResolveScoreOwnerMatchupSide(_ sideID: String) -> Bool {
        if snapshot.scoringGroup(id: sideID) != nil { return true }
        if sharedScoringSubject(matching: sideID) != nil { return true }
        if let scoringUnit = scoringUnit(id: sideID), scoringUnit.owner == .scoreOwner {
            return true
        }
        return false
    }

    private func matchupSectionName(for matchup: TeamMatchup) -> String {
        let names = matchup.pairingIDs().map {
            outcomeMatchupSideName(scoringUnitID: $0, matchup: matchup)
        }
        guard names.count == 2 else { return "Matchup" }
        return "\(names[0]) vs \(names[1])"
    }

    private func reorderedMatchupSection(_ section: MatchupLeaderboardSection) -> MatchupLeaderboardSection {
        let pairingIDs = section.matchup.pairingIDs()
        guard pairingIDs.isPopulated else { return section }

        var usedRowIDs = Set<String>()
        var orderedRows = Array(section.rows.prefix(0))
        for sideID in pairingIDs {
            if let row = section.rows.first(where: {
                !usedRowIDs.contains($0.id)
                    && matchupLeaderboardRowMatches(
                        scoringUnitID: $0.scoringUnitID,
                        owner: $0.owner,
                        participantIDs: $0.participantIDs,
                        sideID: sideID,
                        matchup: section.matchup
                    )
            }) {
                orderedRows.append(row)
                usedRowIDs.insert(row.id)
            }
        }
        orderedRows.append(contentsOf: section.rows.filter { !usedRowIDs.contains($0.id) })

        return MatchupLeaderboardSection(
            id: section.id,
            matchup: section.matchup,
            name: matchupSectionName(for: section.matchup),
            rows: orderedRows
        )
    }

    func matchupTotal(in section: MatchupLeaderboardSection, sideID: String) -> Double? {
        matchupPresentation(in: section).side(id: sideID)?.total
    }

    func matchupScoringUnitID(in section: MatchupLeaderboardSection, sideID: String) -> String? {
        matchupPresentation(in: section).side(id: sideID)?.id
    }

    private func matchupLeaderboardRowMatches(
        scoringUnitID: String,
        owner: ScoringOwner,
        participantIDs: [String],
        sideID: String,
        matchup: TeamMatchup
    ) -> Bool {
        if scoringUnitID == sideID { return true }
        return scoringRowIdentityMatches(
            scoringUnitID: scoringUnitID,
            owner: owner,
            participantIDs: participantIDs,
            sideID: sideID,
            mode: matchup.effectiveMode
        )
    }

    private func scoringRow(
        in rows: [ScoringRow],
        matchesSideID sideID: String,
        matchup: TeamMatchup
    ) -> ScoringRow? {
        rows.first {
            if $0.scoringUnitID == sideID { return true }
            return scoringRowIdentityMatches(
                scoringUnitID: $0.scoringUnitID,
                owner: $0.owner,
                participantIDs: $0.participantIDs,
                sideID: sideID,
                mode: matchup.effectiveMode
            )
        }
    }

    private func scoringRowIdentityMatches(
        scoringUnitID: String,
        owner: ScoringOwner,
        participantIDs: [String],
        sideID: String,
        mode: MatchupMode
    ) -> Bool {
        if scoringUnitID == sideID { return true }

        let scoringUnit = scoringUnit(id: scoringUnitID)
        switch mode {
        case .individual:
            return participantIDs.contains(sideID)
        case .team:
            if let scoringUnit,
               scoringUnit.owner == .team,
               scoringUnit.ownerIDs.contains(sideID) {
                return true
            }
            let teamMemberIDs = Set(snapshot.participants.filter { $0.teamID == sideID }.map(\.id))
            return teamMemberIDs.isPopulated && Set(participantIDs).isSubset(of: teamMemberIDs)
        case .partnership, .teeGroup, .scoreOwner:
            if let scoringUnit,
               scoringUnit.owner == .scoreOwner {
                if scoringUnit.ownerIDs.contains(sideID) { return true }
                if let group = snapshot.scoringGroup(id: sideID) {
                    return Set(scoringUnit.ownerIDs) == Set(group.memberIDs)
                }
            }
            guard let group = snapshot.scoringGroup(id: sideID) else { return false }
            return Set(participantIDs) == Set(group.memberIDs)
        }
    }

    /// Engine-derived leaderboard rows, bridged to the ViewModel's LeaderboardRow type.
    /// Supports both participant rows (Stableford, stroke play) and team rows (best ball).
    private var sharedLeaderboardRows: [LeaderboardRow] {
        let subjects = sharedScoringSubjects
        guard subjects.isPopulated else { return [] }

        let engineRows = engineLeaderboardRows
        let isHighestWins = engineResult.template.leaderboardSort == .highestWins
        let rows = subjects.compactMap { subject in
            sharedLeaderboardRow(for: subject, engineRows: engineRows)
        }

        let sorted = rows.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if ($0.totalPoints != nil) != ($1.totalPoints != nil) {
                return $0.totalPoints != nil
            }
            let a = $0.totalPoints ?? Double($0.scoreToPar)
            let b = $1.totalPoints ?? Double($1.scoreToPar)
            if a != b { return isHighestWins ? a > b : a < b }
            let nameA = $0.teamName ?? $0.participant.alphabeticName
            let nameB = $1.teamName ?? $1.participant.alphabeticName
            return nameA < nameB
        }

        let placeLabels = engineLeaderboardPlaceLabels(for: sorted, isHighestWins: isHighestWins)
        return sorted.map { row in
            LeaderboardRow(
                participant: row.participant,
                participants: row.participants,
                scoringUnitID: row.scoringUnitID,
                thru: row.thru,
                scoreToPar: row.scoreToPar,
                totalPoints: row.totalPoints,
                isPinned: row.isPinned,
                placeLabel: placeLabels[row.id] ?? "-",
                teamID: row.teamID,
                teamName: row.teamName,
                teamColor: row.teamColor,
                memberNames: row.memberNames,
                sharedHandicapLabel: row.sharedHandicapLabel,
                isSharedScoreUnit: row.isSharedScoreUnit
            )
        }
    }

    private func sharedLeaderboardRow(
        for subject: SharedScoringSubject,
        engineRows: [LeaderboardRow]
    ) -> LeaderboardRow? {
        let members = subject.participants.sorted(by: participantDisplaySort)
        guard let anchor = members.first else { return nil }
        let engineRow = engineRows.first { sharedSubject(subject, matches: $0) }
        let displayedMembers = Array(members.dropFirst())
        let memberNames = displayedMembers
            .map { formatDisplayName(for: $0) }
            .filter(\.isPopulated)
            .joined(separator: "\n")
        let isPinned = pinnedParticipantIDs.contains(subject.scoringUnitID)
            || subject.teamID.map { pinnedParticipantIDs.contains($0) } == true
            || members.contains { pinnedParticipantIDs.contains($0.id) }

        return LeaderboardRow(
            participant: anchor,
            participants: members,
            scoringUnitID: subject.scoringUnitID,
            thru: engineRow?.thru ?? (members.map { holesPlayedCount(for: $0.id) }.max() ?? 0),
            scoreToPar: engineRow?.scoreToPar ?? scoringUnitScoreToPar(scoringUnitID: subject.scoringUnitID, basis: scoreBasis),
            totalPoints: engineRow?.totalPoints,
            isPinned: isPinned,
            placeLabel: "",
            teamID: subject.teamID,
            teamName: subject.title,
            teamColor: subject.accentColor,
            memberNames: memberNames.isPopulated ? memberNames : nil,
            sharedHandicapLabel: scoringUnitHandicapDecimalLabel(scoringUnitID: subject.scoringUnitID),
            isSharedScoreUnit: true
        )
    }

    private func sharedSubject(_ subject: SharedScoringSubject, matches row: LeaderboardRow) -> Bool {
        if row.scoringUnitID == subject.scoringUnitID { return true }
        if let scoringGroupID = subject.scoringGroupID, row.scoringUnitID == scoringGroupID {
            return true
        }
        let subjectMemberIDs = Set(subject.participants.map(\.id))
        let rowMemberIDs = Set(row.participants.map(\.id))
        if subjectMemberIDs.isPopulated && subjectMemberIDs == rowMemberIDs {
            return true
        }
        guard snapshot.configuration.scoreOwnerScope == .individual,
              let teamID = subject.teamID else {
            return false
        }
        return row.teamID == teamID || row.scoringUnitID == teamID
    }

    private func sharedScoringSubject(matching id: String) -> SharedScoringSubject? {
        sharedScoringSubjects.first {
            $0.scoringUnitID == id
                || $0.teamID == id
                || $0.scoringGroupID == id
                || $0.teeGroupID == id
        }
    }

    func matchupSideParticipants(scoringUnitID: String, matchup: TeamMatchup) -> [RoundParticipant] {
        switch matchup.effectiveMode {
        case .team:
            let teamMembers = snapshot.participants
                .filter { $0.teamID == scoringUnitID && isPresenceActive($0) }
                .sorted(by: participantDisplaySort)
            if teamMembers.isPopulated { return teamMembers }
            return sharedScoringSubject(matching: scoringUnitID)?.participants ?? []
        case .individual:
            return snapshot.participants
                .filter { $0.id == scoringUnitID && isPresenceActive($0) }
                .sorted(by: participantDisplaySort)
        case .partnership, .teeGroup, .scoreOwner:
            if let group = snapshot.scoringGroup(id: scoringUnitID) {
                return participants(for: group).filter(isPresenceActive)
            }
            return sharedScoringSubject(matching: scoringUnitID)?.participants ?? []
        }
    }

    var engineLeaderboardRows: [LeaderboardRow] {
        leaderboardRows(from: engineResult)
    }

    private var individualContributionLeaderboardRows: [LeaderboardRow] {
        let contributionRows = leaderboardRows(from: individualContributionEngineResult(for: scoreBasis))
        let contributionByParticipantID = Dictionary(uniqueKeysWithValues: contributionRows.map { ($0.participant.id, $0) })
        let rows = leaderboardRows.map { baseRow in
            let contribution = contributionByParticipantID[baseRow.participant.id]
            let pointSummary = stablefordPointSummary(for: baseRow, basis: scoreBasis)
            let totalPoints = effectiveLeaderboardChip == .stableford
                ? Double(pointSummary.total)
                : (contribution?.totalPoints ?? 0)
            return LeaderboardRow(
                participant: baseRow.participant,
                participants: baseRow.participants,
                scoringUnitID: baseRow.scoringUnitID,
                thru: effectiveLeaderboardChip == .stableford
                    ? pointSummary.scoredCount
                    : (contribution?.thru ?? baseRow.thru),
                scoreToPar: effectiveLeaderboardChip == .stableford
                    ? Int(totalPoints.rounded())
                    : (contribution?.scoreToPar ?? Int(totalPoints.rounded())),
                totalPoints: totalPoints,
                isPinned: baseRow.isPinned,
                placeLabel: "",
                teamID: baseRow.teamID,
                teamName: baseRow.teamName,
                teamColor: baseRow.teamColor,
                memberNames: baseRow.memberNames,
                sharedHandicapLabel: baseRow.sharedHandicapLabel,
                isSharedScoreUnit: baseRow.isSharedScoreUnit,
                scoreCompleteness: baseRow.scoreCompleteness
            )
        }
        let isHighestWins = individualContributionEngineResult(for: scoreBasis).template.leaderboardSort == .highestWins
        let sorted = rows.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            let a = $0.totalPoints ?? Double($0.scoreToPar)
            let b = $1.totalPoints ?? Double($1.scoreToPar)
            if a != b { return isHighestWins ? a > b : a < b }
            return $0.participant.alphabeticName < $1.participant.alphabeticName
        }
        let placeLabels = engineLeaderboardPlaceLabels(for: sorted, isHighestWins: isHighestWins)
        return sorted.map { row in
            row.withPlaceLabel(placeLabels[row.id] ?? "-")
        }
    }

    func stablefordPoints(scoreToPar: Int) -> Int {
        let entries = stablefordPointsMap.entries ?? []
        if let match = entries.first(where: { $0.scoreToPar == scoreToPar }) {
            return Int(match.points.rounded())
        }
        if let worst = entries.max(by: { $0.scoreToPar < $1.scoreToPar }), scoreToPar > worst.scoreToPar {
            return Int(worst.points.rounded())
        }
        if let best = entries.min(by: { $0.scoreToPar < $1.scoreToPar }), scoreToPar < best.scoreToPar {
            return Int(best.points.rounded())
        }
        return 0
    }

    func stablefordPoints(displayedStrokes: Int?, par: Int?) -> Int? {
        guard let displayedStrokes, let par else { return nil }
        return stablefordPoints(scoreToPar: displayedStrokes - par)
    }

    func stablefordPointSummary(
        for participant: RoundParticipant,
        basis: ScoreBasis? = nil,
        holes: [Int]? = nil
    ) -> (total: Int, scoredCount: Int) {
        let resolvedBasis = basis ?? scoreBasis
        let resolvedHoles = holes ?? courseOrderHoleNumbers
        let points = resolvedHoles.compactMap { holeNumber -> Int? in
            guard let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else { return nil }
            let displayed = stablefordDisplayedStrokes(gross: gross, participant: participant, holeNumber: holeNumber, basis: resolvedBasis)
            return stablefordPoints(displayedStrokes: displayed, par: hole(for: holeNumber)?.par)
        }
        return (points.reduce(0, +), points.count)
    }

    func stablefordPointSummary(
        for row: LeaderboardRow,
        basis: ScoreBasis? = nil,
        holes: [Int]? = nil
    ) -> (total: Int, scoredCount: Int) {
        guard row.isSharedScoreUnit else {
            return stablefordPointSummary(for: row.participant, basis: basis, holes: holes)
        }

        let resolvedBasis = basis ?? scoreBasis
        let resolvedHoles = holes ?? courseOrderHoleNumbers
        let points = resolvedHoles.compactMap { holeNumber -> Int? in
            let gross = scoringUnitGrossStrokes(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
            let net = scoringUnitNetStrokes(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
            let displayed = resolvedBasis == .gross ? gross : (net ?? gross)
            return stablefordPoints(displayedStrokes: displayed, par: hole(for: holeNumber)?.par)
        }
        return (points.reduce(0, +), points.count)
    }

    private var stablefordPointsMap: PointsMap {
        for stage in snapshot.resolvedActiveTemplate.pipeline {
            if case .transform(let pointsMap) = stage, pointsMap.mode == .parRelative {
                return pointsMap
            }
        }
        return snapshot.configuration.resolvedStablefordPoints.clamped.pointsMap
    }

    private func stablefordDisplayedStrokes(
        gross: Int,
        participant: RoundParticipant,
        holeNumber: Int,
        basis: ScoreBasis
    ) -> Int {
        guard basis == .net else { return gross }
        let received = ScoringEngine.strokesReceived(
            handicap: participant.adjustedHandicap,
            holeNumber: holeNumber,
            holes: defaultTee?.holes ?? [],
            playedHoleNumbers: snapshot.holeRange?.holeNumbers ?? Array(1...18),
            useHandicaps: true,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
        return max(0, gross - received)
    }

    private func leaderboardRows(from result: ScoringResult) -> [LeaderboardRow] {
        let participantMap = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        let teamMap = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })
        let scoringGroupMap = Dictionary(uniqueKeysWithValues: snapshot.scoringGroups.map { ($0.id, $0) })

        let isHighestWins = result.template.leaderboardSort == .highestWins

        let rows: [LeaderboardRow] = result.rows.compactMap {
            leaderboardRow(
                for: $0,
                participantMap: participantMap,
                teamMap: teamMap,
                scoringGroupMap: scoringGroupMap
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
                participants: row.participants,
                scoringUnitID: row.scoringUnitID,
                thru: row.thru,
                scoreToPar: row.scoreToPar,
                totalPoints: row.totalPoints,
                isPinned: row.isPinned,
                placeLabel: placeLabels[row.id] ?? "-",
                teamID: row.teamID,
                teamName: row.teamName,
                teamColor: row.teamColor,
                memberNames: row.memberNames,
                isSharedScoreUnit: row.isSharedScoreUnit
            )
        }
    }

    private func leaderboardRow(
        for row: ScoringRow,
        participantMap: [String: RoundParticipant],
        teamMap: [String: RoundTeam],
        scoringGroupMap: [String: RoundScoringGroup]
    ) -> LeaderboardRow? {
        let activeMembers = row.participantIDs
            .compactMap { participantMap[$0] }
            .filter(isPresenceActive)
            .sorted(by: participantDisplaySort)
        let isSharedRow = snapshot.isSharedScoreSource && (row.owner != .participant || activeMembers.count > 1)

        if let participant = participantMap[row.scoringUnitID] {
            guard isPresenceActive(participant) else { return nil }
            return LeaderboardRow(
                participant: participant,
                participants: [participant],
                scoringUnitID: row.scoringUnitID,
                thru: row.holesPlayed,
                scoreToPar: Int(row.total),
                totalPoints: row.total,
                isPinned: pinnedParticipantIDs.contains(row.scoringUnitID),
                placeLabel: "",
                isSharedScoreUnit: false
            )
        }

        if let team = team(for: row, teamMap: teamMap),
           let participant = activeMembers.first {
            let resolvedScoringUnitID = scoringUnitID(forTeamID: team.id)
            let displayedMembers = isSharedRow ? Array(activeMembers.dropFirst()) : activeMembers
            let separator = isSharedRow ? "\n" : ", "
            let names = displayedMembers
                .map { formatDisplayName(for: $0) }
                .joined(separator: separator)
            return LeaderboardRow(
                participant: participant,
                participants: activeMembers,
                scoringUnitID: resolvedScoringUnitID,
                thru: row.holesPlayed,
                scoreToPar: Int(row.total),
                totalPoints: row.total,
                isPinned: pinnedParticipantIDs.contains(row.scoringUnitID)
                    || pinnedParticipantIDs.contains(resolvedScoringUnitID)
                    || activeMembers.contains { pinnedParticipantIDs.contains($0.id) },
                placeLabel: "",
                teamID: team.id,
                teamName: team.name,
                teamColor: team.displaySwatchColor,
                memberNames: names.isPopulated ? names : nil,
                isSharedScoreUnit: isSharedRow
            )
        }

        if let scoringGroup = scoringGroupMap[row.scoringUnitID] ?? scoringGroup(for: row),
           let participant = activeMembers.first {
            let displayedMembers = isSharedRow ? Array(activeMembers.dropFirst()) : activeMembers
            let separator = isSharedRow ? "\n" : ", "
            let names = displayedMembers
                .map { formatDisplayName(for: $0) }
                .joined(separator: separator)
            let fallbackTeamName = activeMembers
                .map { formatDisplayName(for: $0) }
                .joined(separator: " + ")
            return LeaderboardRow(
                participant: participant,
                participants: activeMembers,
                scoringUnitID: row.scoringUnitID,
                thru: row.holesPlayed,
                scoreToPar: Int(row.total),
                totalPoints: row.total,
                isPinned: pinnedParticipantIDs.contains(row.scoringUnitID) || activeMembers.contains { pinnedParticipantIDs.contains($0.id) },
                placeLabel: "",
                teamID: scoringGroup.teamID,
                teamName: scoringGroup.label ?? (fallbackTeamName.isPopulated ? fallbackTeamName : nil),
                teamColor: scoringGroup.teamID.flatMap { teamMap[$0]?.displaySwatchColor },
                memberNames: names.isPopulated ? names : nil,
                isSharedScoreUnit: isSharedRow
            )
        }

        guard row.owner != .participant,
              let participant = activeMembers.first else {
            return nil
        }
        let displayedMembers = isSharedRow ? Array(activeMembers.dropFirst()) : activeMembers
        let names = displayedMembers
            .map { formatDisplayName(for: $0) }
            .joined(separator: isSharedRow ? "\n" : ", ")
        let teamIDs = Set(activeMembers.compactMap(\.teamID))
        let teamID = teamIDs.count == 1 ? teamIDs.first : nil
        let team = teamID.flatMap { teamMap[$0] }
        return LeaderboardRow(
            participant: participant,
            participants: activeMembers,
            scoringUnitID: row.scoringUnitID,
            thru: row.holesPlayed,
            scoreToPar: Int(row.total),
            totalPoints: row.total,
            isPinned: pinnedParticipantIDs.contains(row.scoringUnitID) || activeMembers.contains { pinnedParticipantIDs.contains($0.id) },
            placeLabel: "",
            teamID: teamID,
            teamName: nil,
            teamColor: team?.displaySwatchColor,
            memberNames: names.isPopulated ? names : nil,
            isSharedScoreUnit: isSharedRow
        )
    }

    private func participantDisplaySort(lhs: RoundParticipant, rhs: RoundParticipant) -> Bool {
        let teeA = lhs.teeOrder ?? Int.max
        let teeB = rhs.teeOrder ?? Int.max
        if teeA != teeB { return teeA < teeB }
        return lhs.alphabeticName < rhs.alphabeticName
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
        
        if scoreInputValue(for: participant.id, holeNumber: holeNumber) == value {
            await clearScore(participant: participant, holeNumber: holeNumber, entryMethod: .clear)
            showCustomScorePrompt = false
            return
        }

        await setScoreInputValue(
            participant: participant,
            holeNumber: holeNumber,
            value: value,
            entryMethod: .customPrompt
        )
        showCustomScorePrompt = false
    }
    
    func setQuickScoreValue(
        participant: RoundParticipant,
        value: Int,
        holeNumber: Int,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        await setScoreInputValue(
            participant: participant,
            holeNumber: holeNumber,
            value: value,
            entryMethod: entryMethod
        )
    }

    func setScoreInputValue(
        participant: RoundParticipant,
        holeNumber: Int,
        value: Int,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        if isFriendlyScoreInputMode {
            await setRelativeScore(
                participant: participant,
                holeNumber: holeNumber,
                relativeToPar: value,
                entryMethod: entryMethod
            )
        } else {
            await setScore(
                participant: participant,
                holeNumber: holeNumber,
                strokes: value,
                entryMethod: entryMethod
            )
        }
    }

    func setScoreInputValue(
        scoringUnitID: String,
        participant: RoundParticipant,
        holeNumber: Int,
        value: Int,
        participantIDs: [String]? = nil,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        if isFriendlyScoreInputMode {
            await setRelativeScore(
                participant: participant,
                holeNumber: holeNumber,
                relativeToPar: value,
                scoringUnitID: scoringUnitID,
                participantIDs: participantIDs,
                entryMethod: entryMethod
            )
        } else {
            await setScore(
                participant: participant,
                holeNumber: holeNumber,
                strokes: value,
                scoringUnitID: scoringUnitID,
                participantIDs: participantIDs,
                entryMethod: entryMethod
            )
        }
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
        await clearScore(
            scoringUnitID: scoreEntry(for: participant.id, holeNumber: holeNumber)?.scoringUnitID ?? participant.id,
            participant: participant,
            holeNumber: holeNumber,
            entryMethod: entryMethod
        )
    }

    func clearScore(
        scoringUnitID: String,
        participant: RoundParticipant,
        holeNumber: Int,
        entryMethod: LiveRoundEntryMethod = .clear
    ) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        guard var entry = scoreEntryForScoringUnit(scoringUnitID: scoringUnitID, holeNumber: holeNumber) ?? scoreEntry(for: participant.id, holeNumber: holeNumber) else { return }
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
        entry.relativeToPar = nil
        entry.entryMode = nil
        
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
        scoringUnitID scoringUnitIDOverride: String? = nil,
        participantIDs participantIDsOverride: [String]? = nil,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        addBreadcrumb()

        guard isPresenceActive(participant) else { return }
        
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
        let explicitScoringUnit = scoringUnitIDOverride.flatMap { scoringUnit(id: $0) }
        let scoringUnitID = scoringUnitIDOverride
            ?? resolvedScoringUnit?.id
            ?? ((isShared && teamID != nil) ? teamID! : participant.id)
        let participantIDs = participantIDsForScoreEntry(
            participant: participant,
            scoringUnitIDOverride: scoringUnitIDOverride,
            participantIDsOverride: participantIDsOverride,
            explicitScoringUnit: explicitScoringUnit,
            resolvedScoringUnit: resolvedScoringUnit
        )

        let id = ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: scoringUnitID)

        let lookupKey = scoringUnitIDOverride ?? resolvedScoringUnit?.id ?? ((isShared && teamID != nil) ? teamID! : participant.id)
        var entry = scoreEntryForScoringUnit(scoringUnitID: lookupKey, holeNumber: holeNumber) ?? ScoreEntry(
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
        entry.relativeToPar = nil
        entry.entryMode = .strokes
        
        let previousEntry = scoreEntryForScoringUnit(scoringUnitID: lookupKey, holeNumber: holeNumber)
        if previousEntry?.strokes == strokes,
           previousEntry?.relativeToPar == nil,
           previousEntry?.id == entry.id,
           previousEntry?.pickedUp == false {
            return
        }
        
        var updatedSnapshot = roundSession.snapshot
        if let previousEntry, previousEntry.id != entry.id {
            updatedSnapshot.scoring.removeAll { $0.id == previousEntry.id }
        }
        updatedSnapshot.scoring.upsert(entry)
        roundSession.snapshot = updatedSnapshot
        
        do {
            _ = try await entry.put().get()
            await roundSession.markFirstScoredIfNeeded(at: entry.createdAt)
            if let previousEntry, previousEntry.id != entry.id {
                _ = try? await previousEntry.delete().get()
            }
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
                rollbackSnapshot.scoring.removeAll { $0.id == entry.id }
                rollbackSnapshot.scoring.upsert(prev)
            } else {
                rollbackSnapshot.scoring.removeAll { $0.id == entry.id }
            }
            roundSession.snapshot = rollbackSnapshot
        }
    }

    func setRelativeScore(
        participant: RoundParticipant,
        holeNumber: Int,
        relativeToPar: Int,
        scoringUnitID scoringUnitIDOverride: String? = nil,
        participantIDs participantIDsOverride: [String]? = nil,
        entryMethod: LiveRoundEntryMethod = .quickPicker
    ) async {
        addBreadcrumb()

        guard isPresenceActive(participant) else { return }
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
        let explicitScoringUnit = scoringUnitIDOverride.flatMap { scoringUnit(id: $0) }
        let scoringUnitID = scoringUnitIDOverride
            ?? resolvedScoringUnit?.id
            ?? ((isShared && teamID != nil) ? teamID! : participant.id)
        let participantIDs = participantIDsForScoreEntry(
            participant: participant,
            scoringUnitIDOverride: scoringUnitIDOverride,
            participantIDsOverride: participantIDsOverride,
            explicitScoringUnit: explicitScoringUnit,
            resolvedScoringUnit: resolvedScoringUnit
        )

        let id = ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: scoringUnitID)
        let lookupKey = scoringUnitIDOverride ?? resolvedScoringUnit?.id ?? ((isShared && teamID != nil) ? teamID! : participant.id)

        var entry = scoreEntryForScoringUnit(scoringUnitID: lookupKey, holeNumber: holeNumber) ?? ScoreEntry(
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
        entry.strokes = nil
        entry.relativeToPar = relativeToPar
        entry.entryMode = .relativeToPar

        let previousEntry = scoreEntryForScoringUnit(scoringUnitID: lookupKey, holeNumber: holeNumber)
        if previousEntry?.relativeToPar == relativeToPar,
           previousEntry?.resolvedEntryMode == .relativeToPar,
           previousEntry?.id == entry.id,
           previousEntry?.pickedUp == false {
            return
        }

        var updatedSnapshot = roundSession.snapshot
        if let previousEntry, previousEntry.id != entry.id {
            updatedSnapshot.scoring.removeAll { $0.id == previousEntry.id }
        }
        updatedSnapshot.scoring.upsert(entry)
        roundSession.snapshot = updatedSnapshot

        do {
            _ = try await entry.put().get()
            await roundSession.markFirstScoredIfNeeded(at: entry.createdAt)
            if let previousEntry, previousEntry.id != entry.id {
                _ = try? await previousEntry.delete().get()
            }
            lastLocalScoreAt = Date()
            emitScoreSavedTelemetry(
                participant: participant,
                holeNumber: holeNumber,
                strokes: max(1, (hole(for: holeNumber)?.par ?? 4) + relativeToPar),
                entryMethod: entryMethod,
                beforeProgress: beforeProgress,
                afterSnapshot: updatedSnapshot,
                relativeToPar: relativeToPar
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set relative score for participant \(participant.id)", error: error)
            var rollbackSnapshot = roundSession.snapshot
            if let prev = previousEntry {
                rollbackSnapshot.scoring.removeAll { $0.id == entry.id }
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
            applySeriesAccessOverrideIfAvailable()
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded()
            return
        }
        
        if currentParticipantID.exists {
            applySeriesAccessOverrideIfAvailable()
            return
        }
        
        guard let primary = await AppData.shared.getPrimaryPlayer() else { return }
        if let p = snapshot.participants.first(where: { $0.playerID == primary.id }) {
            currentParticipantID = p.id
            applySeriesAccessOverrideIfAvailable()
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded()
        }
    }
    
    private func resetRoundScopedStateIfNeeded(for roundID: String) {
        guard scopedRoundID != roundID else { return }
        scopedRoundID = roundID
        currentParticipantID = nil
        visibleTeeGroupID = nil
        resolvedSeriesID = nil
        isSeriesCommissioner = false
        roundManagementAccess = .none
        seriesScoreboardSnapshot = nil
        liveSeriesScoreboardContext = nil
        predictionContextRoundID = nil
        loadedSeriesAccessRoundID = nil
        isLoadingSeriesAccess = false
        selectedTeeID = nil
        restoredHole = nil
        hasPerformedInitialHoleNudge = false
        hasSelectedInitialVisibleGroupStartingHole = false
        currentHoleIndex = 0
    }

    private func defaultVisibleTeeGroupID() -> String? {
        if let actualTeeGroupID,
           orderedTeeGroups.contains(where: { $0.id == actualTeeGroupID }) {
            return actualTeeGroupID
        }

        if canProxyManagedGroupScoring {
            return orderedTeeGroups.first?.id
        }

        return nil
    }

    private func applySeriesAccessOverrideIfAvailable() {
        if let seriesAccessOverride {
            resolvedSeriesID = seriesAccessOverride.seriesID
            isSeriesCommissioner = seriesAccessOverride.isCommissioner
            roundManagementAccess = RoundManagementAccess(
                isHost: actualParticipant?.isHost == true,
                isSeriesCommissioner: seriesAccessOverride.isCommissioner,
                isRoundCreator: false
            )
            return
        }

        guard let actualParticipant else { return }
        let participantAccess = RoundManagementAccess.resolve(
            snapshot: snapshot,
            currentUserID: actualParticipant.userID,
            currentPlayerID: actualParticipant.playerID
        )
        roundManagementAccess.isHost = participantAccess.isHost
        roundManagementAccess.isRoundCreator = participantAccess.isRoundCreator
    }

    private func syncVisibleTeeGroupIfNeeded() {
        let validGroupIDs = Set(orderedTeeGroups.map(\.id))
        if let visibleTeeGroupID, validGroupIDs.contains(visibleTeeGroupID) {
            return
        }

        guard let defaultGroupID = defaultVisibleTeeGroupID() else {
            visibleTeeGroupID = nil
            return
        }

        visibleTeeGroupID = defaultGroupID
        if let restoredHole { selectHole(restoredHole) }
        selectInitialVisibleGroupStartingHoleIfNeeded(groupID: defaultGroupID)
    }

    private func selectInitialVisibleGroupStartingHoleIfNeeded(groupID: String) {
        guard !hasSelectedInitialVisibleGroupStartingHole else { return }
        let targetHoleNumber = targetHoleNumber(forVisibleGroupID: groupID)
        selectHole(targetHoleNumber)
        visibleGroupSwitchRequest = VisibleGroupSwitchRequest(
            groupID: groupID,
            targetHoleNumber: targetHoleNumber,
            revisionID: UUID()
        )
        hasSelectedInitialVisibleGroupStartingHole = true
    }

    private func applyScoreBasisDefaultsForCurrentSnapshot(force: Bool) {
        let defaultBasis: ScoreBasis = snapshot.configuration.useHandicaps ? .net : .gross
        if force || !snapshot.configuration.useHandicaps {
            scoreBasis = defaultBasis
            matchupScoreBasis = defaultBasis
        }
    }

    private func loadSeriesAccessIfNeeded() async {
        let roundID = snapshot.round.id
        guard roundID.isPopulated else { return }
        guard loadedSeriesAccessRoundID != roundID else { return }
        guard !isLoadingSeriesAccess else { return }

        if let seriesAccessOverride {
            resolvedSeriesID = seriesAccessOverride.seriesID
            isSeriesCommissioner = seriesAccessOverride.isCommissioner
            applySeriesAccessOverrideIfAvailable()
            loadedSeriesAccessRoundID = roundID
            if snapshot.round.id == roundID {
                predictionContextRoundID = roundID
                scheduleMatchupProbabilityRefresh()
            }
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded(force: true)
            return
        }

        isLoadingSeriesAccess = true
        defer {
            isLoadingSeriesAccess = false
            loadedSeriesAccessRoundID = roundID
            if snapshot.round.id == roundID {
                predictionContextRoundID = roundID
                scheduleMatchupProbabilityRefresh()
            }
        }

        guard let seriesID = await resolveSeriesIDForRound(),
              seriesID.isPopulated else {
            resolvedSeriesID = nil
            isSeriesCommissioner = false
            let (currentUserID, currentPlayerID) = await currentUserAndPlayerIDs()
            roundManagementAccess = .resolve(
                snapshot: snapshot,
                currentUserID: currentUserID,
                currentPlayerID: currentPlayerID
            )
            liveSeriesScoreboardContext = nil
            seriesScoreboardSnapshot = nil
            syncVisibleTeeGroupIfNeeded()
            updateSelectedTeeIfNeeded(force: true)
            return
        }

        resolvedSeriesID = seriesID

        let series = await resolveSeries(seriesID: seriesID)
        let members = await FirebaseService.shared.fetchSeriesMembers(seriesID: seriesID)
        let activeMembers = members.filter(\.isActive)
        let (currentUserID, currentPlayerID) = await currentUserAndPlayerIDs()

        roundManagementAccess = .resolve(
            snapshot: snapshot,
            currentUserID: currentUserID,
            currentPlayerID: currentPlayerID,
            series: series,
            members: activeMembers
        )
        isSeriesCommissioner = roundManagementAccess.isSeriesCommissioner
        syncVisibleTeeGroupIfNeeded()
        updateSelectedTeeIfNeeded(force: true)
    }

    private func loadLiveSeriesScoreboardContext(
        seriesID: String,
        resolvedSeries: Series? = nil,
        resolvedMembers: [SeriesMember]? = nil
    ) async {
        let series: Series?
        if let resolvedSeries {
            series = resolvedSeries
        } else {
            series = await resolveSeries(seriesID: seriesID)
        }
        guard let series else {
            liveSeriesScoreboardContext = nil
            seriesScoreboardSnapshot = nil
            return
        }

        let teams = await FirebaseService.shared.fetchSeriesTeams(seriesID: seriesID)
        let rounds = await FirebaseService.shared.fetchSeriesRounds(seriesID: seriesID)
        let scoringProfiles = await FirebaseService.shared.fetchScoringProfiles(seriesID: seriesID)
        let pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        let members: [SeriesMember]
        if let resolvedMembers {
            members = resolvedMembers
        } else {
            members = await FirebaseService.shared.fetchSeriesMembers(seriesID: seriesID)
        }
        let currentSeriesRound = rounds.first { $0.roundID == snapshot.round.id }
        let mappings: [SeriesRoundMapping]
        if let currentSeriesRound {
            mappings = await FirebaseService.shared.fetchSeriesRoundMappings(
                seriesID: seriesID,
                seriesRoundID: currentSeriesRound.id
            )
        } else {
            mappings = []
        }
        let canonicalResults: [SeriesRoundResult]
        let processingStates: [SeriesRoundProcessingState]
        switch await FirebaseService.shared.fetchCanonicalRoundResults(seriesID: seriesID) {
        case .success(let values):
            canonicalResults = values
        case .failure:
            canonicalResults = []
        }
        switch await FirebaseService.shared.fetchCanonicalRoundProcessingStates(seriesID: seriesID) {
        case .success(let values):
            processingStates = values
        case .failure:
            processingStates = []
        }
        let latestGenerationIDs = Set(processingStates.compactMap { state in
            state.status == .completed ? state.latestGenerationID : nil
        })
        let verifiedResults = canonicalResults.filter { latestGenerationIDs.contains($0.id) }

        liveSeriesScoreboardContext = LiveSeriesScoreboardContext(
            series: series,
            rounds: rounds,
            scoringProfiles: scoringProfiles,
            pointAwards: pointAwards,
            teams: teams,
            members: members,
            currentSeriesRound: currentSeriesRound,
            currentRoundMappings: mappings,
            canonicalResults: verifiedResults
        )
        cachedPlayerSimulations.removeAll()
        refreshSeriesScoreboardProjection()
    }

    // MARK: - Live analytics

    func canRevealInsights(for participant: RoundParticipant) -> Bool {
        guard snapshot.isSecretScoring && !snapshot.areScoresRevealed else { return true }
        guard let currentParticipant else { return false }
        if currentParticipant.id == participant.id { return true }
        guard let currentTeamID = currentParticipant.teamID,
              currentTeamID.isPopulated else { return false }
        return participant.teamID == currentTeamID
    }

    var shouldShowMatchupProbabilities: Bool {
        !(snapshot.isSecretScoring && !snapshot.areScoresRevealed)
    }

    /// Starts keeping matchup estimates warm independently of whether the Matchups tab is visible.
    func startMatchupProbabilityPrecomputation() {
        isMatchupProbabilityPrecomputationEnabled = true
        scheduleMatchupProbabilityRefresh()
    }

    func projectionScenarioRevision() -> String {
        let participantIDs = Set(snapshot.participants.map(\.id))
        let matchupRevision = (snapshot.roundSegment?.matchups ?? [])
            .sorted { $0.id < $1.id }
            .map {
                "\($0.id):\($0.effectiveMode.rawValue):\($0.pairingIDs().joined(separator: ","))"
            }
            .joined(separator: "|")
        return [
            snapshot.round.id,
            projectionConfigurationRevision,
            projectionParticipantRevision(snapshot.participants),
            matchupRevision,
            projectionHistoryRevision,
            projectionScoreRevision(participantIDs: participantIDs)
        ].joined(separator: "|")
    }

    func projectionRevision(scoreBasis: ScoreBasis) -> String {
        "\(projectionScenarioRevision())|\(scoreBasis.rawValue)"
    }

    func playerProjectionRevision(
        for participant: RoundParticipant,
        scoreBasis: ScoreBasis
    ) -> String {
        "\(playerProjectionScenarioRevision(for: participant))|\(scoreBasis.rawValue)"
    }

    func matchupProbabilityRevision(
        for matchup: TeamMatchup,
        scoreBasis: ScoreBasis
    ) -> String {
        let participants = matchup.pairingIDs()
            .flatMap { matchupSideParticipants(scoringUnitID: $0, matchup: matchup) }
            .reduce(into: [String: RoundParticipant]()) { result, participant in
                result[participant.id] = participant
            }
            .values
            .sorted { $0.id < $1.id }
        let playerRevisions = participants.map {
            "\($0.id):\(ProjectionSeed.make(playerProjectionScenarioRevision(for: $0)))"
        }
        return [
            snapshot.round.id,
            scoreBasis.rawValue,
            projectionConfigurationRevision,
            "\(matchup.id):\(matchup.effectiveMode.rawValue):\(matchup.pairingIDs().joined(separator: ","))",
            playerRevisions.joined(separator: "|")
        ].joined(separator: "|")
    }

    func matchupProbabilityRevision(for matchup: TeamMatchup) -> String {
        matchupProbabilityRevision(
            for: matchup,
            scoreBasis: matchupProbabilityScoreBasis
        )
    }

    private var projectionConfigurationRevision: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot.round.configuration),
              let value = String(data: data, encoding: .utf8) else {
            return snapshot.resolvedActiveTemplate.id
        }
        return String(ProjectionSeed.make(value), radix: 16)
    }

    private var projectionHistoryRevision: String {
        liveSeriesScoreboardContext?.canonicalResults
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\($0.semanticHash)" }
            .joined(separator: "|") ?? "-"
    }

    private func playerProjectionScenarioRevision(for participant: RoundParticipant) -> String {
        [
            snapshot.round.id,
            projectionConfigurationRevision,
            projectionParticipantRevision([participant]),
            projectionHistoryRevision,
            projectionScoreRevision(participantIDs: [participant.id])
        ].joined(separator: "|")
    }

    private func projectionParticipantRevision(_ participants: [RoundParticipant]) -> String {
        participants
            .sorted { $0.id < $1.id }
            .map {
                [
                    $0.id,
                    $0.teeBoxID,
                    String($0.lockedHandicapAllowance),
                    $0.resolvedPresenceStatus.rawValue,
                    $0.isSubstitute ? "1" : "0"
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }

    private func projectionScoreRevision(participantIDs: Set<String>) -> String {
        snapshot.scoring
            .filter { entry in
                participantIDs.contains(entry.scoringUnitID)
                    || entry.participantIDs.contains { participantIDs.contains($0) }
            }
            .sorted { $0.id < $1.id }
            .map {
                [
                    $0.id,
                    String($0.holeNumber),
                    $0.strokes.map(String.init) ?? "-",
                    $0.relativeToPar.map(String.init) ?? "-",
                    $0.pickedUp ? "1" : "0"
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }

    func playerProjectionUnavailableReason(for participant: RoundParticipant) -> String? {
        guard unresolvedPickupHoleNumbers(for: participant).isPopulated else { return nil }
        return "Finish projection needs a resolved score for each picked-up hole."
    }

    func playerProjection(
        for participant: RoundParticipant,
        scoreBasis: ScoreBasis
    ) async -> PlayerFinishProjection? {
        guard canRevealInsights(for: participant),
              playerProjectionUnavailableReason(for: participant) == nil else { return nil }
        return await playerSimulation(for: participant, scoreBasis: scoreBasis)?.projection
    }

    func refreshMatchupProbabilities() async {
        isMatchupProbabilityPrecomputationEnabled = true
        let task = scheduleMatchupProbabilityRefresh()
        await task?.value
    }

    /// Replays the recorded round a checkpoint at a time so the detail view can show how
    /// matchup odds moved, including a pre-round baseline at zero holes completed.
    func matchupProbabilityTimeline(
        for matchup: TeamMatchup,
        scoreBasis: ScoreBasis
    ) async -> MatchupProbabilityTimeline {
        guard shouldShowMatchupProbabilities else {
            return .unsupported("Win probability is hidden until secret scoring is revealed.")
        }
        let template = snapshot.resolvedActiveTemplate
        guard template.inputMode == .strokes, template.scoreSource == .individual else {
            return .unsupported("Odds aren’t available for custom or shared-score formats.")
        }
        guard matchup.isValid, matchup.effectiveMode == snapshot.expectedMatchupMode else {
            return .unsupported("This matchup’s scoring configuration is incomplete.")
        }

        let eligibleParticipantIDs = Set(ScoringEngine.scoringEligibleParticipants(
            snapshot.participants,
            substitutesScore: snapshot.configuration.substitutesScore,
            attendanceConfirmationEnabled: snapshot.configuration.attendanceConfirmationEnabled == true
        ).map(\.id))
        let participants = matchup.pairingIDs()
            .flatMap { matchupSideParticipants(scoringUnitID: $0, matchup: matchup) }
            .filter { eligibleParticipantIDs.contains($0.id) }
            .reduce(into: [String: RoundParticipant]()) { result, participant in
                result[participant.id] = participant
            }
            .values
            .sorted { $0.id < $1.id }
        guard participants.isPopulated else {
            return .unsupported("No eligible players are available for this matchup.")
        }

        let playOrders = Dictionary(uniqueKeysWithValues: participants.map {
            ($0.id, matchupTimelinePlayOrder(for: $0))
        })
        let recordedHoles = Dictionary(uniqueKeysWithValues: participants.map {
            ($0.id, matchupTimelineRecordedHoleNumbers(for: $0))
        })
        var checkpointSet: Set<Int> = [0]
        for participant in participants {
            guard let playOrder = playOrders[participant.id],
                  let participantRecordedHoles = recordedHoles[participant.id] else { continue }
            for holeNumber in participantRecordedHoles {
                if let index = playOrder.firstIndex(of: holeNumber) {
                    checkpointSet.insert(index + 1)
                }
            }
        }

        let revision = matchupProbabilityRevision(for: matchup, scoreBasis: scoreBasis)
        let timelineCacheKey = [snapshot.round.id, matchup.id, scoreBasis.rawValue]
            .joined(separator: "|")
        if let cached = cachedMatchupProbabilityTimelines[timelineCacheKey],
           cached.revision == revision {
            return cached.timeline
        }
        var points: [MatchupProbabilityTrendPoint] = []
        var latestProbability: MatchupProbability?

        for checkpoint in checkpointSet.sorted() {
            if Task.isCancelled {
                return .init(points: points, latest: latestProbability, unsupportedReason: nil)
            }

            var simulations: [String: PlayerProjectionSimulation] = [:]
            var simulationKeys: [String] = []
            for participant in participants {
                guard let playOrder = playOrders[participant.id],
                      let participantRecordedHoles = recordedHoles[participant.id] else { continue }
                let revealedHoles = Set(playOrder.prefix(checkpoint))
                    .intersection(participantRecordedHoles)
                guard let input = projectionInput(
                    for: participant,
                    scoreBasis: scoreBasis,
                    recordedHoleNumbers: revealedHoles
                ) else {
                    return .unsupported("Not enough scoring context is available yet.")
                }

                let simulationKey = [
                    "matchup-timeline-player",
                    revision,
                    participant.id,
                    String(checkpoint),
                    revealedHoles.sorted().map(String.init).joined(separator: ",")
                ].joined(separator: "|")
                do {
                    let simulation = try await RoundProjectionSimulator.shared.simulate(
                        input: input,
                        iterations: Self.matchupTimelineProjectionIterationCount,
                        minimumIterations: Self.matchupTimelineProjectionIterationCount,
                        seed: ProjectionSeed.make(simulationKey),
                        cacheKey: simulationKey,
                        retainsDiagnosticScenarios: false
                    )
                    simulations[participant.id] = simulation
                    simulationKeys.append(simulationKey)
                } catch {
                    if error is CancellationError {
                        return .init(points: points, latest: latestProbability, unsupportedReason: nil)
                    }
                    return .unsupported("The probability replay couldn’t be calculated.")
                }
            }

            guard simulations.count == participants.count else {
                return .unsupported("Not enough scoring context is available yet.")
            }

            do {
                let values = try await MatchupProbabilitySimulator.shared.simulate(
                    snapshot: snapshot,
                    scoreBasis: scoreBasis,
                    playerSimulations: simulations,
                    matchupIDs: [matchup.id],
                    participantIDs: Set(participants.map(\.id)),
                    cacheKey: "matchup-timeline|\(simulationKeys.sorted().joined(separator: "|"))"
                )
                guard let probability = values[matchup.id] else {
                    return .unsupported("The probability replay couldn’t be calculated.")
                }
                latestProbability = probability
                guard probability.isSupported else {
                    let timeline = MatchupProbabilityTimeline(
                        points: points,
                        latest: probability,
                        unsupportedReason: probability.unsupportedReason
                    )
                    cachedMatchupProbabilityTimelines[timelineCacheKey] = (revision, timeline)
                    return timeline
                }
                points.append(.init(
                    holesCompleted: checkpoint,
                    leftWin: probability.leftWin,
                    tie: probability.tie,
                    rightWin: probability.rightWin
                ))
            } catch {
                if error is CancellationError {
                    return .init(points: points, latest: latestProbability, unsupportedReason: nil)
                }
                return .unsupported("The probability replay couldn’t be calculated.")
            }
        }

        let timeline = MatchupProbabilityTimeline(
            points: points,
            latest: latestProbability,
            unsupportedReason: nil
        )
        cachedMatchupProbabilityTimelines[timelineCacheKey] = (revision, timeline)
        return timeline
    }

    /// Replays authoritative scoring at the same through-hole checkpoints. This remains useful
    /// for shared/custom formats where Monte Carlo win odds are intentionally unsupported.
    func matchupScoreTimeline(
        for matchup: TeamMatchup,
        scoreBasis: ScoreBasis
    ) -> [MatchupScoreTrendPoint] {
        let sideIDs = matchup.pairingIDs()
        guard sideIDs.count >= 2 else { return [] }

        let participantIDs = Set(sideIDs.flatMap {
            matchupSideParticipants(scoringUnitID: $0, matchup: matchup).map(\.id)
        })
        let directScoreIDs = sideIDs.reduce(into: Set<String>()) { ids, sideID in
            ids.formUnion(liveMatchupDirectScoreLookupIDs(sideID: sideID, matchup: matchup))
        }
        let relevantEntries = snapshot.scoring.filter { entry in
            entry.hasRecordedScore
                && (
                    directScoreIDs.contains(entry.scoringUnitID)
                        || entry.participantIDs.contains { participantIDs.contains($0) }
                )
        }
        let checkpoints = Set(relevantEntries.map(matchupTimelinePosition(for:))).sorted()
        guard checkpoints.isPopulated else { return [] }

        let segment = snapshot.segments.first {
            $0.matchups?.contains(where: { $0.id == matchup.id }) == true
        } ?? snapshot.roundSegment ?? RoundSegment()
        let holes = snapshot.defaultTee?.holes ?? []
        let scoreLookupIDs = snapshot.segmentScoreLookupSegmentIDs
        var points: [MatchupScoreTrendPoint] = []

        for checkpoint in checkpoints {
            var checkpointSnapshot = snapshot
            checkpointSnapshot.scoring = snapshot.scoring.filter { entry in
                guard entry.hasRecordedScore else { return false }
                return matchupTimelinePosition(for: entry) <= checkpoint
            }
            let result = ScoringEngine.computeSnapshotResult(
                snapshot: checkpointSnapshot,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                scoreLookupSegmentIDs: scoreLookupIDs.isEmpty ? nil : scoreLookupIDs
            )
            let presentation: MatchupResultPresentation
            if let matchupResult = result.matchupResults.first(where: { $0.matchup.id == matchup.id }) {
                presentation = MatchupResultPresentationBuilder.build(
                    snapshot: checkpointSnapshot,
                    result: result,
                    matchupResult: matchupResult,
                    basis: scoreBasis
                )
            } else {
                presentation = MatchupResultPresentationBuilder.build(
                    snapshot: checkpointSnapshot,
                    result: result,
                    section: MatchupLeaderboardSection(
                        id: matchup.id,
                        matchup: matchup,
                        name: "Matchup",
                        rows: []
                    ),
                    basis: scoreBasis
                )
            }
            guard let leftTotal = presentation.side(id: sideIDs[0])?.total,
                  let rightTotal = presentation.side(id: sideIDs[1])?.total else { continue }
            let advantage = presentation.isPointsFormat
                ? leftTotal - rightTotal
                : rightTotal - leftTotal
            points.append(.init(
                holesCompleted: checkpoint,
                leftTotal: leftTotal,
                rightTotal: rightTotal,
                leftAdvantage: advantage
            ))
        }

        return points
    }

    /// Results safe to show outside the Live Round screen. The screen has its own loading
    /// placeholder, but Watch and Activity must never publish an old value with a new score.
    var publishableMatchupProbabilities: [String: MatchupProbability] {
        guard predictionContextRoundID == snapshot.round.id else { return [:] }
        return Dictionary(uniqueKeysWithValues: (snapshot.roundSegment?.matchups ?? []).compactMap {
            matchup -> (String, MatchupProbability)? in
            let matchupID = matchup.id
            guard !loadingMatchupProbabilityIDs.contains(matchupID),
                  matchupProbabilityResultRevisions[matchupID]
                    == matchupProbabilityRevision(for: matchup),
                  let probability = matchupProbabilities[matchupID],
                  probability.scoreBasis == matchupProbabilityScoreBasis else {
                return nil
            }
            return (matchupID, probability)
        })
    }

    @discardableResult
    private func scheduleMatchupProbabilityRefresh() -> Task<Void, Never>? {
        guard isMatchupProbabilityPrecomputationEnabled else { return nil }

        if matchupProbabilityRoundID != snapshot.round.id {
            matchupProbabilityTask?.cancel()
            matchupProbabilityTask = nil
            matchupProbabilityTaskRevision = nil
            matchupProbabilityResultRevisions = [:]
            matchupProbabilities = [:]
            loadingMatchupProbabilityIDs = []
            matchupProbabilityRoundID = snapshot.round.id
        }

        // Historical series results are prediction inputs. Computing before their asynchronous
        // load finishes creates a transient, different set of odds on companion surfaces.
        guard predictionContextRoundID == snapshot.round.id else { return nil }

        let expectedMode = snapshot.expectedMatchupMode
        let validMatchups = (snapshot.roundSegment?.matchups ?? []).filter {
            $0.effectiveMode == expectedMode && $0.isValid
        }
        guard shouldShowMatchupProbabilities,
              snapshot.configuration.resolvedCompetitionScope == .matchup,
              validMatchups.isPopulated else {
            matchupProbabilityTask?.cancel()
            matchupProbabilityTask = nil
            matchupProbabilityTaskRevision = nil
            matchupProbabilityResultRevisions = [:]
            matchupProbabilities = [:]
            loadingMatchupProbabilityIDs = []
            return nil
        }

        let validMatchupIDs = Set(validMatchups.map(\.id))
        matchupProbabilities = matchupProbabilities.filter { validMatchupIDs.contains($0.key) }
        matchupProbabilityResultRevisions = matchupProbabilityResultRevisions.filter {
            validMatchupIDs.contains($0.key)
        }
        loadingMatchupProbabilityIDs.formIntersection(validMatchupIDs)

        let currentRevisions = Dictionary(uniqueKeysWithValues: validMatchups.map {
            ($0.id, matchupProbabilityRevision(for: $0))
        })
        let targetRevisions = currentRevisions.filter {
            matchupProbabilityResultRevisions[$0.key] != $0.value
        }
        guard targetRevisions.isPopulated else {
            matchupProbabilityTask?.cancel()
            matchupProbabilityTask = nil
            matchupProbabilityTaskRevision = nil
            loadingMatchupProbabilityIDs = []
            return nil
        }

        let revisionValue = targetRevisions
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        let taskRevision = String(ProjectionSeed.make(revisionValue), radix: 16)
        if matchupProbabilityTaskRevision == taskRevision {
            return matchupProbabilityTask
        }

        matchupProbabilityTask?.cancel()
        matchupProbabilityTaskRevision = taskRevision
        loadingMatchupProbabilityIDs = Set(targetRevisions.keys)

        let task = Task(priority: .utility) { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                self?.finishMatchupProbabilityTask(
                    revision: taskRevision,
                    targetIDs: Set(targetRevisions.keys)
                )
                return
            }
            guard let self else { return }
            await self.computeMatchupProbabilities(targetRevisions: targetRevisions)
            self.finishMatchupProbabilityTask(
                revision: taskRevision,
                targetIDs: Set(targetRevisions.keys)
            )
        }
        matchupProbabilityTask = task
        return task
    }

    private func finishMatchupProbabilityTask(revision: String, targetIDs: Set<String>) {
        guard matchupProbabilityTaskRevision == revision else { return }
        matchupProbabilityTask = nil
        matchupProbabilityTaskRevision = nil
        loadingMatchupProbabilityIDs.subtract(targetIDs)
    }

    private func computeMatchupProbabilities(targetRevisions: [String: String]) async {
        guard !Task.isCancelled else { return }
        let probabilityBasis = matchupProbabilityScoreBasis
        let template = snapshot.resolvedActiveTemplate
        guard template.inputMode == .strokes, template.scoreSource == .individual else {
            for (matchupID, revision) in targetRevisions {
                applyMatchupProbability(
                    .unsupported(
                        matchupID: matchupID,
                        scoreBasis: probabilityBasis,
                        reason: "Odds aren’t available for custom or shared-score formats."
                    ),
                    matchupID: matchupID,
                    revision: revision,
                    scoreBasis: probabilityBasis
                )
            }
            return
        }

        let matchupsByID = Dictionary(uniqueKeysWithValues: (snapshot.roundSegment?.matchups ?? []).map {
            ($0.id, $0)
        })
        let eligibleParticipantIDs = Set(ScoringEngine.scoringEligibleParticipants(
            snapshot.participants,
            substitutesScore: snapshot.configuration.substitutesScore,
            attendanceConfirmationEnabled: snapshot.configuration.attendanceConfirmationEnabled == true
        ).map(\.id))

        let targetMatchups = targetRevisions.keys.compactMap { matchupID -> TeamMatchup? in
            guard let matchup = matchupsByID[matchupID],
                  let revision = targetRevisions[matchupID],
                  matchupProbabilityRevision(for: matchup, scoreBasis: probabilityBasis) == revision else {
                return nil
            }
            return matchup
        }
        guard targetMatchups.isPopulated else { return }

        let participants = targetMatchups
            .flatMap { matchup in
                matchup.pairingIDs()
                .flatMap { matchupSideParticipants(scoringUnitID: $0, matchup: matchup) }
            }
            .filter { eligibleParticipantIDs.contains($0.id) }
            .reduce(into: [String: RoundParticipant]()) { result, participant in
                result[participant.id] = participant
            }
            .values
            .sorted { $0.id < $1.id }
        let participantIDs = Set(participants.map(\.id))
        var simulations: [String: PlayerProjectionSimulation] = [:]
        for participant in participants {
            if Task.isCancelled { return }
            simulations[participant.id] = await playerSimulation(
                for: participant,
                scoreBasis: probabilityBasis
            )
        }
        guard !Task.isCancelled else { return }

        let currentMatchupIDs = Set(targetMatchups.compactMap { matchup -> String? in
            guard let revision = targetRevisions[matchup.id],
                  matchupProbabilityRevision(for: matchup, scoreBasis: probabilityBasis) == revision else {
                return nil
            }
            return matchup.id
        })
        guard currentMatchupIDs.isPopulated else { return }
        let batchRevision = currentMatchupIDs.sorted().compactMap { matchupID in
            targetRevisions[matchupID].map { "\(matchupID):\($0)" }
        }.joined(separator: "|")

        do {
            let values = try await MatchupProbabilitySimulator.shared.simulate(
                snapshot: snapshot,
                scoreBasis: probabilityBasis,
                playerSimulations: simulations,
                matchupIDs: currentMatchupIDs,
                participantIDs: participantIDs,
                cacheKey: "matchup-batch|\(batchRevision)"
            )
            guard !Task.isCancelled else { return }
            for matchupID in currentMatchupIDs {
                guard let revision = targetRevisions[matchupID],
                      let probability = values[matchupID] else { continue }
                applyMatchupProbability(
                    probability,
                    matchupID: matchupID,
                    revision: revision,
                    scoreBasis: probabilityBasis
                )
            }
        } catch {
            guard !(error is CancellationError) else { return }
            for matchupID in currentMatchupIDs {
                matchupProbabilities[matchupID] = nil
                loadingMatchupProbabilityIDs.remove(matchupID)
            }
        }
    }

    private func applyMatchupProbability(
        _ probability: MatchupProbability,
        matchupID: String,
        revision: String,
        scoreBasis: ScoreBasis
    ) {
        guard scoreBasis == matchupProbabilityScoreBasis,
              probability.scoreBasis == scoreBasis,
              let matchup = snapshot.roundSegment?.matchups?.first(where: { $0.id == matchupID }),
              matchupProbabilityRevision(for: matchup, scoreBasis: scoreBasis) == revision else {
            return
        }
        matchupProbabilities[matchupID] = probability
        matchupProbabilityResultRevisions[matchupID] = revision
        loadingMatchupProbabilityIDs.remove(matchupID)
    }

    func playerSimulation(
        for participant: RoundParticipant,
        scoreBasis: ScoreBasis
    ) async -> PlayerProjectionSimulation? {
        let revision = playerProjectionRevision(for: participant, scoreBasis: scoreBasis)
        let cacheKey = "\(snapshot.round.id)|\(participant.id)|\(scoreBasis.rawValue)"
        if let cached = cachedPlayerSimulations[cacheKey], cached.revision == revision {
            return cached.simulation
        }
        guard let input = projectionInput(for: participant, scoreBasis: scoreBasis) else { return nil }

        do {
            let seed = ProjectionSeed.make(playerProjectionScenarioRevision(for: participant))
            let result = try await RoundProjectionSimulator.shared.simulate(
                input: input,
                iterations: Self.liveProjectionIterationCount,
                seed: seed,
                cacheKey: "player|\(revision)",
                retainsDiagnosticScenarios: false
            )
            guard let currentParticipant = snapshot.participants.first(where: { $0.id == participant.id }),
                  revision == playerProjectionRevision(for: currentParticipant, scoreBasis: scoreBasis),
                  !Task.isCancelled else { return nil }
            cachedPlayerSimulations[cacheKey] = (revision, result)
            return result
        } catch {
            return nil
        }
    }

    private func projectionInput(
        for participant: RoundParticipant,
        scoreBasis: ScoreBasis,
        recordedHoleNumbers: Set<Int>? = nil
    ) -> PlayerProjectionInput? {
        guard snapshot.resolvedActiveTemplate.inputMode == .strokes,
              snapshot.resolvedActiveTemplate.scoreSource == .individual else {
            return nil
        }
        let tee = snapshot.tees.first(where: { $0.id == participant.teeBoxID }) ?? snapshot.defaultTee
        guard let tee else { return nil }

        let memberID = participant.seriesMemberID ?? participant.substituteForSeriesMemberID
        let courseID = currentPredictionCourseID
        let playedHoleNumbers = courseOrderHoleNumbers
        let historicalContexts = liveSeriesScoreboardContext?.canonicalResults
            .filter { $0.linkedRoundID != snapshot.round.id }
            .compactMap { result -> (resultID: String, context: SeriesRoundPredictionContext)? in
                guard let context = result.predictionContext else { return nil }
                return (result.id, context)
            } ?? []
        let currentRoundSamples = playedHoleNumbers.compactMap {
            holeNumber -> (sourceID: String, par: Int, relative: Int)? in
            guard recordedHoleNumbers?.contains(holeNumber) ?? true else { return nil }
            guard let hole = tee.holes.first(where: { $0.number == holeNumber }),
                  let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else { return nil }
            return (
                "current:\(snapshot.round.id):\(participant.id):\(holeNumber)",
                hole.par,
                gross - hole.par
            )
        }

        let holes = playedHoleNumbers.compactMap { holeNumber -> ProjectionHoleInput? in
            guard let hole = tee.holes.first(where: { $0.number == holeNumber }) else { return nil }
            let usesRecordedScore = recordedHoleNumbers?.contains(holeNumber) ?? true
            var samples: [ProjectionHistoricalSample] = []
            for historicalContext in historicalContexts {
                let context = historicalContext.context
                for (sampleIndex, sample) in context.holeSamples.enumerated() {
                    let weight: Double
                    if sample.seriesMemberID == memberID,
                       context.courseID == courseID,
                       sample.teeBoxID == tee.id,
                       sample.holeNumber == holeNumber {
                        weight = 8
                    } else if sample.seriesMemberID == memberID,
                              context.courseID == courseID,
                              sample.holeNumber == holeNumber {
                        weight = 5
                    } else if sample.seriesMemberID == memberID, sample.par == hole.par {
                        weight = 3
                    } else if context.courseID == courseID, sample.holeNumber == holeNumber {
                        weight = 2
                    } else {
                        continue
                    }
                    samples.append(.init(
                        sourceID: "\(historicalContext.resultID):\(sampleIndex)",
                        grossRelativeToPar: sample.grossStrokes - sample.par,
                        weight: weight
                    ))
                }
            }
            samples.append(contentsOf: currentRoundSamples
                .filter { $0.par == hole.par }
                .map {
                    .init(
                        sourceID: $0.sourceID,
                        grossRelativeToPar: $0.relative,
                        weight: 3
                    )
                })

            let strokesReceived = ScoringEngine.strokesReceived(
                handicap: participant.lockedHandicapAllowance,
                holeNumber: holeNumber,
                holes: tee.holes,
                playedHoleNumbers: playedHoleNumbers,
                useHandicaps: snapshot.configuration.useHandicaps,
                handicapStrokeBasis: snapshot.handicapStrokeBasis
            )
            return ProjectionHoleInput(
                holeNumber: holeNumber,
                par: hole.par,
                strokesReceived: strokesReceived,
                recordedGross: usesRecordedScore
                    ? grossStrokes(for: participant.id, holeNumber: holeNumber)
                    : nil,
                isUnresolvedPickup: usesRecordedScore
                    && scoreEntry(for: participant.id, holeNumber: holeNumber)?.pickedUp == true
                    && grossStrokes(for: participant.id, holeNumber: holeNumber) == nil,
                historicalSamples: samples
            )
        }
        guard holes.isPopulated else { return nil }
        return PlayerProjectionInput(
            participantID: participant.id,
            scoreBasis: scoreBasis,
            handicapAllowance: participant.lockedHandicapAllowance,
            holes: holes
        )
    }

    private func matchupTimelineRecordedHoleNumbers(
        for participant: RoundParticipant
    ) -> Set<Int> {
        Set(courseOrderHoleNumbers.filter { holeNumber in
            scoreEntry(for: participant.id, holeNumber: holeNumber)?.hasRecordedScore == true
        })
    }

    private func matchupTimelinePlayOrder(
        for participant: RoundParticipant
    ) -> [Int] {
        let course = courseOrderHoleNumbers
        guard let groupID = participant.groupID,
              let group = snapshot.teeGroups.first(where: { $0.id == groupID }) else {
            return course
        }
        return LiveRoundHoleOrdering.playOrderedHoleNumbers(
            course: course,
            startingHole: group.startingHole
        )
    }

    private func matchupTimelinePosition(for entry: ScoreEntry) -> Int {
        let entryParticipantIDs = Set(entry.participantIDs + [entry.scoringUnitID])
        let participantPositions = snapshot.participants.compactMap { participant -> Int? in
            guard entryParticipantIDs.contains(participant.id) else { return nil }
            return matchupTimelinePlayOrder(for: participant)
                .firstIndex(of: entry.holeNumber)
                .map { $0 + 1 }
        }
        if let position = participantPositions.min() {
            return position
        }

        if let group = snapshot.teeGroups.first(where: { $0.id == entry.groupID }),
           let index = LiveRoundHoleOrdering.playOrderedHoleNumbers(
            course: courseOrderHoleNumbers,
            startingHole: group.startingHole
           ).firstIndex(of: entry.holeNumber) {
            return index + 1
        }

        return courseOrderHoleNumbers.firstIndex(of: entry.holeNumber).map { $0 + 1 } ?? 0
    }

    private func unresolvedPickupHoleNumbers(for participant: RoundParticipant) -> Set<Int> {
        Set(courseOrderHoleNumbers.filter { holeNumber in
            guard scoreEntry(for: participant.id, holeNumber: holeNumber)?.pickedUp == true else {
                return false
            }
            return grossStrokes(for: participant.id, holeNumber: holeNumber) == nil
        })
    }

    private var currentPredictionCourseID: String? {
        guard let course = snapshot.courseInfo else { return nil }
        if course.id.isPopulated { return course.id }
        if let externalID = course.golfCourseApiID { return "golf-course-api:\(externalID)" }
        let normalized = course.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return normalized.isPopulated ? "course-name:\(normalized)" : nil
    }

    private func refreshSeriesScoreboardProjection() {
        guard isOverviewVisible else { return }
        guard let context = liveSeriesScoreboardContext,
              context.series.settings.showScoreboardTile,
              SeriesScoreboardEligibility.isEligible(teams: context.teams) else {
            seriesScoreboardSnapshot = nil
            return
        }

        let projectedAwards = projectedSeriesPointAwards(using: context)
        let officialAwards: [SeriesPointAward]
        if projectedAwards.isPopulated, let currentRoundID = context.currentSeriesRound?.id {
            officialAwards = context.pointAwards.filter { $0.seriesRoundID != currentRoundID }
        } else {
            officialAwards = context.pointAwards
        }

        seriesScoreboardSnapshot = SeriesScoreboardCalculator.snapshot(
            series: context.series,
            rounds: context.rounds,
            scoringProfiles: context.scoringProfiles,
            pointAwards: officialAwards,
            teams: context.teams,
            members: context.members,
            projectedAwards: projectedAwards
        )
    }

    private func projectedSeriesPointAwards(using context: LiveSeriesScoreboardContext) -> [SeriesPointAward] {
        guard let seriesRound = context.currentSeriesRound,
              seriesRound.awardsStatus != .finalized else { return [] }

        let profilesByID = Dictionary(uniqueKeysWithValues: context.scoringProfiles.map { ($0.id, $0) })
        var awards: [SeriesPointAward] = []
        var individualAwards: [SeriesPointAward] = []

        if let profileID = seriesRound.individualScoringProfileID,
           let profile = profilesByID[profileID] {
            individualAwards = projectedAwards(
                for: seriesRound,
                profile: profile,
                awardTrack: .individual,
                context: context
            )
            awards.append(contentsOf: individualAwards)
        }

        if let profileID = seriesRound.teamScoringProfileID,
           let profile = profilesByID[profileID] {
            if profile.kind == .accrueFromIndividual || profile.outcomeSource == .individualAwardsAggregateToTeam {
                awards.append(contentsOf: SeriesViewModel.buildAccruedTeamAwards(
                    seriesRoundID: seriesRound.id,
                    profile: profile,
                    individualAwards: individualAwards,
                    members: context.members,
                    teams: context.teams,
                    seriesID: context.series.id,
                    awardedByMemberID: nil
                ))
            } else {
                awards.append(contentsOf: projectedAwards(
                    for: seriesRound,
                    profile: profile,
                    awardTrack: .team,
                    context: context
                ))
            }
        }

        return awards
    }

    private func projectedAwards(
        for seriesRound: SeriesRound,
        profile: SeriesScoringProfile,
        awardTrack: SeriesAwardTrack,
        context: LiveSeriesScoreboardContext
    ) -> [SeriesPointAward] {
        guard profile.kind != .manual,
              profile.outcomeSource == .roundMatchResult else { return [] }

        let result = engineResult
        guard result.matchupResults.isPopulated else { return [] }
        let isDirectHolePoints = seriesRound.roundConfig.matchupScoringStyle == .holeByHolePoints
        let now = Time()
        var awards: [SeriesPointAward] = []

        for matchupResult in result.matchupResults {
            let rows = matchupResult.rows
            guard rows.contains(where: { $0.holesPlayed > 0 || abs($0.total) > 0.000_001 }) else { continue }
            let highestWins = matchupResult.isPointsFormat ?? (result.template.leaderboardSort == .highestWins)
            let minimumStatus = shouldResolveMinimumCountResult(matchupResult.minimumCountStatus)
                ? matchupResult.minimumCountStatus
                : nil
            let resolvedRows = SeriesViewModel.resolvedMatchupAwardRows(
                rows,
                matchup: matchupResult.matchup,
                status: minimumStatus,
                highestWins: highestWins,
                snapshot: snapshot,
                mappings: context.currentRoundMappings,
                members: context.members
            )
            let sortedRows = resolvedRows.rows
            let isMinimumCountTie = resolvedRows.isMinimumCountTie
            guard let first = sortedRows.first else { continue }
            let isTie = SeriesViewModel.isMatchupAwardTie(sortedRows, isMinimumCountTie: isMinimumCountTie)
            let tieGroupSize = isTie ? sortedRows.count : 1

            for row in sortedRows {
                let placement = isTie ? 1 : (row.scoringUnitID == first.scoringUnitID ? 1 : 2)
                let basePoints: Double
                if isDirectHolePoints {
                    basePoints = row.total
                } else {
                    basePoints = liveResolvePoints(
                        placement: placement,
                        tieGroupSize: tieGroupSize,
                        profile: profile
                    ) ?? 0
                }

                let matchWinnerBonus: Double = {
                    guard isDirectHolePoints, placement == 1 else { return 0 }
                    let bonus = seriesRound.roundConfig.resolvedMatchWinnerBonusPoints
                    guard bonus > 0 else { return 0 }
                    return tieGroupSize > 1 ? bonus / Double(tieGroupSize) : bonus
                }()
                let participationBonus = profile.bonusRules
                    .filter { $0.isEnabled && $0.type == .participation }
                    .reduce(0.0) { $0 + $1.points }
                let bonusPoints = matchWinnerBonus + participationBonus
                let total = basePoints + bonusPoints
                let competitorType: SeriesCompetitorType = awardTrack == .team ? .team : .member
                let mappedCompetitors = liveMappedSeriesCompetitors(
                    row: row,
                    competitorType: competitorType,
                    mappings: context.currentRoundMappings,
                    context: context
                )

                for competitor in mappedCompetitors {
                    awards.append(SeriesPointAward(
                        id: "projected_\(seriesRound.id)_\(awardTrack.rawValue)_\(matchupResult.matchup.id)_\(competitor.id)",
                        seriesRoundID: seriesRound.id,
                        awardTrack: awardTrack,
                        competitorType: competitorType,
                        competitorID: competitor.id,
                        competitorName: competitor.name,
                        profileKind: profile.kind,
                        placement: placement,
                        tieGroupSize: isTie ? sortedRows.count : nil,
                        basePoints: basePoints,
                        bonusPoints: bonusPoints,
                        totalPoints: total,
                        source: .automatic,
                        roundOwnerID: row.scoringUnitID,
                        reason: "Live projection",
                        awardedAt: now,
                        createdAt: now,
                        lastUpdatedAt: now,
                        parentID: context.series.id
                    ))
                }
            }
        }

        return awards
    }

    private func liveResolvePoints(
        placement: Int,
        tieGroupSize: Int,
        profile: SeriesScoringProfile
    ) -> Double? {
        func placementPoints(at rank: Int) -> Double {
            profile.placementRules.first(where: { rank >= $0.rankStart && rank <= $0.rankEnd })?.points ?? 0
        }

        switch profile.kind {
        case .placement:
            let occupiedRanks = Array(placement..<(placement + max(1, tieGroupSize)))
            let total = occupiedRanks.reduce(0.0) { $0 + placementPoints(at: $1) }
            return total / Double(max(1, tieGroupSize))
        case .winTieLoss:
            guard let resultPoints = profile.resultPoints else { return 0 }
            if tieGroupSize > 1 { return resultPoints.tiePoints }
            return placement == 1 ? resultPoints.winPoints : resultPoints.lossPoints
        case .accrueFromIndividual, .manual:
            return nil
        }
    }

    private func liveMappedSeriesCompetitors(
        row: ScoringRow,
        competitorType: SeriesCompetitorType,
        mappings: [SeriesRoundMapping],
        context: LiveSeriesScoreboardContext
    ) -> [(id: String, name: String)] {
        let ownerType = liveRoundOwnerType(for: row.owner)
        let mapped = mappings.filter {
            $0.roundOwnerID == row.scoringUnitID
                && $0.roundOwnerType == ownerType
                && $0.competitorType == competitorType
        }

        if mapped.isPopulated {
            return mapped.map { mapping in
                (mapping.competitorID, liveCompetitorName(for: mapping.competitorID, type: competitorType, context: context))
            }
        }

        switch competitorType {
        case .team:
            let teamID: String? = {
                switch row.owner {
                case .team:
                    return row.scoringUnitID
                case .scoreOwner:
                    return snapshot.scoringGroup(id: row.scoringUnitID)?.teamID
                case .participant:
                    return snapshot.participants.first(where: { $0.id == row.scoringUnitID })?.teamID
                }
            }()
            guard let teamID, teamID.isPopulated else { return [] }
            return [(teamID, liveCompetitorName(for: teamID, type: .team, context: context))]
        case .member:
            return row.participantIDs.compactMap { participantID in
                guard let participant = snapshot.participants.first(where: { $0.id == participantID }) else { return nil }
                let memberID = participant.seriesMemberID
                    ?? context.members.first(where: { $0.playerID == participant.playerID })?.id
                    ?? participantID
                return (memberID, liveCompetitorName(for: memberID, type: .member, context: context))
            }
        }
    }

    private func liveRoundOwnerType(for owner: ScoringOwner) -> SeriesRoundOwnerType {
        switch owner {
        case .participant: return .participant
        case .team: return .team
        case .scoreOwner: return .scoreOwner
        }
    }

    private func liveCompetitorName(
        for competitorID: String,
        type: SeriesCompetitorType,
        context: LiveSeriesScoreboardContext
    ) -> String {
        switch type {
        case .team:
            return context.teams.first(where: { $0.id == competitorID })?.name
                ?? snapshot.teams.first(where: { $0.id == competitorID })?.name
                ?? "Team"
        case .member:
            return context.members.first(where: { $0.id == competitorID })?.name.fullName
                ?? snapshot.participants.first(where: { $0.seriesMemberID == competitorID })?.name.fullName
                ?? "Player"
        }
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
        let userID = actualParticipant?.userID ?? user?.id
        let playerID = actualParticipant?.playerID ?? primaryPlayer?.id
        return (userID, playerID)
    }

    private func scheduleInitialHoleNudgeIfNeeded() {
        guard !hasPerformedInitialHoleNudge else { return }
        guard activeTeeGroupParticipants.isPopulated else { return }

        // Reserve once; a restored/user-selected hole cancels this delayed suggestion.
        hasPerformedInitialHoleNudge = true
        let roundID = snapshot.round.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
            guard self.restoredHole == nil, self.snapshot.round.id == roundID else { return }
            self.navigateToNextUnscoredHole()
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
            let maxRelative = maxScoreRule.friendlyMaxRelativeValue(for: par)
            for participant in players {
                let isScored = scoreEntry(for: participant.id, holeNumber: holeNumber).map {
                    $0.hasRecordedScore
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
                if isFriendlyScoreInputMode {
                    entry.strokes = nil
                    entry.relativeToPar = maxRelative
                    entry.entryMode = .relativeToPar
                } else {
                    entry.strokes = max
                    entry.relativeToPar = nil
                    entry.entryMode = .strokes
                }

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
            if let firstScoredAt = entriesToWrite.map(\.createdAt).min(by: { $0.unix < $1.unix }) {
                await roundSession.markFirstScoredIfNeeded(at: firstScoredAt)
            }
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
        relativeToPar: Int? = nil,
        emitHoleTransition: Bool = true
    ) {
        let participantHolesScoredCount = holesPlayedCount(for: participant.id, in: afterSnapshot)
        let totalHoles = holeNumbers(in: afterSnapshot).count
        let participantCompletionPct = TelemetryEventProps.completionPercentage(
            completedCount: participantHolesScoredCount,
            totalCount: totalHoles
        )
        let entryParticipantID = actualParticipant?.id ?? participant.id
        let scoreEntryMode: ScoreEntryMode = relativeToPar == nil ? .strokes : .relativeToPar
        let friendlyLabel = relativeToPar.map {
            friendlyScoreLabel(
                relativeToPar: $0,
                par: hole(for: holeNumber, teeID: participant.teeBoxID)?.par ?? 4,
                format: .full
            )
        }

        addEvent(
            "live_round.score_saved",
            eventProps: TelemetryEventProps.scoring(
                snapshot: afterSnapshot,
                participant: participant,
                entryParticipantID: entryParticipantID,
                holeNumber: holeNumber,
                strokes: strokes,
                entryMethod: entryMethod,
                scoreEntryMode: scoreEntryMode,
                friendlyRelativeToPar: relativeToPar,
                friendlyScoreLabel: friendlyLabel,
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
