//
//  LeaderboardBuilder.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation
import SwiftUI

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

// MARK: - Matchup Result Presentation

struct MatchupResultPresentation: Identifiable {
    let id: String
    let matchup: TeamMatchup
    let mode: MatchupMode
    let sides: [Side]
    let isPointsFormat: Bool
    let winningSideID: String?
    let isTie: Bool
    let title: String
    let scorelineDetail: String
    let marginDetail: String
    let countingScopeLabel: String?

    var hasCompleteSides: Bool {
        sides.count >= 2 && sides.allSatisfy { $0.total != nil }
    }

    func side(id: String) -> Side? {
        sides.first { $0.id == id }
    }

    struct Side: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let accentColor: Color?
        let total: Double?
        let scoreLabel: String
        let participants: [RoundParticipant]
        let countingParticipantIDs: Set<String>
        let countingScope: AggregationScope?
        let teamScoringMode: RoundTeamScoringMode

        var countsByRoundTotal: Bool {
            teamScoringMode != .all && countingScope == .perRound
        }

        func isParticipantActive(_ participant: RoundParticipant) -> Bool {
            guard countsByRoundTotal else { return true }
            return countingParticipantIDs.contains(participant.id)
        }
    }
}

struct MatchupResultPresentationBuilder {
    static func build(
        snapshot: RoundSnapshot,
        result: ScoringResult,
        section: MatchupLeaderboardSection,
        basis: ScoreBasis? = nil
    ) -> MatchupResultPresentation {
        let matchupResult = result.matchupResults.first { $0.matchup.id == section.matchup.id }
        return build(
            snapshot: snapshot,
            result: result,
            matchup: section.matchup,
            matchupRows: matchupResult?.rows ?? [],
            isPointsFormatOverride: matchupResult?.isPointsFormat,
            basis: basis
        )
    }

    static func build(
        snapshot: RoundSnapshot,
        result: ScoringResult,
        matchupResult: MatchupScoringResult,
        basis: ScoreBasis? = nil
    ) -> MatchupResultPresentation {
        build(
            snapshot: snapshot,
            result: result,
            matchup: matchupResult.matchup,
            matchupRows: matchupResult.rows,
            isPointsFormatOverride: matchupResult.isPointsFormat,
            basis: basis
        )
    }

