//
//  ScoringSession.swift
//  Hackers
//
//  Created by Kyle Beard on 2/23/26.
//

import SwiftUI

/// Presentation model for the LiveHoleScoringView sheet.
/// Bundles participant and hole so the sheet receives explicit context
/// rather than reading from viewModel.currentHoleNumber.
struct ScoringSession: Identifiable {
    let participant: RoundParticipant
    let holeNumber: Int
    let id: UUID

    init(participant: RoundParticipant, holeNumber: Int, id: UUID = UUID()) {
        self.participant = participant
        self.holeNumber = holeNumber
        self.id = id
    }
}
