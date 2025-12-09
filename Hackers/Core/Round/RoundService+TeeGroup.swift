//
//  RoundService+TeeGroup.swift
//  Hackers
//
//  Created by Kyle Beard on 11/18/25.
//

import Foundation
import UIKit

extension RoundService {
    @discardableResult
    func createTeeGroup(startingHole: Int? = nil, teeTime: String? = nil) async throws -> TeeTimeGroup {
        addBreadcrumb(#function)
        
        let nextIndex = snapshot.teeGroups.nextIndex
        
//        if let id = snapshot.teeGroups.first(where: { $0.index == nextIndex - 1 }),
//            snapshot.participants.filter({ $0.groupID == id }).isEmpty {
//            // Last created group is empty, don't create another group until it's populated?
//            return
//        }
        
        let newTeeGroup = TeeTimeGroup(
            id: HackersID.string(),
            index: nextIndex,
            teeTime: teeTime,
            startingHole: startingHole ?? snapshot.holeRange?.startHole ?? 1,
            lastCompletedHole: nil,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: snapshot.round.id
        )
        
        do {
            snapshot.teeGroups.append(newTeeGroup)
            return try await newTeeGroup.put().get()
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to create new tee group", error)
            throw error
        }
    }
    
    /// Removes a tee group and unassigns all players from it
    func removeTeeGroup(_ group: TeeTimeGroup) async throws {
        addBreadcrumb(#function)
        
        do {
            /// 1. Remove the tee group from the subcollection
            snapshot.teeGroups.removeAll(where: { $0.id == group.id })
            _ = try await group.delete().get()
            
            /// 2. Unassign this group from all valid participants
            for (index, p) in snapshot.participants.enumerated() {
                var participant = p
                if participant.groupID == group.id {
                    participant.groupID = nil
                    _ = try await participant.put().get()
                    snapshot.participants[index] = participant
                }
            }
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to remove tee group", error)
            throw error
        }
    }
    
    func update(_ group: TeeTimeGroup) async throws {
        addBreadcrumb(#function)
        
        do {
            /// 1. PUT remotely
            let updatedGroup = try await group.put().get()
        
            /// 2. Update participant locally
            if let index = snapshot.teeGroups.firstIndex(where: { $0.id == group.id }) {
                snapshot.teeGroups[index] = updatedGroup
            }
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to update tee time for group", error)
            throw error
        }
    }
}
