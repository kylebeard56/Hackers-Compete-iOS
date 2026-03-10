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
    case matchupsIncomplete
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
        
        for participant in snapshot.participants {
            // 1. Append error if any player is not assigned to a tee group
            if participant.groupID.doesNotExist {
                errors.insert(.playerMissingFromTeeGroup)
            }
            
            // 2. Append error if any player is not assigned to a team
            if participant.teamID.doesNotExist && snapshot.requiresTeams {
                errors.insert(.playerMissingFromTeam)
            }
        }

        // 3. If competitionScope is matchup, require valid matchups for the current mode
        if snapshot.configuration.resolvedCompetitionScope == .matchup {
            let allMatchups = snapshot.roundSegment?.matchups ?? []
            let currentMode: MatchupMode = snapshot.requiresTeams ? .team : .individual
            let matchupsForMode = allMatchups.filter { ($0.mode ?? .team) == currentMode }
            let minMatchups = max(1, ((snapshot.requiresTeams ? snapshot.teams.count : snapshot.participants.count) + 1) / 2)
            let hasIncompleteMatchup = matchupsForMode.contains { !$0.isValid }
            if matchupsForMode.count < minMatchups || hasIncompleteMatchup {
                errors.insert(.matchupsIncomplete)
            }
        }
        
        // 4. Break early if any errors are populated and show sheet.
        if errors.isPopulated {
            roundActivationErrors = errors
            showRoundActivationErrors = true
            Haptics.fire(.error)
            return false
        }
        
        // 5. If all checks pass, cleanup and prune all empty teams or tee groups that were orphaned.
        do {
            let teeGroupCounts = Dictionary(grouping: snapshot.participants, by: \.groupID).mapValues(\.count)
            let teamCounts = Dictionary(grouping: snapshot.participants, by: \.teamID).mapValues(\.count)
            
            // Prune empty tee groups
            for (key, value) in teeGroupCounts {
                if let key, let group = snapshot.teeGroups.first(where: { $0.id == key }), value == 0 {
                    try await removeTeeGroup(group)
                }
            }
            
            // Prune empty teams
            for (key, value) in teamCounts {
                if let key, let team = snapshot.teams.first(where: { $0.id == key }), value == 0 {
                    try await removeTeam(team)
                }
            }
            
            // Prune all teams and remove teamIDs if prior set and no longer want teams
            if !snapshot.requiresTeams {
                for participant in snapshot.participants where participant.teamID.exists {
                    var p = participant
                    p.teamID = nil
                    _ = try await update(participant: p)
                }
                
                for team in snapshot.teams {
                    _ = try await removeTeam(team)
                }
            }

            // Prune orphaned or empty matchups (keep only valid pairings for both modes)
            if snapshot.configuration.resolvedCompetitionScope == .matchup,
               let mainSegment = snapshot.segments.first {
                let current = mainSegment.matchups ?? []
                let validMatchups = current.filter { $0.isValid }
                if validMatchups.count != current.count {
                    await setMatchups(validMatchups)
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
