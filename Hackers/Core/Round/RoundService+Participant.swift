//
//  RoundService+Participant.swift
//  Hackers
//
//  Created by Kyle Beard on 9/12/25.
//

import Foundation
import UIKit

extension RoundService {
    func addParticipant(_ player: any Playable) async throws -> RoundParticipant? {
        return nil
        
        // TODO: Adding a participant
        // 1. We want to instantiate a new RoundParticipant built upon this player
        
//        var participant = RoundParticipant(
//            id: HackersID.string(),
//            userID: player.userID,
//            playerID: player.id,
//            name: player.name,
//            teeBoxID: "",
//            originalHandicap: 0,
//            adjustedHandicap: 0,
//            teamID: nil,
//            groupID: nil,
//            teeOrder: nil,
//            isHost: true,
//            createdAt: .init(),
//            lastUpdatedAt: .init(),
//            parentID: round.id
//        )
    }
    
    func remove(participant: RoundParticipant) async throws {
        addBreadcrumb(#function)
        
        if participant.isHost {
            addBreadcrumb(.warning, .gameLobby, "Tried to remove host as participant")
            return
        }
        
        do {
            /// 1. Remove the ID of the player from the snapshot round list (how the app loads rounds by player account)
            snapshot.round.players.removeAll(where: { $0 == participant.id })
            _ = try await snapshot.round.put().get()
            
            /// 2. Delete the round participant since this model only lives within the round
            _ = try await participant.delete().get()
            snapshot.participants.removeAll(where: { $0.id == participant.id })
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to remove participant by id \(participant.id)", error)
        }
    }
}
