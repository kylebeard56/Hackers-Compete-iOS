//
//  LeaderboardBuilder.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Leaderboard Row

struct LeaderboardRow: Identifiable {
    var id: String { scoringUnitID }
    let scoringUnitID: String
    let participantIDs: [String]
    let owner: ScoringOwner
    let total: Double
    let holesPlayed: Int
    let placeLabel: String
    let isPinned: Bool
}

// MARK: - Grouped Leaderboard Section

struct GroupedLeaderboardSection: Identifiable {
    let id: String
    let name: String
    let color: String?
    let rows: [LeaderboardRow]
    let sectionTotal: Double
}

// MARK: - Matchup Leaderboard Section

struct MatchupLeaderboardSection: Identifiable {
    let id: String
    let matchup: TeamMatchup
    let name: String
    let rows: [LeaderboardRow]
}

// MARK: - Leaderboard Builder

/// Takes ScoringResult and produces sorted, ranked, place-labeled leaderboard rows.
struct LeaderboardBuilder {

    static func buildIndividualLeaderboard(
        result: ScoringResult,
        participants: [RoundParticipant],
        pinnedIDs: Set<String> = []
    ) -> [LeaderboardRow] {
        let participantMap = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })

        var rows: [LeaderboardRow] = result.rows.compactMap { row in
            guard participantMap[row.scoringUnitID] != nil else { return nil }
            return LeaderboardRow(
                scoringUnitID: row.scoringUnitID,
                participantIDs: row.participantIDs,
                owner: row.owner,
                total: row.total,
                holesPlayed: row.holesPlayed,
                placeLabel: "",
                isPinned: pinnedIDs.contains(row.scoringUnitID)
            )
        }

        let isHighestWins = result.template.leaderboardSort == .highestWins
        rows.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            if lhs.total != rhs.total {
                return isHighestWins ? lhs.total > rhs.total : lhs.total < rhs.total
            }
            let nameA = participantMap[lhs.scoringUnitID]?.alphabeticName ?? ""
            let nameB = participantMap[rhs.scoringUnitID]?.alphabeticName ?? ""
            return nameA < nameB
        }

        let labels = computePlaceLabels(rows: rows, isHighestWins: isHighestWins)
        return rows.map { row in
            LeaderboardRow(
                scoringUnitID: row.scoringUnitID,
                participantIDs: row.participantIDs,
                owner: row.owner,
                total: row.total,
                holesPlayed: row.holesPlayed,
                placeLabel: labels[row.scoringUnitID] ?? "-",
                isPinned: row.isPinned
            )
        }
    }

    static func buildTeamSections(
        result: ScoringResult,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        pinnedIDs: Set<String> = []
    ) -> [GroupedLeaderboardSection] {
        let individualRows = buildIndividualLeaderboard(
            result: result, participants: participants, pinnedIDs: pinnedIDs
        )
        let grouped = Dictionary(grouping: individualRows) { row in
            participants.first { $0.id == row.scoringUnitID }?.teamID
        }
        let orderedTeams = teams.sorted { $0.index < $1.index }

        var sections: [GroupedLeaderboardSection] = []
        for team in orderedTeams {
            let teamRows = grouped[team.id] ?? []
            guard !teamRows.isEmpty else { continue }
            sections.append(GroupedLeaderboardSection(
                id: team.id,
                name: team.name,
                color: team.color,
                rows: teamRows,
                sectionTotal: teamRows.reduce(0) { $0 + $1.total }
            ))
        }

        if let unassigned = grouped[nil], !unassigned.isEmpty {
            sections.append(GroupedLeaderboardSection(
                id: "unassigned",
                name: "Unassigned",
                color: nil,
                rows: unassigned,
                sectionTotal: unassigned.reduce(0) { $0 + $1.total }
            ))
        }

        return sections.sorted { $0.sectionTotal < $1.sectionTotal }
    }

    static func buildTeeGroupSections(
        result: ScoringResult,
        participants: [RoundParticipant],
        teeGroups: [TeeTimeGroup],
        pinnedIDs: Set<String> = []
    ) -> [GroupedLeaderboardSection] {
        let individualRows = buildIndividualLeaderboard(
            result: result, participants: participants, pinnedIDs: pinnedIDs
        )
        let grouped = Dictionary(grouping: individualRows) { row in
            participants.first { $0.id == row.scoringUnitID }?.groupID
        }
        let orderedGroups = teeGroups.sorted { $0.index < $1.index }

        var sections: [GroupedLeaderboardSection] = []
        for group in orderedGroups {
            let groupRows = grouped[group.id] ?? []
            guard !groupRows.isEmpty else { continue }
            sections.append(GroupedLeaderboardSection(
                id: group.id,
                name: group.name,
                color: nil,
                rows: groupRows,
                sectionTotal: groupRows.reduce(0) { $0 + $1.total }
            ))
        }

        if let ungrouped = grouped[nil], !ungrouped.isEmpty {
            sections.append(GroupedLeaderboardSection(
                id: "ungrouped",
                name: "Ungrouped",
                color: nil,
                rows: ungrouped,
                sectionTotal: ungrouped.reduce(0) { $0 + $1.total }
            ))
        }

        return sections
    }

    // MARK: - Matchup Leaderboard

    /// Builds a leaderboard section per matchup pairing, each containing the two rows.
    static func buildMatchupSections(
        result: ScoringResult,
        teams: [RoundTeam],
        participants: [RoundParticipant] = []
    ) -> [MatchupLeaderboardSection] {
        let teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let participantMap = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })

        return result.matchupResults.map { matchupResult in
            let isHighestWins = result.template.leaderboardSort == .highestWins
            let sorted = matchupResult.rows.sorted {
                isHighestWins ? $0.total > $1.total : $0.total < $1.total
            }

            let rows: [LeaderboardRow] = sorted.enumerated().map { (idx, row) in
                LeaderboardRow(
                    scoringUnitID: row.scoringUnitID,
                    participantIDs: row.participantIDs,
                    owner: row.owner,
                    total: row.total,
                    holesPlayed: row.holesPlayed,
                    placeLabel: "\(idx + 1).",
                    isPinned: false
                )
            }

            let pairingIDs = matchupResult.matchup.pairingIDs()
            let nameA: String
            let nameB: String
            if matchupResult.matchup.mode == .individual {
                nameA = participantMap[pairingIDs.first ?? ""]?.name.fullName ?? "Player A"
                nameB = participantMap[pairingIDs.last ?? ""]?.name.fullName ?? "Player B"
            } else {
                nameA = teamMap[pairingIDs.first ?? ""]?.name ?? "Team A"
                nameB = teamMap[pairingIDs.last ?? ""]?.name ?? "Team B"
            }

            return MatchupLeaderboardSection(
                id: matchupResult.matchup.id,
                matchup: matchupResult.matchup,
                name: "\(nameA) vs \(nameB)",
                rows: rows
            )
        }
    }

    // MARK: - Place Labels

    private static func computePlaceLabels(rows: [LeaderboardRow], isHighestWins: Bool) -> [String: String] {
        let sorted = rows.filter { !$0.isPinned }.sorted {
            isHighestWins ? $0.total > $1.total : $0.total < $1.total
        }

        var labels: [String: String] = [:]
        var place = 1
        var index = 0

        while index < sorted.count {
            let score = sorted[index].total
            var group: [LeaderboardRow] = []

            while index < sorted.count, sorted[index].total == score {
                group.append(sorted[index])
                index += 1
            }

            let label = group.count > 1 ? "T-\(place)." : "\(place)."
            for row in group {
                labels[row.scoringUnitID] = label
            }
            place += group.count
        }

        return labels
    }
}
