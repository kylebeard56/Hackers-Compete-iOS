//
//  ScoringEngine+Stages.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Selection Resolver

/// Executes ScoringStage.select: sorts scores by value within a group and applies rank filters.
struct SelectionResolver {

    /// Apply rank-based selection to per-participant hole values.
    /// For team subjects, groups participants by team and selects within each team.
    static func apply(
        selection: RankSelection,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int],
        subject: ScoringSubject,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        selectionGroups: [String: [String]] = [:]
    ) -> [String: [Int: PipelineHoleValue]] {
        guard subject == .team || subject == .competitionSide else {
            return values
        }

        let grouping = selectionGroups.isPopulated
            ? selectionGroups
            : Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
                guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
                return (teamID, participant.id)
            }, by: \.0).mapValues { $0.map(\.1) }

        guard grouping.isPopulated else { return values }

        if selection.scope == .perRound {
            return applyPerRound(
                selection: selection,
                values: values,
                holeNumbers: holeNumbers,
                grouping: grouping
            )
        }

        var result: [String: [Int: PipelineHoleValue]] = [:]

        for (groupID, memberIDs) in grouping where groupID.isPopulated {
            var teamHoles: [Int: PipelineHoleValue] = [:]

            for holeNumber in holeNumbers {
                var holeScores: [(String, PipelineHoleValue)] = []
                for memberID in memberIDs {
                    if let val = values[memberID]?[holeNumber] {
                        holeScores.append((memberID, val))
                    }
                }

                holeScores.sort { $0.1.points < $1.1.points }

                let selected = filterByRanks(
                    sorted: holeScores,
                    includeRanks: selection.includeRanks,
                    excludeRanks: selection.excludeRanks
                )

                if !selected.isEmpty {
                    let totalPoints = selected.reduce(0.0) { $0 + $1.1.points }
                    let bestEntry = selected[0].1
                    teamHoles[holeNumber] = PipelineHoleValue(
                        participantID: groupID,
                        grossStrokes: bestEntry.grossStrokes,
                        netStrokes: bestEntry.netStrokes,
                        par: bestEntry.par,
                        scoreToPar: Int(totalPoints),
                        points: totalPoints,
                        pickedUp: false
                    )
                }
            }

            result[groupID] = teamHoles
        }

        return result
    }

    private static func applyPerRound(
        selection: RankSelection,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int],
        grouping: [String: [String]]
    ) -> [String: [Int: PipelineHoleValue]] {
        var result: [String: [Int: PipelineHoleValue]] = [:]

        for (groupID, memberIDs) in grouping where groupID.isPopulated {
            let totals = memberIDs.compactMap { memberID -> (String, Double)? in
                guard let holeMap = values[memberID] else { return nil }
                let total = holeNumbers.compactMap { holeMap[$0]?.points }.reduce(0, +)
                return (memberID, total)
            }
            let ordered = totals.sorted {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return $0.0 < $1.0
            }
            let selected = filterByRanks(
                sorted: ordered.compactMap { participantID, _ in
                    guard let firstValue = values[participantID]?.values.first else { return nil }
                    return (participantID, firstValue)
                },
                includeRanks: selection.includeRanks,
                excludeRanks: selection.excludeRanks
            ).map(\.0)
            guard selected.isPopulated else { continue }

            var teamHoles: [Int: PipelineHoleValue] = [:]
            for holeNumber in holeNumbers {
                let selectedValues = selected.compactMap { values[$0]?[holeNumber] }
                guard selectedValues.isPopulated else { continue }
                let totalPoints = selectedValues.reduce(0.0) { $0 + $1.points }
                let representative = selectedValues[0]
                teamHoles[holeNumber] = PipelineHoleValue(
                    participantID: groupID,
                    grossStrokes: representative.grossStrokes,
                    netStrokes: representative.netStrokes,
                    par: representative.par,
                    scoreToPar: Int(totalPoints),
                    points: totalPoints,
                    pickedUp: false
                )
            }
            result[groupID] = teamHoles
        }

        return result
    }

    static func filterByRanks(
        sorted: [(String, PipelineHoleValue)],
        includeRanks: [Int]?,
        excludeRanks: [Int]?
    ) -> [(String, PipelineHoleValue)] {
        if let include = includeRanks, !include.isEmpty {
            return include.compactMap { rank in
                let idx = rank - 1
                guard idx >= 0 && idx < sorted.count else { return nil }
                return sorted[idx]
            }
        }
        if let exclude = excludeRanks, !exclude.isEmpty {
            return sorted.enumerated().compactMap { (idx, element) in
                exclude.contains(idx + 1) ? nil : element
            }
        }
        return sorted
    }
}

