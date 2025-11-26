//
//  RoundService+TeeGroup.swift
//  Hackers
//
//  Created by Kyle Beard on 11/18/25.
//

import Foundation
import UIKit

extension RoundService {
    func createTeeGroup(_ group: TeeTimeGroup) async throws {
        addBreadcrumb(#function)
        
        do {
            snapshot.teeGroups.append(group)
            _ = try await group.put().get()
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
