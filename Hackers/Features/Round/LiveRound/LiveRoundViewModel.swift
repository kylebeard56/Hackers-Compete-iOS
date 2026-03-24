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
    
    // MARK: - State
    
    @Published private(set) var snapshot: RoundSnapshot = .init()
    @Published private(set) var currentParticipantID: String?
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
    
    // MARK: - Wiring
    
    private weak var appSession: AppSession?
    private weak var roundSession: RoundSession?
    private var cancellables: Set<AnyCancellable> = []
    
    /// O(1) lookup by (participantID, holeNumber). Rebuilt when snapshot changes.
    private var scoreIndex: [String: ScoreEntry] = [:]
    /// Cached engine result, invalidated when snapshot changes.
    private var cachedEngineResult: ScoringResult?
    private var hasPerformedInitialHoleNudge = false
    
    func bind(appSession: AppSession, roundSession: RoundSession) {
        // Avoid duplicate bindings
        if self.roundSession === roundSession { return }
        
        self.appSession = appSession
        self.roundSession = roundSession
        self.isSpectator = appSession.isSpectating
        
        snapshot = roundSession.snapshot
        lastSnapshotReceivedAt = roundSession.lastSnapshotReceivedAt
        rebuildScoreIndex()
        
        if snapshot.configuration.useHandicaps {
            scoreBasis = .net
        }
        
        roundSession.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                guard let self else { return }
                let currentHole = self.currentHoleNumber
                let wasIncomplete = self.holeCompletionProgress(holeNumber: currentHole) < 1

                self.snapshot = s
                self.rebuildScoreIndex()
                self.ensureHoleIndexInBounds()
                self.updateSelectedTeeIfNeeded()

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
                    await self.resolveCurrentParticipantIDIfNeeded()
                    if !self.hasPerformedInitialHoleNudge && self.teeGroupParticipants.isPopulated {
                        //try? await Task.sleep(for: .seconds(2.0))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                            self.navigateToNextUnscoredHole()
                            self.hasPerformedInitialHoleNudge = true
                        })
                    }
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
        
        Task { await resolveCurrentParticipantIDIfNeeded() }
    }
    
    func ensureParticipantResolved() async {
        await resolveCurrentParticipantIDIfNeeded()
    }

    func set(snapshot: RoundSnapshot) {
        self.snapshot = snapshot
        rebuildScoreIndex()
        if !hasInitializedVisibilitySelection && visibleParticipantIDs.isEmpty && !snapshot.participants.isEmpty {
            visibleParticipantIDs = Set(snapshot.participants.map(\.id))
            lastAppliedVisibleParticipantIDs = visibleParticipantIDs
            hasInitializedVisibilitySelection = true
        }
    }
    
    // MARK: - Holes
    
    var holeNumbers: [Int] {
        let r = snapshot.holeRange ?? HoleRange(startHole: 1, endHole: 18)
        let lo = max(1, r.startHole)
        let hi = max(lo, min(18, r.endHole == 0 ? 18 : r.endHole))
        return Array(lo...hi)
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
        let players = teeGroupParticipants
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
        if holeNumber < current { return .error }
        return .unscored
    }
    
    private func ensureHoleIndexInBounds() {
        let maxIdx = max(0, holeNumbers.count - 1)
        currentHoleIndex = min(max(0, currentHoleIndex), maxIdx)
    }
    
    // MARK: - Tee Group
    
    var currentParticipant: RoundParticipant? {
        guard let id = currentParticipantID else { return nil }
        return snapshot.participants.first(where: { $0.id == id })
    }
    
    var currentTeeGroupID: String? { currentParticipant?.groupID }
    
    var teeGroupParticipants: [RoundParticipant] {
        guard let groupID = currentTeeGroupID else { return [] }
        return snapshot.participants
            .filter { $0.groupID == groupID }
            .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
    }

    struct TeamSection: Identifiable {
        let id: String
        let team: RoundTeam?
        let participants: [RoundParticipant]
    }
    
    func team(for participant: RoundParticipant) -> RoundTeam? {
        guard let id = participant.teamID else { return nil }
        return snapshot.teams.first(where: { $0.id == id })
    }
    
    func teamColor(for participant: RoundParticipant) -> Color? {
        team(for: participant)?.teamColor.value
    }
    
    /// True when any team's color matches the theme color (e.g. Purple team + purple theme).
    /// Use palette.foregroundColor for general UI in this case to avoid confusing team-specific vs neutral actions.
    var hasTeamColorMatchingTheme: Bool {
        guard snapshot.requiresTeams, snapshot.teams.isPopulated else { return false }
        return snapshot.teams.contains { $0.teamColor.value == theme.color }
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
        holeNumbers.filter { hole in
            guard let e = scoreEntry(for: participantID, holeNumber: hole) else { return false }
            return e.strokes != nil || e.pickedUp
        }.count
    }

    func holeCompletionProgress(holeNumber: Int) -> Double {
        let players = teeGroupParticipants
        guard players.isPopulated else { return 0 }
        
        let completed = players.filter { p in
            guard let e = scoreEntry(for: p.id, holeNumber: holeNumber) else { return false }
            return e.strokes != nil || e.pickedUp
        }.count
        
        return Double(completed) / Double(players.count)
    }
    
    // MARK: - Handicap / Net
    
    func strokesReceivedOnHole(participant: RoundParticipant, holeNumber: Int) -> Int {
        guard snapshot.configuration.useHandicaps else { return 0 }
        let hcp = max(0, participant.adjustedHandicap)
        guard hcp > 0 else { return 0 }
        
        guard let holeHcp = hole(for: holeNumber)?.handicap else { return 0 }
        guard holeHcp > 0 else { return 0 }
        
        let full = hcp / 18
        let rem = hcp % 18
        let extra = (rem > 0 && holeHcp <= rem) ? 1 : 0
        return full + extra
    }
    
    func netStrokesOnHole(participant: RoundParticipant, holeNumber: Int) -> Int? {
        guard let gross = grossStrokes(for: participant.id, holeNumber: holeNumber) else { return nil }
        let received = strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
        return max(0, gross - received)
    }
    
    // MARK: - Aggregates (Stroke play MVP)
    
    func scoreToPar(for participant: RoundParticipant, basis: ScoreBasis) -> Int {
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
    /// Phase 0: returns true for all (best ball); best-n refinement later.
    func doesParticipantScoreCount(participantID: String, teamID: String, matchup: TeamMatchup) -> Bool {
        // TODO: For best 2 of 4, compute per-hole which 2 counted. For now assume all contribute.
        return true
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

    /// Subtitle explaining the rank selection (e.g. "Best 2 of 4") when format has configurable best N. Nil when not applicable.
    var leaderboardRankSelectionSubtitle: String? {
        let template = snapshot.resolvedActiveTemplate
        guard template.pipeline.contains(where: { if case .select = $0 { return true }; return false }) else { return nil }
        if snapshot.configuration.bestWorstEnabled == true {
            return "Best / Worst"
        }
        let bestN: Int
        if let n = snapshot.configuration.bestNSelected, n > 0 {
            bestN = n
        } else if let ranks = template.pipeline.compactMap({ stage -> [Int]? in
            if case .select(let sel) = stage { return sel.includeRanks }; return nil
        }).first, !ranks.isEmpty {
            bestN = ranks.count
        } else {
            return nil
        }
        let maxSize = template.requirements.teamSize?.maxTeamSize ?? bestN
        return bestN == 1 ? "Best 1" : "Best \(bestN) of \(maxSize)"
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
        let rows: [LeaderboardRow]
    }
    
    var availableLeaderboardModes: [LeaderboardMode] {
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

        init(
            participant: RoundParticipant,
            thru: Int,
            scoreToPar: Int,
            totalPoints: Double? = nil,
            isPinned: Bool,
            placeLabel: String,
            teamID: String? = nil,
            teamName: String? = nil,
            teamColor: Color? = nil
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
        }
    }
    
    /// Rows to display in the leaderboard; switches between stroke play and format-specific based on selected chip.
    var effectiveLeaderboardRows: [LeaderboardRow] {
        effectiveLeaderboardChip == .strokes ? leaderboardRows : engineLeaderboardRows
    }

    var leaderboardRows: [LeaderboardRow] {
        let basis = scoreBasis
        let baseRows = snapshot.participants.map { p in
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
                color: team.teamColor.value,
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
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return GroupedLeaderboardSection(
            id: id,
            name: name,
            color: color,
            bestScoreToPar: Int(best),
            avgScoreToPar: avg,
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
    
    // MARK: - Scoring Engine Bridge

    /// Runs the new ScoringEngine against the current snapshot.
    /// Uses computeWithPipeline when template has a non-empty pipeline (field or matchup scope).
    /// Uses computeStrokePlay only when pipeline is empty (plain stroke play).
    var engineResult: ScoringResult {
        if let cached = cachedEngineResult { return cached }
        let segment = snapshot.roundSegment ?? RoundSegment()
        let template = snapshot.resolvedActiveTemplate
        let holes = defaultTee?.holes ?? []
        let matchups = segment.matchups ?? []
        let validMatchups = matchups.filter { $0.isValid }
        let isMatchupScope = snapshot.configuration.resolvedCompetitionScope == .matchup && !validMatchups.isEmpty

        let result: ScoringResult
        if !template.pipeline.isEmpty {
            result = ScoringEngine.computeWithPipeline(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                teams: snapshot.teams,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                template: template
            )
        } else {
            result = ScoringEngine.computeStrokePlay(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                template: template
            )
        }
        cachedEngineResult = result
        return result
    }

    /// Matchup sections for the Matchups tab. Empty when not matchup scope or no valid matchups. Only includes sections matching the current mode (requiresTeams).
    var matchupSections: [MatchupLeaderboardSection] {
        let result = engineResult
        guard !result.matchupResults.isEmpty else { return [] }
        let expectedMode: MatchupMode = snapshot.requiresTeams ? .team : .individual
        return LeaderboardBuilder.buildMatchupSections(
            result: result,
            teams: snapshot.teams,
            participants: snapshot.participants
        )
        .filter { ($0.matchup.mode ?? .team) == expectedMode }
    }

    /// Engine-derived leaderboard rows, bridged to the ViewModel's LeaderboardRow type.
    /// Supports both participant rows (Stableford, stroke play) and team rows (best ball).
    var engineLeaderboardRows: [LeaderboardRow] {
        let result = engineResult
        let participantMap = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        let teamMap = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })

        let isHighestWins = result.template.leaderboardSort == .highestWins

        let rows: [LeaderboardRow] = result.rows.compactMap { row in
            let participant: RoundParticipant?
            let teamID: String?
            let teamName: String?
            let teamColor: Color?

            if let p = participantMap[row.scoringUnitID] {
                participant = p
                teamID = nil
                teamName = nil
                teamColor = nil
            } else if let team = teamMap[row.scoringUnitID], let firstPID = row.participantIDs.first,
                      let p = participantMap[firstPID] {
                participant = p
                teamID = team.id
                teamName = team.name
                teamColor = team.teamColor.value
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
                teamColor: teamColor
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
                teamColor: row.teamColor
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
            await clearScore(participant: participant, holeNumber: holeNumber)
            showCustomScorePrompt = false
            return
        }
        
        let quick = quickScores(for: holeNumber)
        if quick.contains(value) {
            await setQuickScore(participant: participant, strokes: value, holeNumber: holeNumber)
        } else {
            await setScore(participant: participant, holeNumber: holeNumber, strokes: value)
        }
        showCustomScorePrompt = false
    }
    
    func setQuickScore(participant: RoundParticipant, strokes: Int, holeNumber: Int) async {
        await setScore(participant: participant, holeNumber: holeNumber, strokes: strokes)
    }
    
    func clearScore(participant: RoundParticipant, holeNumber: Int) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        guard var entry = scoreEntry(for: participant.id, holeNumber: holeNumber) else { return }
        
        let previousEntry = entry
        entry.parentID = snapshot.round.id
        entry.entryID = currentParticipantID ?? entry.entryID
        entry.pickedUp = false
        entry.value = nil
        entry.strokes = nil
        
        var updatedSnapshot = roundSession.snapshot
        updatedSnapshot.scoring.upsert(entry)
        roundSession.snapshot = updatedSnapshot
        
        do {
            _ = try await entry.put().get()
            lastLocalScoreAt = Date()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to clear score for participant \(participant.id)", error: error)
            var rollbackSnapshot = roundSession.snapshot
            rollbackSnapshot.scoring.upsert(previousEntry)
            roundSession.snapshot = rollbackSnapshot
        }
    }
    
    func setScore(participant: RoundParticipant, holeNumber: Int, strokes: Int) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        
        let roundID = snapshot.round.id
        let resolved = snapshot.segment(forHole: holeNumber)
        let segmentID = resolved?.id.isPopulated == true ? resolved!.id : snapshot.roundSegment?.id ?? "seg0"
        let scoringUnitID = participant.id
        
        let id = ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: scoringUnitID)
        
        var entry = scoreEntry(for: participant.id, holeNumber: holeNumber) ?? ScoreEntry(
            id: id,
            holeNumber: holeNumber,
            segmentID: segmentID,
            groupID: participant.groupID ?? "",
            scoringUnitID: scoringUnitID,
            participantIDs: [participant.id],
            strokes: nil,
            value: nil,
            pickedUp: false,
            entryID: currentParticipantID ?? participant.id,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
        
        entry.id = id
        entry.parentID = roundID
        entry.segmentID = segmentID
        entry.groupID = participant.groupID ?? entry.groupID
        entry.scoringUnitID = scoringUnitID
        entry.participantIDs = [participant.id]
        entry.entryID = currentParticipantID ?? entry.entryID
        entry.pickedUp = false
        entry.value = nil
        entry.strokes = strokes
        
        let previousEntry = scoreEntry(for: participant.id, holeNumber: holeNumber)
        
        var updatedSnapshot = roundSession.snapshot
        updatedSnapshot.scoring.upsert(entry)
        roundSession.snapshot = updatedSnapshot
        
        do {
            _ = try await entry.put().get()
            lastLocalScoreAt = Date()
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
    
    // MARK: - Current participant resolution
    
    private func resolveCurrentParticipantIDIfNeeded() async {
        // If guest is spectating/playing without auth, we use ephemeral participant id.
        if let ephemeral = appSession?.ephemeralParticipantID, ephemeral.isPopulated {
            currentParticipantID = ephemeral
            updateSelectedTeeIfNeeded()
            return
        }
        
        if currentParticipantID.exists { return }
        
        guard let primary = await AppData.shared.getPrimaryPlayer() else { return }
        if let p = snapshot.participants.first(where: { $0.playerID == primary.id }) {
            currentParticipantID = p.id
            updateSelectedTeeIfNeeded()
        }
    }
    
    private func updateSelectedTeeIfNeeded() {
        let options = teeOptionsForMenu
        guard options.isPopulated else { return }
        
        if let selectedTeeID, options.contains(where: { $0.id == selectedTeeID }) {
            return
        }
        
        let fromParticipants = teeSelectionOptions
        if fromParticipants.isPopulated {
            selectedTeeID = preferredTeeID(options: fromParticipants)
        } else {
            selectedTeeID = snapshot.defaultTee?.id ?? options.first?.id
        }
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
        holeNumbers.filter { holeCompletionProgress(holeNumber: $0) < 1 }
    }

    /// Sets the max allowed score for every unscored player on every unscored hole.
    /// Uses a single Firestore batch write instead of N individual writes.
    func applyMaxScoresToUnscoredHoles() async {
        guard let roundSession else { return }

        let players = teeGroupParticipants
        let maxScoreRule = snapshot.gameFormat.configuration.maxScoreOverPar
        let roundID = snapshot.round.id
        let resolved = snapshot.segment(forHole: 1)
        let segmentID = resolved?.id.isPopulated == true ? resolved!.id : snapshot.roundSegment?.id ?? "seg0"

        var entriesToWrite: [ScoreEntry] = []
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
                    entryID: currentParticipantID ?? participant.id,
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
                entry.entryID = currentParticipantID ?? participant.id
                entry.pickedUp = false
                entry.value = nil
                entry.strokes = max

                entriesToWrite.append(entry)
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
        } catch {
            addBreadcrumb(level: .error, message: "Failed to batch apply max scores", error: error)
            roundSession.snapshot = previousSnapshot
        }
    }
}