// MARK: - Points Transformer

/// Executes ScoringStage.transform: maps strokes to points via the configured PointsMap.
struct PointsTransformer {

    static func apply(
        pointsMap: PointsMap,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int]
    ) -> [String: [Int: PipelineHoleValue]] {
        var result = values
        for (unitID, holeMap) in values {
            var updatedHoles = holeMap
            for holeNumber in holeNumbers {
                guard var val = holeMap[holeNumber] else { continue }
                val.points = computePoints(pointsMap: pointsMap, value: val)
                updatedHoles[holeNumber] = val
            }
            result[unitID] = updatedHoles
        }
        return result
    }

    static func computePoints(pointsMap: PointsMap, value: PipelineHoleValue) -> Double {
        switch pointsMap.mode {
        case .parRelative:
            guard let entries = pointsMap.entries else { return 0 }
            let scoreToPar = value.scoreToPar
            if let match = entries.first(where: { $0.scoreToPar == scoreToPar }) {
                return match.points
            }
            if let worst = entries.max(by: { $0.scoreToPar < $1.scoreToPar }), scoreToPar > worst.scoreToPar {
                return worst.points
            }
            if let best = entries.min(by: { $0.scoreToPar < $1.scoreToPar }), scoreToPar < best.scoreToPar {
                return best.points
            }
            return 0

        case .parDependent:
            let multiplier = pointsMap.parMultiplier ?? 1.0
            return Double(value.par) * multiplier

        case .fixed:
            return 1.0

        case .custom:
            return value.points
        }
    }
}

// MARK: - Modifier Applicator

/// Executes ScoringStage.modify: evaluates predicates and applies effects.
struct ModifierApplicator {

    static func apply(
        modifier: ConditionalModifier,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int]
    ) -> [String: [Int: PipelineHoleValue]] {
        guard modifier.scope == .perHole else {
            return applyPerRound(modifier: modifier, values: values, holeNumbers: holeNumbers)
        }

        var result = values
        for (unitID, holeMap) in values {
            var updatedHoles = holeMap
            for holeNumber in holeNumbers {
                guard var val = holeMap[holeNumber] else { continue }
                if evaluatePredicate(modifier.predicate, value: val) {
                    val.points = modifier.effect.apply(to: val.points)
                    updatedHoles[holeNumber] = val
                }
            }
            result[unitID] = updatedHoles
        }
        return result
    }

    private static func applyPerRound(
        modifier: ConditionalModifier,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int]
    ) -> [String: [Int: PipelineHoleValue]] {
        var result = values
        for (unitID, holeMap) in values {
            let totalPoints = holeNumbers.compactMap { holeMap[$0]?.points }.reduce(0, +)
            let avgScoreToPar = holeNumbers.compactMap { holeMap[$0]?.scoreToPar }.reduce(0, +)
            let syntheticValue = PipelineHoleValue(
                participantID: unitID, grossStrokes: 0, netStrokes: 0,
                par: 0, scoreToPar: avgScoreToPar, points: totalPoints, pickedUp: false
            )
            if evaluatePredicate(modifier.predicate, value: syntheticValue) {
                var updatedHoles = holeMap
                for holeNumber in holeNumbers {
                    guard var val = holeMap[holeNumber] else { continue }
                    val.points = modifier.effect.apply(to: val.points)
                    updatedHoles[holeNumber] = val
                }
                result[unitID] = updatedHoles
            }
        }
        return result
    }

    static func evaluatePredicate(_ predicate: ScoringPredicate, value: PipelineHoleValue) -> Bool {
        switch predicate {
        case .scoreToPar(let op, let threshold):
            return op.evaluate(value.scoreToPar, threshold)

        case .rawStrokes(let op, let threshold):
            return op.evaluate(value.grossStrokes, threshold)

        case .allPlayersMatch:
            return evaluatePredicate(predicate, value: value)

        case .eventOccurred:
            return false
        }
    }
}

