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
    @Published var isSpectator: Bool = false
    
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
    
    /// Scorecard sheet
    @Published var presentedParticipant: RoundParticipant?

    /// Live hole scoring sheet
    @Published var presentedScoringParticipant: RoundParticipant?
    
    /// Scorecard visibility: which participants appear in FullScorecardView
    @Published var visibleParticipantIDs: Set<String> = []
    private var lastAppliedVisibleParticipantIDs: Set<String> = []
    
    // MARK: - Wiring
    
    private weak var appSession: AppSession?
    private weak var roundSession: RoundSession?
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(appSession: AppSession, roundSession: RoundSession) {
        // Avoid duplicate bindings
        if self.roundSession === roundSession { return }
        
        self.appSession = appSession
        self.roundSession = roundSession
        self.isSpectator = appSession.isSpectating
        
        snapshot = roundSession.snapshot
        
        if snapshot.configuration.useHandicaps {
            scoreBasis = .net
        }
        
        roundSession.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                guard let self else { return }
                self.snapshot = s
                self.ensureHoleIndexInBounds()
                self.updateSelectedTeeIfNeeded()
                
                if !s.configuration.useHandicaps {
                    self.scoreBasis = .gross
                }
                
                if self.visibleParticipantIDs.isEmpty && !s.participants.isEmpty {
                    self.visibleParticipantIDs = Set(s.participants.map(\.id))
                    self.lastAppliedVisibleParticipantIDs = self.visibleParticipantIDs
                }
                
                Task { await self.resolveCurrentParticipantIDIfNeeded() }
            }
            .store(in: &cancellables)
        
        Task { await resolveCurrentParticipantIDIfNeeded() }
    }
    
    func set(snapshot: RoundSnapshot) {
        self.snapshot = snapshot
        if visibleParticipantIDs.isEmpty && !snapshot.participants.isEmpty {
            visibleParticipantIDs = Set(snapshot.participants.map(\.id))
            lastAppliedVisibleParticipantIDs = visibleParticipantIDs
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
        guard let next = nextUnscoredHoleNumber, next != currentHoleNumber else { return }
        selectHole(next)
    }
    
    enum HoleDisplayState {
        case current
        case completed
        case error
        case unscored
    }
    
    func holeState(for holeNumber: Int) -> HoleDisplayState {
        if holeNumber == currentHoleNumber { return .current }
        let progress = holeCompletionProgress(holeNumber: holeNumber)
        if progress >= 1 { return .completed }
        if progress > 0 { return .error }
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
    
    func scoreEntry(for participantID: String, holeNumber: Int) -> ScoreEntry? {
        snapshot.scoring.first(where: { entry in
            entry.holeNumber == holeNumber && (entry.scoringUnitID == participantID || entry.participantIDs.contains(participantID))
        })
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

    /// Primary options: birdie through quad. More options: albatross (par 4 only), eagle, quint, sext, etc. up to hole max.
    func scoreMenuOptions(for holeNumber: Int) -> (primary: [Int], more: [Int]) {
        let par = hole(for: holeNumber)?.par ?? 4
        let configMax = snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: par)
        let minScore: Int
        if par == 4 {
            minScore = 1
        } else {
            minScore = max(1, par - 2)
        }
        let primary = [par - 1, par, par + 1, par + 2, par + 3, par + 4]
        let allScores = Array(minScore...configMax)
        let primarySet = Set(primary)
        let more = allScores.filter { !primarySet.contains($0) }
        return (primary, more)
    }
    
    // MARK: - Leaderboard
    
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
        var id: String { participant.id }
        let participant: RoundParticipant
        let thru: Int
        let scoreToPar: Int
        let isPinned: Bool
        let placeLabel: String
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
        if ids.isEmpty { return leaderboardRows }
        return leaderboardRows.filter { ids.contains($0.participant.id) }
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
        let rows = leaderboardRows
        let grouped = Dictionary(grouping: rows) { $0.participant.teamID }
        let orderedTeams = snapshot.teams.sorted { $0.index < $1.index }
        
        var sections: [GroupedLeaderboardSection] = []
        
        for team in orderedTeams {
            let teamRows = (grouped[team.id] ?? []).sorted {
                if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
                return $0.participant.alphabeticName < $1.participant.alphabeticName
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
                if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
                return $0.participant.alphabeticName < $1.participant.alphabeticName
            }
            sections.append(makeGroupedSection(
                id: "unassigned",
                name: "Unassigned",
                color: nil,
                rows: sorted
            ))
        }
        
        return sections.sorted { $0.bestScoreToPar < $1.bestScoreToPar }
    }
    
    var teeGroupLeaderboardSections: [GroupedLeaderboardSection] {
        let rows = leaderboardRows
        let grouped = Dictionary(grouping: rows) { $0.participant.groupID }
        let orderedGroups = snapshot.teeGroups.sorted { $0.index < $1.index }
        
        var sections: [GroupedLeaderboardSection] = []
        
        for group in orderedGroups {
            let groupRows = (grouped[group.id] ?? []).sorted {
                if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
                return $0.participant.alphabeticName < $1.participant.alphabeticName
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
                if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
                return $0.participant.alphabeticName < $1.participant.alphabeticName
            }
            sections.append(makeGroupedSection(
                id: "ungrouped",
                name: "Ungrouped",
                color: nil,
                rows: sorted
            ))
        }
        
        return sections.sorted { $0.bestScoreToPar < $1.bestScoreToPar }
    }
    
    private func makeGroupedSection(
        id: String,
        name: String,
        color: Color?,
        rows: [LeaderboardRow]
    ) -> GroupedLeaderboardSection {
        let scores = rows.map(\.scoreToPar)
        let best = scores.min() ?? 0
        let avg = scores.isEmpty ? 0 : Double(scores.reduce(0, +)) / Double(scores.count)
        return GroupedLeaderboardSection(
            id: id,
            name: name,
            color: color,
            bestScoreToPar: best,
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
        return formatted
    }
    
    // MARK: - Score entry actions
    
    func promptCustomScore(for participant: RoundParticipant) {
        customScoreParticipant = participant
        customScoreText = ""
        showCustomScorePrompt = true
    }
    
    func submitCustomScore() async {
        guard let participant = customScoreParticipant else { return }
        guard let value = Int(customScoreText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        
        if grossStrokes(for: participant.id, holeNumber: currentHoleNumber) == value {
            await clearScore(participant: participant)
            showCustomScorePrompt = false
            return
        }
        
        let quick = quickScores(for: currentHoleNumber)
        if quick.contains(value) {
            await setQuickScore(participant: participant, strokes: value)
        } else {
            await setScore(participant: participant, strokes: value)
        }
        showCustomScorePrompt = false
    }
    
    func setQuickScore(participant: RoundParticipant, strokes: Int) async {
        await setScore(participant: participant, strokes: strokes)
    }

    func clearScore(participant: RoundParticipant) async {
        await clearScore(participant: participant, holeNumber: currentHoleNumber)
    }
    
    func clearScore(participant: RoundParticipant, holeNumber: Int) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        guard var entry = scoreEntry(for: participant.id, holeNumber: holeNumber) else { return }
        
        entry.parentID = snapshot.round.id
        entry.entryID = currentParticipantID ?? entry.entryID
        entry.pickedUp = false
        entry.value = nil
        entry.strokes = nil
        
        do {
            _ = try await entry.put().get()
            roundSession.snapshot.scoring.upsert(entry)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to clear score for participant \(participant.id)", error: error)
        }
    }
    
    func setScore(participant: RoundParticipant, holeNumber: Int, strokes: Int) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        
        let roundID = snapshot.round.id
        let segmentID = snapshot.roundSegment?.id.isPopulated == true ? snapshot.roundSegment!.id : "seg0"
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
        
        do {
            _ = try await entry.put().get()
            roundSession.snapshot.scoring.upsert(entry)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set score for participant \(participant.id)", error: error)
        }
    }
    
    private func setScore(participant: RoundParticipant, strokes: Int) async {
        await setScore(participant: participant, holeNumber: currentHoleNumber, strokes: strokes)
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
            selectedTeeID = preferredTeeID(from: teeGroupParticipants, options: fromParticipants)
        } else {
            selectedTeeID = options.first?.id
        }
    }
    
    private func preferredTeeID(
        from participants: [RoundParticipant],
        options: [TeeSelectionOption]
    ) -> String? {
        let teeIDs = participants.compactMap(\.teeBoxID).filter { $0.isPopulated }
        guard teeIDs.isPopulated else { return options.first?.id }
        
        if let first = teeIDs.first, teeIDs.allSatisfy({ $0 == first }) {
            return first
        }
        
        if let defaultID = snapshot.defaultTee?.id, teeIDs.contains(defaultID) {
            return defaultID
        }
        
        var counts: [String: Int] = [:]
        teeIDs.forEach { counts[$0, default: 0] += 1 }
        let maxCount = counts.values.max() ?? 0
        
        if maxCount > 1, let majority = counts.first(where: { $0.value == maxCount })?.key {
            return majority
        }
        
        return options.max(by: { $0.yardage < $1.yardage })?.id ?? options.first?.id
    }
    
    private func yardage(for tee: Tee, range: HoleRange) -> Int {
        tee.holes.reduce(0) { result, hole in
            range.contains(hole.number) ? result + hole.yardage : result
        }
    }
}

