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
    
    // MARK: - Course / Hole data
    
    var defaultTee: Tee? { snapshot.defaultTee ?? snapshot.tees.first }
    
    func hole(for holeNumber: Int) -> Hole? {
        guard let tee = defaultTee else { return nil }
        return tee.holes.first(where: { $0.number == holeNumber })
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
    
    // MARK: - Leaderboard
    
    struct LeaderboardRow: Identifiable {
        var id: String { participant.id }
        let participant: RoundParticipant
        let thru: Int
        let scoreToPar: Int
        let isPinned: Bool
    }
    
    var leaderboardRows: [LeaderboardRow] {
        let basis = scoreBasis
        
        let rows = teeGroupParticipants.map { p in
            LeaderboardRow(
                participant: p,
                thru: holesPlayedCount(for: p.id),
                scoreToPar: scoreToPar(for: p, basis: basis),
                isPinned: pinnedParticipantIDs.contains(p.id)
            )
        }
        
        // Pinned first, then best score, then name
        return rows.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
            return $0.participant.alphabeticName < $1.participant.alphabeticName
        }
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
        await setScore(participant: participant, strokes: value)
        showCustomScorePrompt = false
    }
    
    func setQuickScore(participant: RoundParticipant, strokes: Int) async {
        await setScore(participant: participant, strokes: strokes)
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
            return
        }
        
        if currentParticipantID.exists { return }
        
        guard let primary = await AppData.shared.getPrimaryPlayer() else { return }
        if let p = snapshot.participants.first(where: { $0.playerID == primary.id }) {
            currentParticipantID = p.id
        }
    }
}

