//
//  Session+Round.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {
    func loadRounds() async {
        addBreadcrumb(#function)
        guard let user = await AppData.shared.user, let player = user.players.first else { return }
        self.rounds = await FirebaseService.shared.fetchRounds(playerID: player.id)
//        self.activeRoundID = self.rounds.filter({ [.lobby, .live].contains($0.status) }).first?.id
        // TODO: Make this more robust - what happens if a user has multiple lobby or live rounds at the same time?
    }
    
    
    /// Immediately remove locally anticipating success, reinsert on failure
    func archiveRound(_ round: Round) async {
        addBreadcrumb("\(#function), id: \(round.id)")
        
        guard let user = await AppData.shared.user, round.createdBy == user.id else {
            addBreadcrumb("User is not creator, cannot archive")
            return
        }
        
        var r = round
        r.status = .archived
        do {
            _ = try await r.put().get()
            rounds.removeAll(where: { $0.id == r.id })
        } catch {
            addBreadcrumb(.error, .firebase, "Failed to archive round", error)
        }
    }
    
    /// NTOE: This will permanently delete a round and should only be used by an Admin.
    private func cloudFunctionDelete(_ round: Round) async {
        addBreadcrumb("\(#function), id: \(round.id)")
        var index: Int?

        if let position = rounds.firstIndex(where: { $0.id == round.id }) {
            index = position
            rounds.remove(at: position)
        }
        
        let deleted = await FirebaseService.shared.delete(round: round)
        if !deleted {
            if let index {
                rounds.insert(round, at: index)
            }
        }
    }
}
