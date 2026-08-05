//
//  Session+Round.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {
    func loadRounds() async {
        addBreadcrumb()
        isLoadingRounds = true
        defer { isLoadingRounds = false }
        
        guard let player = await AppData.shared.getPrimaryPlayer() else { return }
        
        // [SOON] TODO: Convert this to ForEach for user.players
        let fetchedRounds = await FirebaseService.shared.fetchRounds(playerID: player.id).filter { $0.status != .archived }
        self.rounds = Set(await backfilledDashboardRounds(fetchedRounds))
    }
    
    /// Immediately remove locally anticipating success, reinsert on failure
    func archiveRound(_ round: Round) async {
        addBreadcrumb(message: "Archive round for id: \(round.id)")
        
        guard let user = await AppData.shared.user, round.createdBy == user.id else {
            addBreadcrumb(message: "User is not creator, cannot archive")
            return
        }
        
        var r = round
        r.status = .archived
        do {
            _ = try await r.put().get()
            rounds.remove(round)
            if activeRoundID == round.id {
                clearRoundResume()
            }
        } catch {
            addBreadcrumb(level: .error, message: "Failed to archive round", error: error)
        }
    }
    
    /// Permanently deletes a round via cloud function. Only the host (creator) may delete.
    func deleteRound(_ round: Round) async {
        addBreadcrumb(message: "Delete round for id: \(round.id)")
        guard let user = await AppData.shared.user, round.createdBy == user.id else {
            addBreadcrumb(message: "User is not host, cannot delete")
            return
        }
        await cloudFunctionDelete(round)
    }

    /// Permanently deletes a round via cloud function. Reinserts locally on failure.
    private func cloudFunctionDelete(_ round: Round) async {
        addBreadcrumb(message: "Cloud function delete round for id: \(round.id)")

        rounds.remove(round)
        
        let deleted = await FirebaseService.shared.delete(round: round)
        if !deleted {
            rounds.insert(round)
        } else if activeRoundID == round.id {
            clearRoundResume()
        }
    }

    private func backfilledDashboardRounds(_ rounds: [Round]) async -> [Round] {
        var result: [Round] = []

        for round in rounds {
            var updated = round
            var didChange = false

            if updated.firstScoredAt == nil {
                switch await FirebaseService.shared.getScores(for: updated.id) {
                case .success(let scores):
                    if let firstScoredAt = scores
                        .filter(\.hasRecordedScore)
                        .map(\.createdAt)
                        .min(by: { $0.unix < $1.unix }) {
                        updated.firstScoredAt = firstScoredAt
                        didChange = true
                    }
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "Could not backfill first score timestamp", error: error)
                }
            }

            if updated.teeGroupDisplayNamesByPlayerID.isEmpty {
                switch await FirebaseService.shared.getParticipants(for: updated.id) {
                case .success(let participants):
                    let summaries = Round.teeGroupDisplayNamesByPlayerID(from: participants)
                    if summaries.isPopulated {
                        updated.teeGroupDisplayNamesByPlayerID = summaries
                        didChange = true
                    }
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "Could not backfill tee group display names", error: error)
                }
            }

            if didChange {
                switch await updated.put() {
                case .success(let persisted):
                    result.append(persisted)
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "Could not persist dashboard round backfill", error: error)
                    result.append(updated)
                }
            } else {
                result.append(updated)
            }
        }

        return result
    }
}
