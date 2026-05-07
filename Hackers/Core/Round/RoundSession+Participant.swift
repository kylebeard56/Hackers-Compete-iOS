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
                let participant = RoundParticipant(
                    player: $0,
                    teeBoxID: snapshot.defaultTee?.id ?? "",
                    teamID: nil,
                    groupID: nil,
                    teeOrder: nil,
                    isHost: $0.isHost(in: snapshot),
                    parentID: roundID ?? snapshot.round.id
                )
                let input = Double(participant.originalHandicap)
                return HandicapCalculator.participant(
                    participant,
                    applying: input,
                    format: snapshot.configuration.handicapEntryFormat,
                    courseSegment: snapshot.courseSegment,
                    maximumHandicap: snapshot.configuration.leagueHandicapMaximum,
                    handicapStrokeBasis: snapshot.handicapStrokeBasis
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

            if createdParticipants.isPopulated {
                var props: [String: Any] = [
                    "added_participant_count": createdParticipants.count,
                    "auto_assign_enabled": autoAssign,
                    "created_tee_group_count": newGroups.count
                ]
                if let teeGroupSize {
                    props["tee_group_size"] = teeGroupSize
                }
                emitRoundSetupEvent("round_setup.participants_added", extra: props)
            }

            for group in newGroups {
                emitRoundSetupEvent(
                    "round_setup.tee_group_created",
                    extra: teeGroupTelemetryProps(
                        group,
                        extra: [
                            "creation_source": "auto_assignment"
                        ]
                    )
                )
            }

            if snapshot.configuration.scoreOwnerScope != .individual {
                try await rebuildRoundScoringConfiguration()
            }
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
            let nextIndex = teeGroups.nextIndex
            let group = TeeTimeGroup(
                id: UUID().uuidString,
                index: nextIndex,
                startingHole: resolvedStartingHoleForNewTeeGroup(
                    existingGroups: teeGroups
                ),
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
        let previousParticipant = snapshot.participants.first(where: { $0.id == participant.id })
        let previousHostID = snapshot.participants.first(where: \.isHost)?.id

        do {
            /// 1. PUT remotely
            let updatedParticipant = try await participant.put().get()
            
            /// 2. Update participant locally
            snapshot.participants.upsert(updatedParticipant)

            /// 3. Keep the round's denormalized player list aligned with participant identity swaps.
            let rebuiltPlayerIDs = rebuiltRoundPlayerIDs()
            if snapshot.round.players != rebuiltPlayerIDs {
                snapshot.round.players = rebuiltPlayerIDs
                _ = try await snapshot.round.put().get()
            }

            if snapshot.configuration.scoreOwnerScope != .individual {
                try await rebuildRoundScoringConfiguration()
            }

            /// 4. Emit telemetry from the final local state.
            trackParticipantTelemetry(
                from: previousParticipant,
                to: updatedParticipant,
                previousHostID: previousHostID
            )
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

            if snapshot.configuration.scoreOwnerScope != .individual {
                try await rebuildRoundScoringConfiguration()
            }

            emitRoundSetupEvent(
                "round_setup.participant_removed",
                participant: participant,
                teeID: participant.teeBoxID,
                extra: [
                    "was_host": participant.isHost
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to remove participant by id \(participant.id)", error: error)
            throw error
        }
    }
}

extension RoundSession {
    func changeHost(to participant: RoundParticipant) async throws {
        addBreadcrumb()
        let previousHostID = snapshot.participants.first(where: \.isHost)?.id

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

            guard previousHostID != newHost.id else { return }

            var props: [String: Any] = [:]
            if let previousHostID, previousHostID.isPopulated {
                props["previous_host_participant_id"] = previousHostID
            }
            if let playerID = newHost.playerID, playerID.isPopulated {
                props["host_player_id"] = playerID
            }
            emitRoundSetupEvent(
                "round_setup.host_changed",
                participant: newHost,
                teeID: newHost.teeBoxID,
                extra: props
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to change host: \(participant.id)", error: error)
            throw error
        }
    }
}

private extension RoundSession {
    func rebuiltRoundPlayerIDs() -> [String] {
        var seen: Set<String> = []
        var playerIDs: [String] = []

        for playerID in snapshot.participants.compactMap(\.playerID) where playerID.isPopulated {
            guard seen.insert(playerID).inserted else { continue }
            playerIDs.append(playerID)
        }

        return playerIDs
    }

    func trackParticipantTelemetry(
        from previousParticipant: RoundParticipant?,
        to participant: RoundParticipant,
        previousHostID: String?
    ) {
        guard let previousParticipant else { return }

        let teamChanged = previousParticipant.teamID != participant.teamID
        let groupChanged = previousParticipant.groupID != participant.groupID
        let teeOrderChanged = previousParticipant.teeOrder != participant.teeOrder
        if teamChanged || groupChanged || teeOrderChanged {
            var props: [String: Any] = [
                "team_assignment_changed": teamChanged,
                "tee_group_assignment_changed": groupChanged,
                "tee_order_changed": teeOrderChanged
            ]
            if let previousTeamID = previousParticipant.teamID, previousTeamID.isPopulated {
                props["previous_team_id"] = previousTeamID
            }
            if let teamID = participant.teamID, teamID.isPopulated {
                props["team_id"] = teamID
            }
            if let previousGroupID = previousParticipant.groupID, previousGroupID.isPopulated {
                props["previous_group_id"] = previousGroupID
            }
            if let groupID = participant.groupID, groupID.isPopulated {
                props["group_id"] = groupID
            }
            if let previousTeeOrder = previousParticipant.teeOrder {
                props["previous_tee_order"] = previousTeeOrder
            }
            if let teeOrder = participant.teeOrder {
                props["tee_order"] = teeOrder
            }
            emitRoundSetupEvent(
                "round_setup.participant_assignment_changed",
                participant: participant,
                teeID: participant.teeBoxID,
                extra: props
            )
        }

        if previousParticipant.teeBoxID != participant.teeBoxID {
            var props: [String: Any] = [:]
            if let previousTee = snapshot.tees.first(where: { $0.id == previousParticipant.teeBoxID }) {
                props["previous_tee_id"] = previousTee.id
                props["previous_tee_name"] = previousTee.name
            }
            if let tee = snapshot.tees.first(where: { $0.id == participant.teeBoxID }) {
                props["tee_id"] = tee.id
                props["tee_name"] = tee.name
            }
            emitRoundSetupEvent(
                "round_setup.participant_tee_changed",
                participant: participant,
                teeID: participant.teeBoxID,
                extra: props
            )
        }

        if previousParticipant.originalHandicap != participant.originalHandicap
            || previousParticipant.adjustedHandicap != participant.adjustedHandicap {
            emitRoundSetupEvent(
                "round_setup.handicap_updated",
                participant: participant,
                teeID: participant.teeBoxID,
                extra: [
                    "previous_original_handicap": previousParticipant.originalHandicap,
                    "previous_adjusted_handicap": previousParticipant.adjustedHandicap,
                    "original_handicap": participant.originalHandicap,
                    "adjusted_handicap": participant.adjustedHandicap
                ]
            )
        }

        if previousParticipant.isHost != participant.isHost && participant.isHost {
            var props: [String: Any] = [:]
            if let previousHostID, previousHostID.isPopulated {
                props["previous_host_participant_id"] = previousHostID
            }
            if let playerID = participant.playerID, playerID.isPopulated {
                props["host_player_id"] = playerID
            }
            emitRoundSetupEvent(
                "round_setup.host_changed",
                participant: participant,
                teeID: participant.teeBoxID,
                extra: props
            )
        }
    }
}
