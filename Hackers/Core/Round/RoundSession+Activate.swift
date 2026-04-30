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
    case scoringGroupsIncomplete
    case scoringGroupsInvalidReferences
    case matchupsIncomplete
    case matchupInvalidReferences
    case courseSegmentMismatch
    case vegasConfigurationInvalid
    case unknown
}

extension RoundSession {
    // [PRE-MVP] TODO: Add metric comments for where we want to measure usage using posthog.
    // Use prefix [POSTHOG]
    // Search for addBreadcrumb, likely overlap. Need button taps though as well.
    
    func activateLiveRound() async -> Bool {
        addBreadcrumb()
        emitRoundSetupEvent("round_setup.round_start_attempted")
        
        isStartingLiveRound = true
        defer { isStartingLiveRound = false }

        do {
            try await pruneEmptyOrganizationArtifacts()
        } catch {
            addBreadcrumb(
                level: .error,
                message: "Failed to prune round session prior to activation validation",
                error: error,
                parameters: [
                    "Round ID": snapshot.round.id
                ]
            )
            Haptics.fire(.error)
            return false
        }
        
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

        if snapshot.primarySegmentHoleRangeMismatch != nil {
            errors.insert(.courseSegmentMismatch)
        }

        if snapshot.isVegasFormat {
            let participantsByTeam = Dictionary(grouping: snapshot.participants.compactMap { participant -> (String, RoundParticipant)? in
                guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
                return (teamID, participant)
            }, by: \.0).mapValues { $0.map(\.1) }
            let populatedTeams = participantsByTeam.filter { !$0.value.isEmpty }
            let participantCount = snapshot.participants.count

            if participantCount < 4 || participantCount % 2 != 0 || populatedTeams.count < 2 {
                errors.insert(.vegasConfigurationInvalid)
            } else {
                switch snapshot.configuration.resolvedVegasMode {
                case .exactPair:
                    if populatedTeams.contains(where: { $0.value.count != 2 }) {
                        errors.insert(.vegasConfigurationInvalid)
                    }
                case .partnershipAggregate:
                    let partnerships = snapshot.scoringGroups.filter { $0.kind == .partnership }
                    let partnershipsByTeam = Dictionary(grouping: partnerships.compactMap { group -> (String, RoundScoringGroup)? in
                        guard let teamID = group.teamID, teamID.isPopulated else { return nil }
                        return (teamID, group)
                    }, by: \.0).mapValues { $0.map(\.1) }

                    let invalidTeam = populatedTeams.contains { teamID, members in
                        if members.count == 2 { return false }
                        if members.count < 2 || members.count % 2 != 0 { return true }
                        let teamMemberIDs = Set(members.map(\.id))
                        let teamPartnerships = partnershipsByTeam[teamID] ?? []
                        let coveredIDs = teamPartnerships.reduce(into: Set<String>()) { partial, partnership in
                            partnership.memberIDs.forEach { partial.insert($0) }
                        }
                        let duplicateMemberships = teamPartnerships.flatMap(\.memberIDs).count != coveredIDs.count
                        let mismatchedPair = teamPartnerships.contains {
                            $0.memberIDs.count != 2 || !Set($0.memberIDs).subtracting(teamMemberIDs).isEmpty
                        }
                        return duplicateMemberships || mismatchedPair || coveredIDs != teamMemberIDs
                    }

                    if invalidTeam {
                        errors.insert(.vegasConfigurationInvalid)
                    }
                case .selectedPair:
                    if snapshot.round.configuration.vegasSelectionRule == nil || snapshot.round.configuration.vegasSelectionScope == nil {
                        errors.insert(.vegasConfigurationInvalid)
                    }
                    if populatedTeams.contains(where: { $0.value.count < 2 }) {
                        errors.insert(.vegasConfigurationInvalid)
                    }
                }
            }
        }

        let allMatchups = snapshot.roundSegment?.matchups ?? []
        let hasExplicitScoreOwnerMatchups = allMatchups.contains { ($0.mode ?? .team) == .scoreOwner }

        // 3. Validate score-owner group setup whenever the round config or explicit matchups depend on it.
        if snapshot.configuration.scoreOwnerScope != .individual || hasExplicitScoreOwnerMatchups {
            let participantIDs = Set(snapshot.participants.map(\.id))
            let participantByID = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })

            if snapshot.scoringGroups.isEmpty {
                errors.insert(.scoringGroupsIncomplete)
            }