    static func scoreLabel(for total: Double?, isPointsFormat: Bool) -> String {
        guard let total else { return "—" }
        if isPointsFormat {
            let roundedTenth = (total * 10).rounded() / 10
            if abs(roundedTenth - roundedTenth.rounded(.towardZero)) < 1e-9 {
                return "\(Int(roundedTenth.rounded(.towardZero)))"
            }
            return String(format: "%.1f", roundedTenth)
        }

        let value = Int(total.rounded())
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private static func build(
        snapshot: RoundSnapshot,
        result: ScoringResult,
        matchup: TeamMatchup,
        matchupRows: [ScoringRow],
        isPointsFormatOverride: Bool?,
        basis: ScoreBasis?
    ) -> MatchupResultPresentation {
        let mode = matchup.effectiveMode
        let isPointsFormat = isPointsFormatOverride
            ?? result.matchupResults.first(where: { $0.matchup.id == matchup.id })?.isPointsFormat
            ?? (result.template.leaderboardSort == .highestWins)
        let pairingIDs = matchup.pairingIDs()
        let teamScoring = snapshot.configuration.teamScoring
        let countingScope: AggregationScope? = teamScoring.mode == .all ? nil : teamScoring.scope
        let resolvedBasis = basis ?? snapshot.configuration.primaryFormat.configuration.basis

        let sides = pairingIDs.map { sideID in
            let participants = sideParticipants(sideID: sideID, mode: mode, snapshot: snapshot)
            let row = authoritativeAggregateRow(
                snapshot: snapshot,
                result: result,
                matchupRows: matchupRows,
                sideID: sideID,
                mode: mode,
                participants: participants,
                prefersMatchupRows: isPointsFormat,
                basis: resolvedBasis
            )
            let total = row?.total
            let countingParticipantIDs: [String]
            if let row {
                countingParticipantIDs = row.countingParticipantIDs
            } else if teamScoring.mode == .all || teamScoring.scope == .perHole {
                countingParticipantIDs = participants.map(\.id)
            } else {
                countingParticipantIDs = []
            }

            return MatchupResultPresentation.Side(
                id: sideID,
                title: sideName(sideID: sideID, mode: mode, snapshot: snapshot),
                subtitle: sideSubtitle(sideID: sideID, mode: mode, snapshot: snapshot),
                accentColor: sideAccentColor(sideID: sideID, mode: mode, snapshot: snapshot),
                total: total,
                scoreLabel: scoreLabel(for: total, isPointsFormat: isPointsFormat),
                participants: participants,
                countingParticipantIDs: Set(countingParticipantIDs),
                countingScope: countingScope,
                teamScoringMode: teamScoring.mode
            )
        }

        let completeSides = sides.filter { $0.total != nil }
        let sortedSides = completeSides.sorted {
            let lhs = $0.total ?? 0
            let rhs = $1.total ?? 0
            if abs(lhs - rhs) > 0.0001 {
                return isPointsFormat ? lhs > rhs : lhs < rhs
            }
            return $0.id < $1.id
        }

        let hasTwoCompleteSides = sides.count >= 2 && completeSides.count >= 2
        let isTie = hasTwoCompleteSides && completeSides.allSatisfy {
            abs(($0.total ?? 0) - (completeSides[0].total ?? 0)) < 0.0001
        }
        let winningSide = isTie ? nil : sortedSides.first
        let losingSide = winningSide.flatMap { winner in
            sortedSides.first { $0.id != winner.id }
        }

        let title: String
        let scorelineDetail: String
        let marginDetail: String
        if isTie, let first = sides.first {
            title = "Match tied"
            scorelineDetail = isPointsFormat ? "Tied at \(first.scoreLabel) pts" : "Tied at \(first.scoreLabel)"
            marginDetail = scorelineDetail
        } else if let winningSide, let losingSide {
            title = "\(winningSide.title) wins"
            scorelineDetail = "\(winningSide.scoreLabel) to \(losingSide.scoreLabel)"
            marginDetail = marginText(winning: winningSide, losing: losingSide, isPointsFormat: isPointsFormat)
        } else {
            title = "Matchup pending"
            scorelineDetail = "Waiting for both sides to post scores"
            marginDetail = scorelineDetail
        }

        return MatchupResultPresentation(
            id: matchup.id,
            matchup: matchup,
            mode: mode,
            sides: sides,
            isPointsFormat: isPointsFormat,
            winningSideID: winningSide?.id,
            isTie: isTie,
            title: title,
            scorelineDetail: scorelineDetail,
            marginDetail: marginDetail,
            countingScopeLabel: countingScopeLabel(for: teamScoring)
        )
    }

    private static func marginText(
        winning: MatchupResultPresentation.Side,
        losing: MatchupResultPresentation.Side,
        isPointsFormat: Bool
    ) -> String {
        let margin = abs((winning.total ?? 0) - (losing.total ?? 0))
        let formatted = String(format: isPointsFormat ? "%.1f" : "%.0f", margin)
        let trimmed = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        let unit = isPointsFormat ? (abs(margin - 1) < 0.0001 ? "pt" : "pts") : (abs(margin - 1) < 0.0001 ? "stroke" : "strokes")
        return "Won by \(trimmed) \(unit)"
    }

    private static func countingScopeLabel(for teamScoring: RoundTeamScoringConfiguration) -> String? {
        guard teamScoring.mode != .all else { return nil }
        let qualifier = teamScoring.mode == .worstN ? "Worst" : "Best"
        let scope = teamScoring.scope == .perRound ? "round" : "hole"
        return "\(qualifier) \(teamScoring.count) per \(scope)"
    }

    private static func expectedMatchupMode(for snapshot: RoundSnapshot) -> MatchupMode {
        snapshot.expectedMatchupMode
    }

    private static func authoritativeAggregateRow(
        snapshot: RoundSnapshot,
        result: ScoringResult,
        matchupRows: [ScoringRow],
        sideID: String,
        mode: MatchupMode,
        participants: [RoundParticipant],
        prefersMatchupRows: Bool,
        basis: ScoreBasis
    ) -> ScoringRow? {
        let matchupRow = aggregateScoringRow(
            in: matchupRows,
            matchesSideID: sideID,
            mode: mode,
            snapshot: snapshot
        )
        if prefersMatchupRows, let matchupRow, matchupRow.holesPlayed > 0 {
            return matchupRow
        }

        let exactRow = matchupRow ?? aggregateScoringRow(
            in: result.rows,
            matchesSideID: sideID,
            mode: mode,
            snapshot: snapshot
        )

        let directLookupIDs = directScoreLookupIDs(
            snapshot: snapshot,
            sideID: sideID,
            mode: mode,
            participants: participants
        )

        if hasDirectScoreEntry(snapshot: snapshot, scoringUnitIDs: directLookupIDs),
           let exactRow,
           exactRow.holesPlayed > 0 {
            return exactRow
        }
        if hasDirectScoreEntry(snapshot: snapshot, scoringUnitIDs: directLookupIDs),
           let directRow = directScoringUnitAggregateRow(
            snapshot: snapshot,
            template: result.template,
            sideID: sideID,
            scoringUnitIDs: directLookupIDs,
            mode: mode,
            participants: participants,
            basis: basis
           ) {
            return directRow
        }

        guard mode != .individual,
              let segment = snapshot.roundSegment else {
            return (exactRow?.holesPlayed ?? 0) > 0 ? exactRow : nil
        }

        let owner: ScoringOwner = mode.usesScoringGroupIDs ? .scoreOwner : .team
        let lookupSegmentIDs = snapshot.segmentScoreLookupSegmentIDs
        return ScoringEngine.computeParticipantGroupAggregateRow(
            scoringUnitID: sideID,
            owner: owner,
            participantIDs: participants.map(\.id),
            scores: snapshot.scoring,
            participants: snapshot.participants,
            segment: segment,
            holes: snapshot.defaultTee?.holes ?? [],
            basis: basis,
            scoreInputMode: snapshot.configuration.scoreInputMode,
            template: result.template,
            teamScoring: snapshot.configuration.teamScoring,
            scoreLookupSegmentIDs: lookupSegmentIDs.isEmpty ? nil : lookupSegmentIDs,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        ) ?? ((exactRow?.holesPlayed ?? 0) > 0 ? exactRow : nil)
    }

    private static func directScoreLookupIDs(
        snapshot: RoundSnapshot,
        sideID: String,
        mode: MatchupMode,
        participants: [RoundParticipant]
    ) -> Set<String> {
        var ids = Set([sideID])
        let participantIDs = Set(participants.map(\.id))

        switch mode {
        case .individual:
            break
        case .team:
            snapshot.segments
                .flatMap(\.scoringUnits)
                .filter { unit in
                    unit.owner == .team && (unit.id == sideID || unit.ownerIDs.contains(sideID))
                }
                .forEach { ids.insert($0.id) }
        case .partnership, .teeGroup, .scoreOwner:
            if let group = snapshot.scoringGroup(id: sideID) {
                ids.insert(group.id)
                if let teamID = group.teamID {
                    ids.insert(teamID)
                }
            }
            snapshot.scoringGroups
                .filter { group in
                    group.id == sideID || (participantIDs.isPopulated && Set(group.memberIDs) == participantIDs)
                }
                .forEach { ids.insert($0.id) }
            snapshot.segments
                .flatMap(\.scoringUnits)
                .filter { unit in
                    unit.owner == .scoreOwner
                        && (unit.id == sideID || unit.ownerIDs.contains(sideID) || (participantIDs.isPopulated && Set(unit.ownerIDs) == participantIDs))
                }
                .forEach { ids.insert($0.id) }
        }

        return ids.filter(\.isPopulated)
    }

    private static func hasDirectScoreEntry(snapshot: RoundSnapshot, scoringUnitIDs: Set<String>) -> Bool {
        snapshot.scoring.contains { entry in
            scoringUnitIDs.contains(entry.scoringUnitID)
                && (entry.strokes != nil || entry.relativeToPar != nil || entry.points != nil || entry.value != nil || entry.pickedUp)
        }
    }

    private static func directScoringUnitAggregateRow(
        snapshot: RoundSnapshot,
        template: GameTemplate,
        sideID: String,
        scoringUnitIDs: Set<String>,
        mode: MatchupMode,
        participants: [RoundParticipant],
        basis: ScoreBasis
    ) -> ScoringRow? {
        guard let segment = snapshot.roundSegment else { return nil }
        let lookupSegmentIDs = Set(snapshot.segmentScoreLookupSegmentIDs)
        let holeMap = Dictionary(uniqueKeysWithValues: (snapshot.defaultTee?.holes ?? []).map { ($0.number, $0) })
        let scoringUnit = directScoringUnit(
            snapshot: snapshot,
            sideID: sideID,
            scoringUnitIDs: scoringUnitIDs,
            mode: mode,
            participants: participants
        )
        let handicap = ScoringEngine.scoringUnitHandicap(
            for: scoringUnit,
            participants: participants,
            sharedScoreHandicapConfig: scoringUnit.owner == .participant
                ? nil
                : (snapshot.configuration.sharedScoreHandicapConfig ?? template.requirements.defaultHandicapConfig)
        )
        var holeValues: [Int: ScoringRow.HoleValue] = [:]
        var total = 0.0

        for holeNumber in segment.holeRange.holeNumbers {
            guard let entry = snapshot.scoring.first(where: {
                scoringUnitIDs.contains($0.scoringUnitID)
                    && $0.holeNumber == holeNumber
                    && (lookupSegmentIDs.isEmpty || lookupSegmentIDs.contains($0.segmentID))
            }) else { continue }

            let par = holeMap[holeNumber]?.par ?? 4
            guard let grossRelative = ScoringEngine.resolvedGrossRelativeToPar(entry: entry, par: par) else {
                continue
            }
            let strokesReceived = ScoringEngine.strokesReceived(
                handicap: handicap,
                holeNumber: holeNumber,
                holeMap: holeMap,
                playedHoleNumbers: segment.holeRange.holeNumbers,
                useHandicaps: basis == .net,
                handicapStrokeBasis: snapshot.handicapStrokeBasis
            )
            let rawStrokes = ScoringEngine.resolvedGrossStrokes(entry: entry, par: par)
            let netStrokes = rawStrokes.map { max(0, $0 - strokesReceived) }
            let points: Double
            if let entryPoints = entry.points {
                points = entryPoints
            } else {
                points = Double(basis == .net ? grossRelative - strokesReceived : grossRelative)
            }

            holeValues[holeNumber] = .init(
                rawStrokes: rawStrokes,
                netStrokes: basis == .net ? netStrokes : nil,
                points: points,
                pickedUp: entry.pickedUp
            )
            total += points
        }

        guard holeValues.isPopulated else { return nil }
        let owner = mode.scoringOwner
        let participantIDs = participants.map(\.id)
        return ScoringRow(
            scoringUnitID: sideID,
            participantIDs: participantIDs.isEmpty ? [sideID] : participantIDs,
            countingParticipantIDs: participantIDs.isEmpty ? [sideID] : participantIDs,
            owner: owner,
            holeValues: holeValues,
            total: total,
            holesPlayed: holeValues.count
        )
    }

    private static func directScoringUnit(
        snapshot: RoundSnapshot,
        sideID: String,
        scoringUnitIDs: Set<String>,
        mode: MatchupMode,
        participants: [RoundParticipant]
    ) -> ScoringUnit {
        if let scoringUnit = snapshot.segments
            .flatMap(\.scoringUnits)
            .first(where: { scoringUnitIDs.contains($0.id) }) {
            return scoringUnit
        }

        switch mode {
        case .individual:
            return ScoringUnit(id: sideID, owner: .participant, ownerIDs: [sideID], scoringMethod: .individual)
        case .team:
            return ScoringUnit(id: sideID, owner: .team, ownerIDs: [sideID], scoringMethod: .aggregate)
        case .partnership, .teeGroup, .scoreOwner:
            if let group = snapshot.scoringGroup(id: sideID) {
                return ScoringUnit(id: group.id, owner: .scoreOwner, ownerIDs: group.memberIDs, scoringMethod: .aggregate)
            }
            return ScoringUnit(id: sideID, owner: .scoreOwner, ownerIDs: participants.map(\.id), scoringMethod: .aggregate)
        }
    }

    private static func aggregateScoringRow(
        in rows: [ScoringRow],
        matchesSideID sideID: String,
        mode: MatchupMode,
        snapshot: RoundSnapshot
    ) -> ScoringRow? {
        rows.first { $0.scoringUnitID == sideID }
            ?? rows.first {
                aggregateScoringRowIdentityMatches(
                    scoringUnitID: $0.scoringUnitID,
                    owner: $0.owner,
                    participantIDs: $0.participantIDs,
                    sideID: sideID,
                    mode: mode,
                    snapshot: snapshot
                )
            }
    }

    private static func aggregateScoringRowIdentityMatches(
        scoringUnitID: String,
        owner: ScoringOwner,
        participantIDs: [String],
        sideID: String,
        mode: MatchupMode,
        snapshot: RoundSnapshot
    ) -> Bool {
        if scoringUnitID == sideID { return true }
        let scoringUnit = snapshot.roundSegment?.scoringUnits.first { $0.id == scoringUnitID }

        switch mode {
        case .individual:
            return participantIDs.contains(sideID)
        case .team:
            if let scoringUnit,
               scoringUnit.owner == .team,
               scoringUnit.ownerIDs.contains(sideID) {
                return true
            }
            guard owner == .team else { return false }
            let teamMemberIDs = Set(snapshot.participants.filter { $0.teamID == sideID }.map(\.id))
            return teamMemberIDs.isPopulated && Set(participantIDs) == teamMemberIDs
        case .partnership, .teeGroup, .scoreOwner:
            if let scoringUnit,
               scoringUnit.owner == .scoreOwner {
                if scoringUnit.ownerIDs.contains(sideID) { return true }
                if let group = snapshot.scoringGroup(id: sideID) {
                    return Set(scoringUnit.ownerIDs) == Set(group.memberIDs)
                }
            }
            guard owner == .scoreOwner,
                  let group = snapshot.scoringGroup(id: sideID) else { return false }
            return Set(participantIDs) == Set(group.memberIDs)
        }
    }

    private static func sideName(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> String {
        switch mode {
        case .team:
            return snapshot.teams.first(where: { $0.id == sideID })?.name ?? "Team"
        case .individual:
            return snapshot.participants.first(where: { $0.id == sideID })?.name.fullName ?? "Player"
        case .partnership, .teeGroup, .scoreOwner:
            if let group = snapshot.scoringGroup(id: sideID) {
                if let teamID = group.teamID,
                   let team = snapshot.teams.first(where: { $0.id == teamID }) {
                    return team.name
                }
                if let label = group.label, label.isPopulated {
                    return label
                }
                let names = sideParticipants(sideID: sideID, mode: mode, snapshot: snapshot)
                    .map(\.name.fullName)
                    .filter(\.isPopulated)
                return names.isPopulated ? names.joined(separator: " + ") : "Side"
            }
            return "Side"
        }
    }

    private static func sideSubtitle(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> String? {
        switch mode {
        case .individual:
            return nil
        case .team, .partnership, .teeGroup, .scoreOwner:
            let names = sideParticipants(sideID: sideID, mode: mode, snapshot: snapshot)
                .map(\.name.fullName)
                .filter(\.isPopulated)
            return names.isPopulated ? names.joined(separator: ", ") : nil
        }
    }

    private static func sideAccentColor(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> Color? {
        switch mode {
        case .team:
            return snapshot.teams.first(where: { $0.id == sideID })?.displaySwatchColor
        case .individual:
            return snapshot.participants
                .first(where: { $0.id == sideID })?
                .teamID
                .flatMap { teamID in snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor }
        case .partnership, .teeGroup, .scoreOwner:
            guard let group = snapshot.scoringGroup(id: sideID),
                  let teamID = group.teamID else { return nil }
            return snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor
        }
    }

    private static func sideParticipants(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> [RoundParticipant] {
        let participants: [RoundParticipant]
        switch mode {
        case .team:
            participants = snapshot.participants.filter { $0.teamID == sideID && $0.isPresenceActive }
        case .individual:
            participants = snapshot.participants.filter { $0.id == sideID && $0.isPresenceActive }
        case .partnership, .teeGroup, .scoreOwner:
            guard let group = snapshot.scoringGroup(id: sideID) else { return [] }
            let memberIDs = Set(group.memberIDs)
            participants = snapshot.participants.filter { memberIDs.contains($0.id) && $0.isPresenceActive }
        }

        return participants.sorted {
            let lhs = $0.teeOrder ?? Int.max
            let rhs = $1.teeOrder ?? Int.max
            if lhs != rhs { return lhs < rhs }
            return $0.alphabeticName < $1.alphabeticName
        }
    }
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
            let isHighestWins = matchupResult.isPointsFormat ?? (result.template.leaderboardSort == .highestWins)
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
            if matchupResult.matchup.effectiveMode == .individual {
                nameA = participantMap[pairingIDs.first ?? ""]?.name.fullName ?? "Player A"
                nameB = participantMap[pairingIDs.last ?? ""]?.name.fullName ?? "Player B"
            } else if matchupResult.matchup.effectiveMode.usesScoringGroupIDs {
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
