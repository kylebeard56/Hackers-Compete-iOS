//
//  ScoringEngine.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Scoring Result

/// The complete output of a scoring engine computation for a segment.
struct ScoringResult {
    var rows: [ScoringRow]
    var holeStates: [Int: HoleState]
    var template: GameTemplate
    /// Per-matchup results when competitionScope == .matchup. Empty for field scope.
    var matchupResults: [MatchupScoringResult]

    init(rows: [ScoringRow] = [], holeStates: [Int: HoleState] = [:], template: GameTemplate, matchupResults: [MatchupScoringResult] = []) {
        self.rows = rows
        self.holeStates = holeStates
        self.template = template
        self.matchupResults = matchupResults
    }

    enum HoleState {
        case unscored
        case partial
        case complete
    }
}

/// The result of a single head-to-head matchup between two teams.
struct MatchupScoringResult: Identifiable {
    var id: String { matchup.id }
    let matchup: TeamMatchup
    var rows: [ScoringRow]
}

/// A single row in the engine's output, representing one scoring unit's computed result.
struct ScoringRow: Identifiable {
    var id: String { scoringUnitID }
    let scoringUnitID: String
    let participantIDs: [String]
    let owner: ScoringOwner
    /// Per-hole computed values (after pipeline). Key = hole number.
    var holeValues: [Int: HoleValue]
    /// Aggregate total across all holes.
    var total: Double
    /// Number of holes with a recorded score.
    var holesPlayed: Int

    struct HoleValue {
        var rawStrokes: Int?
        var netStrokes: Int?
        var points: Double
        var pickedUp: Bool
    }
}

// MARK: - Scoring Engine

/// Pure, stateless scoring engine. Takes a snapshot + template + hole/course context
/// and returns a fully computed ScoringResult.
struct ScoringEngine {

    // MARK: - Stroke Play Computation