            let invalidScoringGroup = snapshot.scoringGroups.contains { group in
                let members = group.memberIDs.compactMap { participantByID[$0] }
                guard members.count == group.memberIDs.count else { return true }

                let memberTeamIDs = Set(members.compactMap(\.teamID).filter(\.isPopulated))
                let memberTeeGroupIDs = Set(members.compactMap(\.groupID).filter(\.isPopulated))

                switch group.kind {
                case .partnership:
                    guard group.memberIDs.count == 2 else { return true }
                    if memberTeamIDs.count != 1 || memberTeeGroupIDs.count != 1 {
                        return true
                    }
                    if let teamID = group.teamID, teamID.isPopulated, teamID != memberTeamIDs.first {
                        return true
                    }
                    if let teeGroupID = group.teeGroupID, teeGroupID.isPopulated, teeGroupID != memberTeeGroupIDs.first {
                        return true
                    }
                    return false
                case .teeGroup:
                    guard group.memberIDs.count >= 2 else { return true }
                    guard memberTeeGroupIDs.count == 1, let resolvedGroupID = memberTeeGroupIDs.first else {
                        return true
                    }
                    if let teeGroupID = group.teeGroupID, teeGroupID.isPopulated, teeGroupID != resolvedGroupID {
                        return true
                    }
                    return false
                }
            }

            if invalidScoringGroup || snapshot.scoringGroups.contains(where: { !$0.memberIDs.allSatisfy(participantIDs.contains) }) {
                errors.insert(.scoringGroupsInvalidReferences)
            }
        }

        if snapshot.configuration.resolvedCompetitionScope == .matchup {
            let currentMode = snapshot.expectedMatchupMode
            let matchupsForMode = allMatchups.filter { ($0.mode ?? .team) == currentMode }
            let validMatchups = matchupsForMode.filter(\.isValid)
            let hasSingleSidedMatchup = matchupsForMode.contains { $0.pairingIDs().count == 1 }
            if validMatchups.isEmpty || hasSingleSidedMatchup {
                errors.insert(.matchupsIncomplete)
            }

            let teamIds = Set(snapshot.teams.map(\.id))
            let participantIds = Set(snapshot.participants.map(\.id))
            let scoringGroupIDs = Set(snapshot.scoringGroups.map(\.id))
            let invalidReference = matchupsForMode.contains { m in
                guard m.isValid else { return false }
                switch m.mode ?? .team {
                case .team:
                    return m.teamIDs.contains { !teamIds.contains($0) }
                case .individual:
                    return (m.participantIDs ?? []).contains { !participantIds.contains($0) }
                case .scoreOwner:
                    return (m.scoreOwnerIDs ?? []).contains { !scoringGroupIDs.contains($0) }
                }
            }
            if invalidReference {
                errors.insert(.matchupInvalidReferences)
            }
        }
        
        // 4. Break early if any errors are populated and show sheet.
        if errors.isPopulated {
            roundActivationErrors = errors
            showRoundActivationErrors = true
            Haptics.fire(.error)
            emitRoundSetupEvent(
                "round_setup.round_start_blocked",
                extra: [
                    "blocking_errors": errors.map(\.rawValue).sorted(),
                    "blocking_error_count": errors.count
                ]
            )
            return false
        }
        
        // 5. If all checks pass, cleanup and prune all empty teams or tee groups that were orphaned.
        do {
            try await pruneEmptyOrganizationArtifacts()
            
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

            snapshot.round.status = .live
            snapshot.round = try await snapshot.round.put().get()
            addEvent(
                "round.live_started",
                eventProps: roundSetupEventProps(
                    extra: [
                        "round_status": snapshot.round.status.rawValue
                    ]
                )
            )
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

    private func pruneEmptyOrganizationArtifacts() async throws {
        let plan = SeriesRoundSyncPlanning.organizationPrunePlan(snapshot: snapshot)
        guard plan.hasAny else { return }

        for group in plan.teeGroupsToDelete {
            try await removeTeeGroup(group)
        }

        for team in plan.teamsToDelete {
            try await removeTeam(team)
        }

        for group in plan.scoringGroupsToDelete {
            _ = try await group.delete().get()
            snapshot.scoringGroups.removeAll { $0.id == group.id }
        }

        if plan.didPruneMatchups {
            await setMatchups(plan.retainedMatchups)
        }
    }
}
