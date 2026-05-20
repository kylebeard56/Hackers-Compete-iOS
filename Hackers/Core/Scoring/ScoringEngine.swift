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
    var isPointsFormat: Bool?
    var minimumCountStatus: MatchupMinimumCountStatus?

    init(
        matchup: TeamMatchup,
        rows: [ScoringRow],
        isPointsFormat: Bool? = nil,
        minimumCountStatus: MatchupMinimumCountStatus? = nil
    ) {
        self.matchup = matchup
        self.rows = rows
        self.isPointsFormat = isPointsFormat
        self.minimumCountStatus = minimumCountStatus
    }
}

enum MatchupMinimumCountShortageKind: Equatable {
    case structural
    case missingScores
}

struct MatchupMinimumCountSideStatus: Equatable {
    let sideID: String
    let requiredCount: Int
    let actualCount: Int
    let availableParticipantCount: Int
    let shortageKind: MatchupMinimumCountShortageKind?

    var isUnderMinimum: Bool {
        actualCount < requiredCount
    }
}

struct MatchupMinimumCountStatus: Equatable {
    let requiredCount: Int
    let scope: AggregationScope
    let sideStatuses: [MatchupMinimumCountSideStatus]

    var underMinimumSideIDs: [String] {
        sideStatuses.filter(\.isUnderMinimum).map(\.sideID)
    }

    var hasUnderMinimumSide: Bool {
        underMinimumSideIDs.isPopulated
    }

    var hasStructuralShortage: Bool {
        sideStatuses.contains { $0.shortageKind == .structural }
    }

    var bothSidesUnderMinimum: Bool {
        sideStatuses.count >= 2 && sideStatuses.allSatisfy(\.isUnderMinimum)
    }

    var autoWinnerSideID: String? {
        guard sideStatuses.count == 2,
              let winner = sideStatuses.first(where: { !$0.isUnderMinimum }),
              sideStatuses.filter(\.isUnderMinimum).count == 1 else {
            return nil
        }
        return winner.sideID
    }

    func sideStatus(for sideID: String) -> MatchupMinimumCountSideStatus? {
        sideStatuses.first { $0.sideID == sideID }
    }
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
        var vegasPairs: [VegasPairDetail]?

        init(
            rawStrokes: Int?,
            netStrokes: Int?,
            points: Double,
            pickedUp: Bool,
            vegasPairs: [VegasPairDetail]? = nil
        ) {
            self.rawStrokes = rawStrokes
            self.netStrokes = netStrokes
            self.points = points
            self.pickedUp = pickedUp
            self.vegasPairs = vegasPairs
        }
    }
}

struct VegasPairDetail: Hashable, Identifiable {
    let id: String
    let participantIDs: [String]
    let partnershipID: String?
    let lowStroke: Int
    let highStroke: Int
    let composite: Int
}

// MARK: - Scoring Engine

/// Pure, stateless scoring engine. Takes a snapshot + template + hole/course context
/// and returns a fully computed ScoringResult.
struct ScoringEngine {

    // MARK: - Snapshot Routing

