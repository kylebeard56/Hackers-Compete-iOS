//
//  RoundSession+TeeGroup.swift
//  Hackers
//
//  Created by Kyle Beard on 11/18/25.
//

import Foundation
import UIKit

extension RoundSession {
    @discardableResult
    func createTeeGroup(startingHole: Int? = nil, teeTime: String? = nil) async throws -> TeeTimeGroup {
        addBreadcrumb()

        let newTeeGroup = TeeTimeGroup(
            id: HackersID.string(),
            index: snapshot.teeGroups.nextIndex,
            teeTime: teeTime,
            startingHole: resolvedStartingHoleForNewTeeGroup(
                explicitStartingHole: startingHole,
                existingGroups: snapshot.teeGroups
            ),
            lastCompletedHole: nil,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: snapshot.round.id
        )
        
        do {
            let createdGroup = try await newTeeGroup.put().get()
            snapshot.teeGroups.append(createdGroup)
            emitRoundSetupEvent(
                "round_setup.tee_group_created",
                extra: teeGroupTelemetryProps(
                    createdGroup,
                    extra: [
                        "creation_source": "manual"
                    ]
                )
            )
            return createdGroup
        } catch {
            addBreadcrumb(level: .error, message: "Failed to create new tee group", error: error)
            throw error
        }
    }
    
    /// Removes a tee group and unassigns all players from it
    func removeTeeGroup(_ group: TeeTimeGroup) async throws {
        addBreadcrumb()
        let removedProps = teeGroupTelemetryProps(group)

        do {
            // 1. Unassign participants locally + persist
            for participant in snapshot.participants {
                if participant.groupID == group.id {
                    var p = participant
                    p.groupID = nil
                    p.teeOrder = nil
                    try await self.update(participant: p)
                }
            }

            // 2. Remove group locally
            snapshot.teeGroups.removeAll { $0.id == group.id }

            // 3. Delete group remotely
            _ = try await group.delete().get()

            // 4. Reindex remaining tee groups sequentially
            let sorted = snapshot.teeGroups.sorted { $0.index < $1.index }

            for (index, var teeGroup) in sorted.enumerated() {
                let newIndex = index + 1
                guard teeGroup.index != newIndex else { continue }

                teeGroup.index = newIndex
                teeGroup = try await teeGroup.put().get()
                snapshot.teeGroups.upsert(teeGroup)
            }

            emitRoundSetupEvent(
                "round_setup.tee_group_removed",
                extra: prefixedTelemetryProps(removedProps, prefix: "removed")
            )

        } catch {
            addBreadcrumb(level: .error, message: "Failed to remove tee group", error: error)
            throw error
        }
    }
    
    func clearAllTeeGroups() async throws {
        for group in snapshot.teeGroups {
            try await removeTeeGroup(group)
        }
    }
    
    func update(_ group: TeeTimeGroup) async throws {
        addBreadcrumb()
        let previousGroup = snapshot.teeGroups.first(where: { $0.id == group.id })

        do {
            let updatedGroup = try await group.put().get()
            snapshot.teeGroups.upsert(updatedGroup)

            guard let previousGroup, previousGroup != updatedGroup else { return }

            var props = teeGroupTelemetryProps(updatedGroup)
            props.merge(
                prefixedTelemetryProps(teeGroupTelemetryProps(previousGroup), prefix: "previous")
            ) { _, new in new }
            emitRoundSetupEvent("round_setup.tee_group_updated", extra: props)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update tee time for group", error: error)
            throw error
        }
    }

    func resolvedStartingHoleForNewTeeGroup(
        explicitStartingHole: Int? = nil,
        existingGroups: [TeeTimeGroup]
    ) -> Int {
        if let explicitStartingHole {
            return explicitStartingHole
        }

        if snapshot.configuration.usesSequentialTeeStarts {
            return TeeTimeGroup.nextSequentialStartingHole(
                existingGroups: existingGroups.sorted { $0.index < $1.index },
                in: snapshot.holeRange
            )
        }

        return snapshot.holeRange?.startHole ?? 1
    }

    func resequenceTeeGroupsForSequentialStarts() async throws {
        let orderedGroups = snapshot.teeGroups.sorted { $0.index < $1.index }

        for (sequenceIndex, group) in orderedGroups.enumerated() {
            let desiredStartingHole = TeeTimeGroup.sequentialStartingHole(
                forSequenceIndex: sequenceIndex,
                in: snapshot.holeRange
            )

            guard group.startingHole != desiredStartingHole else { continue }

            var updatedGroup = group
            updatedGroup.startingHole = desiredStartingHole
            try await update(updatedGroup)
        }
    }
}
