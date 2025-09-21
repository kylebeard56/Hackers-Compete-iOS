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
}
