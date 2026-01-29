//
//  RoundSession+Activate.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/26.
//

import SwiftUI

enum RoundActivationError: String, CaseIterable {
    case playerMissingFromTeam
    case playerMissingFromTeeGroup
    case unknown
}

extension RoundSession {
    // [PRE-MVP] TODO: Add metric comments for where we want to measure usage using posthog.
    // Use prefix [POSTHOG]
    // Search for addBreadcrumb, likely overlap. Need button taps though as well.
    
    func activateLiveRound() async -> Bool {
        addBreadcrumb()
        
        isStartingLiveRound = true
        defer { isStartingLiveRound = false }
        
        var errors: Set<RoundActivationError> = .init()
        
        for p in snapshot.participants {
            // 1. Append error if any player is not assigned to a tee group
            if p.groupID.doesNotExist {
                errors.insert(.playerMissingFromTeeGroup)
            }
            
            // 2. Append error if any player is not assigned to a team
            if p.teamID.doesNotExist && snapshot.requiresTeams {
                errors.insert(.playerMissingFromTeam)
            }
        }
        
        // 3. Break early if any errors are populated and show sheet.
        if errors.isPopulated {
            roundActivationErrors = errors
            showRoundActivationErrors = true
            Haptics.fire(.error)
            return false
        }
        
        // 4. If all checks pass, cleanup and prune all empty teams or tee groups that were orphaned.
        do {
            let teeGroupCounts = Dictionary(grouping: snapshot.participants, by: \.groupID).mapValues(\.count)
            let teamCounts = Dictionary(grouping: snapshot.participants, by: \.teamID).mapValues(\.count)
            
            for (key, value) in teeGroupCounts {
                if let key, let group = snapshot.teeGroups.first(where: { $0.id == key }), value == 0 {
                    try await removeTeeGroup(group)
                }
            }
            
            for (key, value) in teamCounts {
                if let key, let team = snapshot.teams.first(where: { $0.id == key }), value == 0 {
                    try await removeTeam(team)
                }
            }
            
            snapshot.round.status = .live
            snapshot.round = try await snapshot.round.put().get()
            return true
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to prune round session prior to activation to live",
                error: error,
                parameters: [
                    "Round ID": snapshot.round.id
                ]
            )
            Haptics.fire(.error)
            return false
        }
    }
}
