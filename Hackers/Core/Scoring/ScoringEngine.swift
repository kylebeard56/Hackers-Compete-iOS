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
    let countingParticipantIDs: [String]
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
        template: GameTemplate,
        scoreLookupSegmentIDs: [String]? = nil
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })

        var rows: [ScoringRow] = []

        let scoreIndex = buildScoreIndex(scores: scores)
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? resolvedScoreLookupSegmentIDs(primarySegment: segment, scores: scores)

        for participant in participants {
            var holeValues: [Int: ScoringRow.HoleValue] = [:]
            var total: Double = 0
            var holesPlayed = 0

            for holeNumber in holeNumbers {
                let par = holeMap[holeNumber]?.par ?? 4
                guard let entry = scoreEntry(
                    scoreIndex: scoreIndex,
                    scoringUnitID: participant.id,
                    holeNumber: holeNumber,
                    lookupSegmentIDs: lookupSegmentIDs
                ) else { continue }

                let rawStrokes = entry.strokes
                let pickedUp = entry.pickedUp

                guard rawStrokes != nil || pickedUp else { continue }
                holesPlayed += 1

                var netStrokes: Int?
                var pointValue: Double = 0

                if let gross = rawStrokes {
                    let received = strokesReceived(
                        handicap: participant.adjustedHandicap,
                        holeNumber: holeNumber,
                        holeMap: holeMap,
                        playedHoleNumbers: holeNumbers,
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
                countingParticipantIDs: [participant.id],
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
            lookupSegmentIDs: lookupSegmentIDs
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
        template: GameTemplate,
        scoreLookupSegmentIDs: [String]? = nil,
        resolvedCompetitionScope: CompetitionScope? = nil,
        scoreOwnerScope: RoundScoreOwnerScope = .individual,
        scoringGroups: [RoundScoringGroup] = [],
        perHoleWinPoints: Double = 1.0
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let scoreIndex = buildScoreIndex(scores: scores)
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? resolvedScoreLookupSegmentIDs(primarySegment: segment, scores: scores)
        let scoringUnits = resolvedScoringUnits(participants: participants, segment: segment)
        let selectionGroups = resolvedSelectionGroups(
            participants: participants,
            scoringGroups: scoringGroups,
            scoreOwnerScope: scoreOwnerScope,
            template: template
        )

        let rawValues = buildRawValues(
            scoringUnits: scoringUnits,
            participants: participants,
            scoringGroups: scoringGroups,
            holeNumbers: holeNumbers,
            holeMap: holeMap,
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs,
            basis: basis
        )

        let preCompareValues = runPreCompareStages(
            values: rawValues,
            pipeline: template.pipeline,
            holeNumbers: holeNumbers,
            subject: template.subject,
            participants: participants,
            teams: teams,
            selectionGroups: selectionGroups
        )

        let matchups = segment.matchups ?? []
        let effectiveScope = resolvedCompetitionScope ?? segment.competitionScope ?? template.resolvedScope
        let isMatchupScope = effectiveScope == .matchup && !matchups.isEmpty

        var allRows: [ScoringRow] = []
        var matchupResults: [MatchupScoringResult] = []

        if isMatchupScope {
            for matchup in matchups {
                guard matchup.isValid else { continue }
                let pairingIDs = matchup.pairingIDs()
                let pairingValues = preCompareValues.filter { pairingIDs.contains($0.key) }

                let compared = runCompareStages(
                    values: pairingValues,
                    pipeline: template.pipeline,
                    holeNumbers: holeNumbers,
                    participants: participants,
                    teams: teams,
                    perHoleWinPoints: perHoleWinPoints
                )

                let rows = buildScoringRows(
                    from: compared,
                    holeNumbers: holeNumbers,
                    participants: participants,
                    teams: teams,
                    scoringGroups: scoringGroups,
                    scoringUnits: scoringUnits
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
                teams: teams,
                perHoleWinPoints: perHoleWinPoints
            )
            allRows = buildScoringRows(
                from: finalValues,
                holeNumbers: holeNumbers,
                participants: participants,
                teams: teams,
                scoringGroups: scoringGroups,
                scoringUnits: scoringUnits
            )
        }

        let holeStates = computeHoleStates(
            holeNumbers: holeNumbers,
            participantIDs: participants.map(\.id),
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs
        )

        return ScoringResult(
            rows: allRows,
            holeStates: holeStates,
            template: template,
            matchupResults: matchupResults
        )
    }

    // MARK: - Team Scoring Builder

    static func computeWithTeamScoring(
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        template: GameTemplate,
        teamScoring: RoundTeamScoringConfiguration,
        matchupResolutionStyle: RoundMatchupResolutionStyle,
        scoreLookupSegmentIDs: [String]? = nil,
        resolvedCompetitionScope: CompetitionScope? = nil
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let scoreIndex = buildScoreIndex(scores: scores)
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? resolvedScoreLookupSegmentIDs(primarySegment: segment, scores: scores)

        let rawValues = buildRawValues(
            participants: participants,
            holeNumbers: holeNumbers,
            holeMap: holeMap,
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs,
            basis: basis
        )

        let baseValues = applyBaseScoringStages(
            values: rawValues,
            pipeline: template.pipeline,
            holeNumbers: holeNumbers
        )

        let teamRows = buildTeamScoringRows(
            values: baseValues,
            participants: participants,
            teams: teams,
            holeNumbers: holeNumbers,
            leaderboardSort: template.leaderboardSort,
            teamScoring: teamScoring
        )

        let matchups = segment.matchups ?? []
        let effectiveScope = resolvedCompetitionScope ?? segment.competitionScope ?? template.resolvedScope
        let matchupResults: [MatchupScoringResult]

        if effectiveScope == .matchup, !matchups.isEmpty {
            let rowByTeamID = Dictionary(uniqueKeysWithValues: teamRows.map { ($0.scoringUnitID, $0) })
            matchupResults = matchups.compactMap { matchup in
                guard matchup.isValid else { return nil }
                let rows = matchup.pairingIDs().compactMap { rowByTeamID[$0] }
                guard rows.count == 2 else { return nil }
                switch matchupResolutionStyle {
                case .roundAggregate:
                    return MatchupScoringResult(matchup: matchup, rows: rows)
                }
            }
        } else {
            matchupResults = []
        }

        let holeStates = computeHoleStates(
            holeNumbers: holeNumbers,
            participantIDs: participants.map(\.id),
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs
        )

        return ScoringResult(
            rows: teamRows,
            holeStates: holeStates,
            template: template,
            matchupResults: matchupResults
        )
    }

    // MARK: - Pipeline Helpers

    static func applyBaseScoringStages(
        values: [String: [Int: PipelineHoleValue]],
        pipeline: [ScoringStage],
        holeNumbers: [Int]
    ) -> [String: [Int: PipelineHoleValue]] {
        var processed = values
        for stage in pipeline {
            switch stage {
            case .transform(let pointsMap):
                processed = PointsTransformer.apply(
                    pointsMap: pointsMap,
                    values: processed,
                    holeNumbers: holeNumbers
                )
            case .modify(let modifier):
                processed = ModifierApplicator.apply(
                    modifier: modifier,
                    values: processed,
                    holeNumbers: holeNumbers
                )
            case .select, .reduce, .compare:
                break
            }
        }
        return processed
    }

    static func buildTeamScoringRows(
        values: [String: [Int: PipelineHoleValue]],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        holeNumbers: [Int],
        leaderboardSort: LeaderboardSort,
        teamScoring: RoundTeamScoringConfiguration
    ) -> [ScoringRow] {
        let participantsByTeam = Dictionary(grouping: participants.compactMap { participant -> (String, RoundParticipant)? in
            guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return (teamID, participant)
        }, by: \.0)
            .mapValues { $0.map(\.1) }

        let orderedTeamIDs = teams.sorted { $0.index < $1.index }.map(\.id)
            + participantsByTeam.keys.filter { teamID in !teams.contains(where: { $0.id == teamID }) }.sorted()

        let isHighestWins = leaderboardSort == .highestWins

        return orderedTeamIDs.compactMap { teamID in
            let teamParticipants = participantsByTeam[teamID] ?? []
            guard teamParticipants.isPopulated else { return nil }

            let participantIDs = teamParticipants.map(\.id)
            let countingIDs: [String]
            let holeValues: [Int: ScoringRow.HoleValue]

            switch teamScoring.scope {
            case .perHole:
                let built = buildPerHoleTeamValues(
                    values: values,
                    participants: teamParticipants,
                    holeNumbers: holeNumbers,
                    isHighestWins: isHighestWins,
                    teamScoring: teamScoring
                )
                countingIDs = Array(built.countingParticipantIDs).sorted()
                holeValues = built.holeValues
            case .perRound:
                let built = buildPerRoundTeamValues(
                    values: values,
                    participants: teamParticipants,
                    holeNumbers: holeNumbers,
                    isHighestWins: isHighestWins,
                    teamScoring: teamScoring
                )
                countingIDs = built.countingParticipantIDs
                holeValues = built.holeValues
            }

            let total = holeNumbers.compactMap { holeValues[$0]?.points }.reduce(0, +)
            let holesPlayed = holeValues.count

            return ScoringRow(
                scoringUnitID: teamID,
                participantIDs: participantIDs,
                countingParticipantIDs: countingIDs.isEmpty ? participantIDs : countingIDs,
                owner: .team,
                holeValues: holeValues,
                total: total,
                holesPlayed: holesPlayed
            )
        }
    }

    private static func buildPerHoleTeamValues(
        values: [String: [Int: PipelineHoleValue]],
        participants: [RoundParticipant],
        holeNumbers: [Int],
        isHighestWins: Bool,
        teamScoring: RoundTeamScoringConfiguration
    ) -> (holeValues: [Int: ScoringRow.HoleValue], countingParticipantIDs: Set<String>) {
        var holeValues: [Int: ScoringRow.HoleValue] = [:]
        var selectedIDs = Set<String>()

        for holeNumber in holeNumbers {
            let holeScores = participants.compactMap { participant -> (String, PipelineHoleValue)? in
                guard let value = values[participant.id]?[holeNumber] else { return nil }
                return (participant.id, value)
            }

            guard holeScores.isPopulated else { continue }
            let ordered = orderedScores(holeScores, isHighestWins: isHighestWins)
            let selected = selectedScores(from: ordered, teamScoring: teamScoring)
            guard selected.isPopulated else { continue }

            selected.forEach { selectedIDs.insert($0.0) }
            let points = selected.reduce(0.0) { $0 + $1.1.points }
            holeValues[holeNumber] = .init(
                rawStrokes: nil,
                netStrokes: nil,
                points: points,
                pickedUp: false
            )
        }

        return (holeValues, selectedIDs)
    }

    private static func buildPerRoundTeamValues(
        values: [String: [Int: PipelineHoleValue]],
        participants: [RoundParticipant],
        holeNumbers: [Int],
        isHighestWins: Bool,
        teamScoring: RoundTeamScoringConfiguration
    ) -> (holeValues: [Int: ScoringRow.HoleValue], countingParticipantIDs: [String]) {
        let participantTotals: [(String, Double)] = participants.map { participant in
            let total = holeNumbers.compactMap { values[participant.id]?[$0]?.points }.reduce(0, +)
            return (participant.id, total)
        }

        let ordered = participantTotals.sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return isHighestWins ? lhs.1 > rhs.1 : lhs.1 < rhs.1
            }
            return lhs.0 < rhs.0
        }

        let selectedIDs: [String]
        switch teamScoring.mode {
        case .all:
            selectedIDs = ordered.map(\.0)
        case .bestN:
            selectedIDs = Array(ordered.prefix(max(1, teamScoring.count)).map(\.0))
        case .worstN:
            selectedIDs = Array(ordered.suffix(max(1, teamScoring.count)).map(\.0))
        }

        var holeValues: [Int: ScoringRow.HoleValue] = [:]
        for holeNumber in holeNumbers {
            let points = selectedIDs.reduce(0.0) { partial, participantID in
                partial + (values[participantID]?[holeNumber]?.points ?? 0)
            }
            let hasAnyScore = selectedIDs.contains { values[$0]?[holeNumber] != nil }
            guard hasAnyScore else { continue }
            holeValues[holeNumber] = .init(
                rawStrokes: nil,
                netStrokes: nil,
                points: points,
                pickedUp: false
            )
        }

        return (holeValues, selectedIDs)
    }

    private static func orderedScores(
        _ scores: [(String, PipelineHoleValue)],
        isHighestWins: Bool
    ) -> [(String, PipelineHoleValue)] {
        scores.sorted { lhs, rhs in
            if lhs.1.points != rhs.1.points {
                return isHighestWins ? lhs.1.points > rhs.1.points : lhs.1.points < rhs.1.points
            }
            return lhs.0 < rhs.0
        }
    }

    private static func selectedScores(
        from orderedScores: [(String, PipelineHoleValue)],
        teamScoring: RoundTeamScoringConfiguration
    ) -> [(String, PipelineHoleValue)] {
        switch teamScoring.mode {
        case .all:
            return orderedScores
        case .bestN:
            return Array(orderedScores.prefix(max(1, teamScoring.count)))
        case .worstN:
            return Array(orderedScores.suffix(max(1, teamScoring.count)))
        }
    }

    /// Builds per-participant raw values for each hole.
    static func buildRawValues(
        scoringUnits: [ScoringUnit],
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup],
        holeNumbers: [Int],
        holeMap: [Int: Hole],
        scoreIndex: [String: ScoreEntry],
        lookupSegmentIDs: [String],
        basis: ScoreBasis
    ) -> [String: [Int: PipelineHoleValue]] {
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let teamParticipantIDs = Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
            guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return (teamID, participant.id)
        }, by: \.0).mapValues { $0.map(\.1) }
        let scoringGroupsByID = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })

        var rawValues: [String: [Int: PipelineHoleValue]] = [:]
        for scoringUnit in scoringUnits {
            let participantIDs = resolvedParticipantIDs(
                for: scoringUnit,
                participantsByID: participantByID,
                teamParticipantIDs: teamParticipantIDs,
                scoringGroupsByID: scoringGroupsByID
            )
            let participantSet = Set(participantIDs)
            let memberParticipants = participantIDs.compactMap { participantByID[$0] }
            let handicap = resolvedHandicap(for: scoringUnit, participants: memberParticipants, basis: basis)
            var unitHoles: [Int: PipelineHoleValue] = [:]

            for holeNumber in holeNumbers {
                let par = holeMap[holeNumber]?.par ?? 4
                let directEntry = scoreEntry(
                    scoreIndex: scoreIndex,
                    scoringUnitID: scoringUnit.id,
                    holeNumber: holeNumber,
                    lookupSegmentIDs: lookupSegmentIDs
                )
                let fallbackEntry = participantIDs.lazy.compactMap { participantID in
                    scoreEntry(
                        scoreIndex: scoreIndex,
                        scoringUnitID: participantID,
                        holeNumber: holeNumber,
                        lookupSegmentIDs: lookupSegmentIDs
                    )
                }.first
                guard let entry = directEntry ?? fallbackEntry,
                      let gross = entry.strokes else { continue }

                let received = strokesReceived(
                    handicap: handicap,
                    holeNumber: holeNumber,
                    holeMap: holeMap,
                    playedHoleNumbers: holeNumbers,
                    useHandicaps: basis == .net
                )
                let net = max(0, gross - received)
                let scoreToPar = (basis == .net ? net : gross) - par
                let holeParticipantID = entry.participantIDs.first(where: { participantSet.contains($0) })
                    ?? participantIDs.first
                    ?? scoringUnit.id

                unitHoles[holeNumber] = PipelineHoleValue(
                    participantID: holeParticipantID,
                    grossStrokes: gross,
                    netStrokes: net,
                    par: par,
                    scoreToPar: scoreToPar,
                    points: Double(scoreToPar),
                    pickedUp: entry.pickedUp
                )
            }
            rawValues[scoringUnit.id] = unitHoles
        }
        return rawValues
    }

    static func buildRawValues(
        participants: [RoundParticipant],
        holeNumbers: [Int],
        holeMap: [Int: Hole],
        scoreIndex: [String: ScoreEntry],
        lookupSegmentIDs: [String],
        basis: ScoreBasis
    ) -> [String: [Int: PipelineHoleValue]] {
        buildRawValues(
            scoringUnits: participants.map { participant in
                ScoringUnit(
                    id: participant.id,
                    owner: .participant,
                    ownerIDs: [participant.id],
                    scoringMethod: .individual
                )
            },
            participants: participants,
            scoringGroups: [],
            holeNumbers: holeNumbers,
            holeMap: holeMap,
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs,
            basis: basis
        )
    }

    /// Runs all pipeline stages except compare (select, transform, modify, reduce).
    static func runPreCompareStages(
        values: [String: [Int: PipelineHoleValue]],
        pipeline: [ScoringStage],
        holeNumbers: [Int],
        subject: ScoringSubject,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        selectionGroups: [String: [String]]
    ) -> [String: [Int: PipelineHoleValue]] {
        var processed = values
        for stage in pipeline {
            switch stage {
            case .select(let selection):
                processed = SelectionResolver.apply(
                    selection: selection, values: processed, holeNumbers: holeNumbers,
                    subject: subject,
                    participants: participants,
                    teams: teams,
                    selectionGroups: selectionGroups
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
        teams: [RoundTeam],
        perHoleWinPoints: Double
    ) -> [String: [Int: PipelineHoleValue]] {
        var processed = values
        for stage in pipeline {
            if case .compare(let rule) = stage {
                processed = ComparisonResolver.apply(
                    rule: rule, values: processed, holeNumbers: holeNumbers,
                    participants: participants,
                    teams: teams,
                    perHoleWinPoints: perHoleWinPoints
                )
            }
        }
        return processed
    }

    /// Converts processed pipeline values into ScoringRows.
    static func buildScoringRows(
        from processedValues: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup],
        scoringUnits: [ScoringUnit]
    ) -> [ScoringRow] {
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let teamParticipantIDs = Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
            guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return (teamID, participant.id)
        }, by: \.0).mapValues { $0.map(\.1) }
        let scoringGroupsByID = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })
        let scoringUnitByID = Dictionary(uniqueKeysWithValues: scoringUnits.map { ($0.id, $0) })
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

            let owner: ScoringOwner
            let participantIDs: [String]

            if let scoringUnit = scoringUnitByID[unitID] {
                owner = scoringUnit.owner
                participantIDs = resolvedParticipantIDs(
                    for: scoringUnit,
                    participantsByID: participantByID,
                    teamParticipantIDs: teamParticipantIDs,
                    scoringGroupsByID: scoringGroupsByID
                )
            } else if let scoringGroup = scoringGroupsByID[unitID] {
                owner = .scoreOwner
                participantIDs = scoringGroup.memberIDs
            } else if participantByID[unitID] != nil {
                owner = .participant
                participantIDs = [unitID]
            } else if teamParticipantIDs[unitID].isPopulated || teams.contains(where: { $0.id == unitID }) {
                owner = .team
                participantIDs = teamParticipantIDs[unitID] ?? []
            } else {
                owner = .participant
                participantIDs = [unitID]
            }

            rows.append(ScoringRow(
                scoringUnitID: unitID,
                participantIDs: participantIDs.isEmpty ? [unitID] : participantIDs,
                countingParticipantIDs: participantIDs.isEmpty ? [unitID] : participantIDs,
                owner: owner,
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

    /// Segment IDs to try when resolving a score (primary segment first, then alternates). Covers multi-segment rounds and scores keyed under a non-first segment id.
    static func resolvedScoreLookupSegmentIDs(primarySegment: RoundSegment, scores: [ScoreEntry]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        if !primarySegment.id.isEmpty {
            ordered.append(primarySegment.id)
            seen.insert(primarySegment.id)
        }
        for entry in scores where !entry.segmentID.isEmpty && !seen.contains(entry.segmentID) {
            ordered.append(entry.segmentID)
            seen.insert(entry.segmentID)
        }
        return ordered
    }

    static func scoreEntry(
        scoreIndex: [String: ScoreEntry],
        scoringUnitID: String,
        holeNumber: Int,
        lookupSegmentIDs: [String]
    ) -> ScoreEntry? {
        for sid in lookupSegmentIDs {
            let key = scoreIndexKey(scoringUnitID: scoringUnitID, holeNumber: holeNumber, segmentID: sid)
            if let entry = scoreIndex[key] { return entry }
        }
        return nil
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

    static func strokesReceived(
        handicap: Int,
        holeNumber: Int,
        holes: [Hole],
        playedHoleNumbers: [Int],
        useHandicaps: Bool
    ) -> Int {
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        return strokesReceived(
            handicap: handicap,
            holeNumber: holeNumber,
            holeMap: holeMap,
            playedHoleNumbers: playedHoleNumbers,
            useHandicaps: useHandicaps
        )
    }

    static func strokesReceived(
        handicap: Int,
        holeNumber: Int,
        holeMap: [Int: Hole],
        playedHoleNumbers: [Int],
        useHandicaps: Bool
    ) -> Int {
        guard useHandicaps else { return 0 }
        let hcp = max(0, handicap)
        guard hcp > 0 else { return 0 }

        let rankedHoleNumbers = playedHoleNumbers
            .compactMap { holeNumber -> (number: Int, handicap: Int)? in
                guard let hole = holeMap[holeNumber], let holeHandicap = hole.handicap, holeHandicap > 0 else {
                    return nil
                }
                return (hole.number, holeHandicap)
            }
            .sorted {
                if $0.handicap != $1.handicap { return $0.handicap < $1.handicap }
                return $0.number < $1.number
            }
            .map(\.number)

        guard let holeIndex = rankedHoleNumbers.firstIndex(of: holeNumber) else { return 0 }

        let holesInPlay = rankedHoleNumbers.count
        let full = hcp / holesInPlay
        let rem = hcp % holesInPlay
        let extra = holeIndex < rem ? 1 : 0
        return full + extra
    }

    private static func resolvedScoringUnits(
        participants: [RoundParticipant],
        segment: RoundSegment
    ) -> [ScoringUnit] {
        if segment.scoringUnits.isPopulated {
            return segment.scoringUnits
        }

        return participants.map { participant in
            ScoringUnit(
                id: participant.id,
                owner: .participant,
                ownerIDs: [participant.id],
                scoringMethod: .individual
            )
        }
    }

    private static func resolvedSelectionGroups(
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup],
        scoreOwnerScope: RoundScoreOwnerScope,
        template: GameTemplate
    ) -> [String: [String]] {
        switch scoreOwnerScope {
        case .partnership:
            guard template.scoreSource == .individual else { return [:] }
            return Dictionary(uniqueKeysWithValues: scoringGroups
                .filter { $0.kind == .partnership && $0.memberIDs.isPopulated }
                .map { ($0.id, $0.memberIDs) })
        case .teeGroup:
            guard template.scoreSource == .individual else { return [:] }
            return Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
                guard let groupID = participant.groupID, groupID.isPopulated else { return nil }
                return (groupID, participant.id)
            }, by: \.0).mapValues { $0.map(\.1) }
        case .individual:
            return Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
                guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
                return (teamID, participant.id)
            }, by: \.0).mapValues { $0.map(\.1) }
        }
    }

    private static func resolvedParticipantIDs(
        for scoringUnit: ScoringUnit,
        participantsByID: [String: RoundParticipant],
        teamParticipantIDs: [String: [String]],
        scoringGroupsByID: [String: RoundScoringGroup]
    ) -> [String] {
        switch scoringUnit.owner {
        case .participant:
            if scoringUnit.ownerIDs.isPopulated {
                return scoringUnit.ownerIDs
            }
            return participantsByID[scoringUnit.id] != nil ? [scoringUnit.id] : []
        case .team:
            if let teamID = scoringUnit.ownerIDs.first, let participantIDs = teamParticipantIDs[teamID] {
                return participantIDs
            }
            return scoringUnit.ownerIDs
        case .scoreOwner:
            if let scoringGroup = scoringGroupsByID[scoringUnit.id] {
                return scoringGroup.memberIDs
            }
            return scoringUnit.ownerIDs
        }
    }

    private static func resolvedHandicap(
        for scoringUnit: ScoringUnit,
        participants: [RoundParticipant],
        basis: ScoreBasis
    ) -> Int {
        guard basis == .net else { return 0 }

        switch scoringUnit.owner {
        case .participant:
            return participants.first?.adjustedHandicap ?? 0
        case .team, .scoreOwner:
            if let handicapAdjustments = scoringUnit.handicapAdjustments, handicapAdjustments.isPopulated {
                return Int(handicapAdjustments.values.reduce(0.0, +).rounded())
            }
            guard participants.isPopulated else { return 0 }
            let average = Double(participants.map(\.adjustedHandicap).reduce(0, +)) / Double(participants.count)
            return Int(average.rounded())
        }
    }

    private static func computeHoleStates(
        holeNumbers: [Int],
        participantIDs: [String],
        scoreIndex: [String: ScoreEntry],
        lookupSegmentIDs: [String]
    ) -> [Int: ScoringResult.HoleState] {
        var states: [Int: ScoringResult.HoleState] = [:]
        for hole in holeNumbers {
            var scored = 0
            for pid in participantIDs {
                if let entry = scoreEntry(
                    scoreIndex: scoreIndex,
                    scoringUnitID: pid,
                    holeNumber: hole,
                    lookupSegmentIDs: lookupSegmentIDs
                ), entry.strokes != nil || entry.pickedUp {
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
