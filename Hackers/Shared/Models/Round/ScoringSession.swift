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
    let participants: [RoundParticipant]
    let scoringUnitID: String
    let title: String?
    let subtitle: String?
    let teamID: String?
    let scoringGroupID: String?
    let isSharedEntry: Bool
    let holeNumber: Int
    let id: UUID

    init(
        participant: RoundParticipant,
        participants: [RoundParticipant]? = nil,
        scoringUnitID: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        teamID: String? = nil,
        scoringGroupID: String? = nil,
        isSharedEntry: Bool = false,
        holeNumber: Int,
        id: UUID = UUID()
    ) {
        self.participant = participant
        self.participants = participants?.isPopulated == true ? participants! : [participant]
        self.scoringUnitID = scoringUnitID ?? participant.id
        self.title = title
        self.subtitle = subtitle
        self.teamID = teamID
        self.scoringGroupID = scoringGroupID
        self.isSharedEntry = isSharedEntry
        self.holeNumber = holeNumber
        self.id = id
    }
}