    static func computeSnapshotResult(
        snapshot: RoundSnapshot,
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        scoreLookupSegmentIDs: [String]? = nil
    ) -> ScoringResult {
        let template = snapshot.resolvedActiveTemplate
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? snapshot.segmentScoreLookupSegmentIDs
        let handicapNormalizationMode = basis == .net ? snapshot.configuration.handicapNormalizationMode : .off
        let scoringParticipants = handicapNormalizationMode == .field
            ? HandicapCalculator.normalizedParticipantsForField(snapshot.participants)
            : snapshot.participants

        if snapshot.isVegasFormat {
            return computeVegas(
                scores: snapshot.scoring,
                participants: scoringParticipants,
                teams: snapshot.teams,
                scoringGroups: snapshot.scoringGroups,
                segment: segment,
                holes: holes,
                basis: basis,
                scoreInputMode: snapshot.configuration.scoreInputMode,
                template: template,
                vegasMode: snapshot.configuration.resolvedVegasMode,
                selectionRule: snapshot.configuration.resolvedVegasSelectionRule,
                selectionScope: snapshot.configuration.resolvedVegasSelectionScope,
                scoreLookupSegmentIDs: lookupSegmentIDs.isEmpty ? nil : lookupSegmentIDs,
                handicapStrokeBasis: snapshot.handicapStrokeBasis
            )
        }

        if shouldUseTeamAggregateScoring(snapshot: snapshot, segment: segment) {
            return computeWithTeamScoring(
                scores: snapshot.scoring,
                participants: scoringParticipants,
                unnormalizedParticipants: snapshot.participants,
                teams: snapshot.teams,
                segment: segment,
                holes: holes,
                basis: basis,
                scoreInputMode: snapshot.configuration.scoreInputMode,
                template: template,
                teamScoring: snapshot.configuration.teamScoring,
                matchupResolutionStyle: snapshot.configuration.matchupResolutionStyle,
                matchupScoringStyle: snapshot.configuration.matchupScoringStyle,
                perHoleWinPoints: snapshot.configuration.resolvedHoleWinPoints,
                scoreLookupSegmentIDs: lookupSegmentIDs.isEmpty ? nil : lookupSegmentIDs,
                resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope,
                handicapNormalizationMode: handicapNormalizationMode,
                handicapStrokeBasis: snapshot.handicapStrokeBasis
            )
        }

        if template.id == FormatTemplateRegistry.strokePlay.id,
           snapshot.configuration.resolvedCompetitionScope != .matchup {
            return computeStrokePlay(
                scores: snapshot.scoring,
                participants: scoringParticipants,
                segment: segment,
                holes: holes,
                basis: basis,
                scoreInputMode: snapshot.configuration.scoreInputMode,
                template: template,
                scoreLookupSegmentIDs: lookupSegmentIDs.isEmpty ? nil : lookupSegmentIDs,
                handicapStrokeBasis: snapshot.handicapStrokeBasis
            )
        }

        return computeWithPipeline(
            scores: snapshot.scoring,
            participants: scoringParticipants,
            unnormalizedParticipants: snapshot.participants,
            teams: snapshot.teams,
            segment: segment,
            holes: holes,
            basis: basis,
            scoreInputMode: snapshot.configuration.scoreInputMode,
            template: template,
            scoreLookupSegmentIDs: lookupSegmentIDs.isEmpty ? nil : lookupSegmentIDs,
            resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope,
            scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
            selectionDomain: snapshot.configuration.selectionDomain,
            teamScoring: snapshot.configuration.teamScoring,
            scoringGroups: snapshot.scoringGroups,
            perHoleWinPoints: snapshot.configuration.resolvedHoleWinPoints,
            sharedScoreHandicapConfig: snapshot.configuration.sharedScoreHandicapConfig,
            handicapNormalizationMode: handicapNormalizationMode,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
    }

    static func shouldUseTeamAggregateScoring(snapshot: RoundSnapshot, segment: RoundSegment) -> Bool {
        guard !snapshot.isVegasFormat,
              !snapshot.isSharedScoreSource,
              snapshot.configuration.scoreOwnerScope == .individual,
              snapshot.teams.isPopulated else {
            return false
        }

        let hasTeamAggregateShape = snapshot.requiresTeams
            || snapshot.hasScheduledTeamMatchups
            || snapshot.configuration.teamScoring.isCountedSelection
        guard hasTeamAggregateShape else { return false }

        let matchups = (segment.matchups ?? []).filter(\.isValid)
        let isMatchupScope = snapshot.configuration.resolvedCompetitionScope == .matchup
            || segment.competitionScope == .matchup
        guard isMatchupScope else { return true }

        let matchupModes = matchups.map(\.effectiveMode)
        if matchupModes.contains(where: { $0.usesScoringGroupIDs }) || matchupModes.contains(.individual) {
            return false
        }
        if matchupModes.contains(.team) {
            return true
        }
        return snapshot.expectedMatchupMode == .team
    }

    // MARK: - Stroke Play Computation

    /// Computes a ScoringResult for stroke play (the Phase 0 fast path).
    /// This is a direct pipeline for individual stroke play with no pipeline stages.
    static func computeStrokePlay(
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        template: GameTemplate,
        scoreLookupSegmentIDs: [String]? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
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

                let rawStrokes = resolvedGrossStrokes(entry: entry, par: par)
                let pickedUp = entry.pickedUp
                let grossRelativeToPar = resolvedGrossRelativeToPar(entry: entry, par: par)

                guard rawStrokes != nil || grossRelativeToPar != nil || pickedUp else { continue }
                holesPlayed += 1

                var netStrokes: Int?
                var pointValue: Double = 0

                if let grossRelativeToPar {
                    let received = strokesReceived(
                        handicap: participant.adjustedHandicap,
                        holeNumber: holeNumber,
                        holeMap: holeMap,
                        playedHoleNumbers: holeNumbers,
                        useHandicaps: basis == .net,
                        handicapStrokeBasis: handicapStrokeBasis
                    )
                    let gross = rawStrokes ?? max(1, par + grossRelativeToPar)
                    let netRelativeToPar = grossRelativeToPar - received
                    netStrokes = max(0, gross - received)

                    switch basis {
                    case .gross: pointValue = Double(grossRelativeToPar)
                    case .net:   pointValue = Double(netRelativeToPar)
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
        unnormalizedParticipants: [RoundParticipant]? = nil,
        teams: [RoundTeam],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        template: GameTemplate,
        scoreLookupSegmentIDs: [String]? = nil,
        resolvedCompetitionScope: CompetitionScope? = nil,
        scoreOwnerScope: RoundScoreOwnerScope = .individual,
        selectionDomain: ScoringSelectionDomain? = nil,
        teamScoring: RoundTeamScoringConfiguration = .init(),
        scoringGroups: [RoundScoringGroup] = [],
        perHoleWinPoints: Double = 1.0,
        sharedScoreHandicapConfig: HandicapConfiguration? = nil,
        handicapNormalizationMode: HandicapNormalizationMode = .off,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let usesSharedScoreSource = template.scoreSource == .shared
        let scoreIndex = buildScoreIndex(scores: scores, includeParticipantAliases: !usesSharedScoreSource)
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? resolvedScoreLookupSegmentIDs(primarySegment: segment, scores: scores)
        let rawBaseScoringUnits = resolvedScoringUnits(
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segment: segment,
            template: template,
            scoreOwnerScope: scoreOwnerScope
        )
        let baseScoringUnits = handicapNormalizationMode == .off
            ? rawBaseScoringUnits
            : scoringUnitsWithoutStoredHandicapAllowances(rawBaseScoringUnits)
        let scoringUnits = augmentedScoringUnitsForMatchups(
            baseScoringUnits,
            matchups: segment.matchups ?? [],
            scoringGroups: scoringGroups,
            template: template
        )
        let matchups = segment.matchups ?? []
        let effectiveSelectionDomain = resolvedSelectionDomain(
            explicit: selectionDomain,
            matchups: matchups,
            scoringGroups: scoringGroups,
            scoreOwnerScope: scoreOwnerScope,
            teamScoring: teamScoring,
            template: template,
            teams: teams
        )
        let selectionGroups = resolvedSelectionGroups(
            participants: participants,
            scoringGroups: scoringGroups,
            selectionDomain: effectiveSelectionDomain,
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
            basis: basis,
            scoreInputMode: scoreInputMode,
            allowParticipantFallback: !usesSharedScoreSource,
            sharedScoreHandicapConfig: usesSharedScoreSource
                ? (sharedScoreHandicapConfig ?? template.requirements.defaultHandicapConfig)
                : nil,
            handicapStrokeBasis: handicapStrokeBasis
        )
        let baseValues = applyBaseScoringStages(
            values: rawValues,
            pipeline: template.pipeline,
            holeNumbers: holeNumbers
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

        let effectiveScope = resolvedCompetitionScope ?? segment.competitionScope ?? template.resolvedScope
        let isMatchupScope = effectiveScope == .matchup && !matchups.isEmpty

        var allRows: [ScoringRow] = []
        var matchupResults: [MatchupScoringResult] = []

        if isMatchupScope {
            for matchup in matchups {
                guard matchup.isValid else { continue }
                let usesMatchupNormalization = handicapNormalizationMode == .matchup
                let matchupParticipants = usesMatchupNormalization
                    ? HandicapCalculator.normalizedParticipants(
                        unnormalizedParticipants ?? participants,
                        for: matchup,
                        teams: teams,
                        scoringGroups: scoringGroups
                    )
                    : participants
                let matchupScoringUnits: [ScoringUnit]
                let matchupBaseValues: [String: [Int: PipelineHoleValue]]
                let matchupPreCompareValues: [String: [Int: PipelineHoleValue]]
                if usesMatchupNormalization {
                    let rawUnits = resolvedScoringUnits(
                        participants: matchupParticipants,
                        teams: teams,
                        scoringGroups: scoringGroups,
                        segment: segment,
                        template: template,
                        scoreOwnerScope: scoreOwnerScope
                    )
                    matchupScoringUnits = augmentedScoringUnitsForMatchups(
                        scoringUnitsWithoutStoredHandicapAllowances(rawUnits),
                        matchups: matchups,
                        scoringGroups: scoringGroups,
                        template: template
                    )
                    let matchupSelectionGroups = resolvedSelectionGroups(
                        participants: matchupParticipants,
                        scoringGroups: scoringGroups,
                        selectionDomain: effectiveSelectionDomain,
                        template: template
                    )
                    let matchupRawValues = buildRawValues(
                        scoringUnits: matchupScoringUnits,
                        participants: matchupParticipants,
                        scoringGroups: scoringGroups,
                        holeNumbers: holeNumbers,
                        holeMap: holeMap,
                        scoreIndex: scoreIndex,
                        lookupSegmentIDs: lookupSegmentIDs,
                        basis: basis,
                        scoreInputMode: scoreInputMode,
                        allowParticipantFallback: !usesSharedScoreSource,
                        sharedScoreHandicapConfig: usesSharedScoreSource
                            ? (sharedScoreHandicapConfig ?? template.requirements.defaultHandicapConfig)
                            : nil,
                        handicapStrokeBasis: handicapStrokeBasis
                    )
                    matchupBaseValues = applyBaseScoringStages(
                        values: matchupRawValues,
                        pipeline: template.pipeline,
                        holeNumbers: holeNumbers
                    )
                    matchupPreCompareValues = runPreCompareStages(
                        values: matchupRawValues,
                        pipeline: template.pipeline,
                        holeNumbers: holeNumbers,
                        subject: template.subject,
                        participants: matchupParticipants,
                        teams: teams,
                        selectionGroups: matchupSelectionGroups
                    )
                } else {
                    matchupScoringUnits = scoringUnits
                    matchupBaseValues = baseValues
                    matchupPreCompareValues = preCompareValues
                }
                if shouldUseDomainSelectionForMatchup(
                    matchup,
                    domain: effectiveSelectionDomain,
                    template: template
                ), let rows = buildDomainSelectedMatchupRows(
                    matchup: matchup,
                    values: matchupBaseValues,
                    participants: matchupParticipants,
                    teams: teams,
                    scoringGroups: scoringGroups,
                    scoringUnits: matchupScoringUnits,
                    holeNumbers: holeNumbers,
                    template: template,
                    teamScoring: teamScoring,
                    perHoleWinPoints: perHoleWinPoints
                ) {
                    let minimumStatus = minimumCountStatus(
                        matchup: matchup,
                        values: matchupBaseValues,
                        participants: matchupParticipants,
                        teams: teams,
                        scoringGroups: scoringGroups,
                        scoringUnits: matchupScoringUnits,
                        holeNumbers: holeNumbers,
                        teamScoring: teamScoring
                    )
                    matchupResults.append(MatchupScoringResult(
                        matchup: matchup,
                        rows: rows,
                        minimumCountStatus: minimumStatus
                    ))
                    allRows.append(contentsOf: rows)
                    continue
                }

                let matchupSides = resolvedMatchupSides(
                    matchup: matchup,
                    participants: matchupParticipants,
                    teams: teams,
                    scoringGroups: scoringGroups,
                    scoringUnits: matchupScoringUnits
                )
                let pairingValues = matchupValues(
                    values: matchupPreCompareValues,
                    sides: matchupSides
                )

                let compared = runCompareStages(
                    values: pairingValues,
                    pipeline: template.pipeline,
                    holeNumbers: holeNumbers,
                    participants: matchupParticipants,
                    teams: teams,
                    perHoleWinPoints: perHoleWinPoints
                )

                let rows = buildScoringRows(
                    from: compared,
                    holeNumbers: holeNumbers,
                    participants: matchupParticipants,
                    teams: teams,
                    scoringGroups: scoringGroups,
                    scoringUnits: matchupScoringUnits
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
            participantIDs: usesSharedScoreSource ? scoringUnits.map(\.id) : participants.map(\.id),
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

    // MARK: - Vegas Computation

    static func computeVegas(
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        template: GameTemplate,
        vegasMode: RoundVegasMode,
        selectionRule: RoundVegasSelectionRule,
        selectionScope: AggregationScope,
        scoreLookupSegmentIDs: [String]? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> ScoringResult {
        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let scoreIndex = buildScoreIndex(
            scores: scores,
            includeParticipantAliases: template.scoreSource != .shared
        )
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? resolvedScoreLookupSegmentIDs(primarySegment: segment, scores: scores)
        let rawValues = buildRawValues(
            participants: participants,
            holeNumbers: holeNumbers,
            holeMap: holeMap,
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs,
            basis: basis,
            scoreInputMode: scoreInputMode,
            handicapStrokeBasis: handicapStrokeBasis
        )

        let participantsByTeam = Dictionary(grouping: participants.compactMap { participant -> (String, RoundParticipant)? in
            guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return (teamID, participant)
        }, by: \.0).mapValues { $0.map(\.1) }

        let orderedTeamIDs = teams.sorted { $0.index < $1.index }.map(\.id)
            + participantsByTeam.keys.filter { teamID in !teams.contains(where: { $0.id == teamID }) }.sorted()

        let scoreForBasis: (PipelineHoleValue) -> Int = { value in
            if scoreInputMode == .friendlyRelativeToPar {
                return value.scoreToPar
            }
            return basis == .net ? value.netStrokes : value.grossStrokes
        }

        let preselectedPairIDsByTeam: [String: [String]]
        if vegasMode == .selectedPair, selectionScope == .perRound {
            preselectedPairIDsByTeam = Dictionary(uniqueKeysWithValues: participantsByTeam.compactMap { teamID, members in
                let selected = selectVegasParticipants(
                    participants: members,
                    rawValues: rawValues,
                    holeNumbers: holeNumbers,
                    rule: selectionRule,
                    scope: .perRound
                )
                guard selected.count == 2 else { return nil }
                return (teamID, selected)
            })
        } else {
            preselectedPairIDsByTeam = [:]
        }

        let rows: [ScoringRow] = orderedTeamIDs.compactMap { teamID in
            let teamParticipants = participantsByTeam[teamID] ?? []
            guard teamParticipants.isPopulated else { return nil }

            var holeValues: [Int: ScoringRow.HoleValue] = [:]
            var countedIDs = Set<String>()

            for holeNumber in holeNumbers {
                let pairDetails: [VegasPairDetail]
                switch vegasMode {
                case .exactPair:
                    pairDetails = vegasDetailsForParticipants(
                        participantIDs: teamParticipants.map(\.id),
                        holeNumber: holeNumber,
                        rawValues: rawValues,
                        scoreForBasis: scoreForBasis
                    ).map { [$0] } ?? []
                case .partnershipAggregate:
                    let teamPartnerships = scoringGroups
                        .filter { $0.kind == .partnership && $0.teamID == teamID }
                        .sorted { ($0.label ?? $0.id) < ($1.label ?? $1.id) }

                    if teamParticipants.count == 2 && teamPartnerships.isEmpty {
                        pairDetails = vegasDetailsForParticipants(
                            participantIDs: teamParticipants.map(\.id),
                            holeNumber: holeNumber,
                            rawValues: rawValues,
                            scoreForBasis: scoreForBasis
                        ).map { [$0] } ?? []
                    } else {
                        pairDetails = teamPartnerships.compactMap { partnership in
                            vegasDetailsForParticipants(
                                participantIDs: partnership.memberIDs,
                                holeNumber: holeNumber,
                                rawValues: rawValues,
                                scoreForBasis: scoreForBasis,
                                partnershipID: partnership.id
                            )
                        }
                    }
                case .selectedPair:
                    let selectedParticipantIDs: [String]
                    if selectionScope == .perRound {
                        selectedParticipantIDs = preselectedPairIDsByTeam[teamID] ?? []
                    } else {
                        selectedParticipantIDs = selectVegasParticipants(
                            participants: teamParticipants,
                            rawValues: rawValues,
                            holeNumbers: [holeNumber],
                            rule: selectionRule,
                            scope: .perHole,
                            holeNumber: holeNumber
                        )
                    }
                    pairDetails = vegasDetailsForParticipants(
                        participantIDs: selectedParticipantIDs,
                        holeNumber: holeNumber,
                        rawValues: rawValues,
                        scoreForBasis: scoreForBasis
                    ).map { [$0] } ?? []
                }

                guard pairDetails.isPopulated else { continue }
                pairDetails.forEach { detail in
                    detail.participantIDs.forEach { countedIDs.insert($0) }
                }

                let totalComposite = pairDetails.reduce(0) { $0 + $1.composite }
                holeValues[holeNumber] = .init(
                    rawStrokes: nil,
                    netStrokes: nil,
                    points: Double(totalComposite),
                    pickedUp: false,
                    vegasPairs: pairDetails
                )
            }

            let total = holeValues.values.reduce(0.0) { $0 + $1.points }
            return ScoringRow(
                scoringUnitID: teamID,
                participantIDs: teamParticipants.map(\.id),
                countingParticipantIDs: countedIDs.isEmpty ? teamParticipants.map(\.id) : Array(countedIDs).sorted(),
                owner: .team,
                holeValues: holeValues,
                total: total,
                holesPlayed: holeValues.count
            )
        }

        let holeStates = computeHoleStates(
            holeNumbers: holeNumbers,
            participantIDs: participants.map(\.id),
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs
        )

        return ScoringResult(rows: rows, holeStates: holeStates, template: template, matchupResults: [])
    }

    // MARK: - Team Scoring Builder

    static func computeWithTeamScoring(
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        unnormalizedParticipants: [RoundParticipant]? = nil,
        teams: [RoundTeam],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        template: GameTemplate,
        teamScoring: RoundTeamScoringConfiguration,
        matchupResolutionStyle: RoundMatchupResolutionStyle,
        matchupScoringStyle: RoundMatchupScoringStyle = .aggregateRoundTotal,
        perHoleWinPoints: Double = 1.0,
        scoreLookupSegmentIDs: [String]? = nil,
        resolvedCompetitionScope: CompetitionScope? = nil,
        handicapNormalizationMode: HandicapNormalizationMode = .off,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
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
            basis: basis,
            scoreInputMode: scoreInputMode,
            handicapStrokeBasis: handicapStrokeBasis
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
                let matchupRows: [ScoringRow]
                if handicapNormalizationMode == .matchup {
                    let matchupParticipants = HandicapCalculator.normalizedParticipants(
                        unnormalizedParticipants ?? participants,
                        for: matchup,
                        teams: teams,
                        scoringGroups: []
                    )
                    let matchupRawValues = buildRawValues(
                        participants: matchupParticipants,
                        holeNumbers: holeNumbers,
                        holeMap: holeMap,
                        scoreIndex: scoreIndex,
                        lookupSegmentIDs: lookupSegmentIDs,
                        basis: basis,
                        scoreInputMode: scoreInputMode,
                        handicapStrokeBasis: handicapStrokeBasis
                    )
                    let matchupBaseValues = applyBaseScoringStages(
                        values: matchupRawValues,
                        pipeline: template.pipeline,
                        holeNumbers: holeNumbers
                    )
                    let localRows = buildTeamScoringRows(
                        values: matchupBaseValues,
                        participants: matchupParticipants,
                        teams: teams,
                        holeNumbers: holeNumbers,
                        leaderboardSort: template.leaderboardSort,
                        teamScoring: teamScoring
                    )
                    let localRowByTeamID = Dictionary(uniqueKeysWithValues: localRows.map { ($0.scoringUnitID, $0) })
                    matchupRows = matchup.pairingIDs().compactMap { localRowByTeamID[$0] }
                } else {
                    matchupRows = matchup.pairingIDs().compactMap { rowByTeamID[$0] }
                }
                let rows = matchupRows
                guard rows.count == 2 else { return nil }
                let minimumStatus = minimumCountStatus(
                    matchup: matchup,
                    values: baseValues,
                    participants: unnormalizedParticipants ?? participants,
                    teams: teams,
                    scoringGroups: [],
                    scoringUnits: [],
                    holeNumbers: holeNumbers,
                    teamScoring: teamScoring
                )
                if matchupScoringStyle == .holeByHolePoints {
                    return MatchupScoringResult(
                        matchup: matchup,
                        rows: buildMatchPlayPointRows(
                            from: rows,
                            holeNumbers: holeNumbers,
                            perHoleWinPoints: perHoleWinPoints
                        ),
                        isPointsFormat: true,
                        minimumCountStatus: minimumStatus
                    )
                }
                switch matchupResolutionStyle {
                case .roundAggregate:
                    return MatchupScoringResult(
                        matchup: matchup,
                        rows: rows,
                        isPointsFormat: false,
                        minimumCountStatus: minimumStatus
                    )
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

    private static func buildMatchPlayPointRows(
        from aggregateRows: [ScoringRow],
        holeNumbers: [Int],
        perHoleWinPoints: Double
    ) -> [ScoringRow] {
        guard aggregateRows.count == 2 else { return aggregateRows }

        let first = aggregateRows[0]
        let second = aggregateRows[1]
        var firstHoleValues: [Int: ScoringRow.HoleValue] = [:]
        var secondHoleValues: [Int: ScoringRow.HoleValue] = [:]

        for holeNumber in holeNumbers {
            guard let firstValue = first.holeValues[holeNumber],
                  let secondValue = second.holeValues[holeNumber] else {
                continue
            }

            let firstPoints: Double
            let secondPoints: Double
            if firstValue.points < secondValue.points {
                firstPoints = perHoleWinPoints
                secondPoints = 0
            } else if secondValue.points < firstValue.points {
                firstPoints = 0
                secondPoints = perHoleWinPoints
            } else {
                firstPoints = perHoleWinPoints / 2
                secondPoints = perHoleWinPoints / 2
            }

            firstHoleValues[holeNumber] = .init(
                rawStrokes: firstValue.rawStrokes,
                netStrokes: firstValue.netStrokes,
                points: firstPoints,
                pickedUp: firstValue.pickedUp
            )
            secondHoleValues[holeNumber] = .init(
                rawStrokes: secondValue.rawStrokes,
                netStrokes: secondValue.netStrokes,
                points: secondPoints,
                pickedUp: secondValue.pickedUp
            )
        }

        return [
            matchPlayPointRow(from: first, holeValues: firstHoleValues),
            matchPlayPointRow(from: second, holeValues: secondHoleValues),
        ]
    }

    private static func matchPlayPointRow(
        from aggregateRow: ScoringRow,
        holeValues: [Int: ScoringRow.HoleValue]
    ) -> ScoringRow {
        ScoringRow(
            scoringUnitID: aggregateRow.scoringUnitID,
            participantIDs: aggregateRow.participantIDs,
            countingParticipantIDs: aggregateRow.countingParticipantIDs,
            owner: aggregateRow.owner,
            holeValues: holeValues,
            total: holeValues.values.reduce(0) { $0 + $1.points },
            holesPlayed: holeValues.count
        )
    }

    static func computeParticipantGroupAggregateRow(
        scoringUnitID: String,
        owner: ScoringOwner,
        participantIDs: [String],
        scores: [ScoreEntry],
        participants: [RoundParticipant],
        segment: RoundSegment,
        holes: [Hole],
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        template: GameTemplate,
        teamScoring: RoundTeamScoringConfiguration,
        scoreLookupSegmentIDs: [String]? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> ScoringRow? {
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let groupParticipants = participantIDs.compactMap { participantByID[$0] }
        guard groupParticipants.isPopulated else { return nil }

        let holeNumbers = segment.holeRange.holeNumbers
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let scoreIndex = buildScoreIndex(scores: scores)
        let lookupSegmentIDs = scoreLookupSegmentIDs ?? resolvedScoreLookupSegmentIDs(primarySegment: segment, scores: scores)

        let rawValues = buildRawValues(
            participants: groupParticipants,
            holeNumbers: holeNumbers,
            holeMap: holeMap,
            scoreIndex: scoreIndex,
            lookupSegmentIDs: lookupSegmentIDs,
            basis: basis,
            scoreInputMode: scoreInputMode,
            handicapStrokeBasis: handicapStrokeBasis
        )

        let baseValues = applyBaseScoringStages(
            values: rawValues,
            pipeline: template.pipeline,
            holeNumbers: holeNumbers
        )

        return buildParticipantGroupAggregateRow(
            scoringUnitID: scoringUnitID,
            owner: owner,
            values: baseValues,
            participants: groupParticipants,
            holeNumbers: holeNumbers,
            leaderboardSort: template.leaderboardSort,
            teamScoring: teamScoring
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

    private static func buildParticipantGroupAggregateRow(
        scoringUnitID: String,
        owner: ScoringOwner,
        values: [String: [Int: PipelineHoleValue]],
        participants: [RoundParticipant],
        holeNumbers: [Int],
        leaderboardSort: LeaderboardSort,
        teamScoring: RoundTeamScoringConfiguration
    ) -> ScoringRow? {
        let participantIDs = participants.map(\.id)
        guard participantIDs.isPopulated else { return nil }

        let isHighestWins = leaderboardSort == .highestWins
        let countingIDs: [String]
        let holeValues: [Int: ScoringRow.HoleValue]

        switch teamScoring.scope {
        case .perHole:
            let built = buildPerHoleTeamValues(
                values: values,
                participants: participants,
                holeNumbers: holeNumbers,
                isHighestWins: isHighestWins,
                teamScoring: teamScoring
            )
            countingIDs = Array(built.countingParticipantIDs).sorted()
            holeValues = built.holeValues
        case .perRound:
            let built = buildPerRoundTeamValues(
                values: values,
                participants: participants,
                holeNumbers: holeNumbers,
                isHighestWins: isHighestWins,
                teamScoring: teamScoring
            )
            countingIDs = built.countingParticipantIDs
            holeValues = built.holeValues
        }

        guard holeValues.isPopulated else { return nil }
        let total = holeNumbers.compactMap { holeValues[$0]?.points }.reduce(0, +)

        return ScoringRow(
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            countingParticipantIDs: countingIDs.isEmpty ? participantIDs : countingIDs,
            owner: owner,
            holeValues: holeValues,
            total: total,
            holesPlayed: holeValues.count
        )
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
        let participantTotals: [(String, Double)] = participants.compactMap { participant in
            let playedValues = holeNumbers.compactMap { values[participant.id]?[$0]?.points }
            guard playedValues.isPopulated else { return nil }
            let total = playedValues.reduce(0, +)
            return (participant.id, total)
        }

        guard participantTotals.isPopulated else {
            return ([:], [])
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

    private static func minimumCountStatus(
        matchup: TeamMatchup,
        values: [String: [Int: PipelineHoleValue]],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup],
        scoringUnits: [ScoringUnit],
        holeNumbers: [Int],
        teamScoring: RoundTeamScoringConfiguration
    ) -> MatchupMinimumCountStatus? {
        guard teamScoring.mode != .all else { return nil }
        let requiredCount = max(1, teamScoring.count)
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let sides = resolvedMatchupSides(
            matchup: matchup,
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            scoringUnits: scoringUnits
        )
        guard sides.count == 2 else { return nil }
        let activeHoleNumbers = holeNumbers.filter { holeNumber in
            sides.contains { side in
                side.participantIDs.contains { participantID in
                    values[participantID]?[holeNumber] != nil
                }
            }
        }

        let sideStatuses = sides.map { side in
            let sideParticipants = side.participantIDs.compactMap { participantByID[$0] }
            let actualCount: Int
            switch teamScoring.scope {
            case .perRound:
                actualCount = sideParticipants.filter { participant in
                    holeNumbers.contains { values[participant.id]?[$0] != nil }
                }.count
            case .perHole:
                if activeHoleNumbers.isEmpty {
                    actualCount = 0
                } else {
                    actualCount = activeHoleNumbers.map { holeNumber in
                        sideParticipants.filter { values[$0.id]?[holeNumber] != nil }.count
                    }.min() ?? 0
                }
            }

            let shortageKind: MatchupMinimumCountShortageKind?
            if sideParticipants.count < requiredCount {
                shortageKind = .structural
            } else if actualCount < requiredCount {
                shortageKind = .missingScores
            } else {
                shortageKind = nil
            }

            return MatchupMinimumCountSideStatus(
                sideID: side.sideID,
                requiredCount: requiredCount,
                actualCount: min(actualCount, requiredCount),
                availableParticipantCount: sideParticipants.count,
                shortageKind: shortageKind
            )
        }

        guard sideStatuses.contains(where: \.isUnderMinimum) else { return nil }
        return MatchupMinimumCountStatus(
            requiredCount: requiredCount,
            scope: teamScoring.scope,
            sideStatuses: sideStatuses
        )
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
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        allowParticipantFallback: Bool = true,
        sharedScoreHandicapConfig: HandicapConfiguration? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
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
            let handicap = resolvedHandicap(
                for: scoringUnit,
                participants: memberParticipants,
                basis: basis,
                sharedScoreHandicapConfig: sharedScoreHandicapConfig
            )
            var unitHoles: [Int: PipelineHoleValue] = [:]

            for holeNumber in holeNumbers {
                let par = holeMap[holeNumber]?.par ?? 4
                let directEntry = scoreOwnerEntry(
                    for: scoringUnit,
                    scoringGroups: scoringGroups,
                    scoreIndex: scoreIndex,
                    holeNumber: holeNumber,
                    lookupSegmentIDs: lookupSegmentIDs
                )
                let fallbackEntry = allowParticipantFallback
                    ? participantIDs.lazy.compactMap { participantID in
                        scoreEntry(
                            scoreIndex: scoreIndex,
                            scoringUnitID: participantID,
                            holeNumber: holeNumber,
                            lookupSegmentIDs: lookupSegmentIDs
                        )
                    }.first
                    : nil
                guard let entry = directEntry ?? fallbackEntry else { continue }
                guard let grossRelativeToPar = resolvedGrossRelativeToPar(entry: entry, par: par) else { continue }

                let received = strokesReceived(
                    handicap: handicap,
                    holeNumber: holeNumber,
                    holeMap: holeMap,
                    playedHoleNumbers: holeNumbers,
                    useHandicaps: basis == .net,
                    handicapStrokeBasis: handicapStrokeBasis
                )
                let gross = resolvedGrossStrokes(entry: entry, par: par) ?? max(1, par + grossRelativeToPar)
                let net = max(0, gross - received)
                let netRelativeToPar = grossRelativeToPar - received
                let scoreToPar = basis == .net ? netRelativeToPar : grossRelativeToPar
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

    private static func scoreOwnerEntry(
        for scoringUnit: ScoringUnit,
        scoringGroups: [RoundScoringGroup],
        scoreIndex: [String: ScoreEntry],
        holeNumber: Int,
        lookupSegmentIDs: [String]
    ) -> ScoreEntry? {
        for scoringUnitID in scoreLookupIDs(for: scoringUnit, scoringGroups: scoringGroups) {
            if let entry = scoreEntry(
                scoreIndex: scoreIndex,
                scoringUnitID: scoringUnitID,
                holeNumber: holeNumber,
                lookupSegmentIDs: lookupSegmentIDs
            ) {
                return entry
            }
        }
        return nil
    }

    private static func scoreLookupIDs(
        for scoringUnit: ScoringUnit,
        scoringGroups: [RoundScoringGroup]
    ) -> [String] {
        var ids: [String] = []
        var seen = Set<String>()

        func append(_ id: String) {
            guard id.isPopulated, !seen.contains(id) else { return }
            ids.append(id)
            seen.insert(id)
        }

        append(scoringUnit.id)

        switch scoringUnit.owner {
        case .team:
            scoringUnit.ownerIDs.forEach(append)
        case .scoreOwner:
            let ownerIDs = Set(scoringUnit.ownerIDs)
            scoringGroups
                .filter { group in
                    group.memberIDs.isPopulated && Set(group.memberIDs) == ownerIDs
                }
                .map(\.id)
                .forEach(append)
        case .participant:
            break
        }

        return ids
    }

    private static func scoringUnitsWithoutStoredHandicapAllowances(_ scoringUnits: [ScoringUnit]) -> [ScoringUnit] {
        scoringUnits.map { unit in
            var updated = unit
            updated.handicapAllowance = nil
            updated.handicapAdjustments = nil
            return updated
        }
    }

    static func buildRawValues(
        participants: [RoundParticipant],
        holeNumbers: [Int],
        holeMap: [Int: Hole],
        scoreIndex: [String: ScoreEntry],
        lookupSegmentIDs: [String],
        basis: ScoreBasis,
        scoreInputMode: RoundScoreInputMode = .strokes,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
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
            basis: basis,
            scoreInputMode: scoreInputMode,
            allowParticipantFallback: true,
            handicapStrokeBasis: handicapStrokeBasis
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

    private static func selectVegasParticipants(
        participants: [RoundParticipant],
        rawValues: [String: [Int: PipelineHoleValue]],
        holeNumbers: [Int],
        rule: RoundVegasSelectionRule,
        scope: AggregationScope,
        holeNumber: Int? = nil
    ) -> [String] {
        let scoredParticipants: [(String, Double)] = participants.compactMap { participant in
            let values: [PipelineHoleValue]
            switch scope {
            case .perHole:
                guard let holeNumber, let value = rawValues[participant.id]?[holeNumber] else { return nil }
                values = [value]
            case .perRound:
                let holeMap = rawValues[participant.id] ?? [:]
                values = holeNumbers.compactMap { holeMap[$0] }
                guard values.isPopulated else { return nil }
            }

            let total = values.reduce(0.0) { $0 + $1.points }
            return (participant.id, total)
        }

        guard scoredParticipants.count >= 2 else { return [] }
        let ordered = scoredParticipants.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0 < $1.0
        }

        switch rule {
        case .best2:
            return Array(ordered.prefix(2).map(\.0))
        case .worst2:
            return Array(ordered.suffix(2).map(\.0)).sorted()
        case .bestAndWorst:
            guard let best = ordered.first?.0, let worst = ordered.last?.0, best != worst else { return [] }
            return [best, worst].sorted()
        }
    }

    private static func vegasDetailsForParticipants(
        participantIDs: [String],
        holeNumber: Int,
        rawValues: [String: [Int: PipelineHoleValue]],
        scoreForBasis: (PipelineHoleValue) -> Int,
        partnershipID: String? = nil
    ) -> VegasPairDetail? {
        let uniqueIDs = Array(Set(participantIDs.filter(\.isPopulated))).sorted()
        guard uniqueIDs.count == 2 else { return nil }

        let scoredMembers: [(String, Int)] = uniqueIDs.compactMap { participantID in
            guard let value = rawValues[participantID]?[holeNumber] else { return nil }
            return (participantID, scoreForBasis(value))
        }
        guard scoredMembers.count == 2 else { return nil }

        let orderedScores = scoredMembers.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0 < $1.0
        }
        let low = orderedScores[0].1
        let high = orderedScores[1].1
        let orderedParticipantIDs = orderedScores.map(\.0)
        let idSeed = partnershipID?.isPopulated == true ? partnershipID! : orderedParticipantIDs.joined(separator: "_")

        return VegasPairDetail(
            id: "\(idSeed)_\(holeNumber)",
            participantIDs: orderedParticipantIDs,
            partnershipID: partnershipID,
            lowStroke: low,
            highStroke: high,
            composite: (low * 10) + high
        )
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

    static func buildScoreIndex(
        scores: [ScoreEntry],
        includeParticipantAliases: Bool = true
    ) -> [String: ScoreEntry] {
        var index: [String: ScoreEntry] = [:]
        for entry in scores {
            let key = scoreIndexKey(scoringUnitID: entry.scoringUnitID, holeNumber: entry.holeNumber, segmentID: entry.segmentID)
            if index[key] == nil { index[key] = entry }
            guard includeParticipantAliases else { continue }
            for pid in entry.participantIDs where pid != entry.scoringUnitID {
                let pk = scoreIndexKey(scoringUnitID: pid, holeNumber: entry.holeNumber, segmentID: entry.segmentID)
                if index[pk] == nil { index[pk] = entry }
            }
        }
        return index
    }

    static func resolvedGrossRelativeToPar(entry: ScoreEntry, par: Int) -> Int? {
        if let relativeToPar = entry.relativeToPar {
            return relativeToPar
        }
        guard let strokes = entry.strokes else { return nil }
        return strokes - par
    }

    static func resolvedGrossStrokes(entry: ScoreEntry, par: Int) -> Int? {
        if let strokes = entry.strokes {
            return strokes
        }
        guard let relativeToPar = entry.relativeToPar else { return nil }
        return max(1, par + relativeToPar)
    }

    static func strokesReceived(
        handicap: Int,
        holeHandicap: Int?,
        useHandicaps: Bool
    ) -> Int {
        guard useHandicaps else { return 0 }
        let hcp = max(0, handicap)
        guard hcp > 0, let holeHandicap, holeHandicap > 0 else { return 0 }

        let fullRounds = hcp / 18
        let remainder = hcp % 18
        let bonusStroke = holeHandicap <= remainder ? 1 : 0
        return fullRounds + bonusStroke
    }

    static func strokesReceived(
        handicap: Int,
        holeNumber: Int,
        holes: [Hole],
        playedHoleNumbers: [Int],
        useHandicaps: Bool,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> Int {
        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        return strokesReceived(
            handicap: handicap,
            holeNumber: holeNumber,
            holeMap: holeMap,
            playedHoleNumbers: playedHoleNumbers,
            useHandicaps: useHandicaps,
            handicapStrokeBasis: handicapStrokeBasis
        )
    }

    static func strokesReceived(
        handicap: Int,
        holeNumber: Int,
        holeMap: [Int: Hole],
        playedHoleNumbers: [Int],
        useHandicaps: Bool,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
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

        let allocationOrder: [Int]
        if rankedHoleNumbers.isPopulated {
            allocationOrder = rankedHoleNumbers
        } else {
            allocationOrder = playedHoleNumbers.filter { holeMap[$0] != nil || $0 == holeNumber }
        }

        guard let holeIndex = allocationOrder.firstIndex(of: holeNumber) else { return 0 }

        let holesInPlay = allocationOrder.count
        guard holesInPlay > 0 else { return 0 }
        let strokesForMatch = handicapStrokesForPlayedHoles(
            handicap: hcp,
            basis: handicapStrokeBasis,
            holesInPlay: holesInPlay
        )
        guard strokesForMatch > 0 else { return 0 }

        let full = strokesForMatch / holesInPlay
        let rem = strokesForMatch % holesInPlay
        let extra = holeIndex < rem ? 1 : 0
        return full + extra
    }

    static func handicapStrokesForPlayedHoles(
        handicap: Int,
        basis: SeriesHandicapStrokeBasis,
        holesInPlay: Int
    ) -> Int {
        let hcp = max(0, handicap)
        guard hcp > 0, holesInPlay > 0 else { return 0 }
        guard holesInPlay != basis.holeCount else { return hcp }
        let scaled = Double(hcp) * Double(holesInPlay) / Double(basis.holeCount)
        return Int(scaled.rounded(.toNearestOrAwayFromZero))
    }

    private struct ResolvedMatchupSide {
        let sideID: String
        let participantIDs: [String]
        let lookupIDs: [String]
    }

    static func resolvedSelectionDomain(
        explicit: ScoringSelectionDomain?,
        matchups: [TeamMatchup],
        scoringGroups: [RoundScoringGroup],
        scoreOwnerScope: RoundScoreOwnerScope,
        teamScoring: RoundTeamScoringConfiguration,
        template: GameTemplate,
        teams: [RoundTeam]
    ) -> ScoringSelectionDomain {
        if let explicit { return explicit }

        let partnershipGroupIDs = Set(scoringGroups.filter { $0.kind == .partnership }.map(\.id))
        let teeGroupIDs = Set(scoringGroups.filter { $0.kind == .teeGroup }.map(\.id))
        let hasPartnershipMatchup = matchups.contains { matchup in
            guard matchup.effectiveMode.usesScoringGroupIDs, matchup.isValid else { return false }
            let sideIDs = matchup.pairingIDs()
            return sideIDs.count == 2 && sideIDs.allSatisfy { partnershipGroupIDs.contains($0) }
        }
        if hasPartnershipMatchup {
            return .partnership
        }

        let hasTeeGroupMatchup = matchups.contains { matchup in
            guard matchup.effectiveMode.usesScoringGroupIDs, matchup.isValid else { return false }
            let sideIDs = matchup.pairingIDs()
            return sideIDs.count == 2 && sideIDs.allSatisfy { teeGroupIDs.contains($0) }
        }
        if hasTeeGroupMatchup {
            return .teeGroup
        }

        if template.scoreSource == .shared {
            switch scoreOwnerScope {
            case .partnership:
                return .partnership
            case .teeGroup:
                return .teeGroup
            case .individual:
                break
            }
        }

        if teamScoring.mode != .all || template.requirements.requiresTeams || teams.isPopulated {
            return .team
        }
        return .participant
    }

    private static func shouldUseDomainSelectionForMatchup(
        _ matchup: TeamMatchup,
        domain: ScoringSelectionDomain,
        template: GameTemplate
    ) -> Bool {
        guard template.scoreSource == .individual,
              matchup.effectiveMode.usesScoringGroupIDs else {
            return false
        }
        return domain == .partnership || domain == .teeGroup
    }

    private static func buildDomainSelectedMatchupRows(
        matchup: TeamMatchup,
        values: [String: [Int: PipelineHoleValue]],
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup],
        scoringUnits: [ScoringUnit],
        holeNumbers: [Int],
        template: GameTemplate,
        teamScoring: RoundTeamScoringConfiguration,
        perHoleWinPoints: Double
    ) -> [ScoringRow]? {
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let sides = resolvedMatchupSides(
            matchup: matchup,
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            scoringUnits: scoringUnits
        )
        guard sides.count == 2 else { return nil }

        let sideRows = sides.compactMap { side -> ScoringRow? in
            let sideParticipants = side.participantIDs.compactMap { participantByID[$0] }
            guard sideParticipants.isPopulated else { return nil }
            return buildParticipantGroupAggregateRow(
                scoringUnitID: side.sideID,
                owner: .scoreOwner,
                values: values,
                participants: sideParticipants,
                holeNumbers: holeNumbers,
                leaderboardSort: selectionSort(for: template),
                teamScoring: teamScoring
            )
        }
        guard sideRows.count == 2 else { return nil }

        guard hasMatchPlayCompare(in: template) else {
            return sideRows
        }

        let comparableValues: [String: [Int: PipelineHoleValue]] = Dictionary(uniqueKeysWithValues: sideRows.map { row in
            let holeMap: [Int: PipelineHoleValue] = Dictionary(uniqueKeysWithValues: row.holeValues.map { holeNumber, value in
                let strokes = Int(value.points)
                return (
                    holeNumber,
                    PipelineHoleValue(
                        participantID: row.scoringUnitID,
                        grossStrokes: value.rawStrokes ?? strokes,
                        netStrokes: value.netStrokes ?? strokes,
                        par: 0,
                        scoreToPar: strokes,
                        points: value.points,
                        pickedUp: value.pickedUp
                    )
                )
            })
            return (row.scoringUnitID, holeMap)
        })
        let compared = runCompareStages(
            values: comparableValues,
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
        let rowByID: [String: ScoringRow] = Dictionary(uniqueKeysWithValues: rows.map { ($0.scoringUnitID, $0) })
        return sides.compactMap { rowByID[$0.sideID] }
    }

    private static func selectionSort(for template: GameTemplate) -> LeaderboardSort {
        hasMatchPlayCompare(in: template) ? .lowestWins : template.leaderboardSort
    }

    private static func hasMatchPlayCompare(in template: GameTemplate) -> Bool {
        template.pipeline.contains { stage in
            guard case .compare(let rule) = stage else { return false }
            return rule.mode == .matchPlay
        }
    }

    private static func augmentedScoringUnitsForMatchups(
        _ scoringUnits: [ScoringUnit],
        matchups: [TeamMatchup],
        scoringGroups: [RoundScoringGroup],
        template: GameTemplate
    ) -> [ScoringUnit] {
        guard template.scoreSource == .shared else { return scoringUnits }

        var units = scoringUnits
        var seenIDs = Set(scoringUnits.map(\.id))
        var existingMemberSets = Set(scoringUnits
            .filter { $0.owner == .scoreOwner }
            .map { Set($0.ownerIDs) })
        let scoringGroupsByID = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })

        for matchup in matchups where matchup.effectiveMode.usesScoringGroupIDs {
            for sideID in matchup.pairingIDs() {
                guard let group = scoringGroupsByID[sideID],
                      group.memberIDs.isPopulated,
                      !seenIDs.contains(group.id),
                      !existingMemberSets.contains(Set(group.memberIDs)) else {
                    continue
                }
                units.append(ScoringUnit(
                    id: group.id,
                    owner: .scoreOwner,
                    ownerIDs: group.memberIDs,
                    scoringMethod: .aggregate,
                    aggregation: .init(mode: .sumAll, scope: .perHole)
                ))
                seenIDs.insert(group.id)
                existingMemberSets.insert(Set(group.memberIDs))
            }
        }

        return units
    }

    private static func resolvedMatchupSides(
        matchup: TeamMatchup,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup],
        scoringUnits: [ScoringUnit]
    ) -> [ResolvedMatchupSide] {
        let mode = matchup.effectiveMode
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let teamParticipantIDs = Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
            guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return (teamID, participant.id)
        }, by: \.0).mapValues { $0.map(\.1) }
        let scoringGroupsByID = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })
        let teamIDs = Set(teams.map(\.id))

        return matchup.pairingIDs().map { sideID in
            let participantIDs: [String]
            switch mode {
            case .individual:
                participantIDs = participantByID[sideID] != nil ? [sideID] : []
            case .team:
                participantIDs = teamParticipantIDs[sideID] ?? []
            case .partnership, .teeGroup, .scoreOwner:
                if let group = scoringGroupsByID[sideID] {
                    participantIDs = group.memberIDs
                } else if let scoringUnit = scoringUnits.first(where: { $0.id == sideID }) {
                    participantIDs = resolvedParticipantIDs(
                        for: scoringUnit,
                        participantsByID: participantByID,
                        teamParticipantIDs: teamParticipantIDs,
                        scoringGroupsByID: scoringGroupsByID
                    )
                } else if teamIDs.contains(sideID) {
                    participantIDs = teamParticipantIDs[sideID] ?? []
                } else {
                    participantIDs = []
                }
            }

            let lookupIDs = matchupSideLookupIDs(
                sideID: sideID,
                mode: mode,
                participantIDs: participantIDs,
                scoringGroups: scoringGroups,
                scoringUnits: scoringUnits
            )

            return ResolvedMatchupSide(
                sideID: sideID,
                participantIDs: participantIDs,
                lookupIDs: lookupIDs
            )
        }
    }

    private static func matchupSideLookupIDs(
        sideID: String,
        mode: MatchupMode,
        participantIDs: [String],
        scoringGroups: [RoundScoringGroup],
        scoringUnits: [ScoringUnit]
    ) -> [String] {
        var ids: [String] = []
        var seen = Set<String>()
        func append(_ id: String?) {
            guard let id, id.isPopulated, !seen.contains(id) else { return }
            ids.append(id)
            seen.insert(id)
        }

        append(sideID)
        let participantSet = Set(participantIDs)

        switch mode {
        case .individual:
            break
        case .team:
            scoringUnits
                .filter { unit in
                    unit.owner == .team
                        && (unit.id == sideID || unit.ownerIDs.contains(sideID))
                }
                .forEach { append($0.id) }
        case .partnership, .teeGroup, .scoreOwner:
            if let group = scoringGroups.first(where: { $0.id == sideID }) {
                append(group.id)
                append(group.teamID)
            }
            scoringGroups
                .filter { group in
                    group.id == sideID
                        || (participantSet.isPopulated && Set(group.memberIDs) == participantSet)
                }
                .forEach { group in
                    append(group.id)
                    append(group.teamID)
                }
            scoringUnits
                .filter { unit in
                    unit.owner == .scoreOwner
                        && (unit.id == sideID
                            || unit.ownerIDs.contains(sideID)
                            || (participantSet.isPopulated && Set(unit.ownerIDs) == participantSet))
                }
                .forEach { append($0.id) }
        }

        return ids
    }

    private static func matchupValues(
        values: [String: [Int: PipelineHoleValue]],
        sides: [ResolvedMatchupSide]
    ) -> [String: [Int: PipelineHoleValue]] {
        var result: [String: [Int: PipelineHoleValue]] = [:]
        for side in sides {
            for lookupID in side.lookupIDs {
                guard let holeMap = values[lookupID] else { continue }
                result[side.sideID] = holeMap.mapValues { value in
                    PipelineHoleValue(
                        participantID: side.sideID,
                        grossStrokes: value.grossStrokes,
                        netStrokes: value.netStrokes,
                        par: value.par,
                        scoreToPar: value.scoreToPar,
                        points: value.points,
                        pickedUp: value.pickedUp
                    )
                }
                break
            }
        }
        return result
    }

    private static func resolvedScoringUnits(
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup],
        segment: RoundSegment,
        template: GameTemplate,
        scoreOwnerScope: RoundScoreOwnerScope
    ) -> [ScoringUnit] {
        if segment.scoringUnits.isPopulated {
            return segment.scoringUnits
        }

        if template.scoreSource == .shared {
            switch scoreOwnerScope {
            case .partnership:
                let units = scoringGroups
                    .filter { $0.kind == .partnership && $0.memberIDs.isPopulated }
                    .map { group in
                        ScoringUnit(
                            id: group.id,
                            owner: .scoreOwner,
                            ownerIDs: group.memberIDs,
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole)
                        )
                    }
                if units.isPopulated { return units }
            case .teeGroup:
                let persisted = scoringGroups
                    .filter { $0.kind == .teeGroup && $0.memberIDs.isPopulated }
                    .map { group in
                        ScoringUnit(
                            id: group.id,
                            owner: .scoreOwner,
                            ownerIDs: group.memberIDs,
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole)
                        )
                    }
                if persisted.isPopulated { return persisted }

                let grouped = Dictionary(grouping: participants) { $0.groupID ?? "" }
                let units = grouped.compactMap { groupID, members -> ScoringUnit? in
                    guard groupID.isPopulated, members.isPopulated else { return nil }
                    return ScoringUnit(
                        id: groupID,
                        owner: .scoreOwner,
                        ownerIDs: members.map(\.id),
                        scoringMethod: .aggregate,
                        aggregation: .init(mode: .sumAll, scope: .perHole)
                    )
                }
                if units.isPopulated { return units }
            case .individual:
                let participantsByTeam = Dictionary(grouping: participants) { $0.teamID ?? "" }
                let orderedTeamIDs = teams.sorted { $0.index < $1.index }.map(\.id)
                    + participantsByTeam.keys.filter { teamID in
                        teamID.isPopulated && !teams.contains(where: { $0.id == teamID })
                    }.sorted()
                let units = orderedTeamIDs.compactMap { teamID -> ScoringUnit? in
                    let memberIDs = participantsByTeam[teamID]?.map(\.id) ?? []
                    guard memberIDs.isPopulated else { return nil }
                    return ScoringUnit(
                        id: teamID,
                        owner: .team,
                        ownerIDs: [teamID],
                        scoringMethod: .aggregate,
                        aggregation: .init(mode: .sumAll, scope: .perHole)
                    )
                }
                if units.isPopulated { return units }
            }
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
        selectionDomain: ScoringSelectionDomain,
        template: GameTemplate
    ) -> [String: [String]] {
        switch selectionDomain {
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
        case .team:
            guard template.scoreSource == .individual else { return [:] }
            return Dictionary(grouping: participants.compactMap { participant -> (String, String)? in
                guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
                return (teamID, participant.id)
            }, by: \.0).mapValues { $0.map(\.1) }
        case .participant:
            return [:]
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
        basis: ScoreBasis,
        sharedScoreHandicapConfig: HandicapConfiguration?
    ) -> Int {
        guard basis == .net else { return 0 }

        return scoringUnitHandicap(
            for: scoringUnit,
            participants: participants,
            sharedScoreHandicapConfig: sharedScoreHandicapConfig
        )
    }

    static func scoringUnitHandicap(
        for scoringUnit: ScoringUnit,
        participants: [RoundParticipant],
        sharedScoreHandicapConfig: HandicapConfiguration? = nil
    ) -> Int {
        Int(scoringUnitHandicapStrokes(
            for: scoringUnit,
            participants: participants,
            sharedScoreHandicapConfig: sharedScoreHandicapConfig
        ).rounded())
    }

    static func scoringUnitHandicapStrokes(
        for scoringUnit: ScoringUnit,
        participants: [RoundParticipant],
        sharedScoreHandicapConfig: HandicapConfiguration? = nil
    ) -> Double {
        switch scoringUnit.owner {
        case .participant:
            return Double(participants.first?.adjustedHandicap ?? 0)
        case .team, .scoreOwner:
            if let allowance = scoringUnit.handicapAllowance {
                return allowance.unitStrokes
            }
            if let handicapAdjustments = scoringUnit.handicapAdjustments, handicapAdjustments.isPopulated {
                return handicapAdjustments.values.reduce(0.0, +)
            }
            if let sharedScoreHandicapConfig,
               let allowance = handicapAllowance(participants: participants, config: sharedScoreHandicapConfig) {
                return allowance.unitStrokes
            }
            guard participants.isPopulated else { return 0 }
            let average = Double(participants.map(\.adjustedHandicap).reduce(0, +)) / Double(participants.count)
            return average
        }
    }

    static func handicapAllowance(
        participants: [RoundParticipant],
        config: HandicapConfiguration
    ) -> ScoringUnitHandicapAllowance? {
        let orderedMembers = participants.sorted {
            if $0.adjustedHandicap != $1.adjustedHandicap {
                return $0.adjustedHandicap < $1.adjustedHandicap
            }
            return $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
        }
        guard orderedMembers.isPopulated else { return nil }

        let memberStrokes: [String: Double]
        if let percentages = config.positionPercentages, percentages.isPopulated {
            var strokes: [String: Double] = [:]
            for (index, participant) in orderedMembers.enumerated() {
                guard index < percentages.count else { break }
                strokes[participant.id] = Double(participant.adjustedHandicap) * percentages[index] * config.percentage
            }
            memberStrokes = strokes
        } else if config.isTeamCombined {
            memberStrokes = Dictionary(uniqueKeysWithValues: orderedMembers.map { participant in
                (participant.id, Double(participant.adjustedHandicap) * config.percentage)
            })
        } else {
            let average = Double(orderedMembers.map(\.adjustedHandicap).reduce(0, +)) / Double(orderedMembers.count)
            let unitStrokes = average * config.percentage
            let perMember = unitStrokes / Double(orderedMembers.count)
            memberStrokes = Dictionary(uniqueKeysWithValues: orderedMembers.map { ($0.id, perMember) })
        }

        return ScoringUnitHandicapAllowance(
            unitStrokes: memberStrokes.values.reduce(0.0, +),
            memberStrokes: memberStrokes,
            sourceConfig: config
        )
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
                ), entry.hasRecordedScore {
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
