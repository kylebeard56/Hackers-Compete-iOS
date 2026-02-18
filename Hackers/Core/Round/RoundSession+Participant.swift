//
//  RoundSession+Participant.swift
//  Hackers
//
//  Created by Kyle Beard on 9/12/25.
//

import Foundation
import UIKit

extension RoundSession {
//    func addPlayers(_ data: [Player]) async throws {
//        addBreadcrumb()
//
//        isAddingPlayers = true
//        defer { isAddingPlayers = false }
//
//        var players = data
//        var participants: [RoundParticipant] = []
//
//        do {
//            // 1. Ensure players exist if needing to be created (offline)
//            for player in players where player.needsToBeCreated {
//                let created = try await player.post().get()
//                players.upsert(created)
//            }
//            
//            // 2. Auto-assign to first (and assumed only) group if players are still less than 5
////            var groupID: String? = nil
////            if let id = snapshot.teeGroups.first?.id, (data.count + snapshot.round.players.count) < 5 {
////                groupID = id
////            }
//
//            // 2. Create participants WITHOUT group assignment
//            for player in players {
//                let participant = try await RoundParticipant(
//                    player: player,
//                    teeBoxID: snapshot.defaultTee?.id ?? "",
//                    teamID: nil,
//                    groupID: nil,
//                    teeOrder: nil,
//                    isHost: player.isHost(in: snapshot),
//                    parentID: roundID ?? snapshot.round.id
//                ).post().get()
//
//                participants.append(participant)
//            }
//
//            // 3. Assign tee groups
//            try await assignParticipantsToTeeGroups(participants)
//
//            // 4. Append IDs to round
//            snapshot.round.players.append(contentsOf: participants.compactMap(\.id))
//            _ = try await snapshot.round.put().get()
//
//        } catch {
//            addBreadcrumb(.error, .gameLobby, "Failed to add new participants", error)
//            throw error
//        }
//    }
//
//    private func assignParticipantsToTeeGroups(_ participants: [RoundParticipant]) async throws {
//        addBreadcrumb()
//
//        // Start with existing tee groups, ordered
//        var teeGroups = snapshot.teeGroups.sorted { $0.index < $1.index }
//
//        // Map of groupID → current count
//        var groupCounts: [String: Int] = [:]
//
//        for group in teeGroups {
//            groupCounts[group.id] = snapshot.participants
//                .filter { $0.groupID == group.id }
//                .count
//        }
//
//        // Pointer to the active group
//        var currentGroup = teeGroups.last
//
//        for participant in participants {
//            // Create a group if needed
//            if currentGroup == nil ||
//                (groupCounts[currentGroup!.id, default: 0] >= 4) {
//
//                let newGroup = try await createTeeGroup()
//                teeGroups.append(newGroup)
//                snapshot.teeGroups.append(newGroup)
//
//                groupCounts[newGroup.id] = 0
//                currentGroup = newGroup
//            }
//
//            guard let group = currentGroup else { continue }
//
//            let teeOrder = groupCounts[group.id, default: 0] + 1
//
//            var updatedParticipant = participant
//            updatedParticipant.groupID = group.id
//            updatedParticipant.teeOrder = teeOrder
//
//            updatedParticipant = try await updatedParticipant.put().get()
//            snapshot.participants.upsert(updatedParticipant)
//
//            groupCounts[group.id] = teeOrder
//        }
//    }
    
