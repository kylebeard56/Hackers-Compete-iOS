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

    enum HoleState {
        case unscored
        case partial
        case complete
    }
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

        return ScoringResult(rows: rows, holeStates: holeStates, template: template)
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

        // Step 1: Build per-participant raw values for each hole
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

        // Step 2: Walk the pipeline stages
        var processedValues = rawValues

        for stage in template.pipeline {
            switch stage {
            case .select(let selection):
                processedValues = SelectionResolver.apply(
                    selection: selection,
                    values: processedValues,
                    holeNumbers: holeNumbers,
                    subject: template.subject,
                    participants: participants,
                    teams: teams
                )

            case .transform(let pointsMap):
                processedValues = PointsTransformer.apply(
                    pointsMap: pointsMap,
                    values: processedValues,
                    holeNumbers: holeNumbers
                )

            case .modify(let modifier):
                processedValues = ModifierApplicator.apply(
                    modifier: modifier,
                    values: processedValues,
                    holeNumbers: holeNumbers
                )

            case .reduce(let reduction):
                processedValues = ReductionResolver.apply(
                    reduction: reduction,
                    values: processedValues,
                    holeNumbers: holeNumbers
                )

            case .compare(let rule):
                processedValues = ComparisonResolver.apply(
                    rule: rule,
                    values: processedValues,
                    holeNumbers: holeNumbers,
                    participants: participants,
                    teams: teams
                )
            }
        }

        // Step 3: Build ScoringRows from processed values
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

        let holeStates = computeHoleStates(
            holeNumbers: holeNumbers,
            participantIDs: participants.map(\.id),
            scoreIndex: scoreIndex,
            segmentID: segment.id
        )

        return ScoringResult(rows: rows, holeStates: holeStates, template: template)
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
