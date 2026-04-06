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

    /// Synthetic team section for participants with no `teamID` (not a real series team).
    static let unassignedTeamSectionID = "unassigned"

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
        let teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let directTeamRows = result.rows.filter { $0.owner == .team && teamMap[$0.scoringUnitID] != nil }
        if directTeamRows.isPopulated {
            let isHighestWins = result.template.leaderboardSort == .highestWins
            let sortedRows = directTeamRows.sorted { lhs, rhs in
                if lhs.total != rhs.total {
                    return isHighestWins ? lhs.total > rhs.total : lhs.total < rhs.total
                }
                let nameA = teamMap[lhs.scoringUnitID]?.name ?? ""
                let nameB = teamMap[rhs.scoringUnitID]?.name ?? ""
                return nameA.localizedCaseInsensitiveCompare(nameB) == .orderedAscending
            }
            let baseRows: [LeaderboardRow] = sortedRows.map { row in
                LeaderboardRow(
                    scoringUnitID: row.scoringUnitID,
                    participantIDs: row.participantIDs,
                    owner: row.owner,
                    total: row.total,
                    holesPlayed: row.holesPlayed,
                    placeLabel: "",
                    isPinned: pinnedIDs.contains(row.scoringUnitID)
                )
            }
            let labels = computePlaceLabels(rows: baseRows, isHighestWins: isHighestWins)

            return sortedRows.compactMap { row in
                guard let team = teamMap[row.scoringUnitID] else { return nil }
                let leaderboardRow = LeaderboardRow(
                    scoringUnitID: row.scoringUnitID,
                    participantIDs: row.participantIDs,
                    owner: row.owner,
                    total: row.total,
                    holesPlayed: row.holesPlayed,
                    placeLabel: labels[row.scoringUnitID] ?? "-",
                    isPinned: pinnedIDs.contains(row.scoringUnitID)
                )
                return GroupedLeaderboardSection(
                    id: team.id,
                    name: team.name,
                    color: team.color,
                    rows: [leaderboardRow],
                    sectionTotal: row.total
                )
            }
        }

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
                id: unassignedTeamSectionID,
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
        participants: [RoundParticipant] = [],
        scoringGroups: [RoundScoringGroup] = []
    ) -> [MatchupLeaderboardSection] {
        let teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let participantMap = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let scoringGroupMap = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })

        return result.matchupResults.map { matchupResult in
            let isHighestWins = result.template.leaderboardSort == .highestWins
            let sortedByStanding = matchupResult.rows.sorted {
                isHighestWins ? $0.total > $1.total : $0.total < $1.total
            }
            var placeByUnit: [String: String] = [:]
            for (idx, row) in sortedByStanding.enumerated() {
                placeByUnit[row.scoringUnitID] = "\(idx + 1)."
            }

            let rowByUnit = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
            let pairingOrder = matchupResult.matchup.pairingIDs()
            var orderedRows: [ScoringRow] = pairingOrder.compactMap { rowByUnit[$0] }
            for row in matchupResult.rows where !pairingOrder.contains(row.scoringUnitID) {
                orderedRows.append(row)
            }

            let rows: [LeaderboardRow] = orderedRows.map { row in
                LeaderboardRow(
                    scoringUnitID: row.scoringUnitID,
                    participantIDs: row.participantIDs,
                    owner: row.owner,
                    total: row.total,
                    holesPlayed: row.holesPlayed,
                    placeLabel: placeByUnit[row.scoringUnitID] ?? "-",
                    isPinned: false
                )
            }

            let pairingIDs = matchupResult.matchup.pairingIDs()
            let nameA: String
            let nameB: String
            if matchupResult.matchup.mode == .individual {
                nameA = participantMap[pairingIDs.first ?? ""]?.name.fullName ?? "Player A"
                nameB = participantMap[pairingIDs.last ?? ""]?.name.fullName ?? "Player B"
            } else if matchupResult.matchup.mode == .scoreOwner {
                nameA = scoreOwnerName(
                    ownerID: pairingIDs.first ?? "",
                    scoringGroupMap: scoringGroupMap,
                    participantMap: participantMap
                )
                nameB = scoreOwnerName(
                    ownerID: pairingIDs.last ?? "",
                    scoringGroupMap: scoringGroupMap,
                    participantMap: participantMap
                )
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

    private static func scoreOwnerName(
        ownerID: String,
        scoringGroupMap: [String: RoundScoringGroup],
        participantMap: [String: RoundParticipant]
    ) -> String {
        guard let scoringGroup = scoringGroupMap[ownerID] else { return "Side" }
        if let label = scoringGroup.label, label.isPopulated {
            return label
        }
        let names = scoringGroup.memberIDs
            .compactMap { participantMap[$0]?.name.fullName }
            .filter(\.isPopulated)
        return names.isPopulated ? names.joined(separator: " + ") : "Side"
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