    func addPlayers(_ data: [Player], teeGroupSize: Int? = nil, autoAssign: Bool = true) async throws {
        addBreadcrumb()
        
        isAddingPlayers = true
        defer { isAddingPlayers = false }

        do {
            // 1. Ensure players exist (offline → create)
            var players = data
            for player in players where player.needsToBeCreated {
                let created = try await player.post().get()
                players.upsert(created)
            }

            // 2. Create participants locally (no DB writes yet)
            var participants = players.map {
                RoundParticipant(
                    player: $0,
                    teeBoxID: snapshot.defaultTee?.id ?? "",
                    teamID: nil,
                    groupID: nil,
                    teeOrder: nil,
                    isHost: $0.isHost(in: snapshot),
                    parentID: roundID ?? snapshot.round.id
                )
            }

            // 3. Optional auto-assignment
            var newGroups: [TeeTimeGroup] = []
            if autoAssign, let groupSize = teeGroupSize, groupSize > 0 {
                let result = computeTeeAssignments(
                    newParticipants: participants,
                    groupSize: groupSize
                )

                participants = result.assignments.map {
                    var p = $0.participant
                    p.groupID = $0.groupID
                    p.teeOrder = $0.teeOrder
                    return p
                }

                newGroups = result.newGroups
            }

            // 4. Persist as batch for speed
            let createdParticipants = try await participants.batchPost().get()
            _ = try await newGroups.batchPost().get() // If empty, the guard will catch in API.

            // 5. Update round once (player IDs for fetchRounds query)
            snapshot.round.players.append(contentsOf: createdParticipants.compactMap(\.playerID))
            _ = try await snapshot.round.put().get()

            // 6. Replace snapshot state atomically
            snapshot.participants.append(contentsOf: createdParticipants)
            snapshot.teeGroups.append(contentsOf: newGroups)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to add participants", error: error)
            throw error
        }
    }

    private func computeTeeAssignments(
        newParticipants: [RoundParticipant],
        groupSize: Int
    ) -> (
        assignments: [(participant: RoundParticipant, groupID: String, teeOrder: Int)],
        newGroups: [TeeTimeGroup]
    ) {

        // Existing groups ordered by index
        var teeGroups = snapshot.teeGroups.sorted { $0.index < $1.index }

        // groupID → current count
        var groupCounts: [String: Int] = [:]

        for group in teeGroups {
            groupCounts[group.id] = snapshot.participants.filter { $0.groupID == group.id }.count
        }

        var assignments: [(RoundParticipant, String, Int)] = []
        var createdGroups: [TeeTimeGroup] = []

        func createGroup() -> TeeTimeGroup {
            let nextIndex = (teeGroups.map(\.index).max() ?? 0) + 1
            let group = TeeTimeGroup(
                id: UUID().uuidString,
                index: nextIndex,
                createdAt: .init(),
                parentID: snapshot.round.id
            )

            teeGroups.append(group)
            groupCounts[group.id] = 0
            createdGroups.append(group)
            return group
        }

        for participant in newParticipants {
            let targetGroup = teeGroups.first(where: { groupCounts[$0.id, default: 0] < groupSize }) ?? createGroup()
            let teeOrder = groupCounts[targetGroup.id, default: 0] + 1
            groupCounts[targetGroup.id] = teeOrder
            assignments.append((participant, targetGroup.id, teeOrder))
        }

        return (assignments, createdGroups)
    }
    
    func update(participant: RoundParticipant) async throws {
        addBreadcrumb()
        
        do {
            /// 1. PUT remotely
            let updatedParticipant = try await participant.put().get()
            
            /// 2. Update participant locally
            snapshot.participants.upsert(updatedParticipant)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update participant by id \(participant.id)", error: error)
            throw error
        }
    }
    
    func remove(participant: RoundParticipant) async throws {
        addBreadcrumb()
        
        if participant.isHost {
            addBreadcrumb(level: .warning, message: "Tried to remove host as participant")
            return
        }
        
        do {
            /// 1. Remove the player ID from the snapshot round list (how the app loads rounds by player account)
            snapshot.round.players.removeAll(where: { $0 == participant.playerID })
            _ = try await snapshot.round.put().get()
            
            /// 2. Delete the round participant since this model only lives within the round
            _ = try await participant.delete().get()
            snapshot.participants.removeAll(where: { $0.id == participant.id })
        } catch {
            addBreadcrumb(level: .error, message: "Failed to remove participant by id \(participant.id)", error: error)
            throw error
        }
    }
}

extension RoundSession {
    func changeHost(to participant: RoundParticipant) async throws {
        addBreadcrumb()
        
        do {
            // 1. Remove existing host
            if var previousHost = snapshot.participants.first(where: \.isHost) {
                previousHost.isHost = false
                previousHost = try await previousHost.put().get()
                snapshot.participants.upsert(previousHost)
            }
            
            // 2. Set new host
            var newHost = participant
            newHost.isHost = true
            newHost = try await newHost.put().get()
            snapshot.participants.upsert(newHost)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to change host: \(participant.id)", error: error)
            throw error
        }
    }
}
