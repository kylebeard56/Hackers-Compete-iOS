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

        for (i, group) in groups.enumerated() {
            let team = try await createTeam(index: i + 1)
            let playersInGroup = snapshot.participants.filter { $0.groupID == group.id }
            for var p in playersInGroup {
                p.teamID = team.id
                try await update(participant: p)
            }
        }
    }

    /// Creates N teams and randomly distributes players.
    func randomizeTeams(count: Int) async throws {
        addBreadcrumb()

        guard snapshot.teams.isEmpty,
              snapshot.participants.count >= 2 else {
            return
        }

        let teamCount = min(max(2, count), min(snapshot.participants.count, TeamColor.cycle.count))
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
    }

    /// Creates N teams and distributes so sum of HCP per team is as equal as possible (snake draft).
    func balanceTeams(count: Int) async throws {
        addBreadcrumb()

        guard snapshot.teams.isEmpty,
              snapshot.participants.count >= 2 else {
            return
        }

        let teamCount = min(max(2, count), min(snapshot.participants.count, TeamColor.cycle.count))
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
    }
}
