//
//  RoundService+Participant.swift
//  Hackers
//
//  Created by Kyle Beard on 9/12/25.
//

import Foundation
import UIKit

extension RoundService {
    func addPlayers(_ data: [Player]) async throws {
        addBreadcrumb(#function)
        
        isAddingPlayers = true
        defer { isAddingPlayers = false }
        
        var players = data
        var participants: [RoundParticipant] = []
        
        do {
            // 1. Add players to the collection (offline, new)
            for (index, player) in players.filter(\.needsToBeCreated).enumerated() {
                players[index] = try await player.post().get()
            }
            
            // 2. Create round participant for each player
            for player in players {
                let participant = try await RoundParticipant(
                    player: player,
                    teeBoxID: self.snapshot.defaultTee?.id ?? "",
                    teamID: nil,
                    groupID: nil,
                    teeOrder: nil,
                    isHost: player.isHost(in: self.snapshot),
                    parentID: self.roundID ?? self.snapshot.round.id
                ).post().get()

                participants.append(participant)
            }
            
            // 3. Add IDs at the round snapshot root
            let ids = participants.compactMap { $0.id }
            snapshot.round.players.append(contentsOf: ids)
            _ = try await snapshot.round.put().get()
            
            // TODO: In the future, create and auto-assign tee groups if teeGroupID is nil
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to add new participants", error)
            throw error
        }
    }
    
    func update(participant: RoundParticipant) async throws {
        addBreadcrumb(#function)
        
        do {
            /// 1. PUT remotely
            let updatedParticipant = try await participant.put().get()
            
            /// 2. Update participant locally
            if let index = snapshot.participants.firstIndex(where: { $0.id == participant.id }) {
                snapshot.participants[index] = updatedParticipant
            }
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to update participant by id \(participant.id)", error)
            throw error
        }
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
            throw error
        }
    }
}