    /// Computes a ScoringResult for stroke play (the Phase 0 fast path).
    /// This is a direct pipeline for individual stroke play with no pipeline stages.
    static func computeStrokePlay(
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        template: GameTemplate
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })

        var rows: [ScoringRow] = []

        let scoreIndex = buildScoreIndex(scores: scores)

        for participant in participants {
            var holeValues: [Int: ScoringRow.HoleValue] = [:]
            var total: Double = 0
            var holesPlayed = 0

            for holeNumber in holeNumbers {
                let par = holeMap[holeNumber]?.par ?? 4
                let key = scoreIndexKey(scoringUnitID: participant.id, holeNumber: holeNumber, segmentID: segment.id)
                guard let entry = scoreIndex[key] else { continue }

                let rawStrokes = entry.strokes
                let pickedUp = entry.pickedUp

                guard rawStrokes != nil || pickedUp else { continue }
                holesPlayed += 1

                var netStrokes: Int?
                var pointValue: Double = 0

                if let gross = rawStrokes {
                    let received = strokesReceived(
                        handicap: participant.adjustedHandicap,
                        holeHandicap: holeMap[holeNumber]?.handicap,
                        useHandicaps: basis == .net
                    )
                    netStrokes = max(0, gross - received)

                    switch basis {
                    case .gross: pointValue = Double(gross - par)
                    case .net:   pointValue = Double((netStrokes ?? gross) - par)
                    }
                    total += pointValue
                }

                holeValues[holeNumber] = .init(
                    rawStrokes: rawStrokes,
                    netStrokes: netStrokes,
                    points: pointValue,
                    pickedUp: pickedUp
                )
            }

            rows.append(ScoringRow(
                scoringUnitID: participant.id,
                participantIDs: [participant.id],
                owner: .participant,
                holeValues: holeValues,
                total: total,
                holesPlayed: holesPlayed
            ))
        }

        let holeStates = computeHoleStates(
            holeNumbers: holeNumbers,
            participantIDs: participants.map(\.id),
            scoreIndex: scoreIndex,
            segmentID: segment.id
        )

        return ScoringResult(rows: rows, holeStates: holeStates, template: template, matchupResults: [])
    }

    // MARK: - Generic Pipeline Computation

    /// Computes a ScoringResult by walking the template's pipeline stages.
    /// Used for non-stroke-play formats (stableford, best ball, match play, etc.).
    static func computeWithPipeline(
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        template: GameTemplate
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let scoreIndex = buildScoreIndex(scores: scores)

        let rawValues = buildRawValues(
            participants: participants,
            holeNumbers: holeNumbers,
            holeMap: holeMap,
            scoreIndex: scoreIndex,
            segment: segment,
            basis: basis
        )

        let preCompareValues = runPreCompareStages(
            values: rawValues,
            pipeline: template.pipeline,
            holeNumbers: holeNumbers,
            subject: template.subject,
            participants: participants,
            teams: teams
        )

        let matchups = segment.matchups ?? []
        let isMatchupScope = template.resolvedScope == .matchup && !matchups.isEmpty

        var allRows: [ScoringRow] = []
        var matchupResults: [MatchupScoringResult] = []

        if isMatchupScope {
            for matchup in matchups {
                guard matchup.teamIDs.count == 2 else { continue }
                let pairingValues = preCompareValues.filter { matchup.teamIDs.contains($0.key) }

                let compared = runCompareStages(
                    values: pairingValues,
                    pipeline: template.pipeline,
                    holeNumbers: holeNumbers,
                    participants: participants,
                    teams: teams
                )

                let rows = buildScoringRows(
                    from: compared, holeNumbers: holeNumbers, participants: participants
                )
                matchupResults.append(MatchupScoringResult(matchup: matchup, rows: rows))
                allRows.append(contentsOf: rows)
            }
        } else {
            let finalValues = runCompareStages(
                values: preCompareValues,
                pipeline: template.pipeline,
                holeNumbers: holeNumbers,
                participants: participants,
                teams: teams
            )
            allRows = buildScoringRows(
                from: finalValues, holeNumbers: holeNumbers, participants: participants
            )
        }

        let holeStates = computeHoleStates(
            holeNumbers: holeNumbers,
            participantIDs: participants.map(\.id),
            scoreIndex: scoreIndex,
            segmentID: segment.id
        )

        return ScoringResult(
            rows: allRows,
            holeStates: holeStates,
            template: template,
            matchupResults: matchupResults
        )
    }

    // MARK: - Pipeline Helpers

    /// Builds per-participant raw values for each hole.
    static func buildRawValues(
        participants: [RoundParticipant],
        holeNumbers: [Int],
        holeMap: [Int: Hole],
        scoreIndex: [String: ScoreEntry],
        segment: RoundSegment,
        basis: ScoreBasis
    ) -> [String: [Int: PipelineHoleValue]] {
        var rawValues: [String: [Int: PipelineHoleValue]] = [:]
        for participant in participants {
            var participantHoles: [Int: PipelineHoleValue] = [:]
            for holeNumber in holeNumbers {
                let par = holeMap[holeNumber]?.par ?? 4
                let key = scoreIndexKey(scoringUnitID: participant.id, holeNumber: holeNumber, segmentID: segment.id)
                guard let entry = scoreIndex[key], let gross = entry.strokes else { continue }

                let received = strokesReceived(
                    handicap: participant.adjustedHandicap,
                    holeHandicap: holeMap[holeNumber]?.handicap,
                    useHandicaps: basis == .net
                )
                let net = max(0, gross - received)
                let scoreToPar = (basis == .net ? net : gross) - par

                participantHoles[holeNumber] = PipelineHoleValue(
                    participantID: participant.id,
                    grossStrokes: gross,
                    netStrokes: net,
                    par: par,
                    scoreToPar: scoreToPar,
                    points: Double(scoreToPar),
                    pickedUp: entry.pickedUp
                )
            }
            rawValues[participant.id] = participantHoles
        }
        return rawValues
    }

    /// Runs all pipeline stages except compare (select, transform, modify, reduce).
    static func runPreCompareStages(
        values: [String: [Int: PipelineHoleValue]],
        pipeline: [ScoringStage],
        holeNumbers: [Int],
        subject: ScoringSubject,
        participants: [RoundParticipant],
        teams: [RoundTeam]
    ) -> [String: [Int: PipelineHoleValue]] {
        var processed = values
        for stage in pipeline {
            switch stage {
            case .select(let selection):
                processed = SelectionResolver.apply(
                    selection: selection, values: processed, holeNumbers: holeNumbers,
                    subject: subject, participants: participants, teams: teams
                )
            case .transform(let pointsMap):
                processed = PointsTransformer.apply(
                    pointsMap: pointsMap, values: processed, holeNumbers: holeNumbers
                )
            case .modify(let modifier):
                processed = ModifierApplicator.apply(
                    modifier: modifier, values: processed, holeNumbers: holeNumbers
                )
            case .reduce(let reduction):
                processed = ReductionResolver.apply(
                    reduction: reduction, values: processed, holeNumbers: holeNumbers
                )
            case .compare:
                break
            }
        }
        return processed
    }

    /// Runs only the compare stages from the pipeline.
    static func runCompareStages(
        values: [String: [Int: PipelineHoleValue]],
        pipeline: [ScoringStage],
        holeNumbers: [Int],
        participants: [RoundParticipant],
        teams: [RoundTeam]
    ) -> [String: [Int: PipelineHoleValue]] {
        var processed = values
        for stage in pipeline {
            if case .compare(let rule) = stage {
                processed = ComparisonResolver.apply(
                    rule: rule, values: processed, holeNumbers: holeNumbers,
                    participants: participants, teams: teams
                )
            }
        }
        return processed
    }

    /// Converts processed pipeline values into ScoringRows.
    static func buildScoringRows(
        from processedValues: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int],
        participants: [RoundParticipant]
    ) -> [ScoringRow] {
        var rows: [ScoringRow] = []
        for (unitID, holeMap) in processedValues {
            var holeValues: [Int: ScoringRow.HoleValue] = [:]
            var total: Double = 0
            var holesPlayed = 0

            for holeNumber in holeNumbers {
                guard let val = holeMap[holeNumber] else { continue }
                holesPlayed += 1
                total += val.points
                holeValues[holeNumber] = .init(
                    rawStrokes: val.grossStrokes,
                    netStrokes: val.netStrokes,
                    points: val.points,
                    pickedUp: val.pickedUp
                )
            }

            let pids = participants.filter { $0.id == unitID || $0.teamID == unitID }.map(\.id)

            rows.append(ScoringRow(
                scoringUnitID: unitID,
                participantIDs: pids.isEmpty ? [unitID] : pids,
                owner: pids.count == 1 && pids.first == unitID ? .participant : .team,
                holeValues: holeValues,
                total: total,
                holesPlayed: holesPlayed
            ))
        }
        return rows
    }

    // MARK: - Helpers

    static func scoreIndexKey(scoringUnitID: String, holeNumber: Int, segmentID: String) -> String {
        "\(segmentID)_\(scoringUnitID)_\(holeNumber)"
    }

    static func buildScoreIndex(scores: [ScoreEntry]) -> [String: ScoreEntry] {
        var index: [String: ScoreEntry] = [:]
        for entry in scores {
            let key = scoreIndexKey(scoringUnitID: entry.scoringUnitID, holeNumber: entry.holeNumber, segmentID: entry.segmentID)
            if index[key] == nil { index[key] = entry }
            for pid in entry.participantIDs where pid != entry.scoringUnitID {
                let pk = scoreIndexKey(scoringUnitID: pid, holeNumber: entry.holeNumber, segmentID: entry.segmentID)
                if index[pk] == nil { index[pk] = entry }
            }
        }
        return index
    }

    static func strokesReceived(handicap: Int, holeHandicap: Int?, useHandicaps: Bool) -> Int {
        guard useHandicaps else { return 0 }
        let hcp = max(0, handicap)
        guard hcp > 0, let holeHcp = holeHandicap, holeHcp > 0 else { return 0 }
        let full = hcp / 18
        let rem = hcp % 18
        let extra = (rem > 0 && holeHcp <= rem) ? 1 : 0
        return full + extra
    }

    private static func computeHoleStates(
        holeNumbers: [Int],
        participantIDs: [String],
        scoreIndex: [String: ScoreEntry],
        segmentID: String
    ) -> [Int: ScoringResult.HoleState] {
        var states: [Int: ScoringResult.HoleState] = [:]
        for hole in holeNumbers {
            var scored = 0
            for pid in participantIDs {
                let key = scoreIndexKey(scoringUnitID: pid, holeNumber: hole, segmentID: segmentID)
                if let entry = scoreIndex[key], entry.strokes != nil || entry.pickedUp {
                    scored += 1
                }
            }
            if scored == 0 {
                states[hole] = .unscored
            } else if scored < participantIDs.count {
                states[hole] = .partial
            } else {
                states[hole] = .complete
            }
        }
        return states
    }
}

// MARK: - Pipeline Intermediate Value

/// Intermediate per-hole value as it flows through pipeline stages.
struct PipelineHoleValue {
    var participantID: String
    var grossStrokes: Int
    var netStrokes: Int
    var par: Int
    var scoreToPar: Int
    var points: Double
    var pickedUp: Bool
}
