//
//  RoundSession+TeamShortcuts.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundSession {
    /// Keeps teams in sync with tee groups for shared-score formats (Captain's Choice).
    /// Creates/removes teams as needed and ensures every participant's teamID matches their groupID mapping.
    func syncTeamsToTeeGroups() async throws {
        guard snapshot.shouldAutoMirrorTeeGroupsToTeams else { return }

        let groups = snapshot.teeGroups.sorted { $0.index < $1.index }
        let existingTeams = snapshot.teams.sorted { $0.index < $1.index }

        var teamByGroupIndex: [Int: RoundTeam] = [:]
        for (index, team) in existingTeams.enumerated() where index < groups.count {
            teamByGroupIndex[index] = team
        }

        // Remove excess teams beyond group count (direct delete to avoid cascading participant unassignments)
        for team in existingTeams.dropFirst(groups.count) {
            snapshot.teams.removeAll { $0.id == team.id }
            _ = try? await team.delete().get()
        }

        // Create missing teams for each group
        for (i, _) in groups.enumerated() {
            if teamByGroupIndex[i] == nil {
                let team = try await createTeam(index: i + 1)
                teamByGroupIndex[i] = team
            }
        }

        // Assign participants to the team matching their tee group
        for var p in snapshot.participants {
            guard let groupID = p.groupID,
                  let groupIndex = groups.firstIndex(where: { $0.id == groupID }),
                  let team = teamByGroupIndex[groupIndex] else {
                if p.teamID != nil {
                    p.teamID = nil
                    try? await update(participant: p)
                }
                continue
            }
            if p.teamID != team.id {
                p.teamID = team.id
                try? await update(participant: p)
            }
        }
    }

    /// Creates one team per tee group; assigns each group's players to that team.
    /// Team names = "Team 1", "Team 2", etc.
    func mapTeeGroupsToTeams() async throws {
        addBreadcrumb()

        guard snapshot.teams.isEmpty,
              snapshot.teeGroups.isPopulated,
              snapshot.participants.count >= 2 else {
            return
        }

        let groups = snapshot.teeGroups.sorted { $0.index < $1.index }
        var assignedParticipantCount = 0

        for (i, group) in groups.enumerated() {
            let team = try await createTeam(index: i + 1)
            let playersInGroup = snapshot.participants.filter { $0.groupID == group.id }
            assignedParticipantCount += playersInGroup.count
            for var p in playersInGroup {
                p.teamID = team.id
                try await update(participant: p)
            }
        }

        emitRoundSetupEvent(
            "round_setup.team_shortcut_applied",
            extra: [
                "shortcut_type": "mirror_tee_groups",
                "created_team_count": groups.count,
                "assigned_participant_count": assignedParticipantCount
            ]
        )
    }

    /// Creates N teams and randomly distributes players.
    func randomizeTeams(count: Int) async throws {
        addBreadcrumb()

        guard snapshot.teams.isEmpty,
              snapshot.participants.count >= 2 else {
            return
        }

        let cap = snapshot.configuration.usesTeamColors
            ? min(snapshot.participants.count, TeamColor.cycle.count)
            : snapshot.participants.count
        let teamCount = min(max(2, count), cap)
        var teams: [RoundTeam] = []
        for i in 0..<teamCount {
            let team = try await createTeam(index: i + 1)
            teams.append(team)
        }

        let shuffled = snapshot.participants.shuffled()
        for (i, var p) in shuffled.enumerated() {
            p.teamID = teams[i % teamCount].id
            try await update(participant: p)
        }

        emitRoundSetupEvent(
            "round_setup.team_shortcut_applied",
            extra: [
                "shortcut_type": "randomize",
                "created_team_count": teamCount,
                "assigned_participant_count": shuffled.count
            ]
        )
    }

    /// Creates N teams and distributes so sum of HCP per team is as equal as possible (snake draft).
    func balanceTeams(count: Int) async throws {
        addBreadcrumb()

        guard snapshot.teams.isEmpty,
              snapshot.participants.count >= 2 else {
            return
        }

        let cap = snapshot.configuration.usesTeamColors
            ? min(snapshot.participants.count, TeamColor.cycle.count)
            : snapshot.participants.count
        let teamCount = min(max(2, count), cap)
        var teams: [RoundTeam] = []
        for i in 0..<teamCount {
            let team = try await createTeam(index: i + 1)
            teams.append(team)
        }

        let sorted = snapshot.participants.sorted { $0.adjustedHandicap < $1.adjustedHandicap }
        for (i, var p) in sorted.enumerated() {
            let teamIndex: Int
            let round = i / teamCount
            if round % 2 == 0 {
                teamIndex = i % teamCount
            } else {
                teamIndex = teamCount - 1 - (i % teamCount)
            }
            p.teamID = teams[teamIndex].id
            try await update(participant: p)
        }

        emitRoundSetupEvent(
            "round_setup.team_shortcut_applied",
            extra: [
                "shortcut_type": "balance",
                "created_team_count": teamCount,
                "assigned_participant_count": sorted.count
            ]
        )
    }
}
