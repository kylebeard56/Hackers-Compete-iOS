//
//  LiveRoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/30/26.
//

import Combine
import SwiftUI

@MainActor
final class LiveRoundViewModel: ObservableObject, Loggable {
    
    // MARK: - State
    
    @Published private(set) var snapshot: RoundSnapshot = .init()
    @Published private(set) var currentParticipantID: String?
    @Published var selectedTeeID: String?
    
    @Published var currentHoleIndex: Int = 0
    @Published var scoreBasis: ScoreBasis = .gross
    
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
    
    // MARK: - Wiring
    
    private weak var appSession: AppSession?
    private weak var roundSession: RoundSession?
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(appSession: AppSession, roundSession: RoundSession) {
        // Avoid duplicate bindings
        if self.roundSession === roundSession { return }
        
        self.appSession = appSession
        self.roundSession = roundSession
        
        snapshot = roundSession.snapshot
        
        roundSession.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                guard let self else { return }
                self.snapshot = s
                self.ensureHoleIndexInBounds()
                
                Task { await self.resolveCurrentParticipantIDIfNeeded() }
            }
            .store(in: &cancellables)
        
        Task { await resolveCurrentParticipantIDIfNeeded() }
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
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    func friendlyScoreLabel(strokes: Int, par: Int) -> String {
        let diff = strokes - par
        switch diff {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case 3: return "Triple Bogey"
        case 4: return "Quad Bogey"
        case 5: return "Quint Bogey"
        default:
            return diff > 0 ? "\(diff) Over" : "\(abs(diff)) Under"
        }
    }

    func friendlyScoreSummary(strokes: Int, par: Int) -> String {
        "\(friendlyScoreLabel(strokes: strokes, par: par)) (\(strokes))"
    }
    
    // MARK: - Leaderboard
    
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
        if pinnedParticipantIDs.contains(participant.id) {
            pinnedParticipantIDs.remove(participant.id)
        } else {
            pinnedParticipantIDs.insert(participant.id)
        }
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
        addBreadcrumb()
        
        guard let roundSession else { return }
        guard var entry = scoreEntry(for: participant.id, holeNumber: currentHoleNumber) else { return }
        
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
    
    private func setScore(participant: RoundParticipant, strokes: Int) async {
        addBreadcrumb()
        
        guard let roundSession else { return }
        
        let roundID = snapshot.round.id
        let segmentID = snapshot.roundSegment?.id.isPopulated == true ? snapshot.roundSegment!.id : "seg0"
        let scoringUnitID = participant.id
        
        let id = ScoreEntry.makeID(hole: currentHoleNumber, segment: segmentID, scoringUnit: scoringUnitID)
        
        var entry = scoreEntry(for: participant.id, holeNumber: currentHoleNumber) ?? ScoreEntry(
            id: id,
            holeNumber: currentHoleNumber,
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
            // Listener will refresh snapshot; this keeps the view snappy even if pending writes are filtered.
            roundSession.snapshot.scoring.upsert(entry)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set score for participant \(participant.id)", error: error)
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
        let options = teeSelectionOptions
        guard options.isPopulated else { return }
        
        if let selectedTeeID, options.contains(where: { $0.id == selectedTeeID }) {
            return
        }
        
        selectedTeeID = preferredTeeID(from: teeGroupParticipants, options: options)
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

