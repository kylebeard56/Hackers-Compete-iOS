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
        guard let user = await AppData.shared.user,
              let players = try? await FirebaseService.shared.getPlayersByIDs(user.players).get(),
              let player = players.first(where: \.isPrimary)
        else {
            return
        }
        
        self.rounds = Set(
            await FirebaseService.shared.fetchRounds(playerID: player.id).filter({ $0.status != .archived })
        )
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
        } catch {
            addBreadcrumb(level: .error, message: "Failed to archive round", error: error)
        }
    }
    
    /// NTOE: This will permanently delete a round and should only be used by an Admin.
    private func cloudFunctionDelete(_ round: Round) async {
        addBreadcrumb(message: "Cloud function delete round for id: \(round.id)")

        rounds.remove(round)
        
        let deleted = await FirebaseService.shared.delete(round: round)
        if !deleted {
            rounds.insert(round)
        }
    }
}
