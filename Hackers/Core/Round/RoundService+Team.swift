//
//  RoundService+Team.swift
//  Hackers
//
//  Created by Kyle Beard on 11/2/25.
//

import SwiftUI

extension RoundService {
    @discardableResult
    func createTeam(index: Int? = nil) async throws -> RoundTeam {
        addBreadcrumb(#function)
        
        let nextIndex = index ?? snapshot.teams.nextIndex
        let (teamColor, teamName) = TeamColor.teamValue(for: nextIndex)
        
        let newTeam = RoundTeam(
            id: HackersID.string(),
            name: teamName,
            color: teamColor.rawValue,
            index: nextIndex,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: snapshot.round.id
        )
        
        do {
            snapshot.teams.append(newTeam)
            return try await newTeam.put().get()
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to create new team", error)
            throw error
        }
    }
    
    /// Removes a team and unassigns all players from it
    func removeTeam(_ team: RoundTeam) async throws {
        addBreadcrumb(#function)

        do {
            // 1. Unassign participants locally + persist
            for participant in snapshot.participants {
                if participant.teamID == team.id {
                    var p = participant
                    p.teamID = nil
                    try await self.update(participant: p)
                }
            }

            // 2. Remove team locally
            snapshot.teams.removeAll { $0.id == team.id }

            // 3. Delete team remotely
            _ = try await team.delete().get()

            // 4. Reindex remaining teams sequentially
            let sorted = snapshot.teams.sorted { $0.index < $1.index }

            for (newIndexZeroBased, var t) in sorted.enumerated() {
                let newIndex = newIndexZeroBased + 1   // same pattern as tee groups: 1-based

                guard t.index != newIndex else { continue }

                t.index = newIndex

                // Persist update
                let updatedTeam = try await t.put().get()

                // Update local snapshot
                snapshot.teams.upsert(updatedTeam)
            }

        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to remove team", error)
            throw error
        }
    }
    
    func update(_ team: RoundTeam) async throws {
        addBreadcrumb(#function)
        
        do {
            let updatedTeam = try await team.put().get()
            snapshot.teams.upsert(updatedTeam)
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to update tee time for group", error)
            throw error
        }
    }
}