// MARK: - Reduction Resolver

/// Executes ScoringStage.reduce: combines multiple values into aggregate scores.
struct ReductionResolver {

    static func apply(
        reduction: Reduction,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int]
    ) -> [String: [Int: PipelineHoleValue]] {
        guard reduction.scope == .perRound else {
            return values
        }

        var result = values
        for (unitID, holeMap) in values {
            let allPoints = holeNumbers.compactMap { holeMap[$0]?.points }
            guard !allPoints.isEmpty else { continue }

            let reduced: Double
            switch reduction.mode {
            case .sum:        reduced = allPoints.reduce(0, +)
            case .average:    reduced = allPoints.reduce(0, +) / Double(allPoints.count)
            case .min:        reduced = allPoints.min() ?? 0
            case .max:        reduced = allPoints.max() ?? 0
            case .difference:
                if allPoints.count >= 2 {
                    reduced = allPoints[0] - allPoints[1]
                } else {
                    reduced = allPoints.first ?? 0
                }
            }

            // For .sum, leave per-hole points unchanged so buildScoringRows sums correctly.
            // Overwriting with reduced/holeCount would incorrectly average over the full round.
            guard reduction.mode != .sum else { continue }

            var updatedHoles = holeMap
            for holeNumber in holeNumbers {
                guard var val = holeMap[holeNumber] else { continue }
                val.points = reduced / Double(holeNumbers.count)
                updatedHoles[holeNumber] = val
            }
            result[unitID] = updatedHoles
        }
        return result
    }
}

// MARK: - Comparison Resolver

/// Executes ScoringStage.compare: head-to-head matchup resolution.
struct ComparisonResolver {

    static func apply(
        rule: ComparisonRule,
        values: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        perHoleWinPoints: Double = 1.0
    ) -> [String: [Int: PipelineHoleValue]] {
        guard rule.mode == .matchPlay else { return values }

        let unitIDs = Array(values.keys).sorted()
        guard unitIDs.count == 2 else { return values }

        let idA = unitIDs[0]
        let idB = unitIDs[1]

        var resultA: [Int: PipelineHoleValue] = [:]
        var resultB: [Int: PipelineHoleValue] = [:]
        var carryover: Double = 0

        for holeNumber in holeNumbers {
            let valA = values[idA]?[holeNumber]
            let valB = values[idB]?[holeNumber]

            guard let a = valA, let b = valB else { continue }

            let pointsAtStake = perHoleWinPoints + carryover
            var ptsA: Double = 0
            var ptsB: Double = 0

            if a.points < b.points {
                ptsA = pointsAtStake
                carryover = 0
            } else if b.points < a.points {
                ptsB = pointsAtStake
                carryover = 0
            } else {
                switch rule.tiePolicy {
                case .half:
                    ptsA = pointsAtStake / 2
                    ptsB = pointsAtStake / 2
                    carryover = 0
                case .pushover:
                    carryover = 0
                case .carryover:
                    carryover = pointsAtStake
                case .none:
                    carryover = 0
                }
            }

            resultA[holeNumber] = PipelineHoleValue(
                participantID: idA, grossStrokes: a.grossStrokes, netStrokes: a.netStrokes,
                par: a.par, scoreToPar: a.scoreToPar, points: ptsA, pickedUp: a.pickedUp
            )
            resultB[holeNumber] = PipelineHoleValue(
                participantID: idB, grossStrokes: b.grossStrokes, netStrokes: b.netStrokes,
                par: b.par, scoreToPar: b.scoreToPar, points: ptsB, pickedUp: b.pickedUp
            )
        }

        return [idA: resultA, idB: resultB]
    }
}
