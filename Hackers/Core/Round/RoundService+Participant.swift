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
            // 1. Ensure players exist
            for (index, player) in players.filter(\.needsToBeCreated).enumerated() {
                players[index] = try await player.post().get()
            }
            
            // 2. Auto-assign to first (and assumed only) group if players are still less than 5
//            var groupID: String? = nil
//            if let id = snapshot.teeGroups.first?.id, (data.count + snapshot.round.players.count) < 5 {
//                groupID = id
//            }

            // 2. Create participants WITHOUT group assignment
            for player in players {
                let participant = try await RoundParticipant(
                    player: player,
                    teeBoxID: snapshot.defaultTee?.id ?? "",
                    teamID: nil,
                    groupID: nil,
                    teeOrder: nil,
                    isHost: player.isHost(in: snapshot),
                    parentID: roundID ?? snapshot.round.id
                ).post().get()

                participants.append(participant)
            }

            // 3. Assign tee groups
            try await assignParticipantsToTeeGroups(participants)
            //snapshot.participants.append(contentsOf: participants)

            // 4. Append IDs to round
            snapshot.round.players.append(contentsOf: participants.compactMap(\.id))
            _ = try await snapshot.round.put().get()

        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to add new participants", error)
            throw error
        }
    }

    private func assignParticipantsToTeeGroups(_ participants: [RoundParticipant]) async throws {
        addBreadcrumb(#function)
        
        // Start with existing tee groups, ordered
        var teeGroups = snapshot.teeGroups.sorted { $0.index < $1.index }

        // Map of groupID → current count
        var groupCounts: [String: Int] = [:]

        for group in teeGroups {
            groupCounts[group.id] = snapshot.participants
                .filter { $0.groupID == group.id }
                .count
        }

        // Pointer to the active group
        var currentGroup = teeGroups.last

        for participant in participants {
            // Create a group if needed
            if currentGroup == nil ||
                (groupCounts[currentGroup!.id, default: 0] >= 4) {

                let newGroup = try await createTeeGroup()
                teeGroups.append(newGroup)
                snapshot.teeGroups.append(newGroup)

                groupCounts[newGroup.id] = 0
                currentGroup = newGroup
            }

            guard let group = currentGroup else { continue }

            let teeOrder = groupCounts[group.id, default: 0] + 1

            var updatedParticipant = participant
            updatedParticipant.groupID = group.id
            updatedParticipant.teeOrder = teeOrder

            updatedParticipant = try await updatedParticipant.put().get()
            snapshot.participants.upsert(updatedParticipant)
            
            groupCounts[group.id] = teeOrder
        }
    }
    
    func update(participant: RoundParticipant) async throws {
        addBreadcrumb(#function)
        
        do {
            /// 1. PUT remotely
            let updatedParticipant = try await participant.put().get()
            
            /// 2. Update participant locally
            snapshot.participants.upsert(updatedParticipant)
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
