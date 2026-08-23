//
//  SeriesStandingsPublication.swift
//  Hackers
//

import CryptoKit
import Foundation

struct SeriesPointAwardsPublicationPlan {
    let deleting: [SeriesPointAward]
    let upserting: [SeriesPointAward]
    let published: [SeriesPointAward]

    var writeCount: Int {
        deleting.count + upserting.count
    }
}

enum SeriesPointAwardsPublicationPlanner {
    static func plan(
        existing: [SeriesPointAward],
        computed: [SeriesPointAward],
        rebuiltTracks: Set<SeriesAwardTrack>
    ) -> SeriesPointAwardsPublicationPlan {
        let replaceableExisting = existing.filter {
            $0.source == .automatic && rebuiltTracks.contains($0.awardTrack)
        }
        let existingByID = Dictionary(uniqueKeysWithValues: replaceableExisting.map { ($0.id, $0) })
        let computedIDs = Set(computed.map(\.id))
        let deleting = replaceableExisting.filter { !computedIDs.contains($0.id) }
        var upserting: [SeriesPointAward] = []
        let rebuiltPublished = computed.map { candidate -> SeriesPointAward in
            guard let current = existingByID[candidate.id] else {
                upserting.append(candidate)
                return candidate
            }
            guard !semanticallyEqual(current, candidate) else { return current }
            var updated = candidate
            updated.createdAt = current.createdAt
            upserting.append(updated)
            return updated
        }
        let untouched = existing.filter {
            $0.source != .automatic || !rebuiltTracks.contains($0.awardTrack)
        }
        let published = (untouched + rebuiltPublished).sorted(by: stableAwardOrder)
        return SeriesPointAwardsPublicationPlan(
            deleting: deleting,
            upserting: upserting,
            published: published
        )
    }

    static func semanticallyEqual(_ lhs: SeriesPointAward, _ rhs: SeriesPointAward) -> Bool {
        lhs.id == rhs.id
            && lhs.seriesRoundID == rhs.seriesRoundID
            && lhs.awardTrack == rhs.awardTrack
            && lhs.competitorType == rhs.competitorType
            && lhs.competitorID == rhs.competitorID
            && lhs.competitorName == rhs.competitorName
            && lhs.profileKind == rhs.profileKind
            && lhs.placement == rhs.placement
            && lhs.tieGroupSize == rhs.tieGroupSize
            && lhs.basePoints == rhs.basePoints
            && lhs.bonusPoints == rhs.bonusPoints
            && lhs.totalPoints == rhs.totalPoints
            && lhs.source == rhs.source
            && lhs.roundOwnerID == rhs.roundOwnerID
            && lhs.reason == rhs.reason
            && lhs.awardedByMemberID == rhs.awardedByMemberID
            && lhs.parentID == rhs.parentID
            && lhs.schema == rhs.schema
    }

    private static func stableAwardOrder(_ lhs: SeriesPointAward, _ rhs: SeriesPointAward) -> Bool {
        if lhs.awardTrack != rhs.awardTrack { return lhs.awardTrack.rawValue < rhs.awardTrack.rawValue }
        if lhs.competitorID != rhs.competitorID { return lhs.competitorID < rhs.competitorID }
        return lhs.id < rhs.id
    }
}

enum SeriesRoundResultPublicationDecision: String, Equatable {
    case publish
    case repairState = "repair_state"
    case alreadyPublished = "already_published"
    case stale
}

enum SeriesRoundResultPublicationPlanner {
    static func decision(
        for result: SeriesRoundResult,
        currentState: SeriesRoundProcessingState?,
        resultAlreadyExists: Bool
    ) -> SeriesRoundResultPublicationDecision {
        if resultAlreadyExists {
            if currentState?.latestGenerationID == result.id, currentState?.status == .completed {
                return .alreadyPublished
            }
            return .repairState
        }
        if let currentState, result.sourceUpdatedAt < currentState.sourceUpdatedAt {
            return .stale
        }
        if let currentState,
           result.sourceUpdatedAt == currentState.sourceUpdatedAt,
           result.sourceRevision != currentState.sourceRevision {
            return .stale
        }
        return .publish
    }
}

enum SeriesRoundCanonicalRetryPlanner {
    static func needsProcessing(
        state: SeriesRoundProcessingState?,
        processorVersion: Int = SeriesRoundCanonicalBuilder.processorVersion
    ) -> Bool {
        guard let state else { return false }
        if state.status == .pending || state.status == .failed { return true }
        return state.processorVersion < processorVersion
    }
}

struct SeriesRoundShadowValidation: Equatable {
    let missingAwardIDs: [String]
    let unexpectedAwardIDs: [String]
    let mismatchedAwardIDs: [String]

    var isEquivalent: Bool {
        missingAwardIDs.isEmpty && unexpectedAwardIDs.isEmpty && mismatchedAwardIDs.isEmpty
    }
}

enum SeriesRoundShadowValidator {
    static func validate(
        authoritativeAwards: [SeriesPointAward],
        canonicalResult: SeriesRoundResult
    ) -> SeriesRoundShadowValidation {
        let authoritative = Dictionary(
            uniqueKeysWithValues: SeriesRoundCanonicalBuilder.awardProjections(from: authoritativeAwards).map { ($0.id, $0) }
        )
        let canonical = Dictionary(uniqueKeysWithValues: canonicalResult.pointAwards.map { ($0.id, $0) })
        let authoritativeIDs = Set(authoritative.keys)
        let canonicalIDs = Set(canonical.keys)
        return SeriesRoundShadowValidation(
            missingAwardIDs: authoritativeIDs.subtracting(canonicalIDs).sorted(),
            unexpectedAwardIDs: canonicalIDs.subtracting(authoritativeIDs).sorted(),
            mismatchedAwardIDs: authoritativeIDs.intersection(canonicalIDs)
                .filter { authoritative[$0] != canonical[$0] }
                .sorted()
        )
    }
}

enum SeriesRoundCanonicalBuilder {
    static let processorVersion = 3

    static func generationID(
        sourceRevision: String,
        policyFingerprint: String,
        processorVersion: Int = SeriesRoundCanonicalBuilder.processorVersion
    ) -> String {
        hash(GenerationKey(
            sourceRevision: sourceRevision,
            policyFingerprint: policyFingerprint,
            processorVersion: processorVersion
        ))
    }

    static func sourceRevision(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        mappings: [SeriesRoundMapping],
        processingInputs: SeriesRoundProcessingInputManifest? = nil,
        awards: [SeriesPointAward] = [],
        handicapScores: [SeriesHandicapScore] = []
    ) -> String {
        let source = CanonicalSource(
            seriesRound: seriesRound,
            snapshot: snapshot,
            mappings: mappings,
            processingInputs: processingInputs,
            pointAwards: awardProjections(from: awards),
            handicapSamples: handicapProjections(from: handicapScores)
        )
        return hash(source)
    }

    static func sourceUpdatedAt(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        awards: [SeriesPointAward] = [],
        handicapScores: [SeriesHandicapScore] = []
    ) -> Double {
        let sourceTimes: [Double] = [
            seriesRound.lastUpdatedAt.unix,
            snapshot.round.lastUpdatedAt.unix,
            snapshot.participants.map { $0.lastUpdatedAt.unix }.compactMap { $0 }.max() ?? 0,
            snapshot.teams.map { $0.lastUpdatedAt.unix }.compactMap { $0 }.max() ?? 0,
            snapshot.teeGroups.map { $0.lastUpdatedAt.unix }.compactMap { $0 }.max() ?? 0,
            snapshot.segments.map { $0.lastUpdatedAt.unix }.compactMap { $0 }.max() ?? 0,
            snapshot.scoringGroups.map { $0.lastUpdatedAt.unix }.compactMap { $0 }.max() ?? 0,
            snapshot.scoring.map { $0.lastUpdatedAt.unix }.compactMap { $0 }.max() ?? 0,
            awards.map { $0.lastUpdatedAt.unix }.max() ?? 0,
            handicapScores.map { $0.lastUpdatedAt.unix }.max() ?? 0
        ]
        return sourceTimes.max() ?? 0
    }

    static func performanceMetrics(
        from result: ScoringResult,
        seriesRound: SeriesRound? = nil,
        snapshot: RoundSnapshot? = nil
    ) -> [SeriesRoundPerformanceMetric] {
        result.rows.map { row in
            let holeValues = row.holeValues.values
            let rawValues = holeValues.compactMap(\.rawStrokes)
            let netValues = holeValues.compactMap(\.netStrokes)
            let context = metricContext(for: row, seriesRound: seriesRound, snapshot: snapshot)
            let basisStrokes = context?.scoreBasis == .net
                ? (netValues.isEmpty ? nil : netValues.reduce(0, +))
                : (rawValues.isEmpty ? nil : rawValues.reduce(0, +))
            return SeriesRoundPerformanceMetric(
                scoringUnitID: row.scoringUnitID,
                participantIDs: row.participantIDs.sorted(),
                countingParticipantIDs: row.countingParticipantIDs.sorted(),
                owner: row.owner,
                total: row.total,
                holesPlayed: row.holesPlayed,
                rawStrokes: rawValues.isEmpty ? nil : rawValues.reduce(0, +),
                netStrokes: netValues.isEmpty ? nil : netValues.reduce(0, +),
                points: holeValues.reduce(0) { $0 + $1.points },
                context: context,
                scoreToPar: basisStrokes.flatMap { strokes in
                    context?.aggregatePar.map { Double(strokes) - $0 }
                },
                isComplete: context.map { row.holesPlayed >= $0.expectedHoleCount }
            )
        }
        .sorted { $0.scoringUnitID < $1.scoringUnitID }
    }

    static func processingInputs(
        teamProfile: SeriesScoringProfile?,
        individualProfile: SeriesScoringProfile?,
        handicapConfig: SeriesHandicapConfig,
        members: [SeriesMember],
        teams: [SeriesTeam]
    ) -> SeriesRoundProcessingInputManifest {
        SeriesRoundProcessingInputManifest(
            schemaVersion: 1,
            teamScoringProfile: teamProfile.map(profileSnapshot),
            individualScoringProfile: individualProfile.map(profileSnapshot),
            handicapConfig: handicapConfig,
            members: members.map {
                SeriesRoundProcessingMemberInput(
                    id: $0.id,
                    playerID: $0.playerID,
                    teamID: $0.teamID,
                    name: $0.name.fullName
                )
            }
            .sorted { $0.id < $1.id },
            teams: teams.map { SeriesRoundProcessingTeamInput(id: $0.id, name: $0.name) }
                .sorted { $0.id < $1.id }
        )
    }

    private static func profileSnapshot(_ profile: SeriesScoringProfile) -> SeriesRoundScoringProfileSnapshot {
        SeriesRoundScoringProfileSnapshot(
            id: profile.id,
            revisionRootID: profile.revisionRootID ?? profile.id,
            revisionSequence: profile.revisionSequence ?? 1,
            outcomeSource: profile.outcomeSource,
            competitorType: profile.competitorType,
            kind: profile.kind,
            tieHandling: profile.tieHandling,
            placementRules: profile.placementRules.sorted { $0.id < $1.id },
            resultPoints: profile.resultPoints,
            bonusRules: profile.bonusRules.sorted { $0.id < $1.id }
        )
    }

    private static func metricContext(
        for row: ScoringRow,
        seriesRound: SeriesRound?,
        snapshot: RoundSnapshot?
    ) -> SeriesRoundPerformanceMetricContext? {
        guard let seriesRound, let snapshot else { return nil }
        let config = seriesRound.roundConfig
        let expectedHoleCount = snapshot.roundSegment?.holeRange.count
            ?? snapshot.holeRange?.count
            ?? snapshot.holeSegment.holeCount
        let coursePar = aggregateCoursePar(snapshot: snapshot)
        let contributionCount: Int
        if row.owner == .team, snapshot.usesTeamScoringAggregates {
            switch config.teamScoring.mode {
            case .all:
                contributionCount = max(1, row.participantIDs.count)
            case .bestN, .worstN:
                contributionCount = max(1, min(config.teamScoring.count, row.participantIDs.count))
            }
        } else {
            contributionCount = 1
        }
        return SeriesRoundPerformanceMetricContext(
            formatTemplateID: config.formatTemplateID,
            scoringFamily: SeriesStandingsPolicyResolver.scoringFamily(for: config),
            scoreBasis: config.scoreBasisOverride ?? config.template.requirements.defaultScoreBasis,
            expectedHoleCount: expectedHoleCount,
            aggregatePar: coursePar.map { Double($0 * contributionCount) },
            teamScoring: config.teamScoring
        )
    }

    private static func aggregateCoursePar(snapshot: RoundSnapshot) -> Int? {
        guard let tee = snapshot.defaultTee ?? snapshot.courseInfo?.tees.first else { return nil }
        let holeNumbers = Set(
            snapshot.roundSegment?.holeRange.holeNumbers
                ?? snapshot.holeRange?.holeNumbers
                ?? snapshot.holeSegment.holeRange.holeNumbers
        )
        let holes = tee.holes.filter { holeNumbers.contains($0.number) }
        return holes.isEmpty ? nil : holes.reduce(0) { $0 + $1.par }
    }

    static func awardProjections(from awards: [SeriesPointAward]) -> [SeriesRoundPointAwardProjection] {
        awards.map {
            SeriesRoundPointAwardProjection(
                id: $0.id,
                awardTrack: $0.awardTrack,
                competitorType: $0.competitorType,
                competitorID: $0.competitorID,
                competitorName: $0.competitorName,
                profileKind: $0.profileKind,
                placement: $0.placement,
                tieGroupSize: $0.tieGroupSize,
                basePoints: $0.basePoints,
                bonusPoints: $0.bonusPoints,
                totalPoints: $0.totalPoints,
                source: $0.source,
                roundOwnerID: $0.roundOwnerID,
                reason: $0.reason
            )
        }
        .sorted {
            if $0.awardTrack != $1.awardTrack { return $0.awardTrack.rawValue < $1.awardTrack.rawValue }
            if $0.competitorID != $1.competitorID { return $0.competitorID < $1.competitorID }
            return $0.id < $1.id
        }
    }

    static func handicapProjections(
        from scores: [SeriesHandicapScore]
    ) -> [SeriesRoundHandicapSampleProjection] {
        scores.map {
            SeriesRoundHandicapSampleProjection(
                id: $0.id,
                memberID: $0.memberID,
                score: $0.score,
                par: $0.par,
                holeSegment: $0.holeSegment,
                teeBoxID: $0.teeBoxID,
                courseRating: $0.courseRating,
                courseSlope: $0.courseSlope,
                countsTowardHandicapIndex: $0.countsTowardHandicapIndex
            )
        }
        .sorted { $0.id < $1.id }
    }

    static func predictionContext(snapshot: RoundSnapshot) -> SeriesRoundPredictionContext? {
        guard snapshot.resolvedActiveTemplate.supportsLeagueHandicapAccrual,
              let courseInfo = snapshot.courseInfo else {
            return nil
        }

        let courseID: String
        if courseInfo.id.isPopulated {
            courseID = courseInfo.id
        } else if let externalID = courseInfo.golfCourseApiID {
            courseID = "golf-course-api:\(externalID)"
        } else {
            let normalizedName = courseInfo.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            guard normalizedName.isPopulated else { return nil }
            courseID = "course-name:\(normalizedName)"
        }

        let participantMap = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        let teeMap = courseInfo.teeMap
        let samples = snapshot.scoring.flatMap { entry -> [SeriesRoundHoleSample] in
            guard entry.hasRecordedScore,
                  !entry.pickedUp else { return [] }

            let participantIDs = entry.participantIDs.isPopulated
                ? entry.participantIDs
                : [entry.scoringUnitID]
            return participantIDs.compactMap { participantID in
                guard let participant = participantMap[participantID],
                      let memberID = participant.seriesMemberID,
                      memberID.isPopulated,
                      entry.scoringUnitID == participantID,
                      let tee = teeMap[participant.teeBoxID] ?? snapshot.defaultTee,
                      let hole = tee.holes.first(where: { $0.number == entry.holeNumber }),
                      let gross = RoundScoreCompleteness.validGrossStrokes(entry: entry, par: hole.par) else {
                    return nil
                }
                return SeriesRoundHoleSample(
                    seriesMemberID: memberID,
                    participantID: participantID,
                    teeBoxID: tee.id,
                    holeNumber: entry.holeNumber,
                    par: hole.par,
                    grossStrokes: gross
                )
            }
        }
        .sorted {
            if $0.seriesMemberID != $1.seriesMemberID { return $0.seriesMemberID < $1.seriesMemberID }
            if $0.holeNumber != $1.holeNumber { return $0.holeNumber < $1.holeNumber }
            return $0.teeBoxID < $1.teeBoxID
        }

        return SeriesRoundPredictionContext(
            courseID: courseID,
            courseName: courseInfo.name,
            holeSegment: snapshot.holeSegment,
            holeSamples: samples
        )
    }

    static func compatibilityProjections(
        _ values: [SeriesStandingsRuleCompatibility]
    ) -> [SeriesRoundRuleCompatibilityProjection] {
        values.map { value in
            let classification: String
            let details: [String]
            switch value.classification {
            case .eligible:
                classification = "eligible"
                details = []
            case .normalized(let normalizations):
                classification = "normalized"
                details = normalizations.map { String(describing: $0) }.sorted()
            case .excluded(let reasons):
                classification = "excluded"
                details = reasons.map { String(describing: $0) }.sorted()
            case .invalid(let reasons):
                classification = "invalid"
                details = reasons.map { String(describing: $0) }.sorted()
            }
            return SeriesRoundRuleCompatibilityProjection(
                ruleID: value.rule.id,
                awardTrack: value.rule.track,
                classification: classification,
                details: details
            )
        }
        .sorted { $0.ruleID < $1.ruleID }
    }

    static func makeResult(
        seriesID: String,
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        mappings: [SeriesRoundMapping],
        policy: ResolvedSeriesStandingsPolicy,
        compatibility: [SeriesStandingsRuleCompatibility],
        scoringResult: ScoringResult,
        awards: [SeriesPointAward],
        handicapScores: [SeriesHandicapScore],
        processingInputs: SeriesRoundProcessingInputManifest? = nil,
        generatedAt: Time = .init()
    ) -> SeriesRoundResult? {
        guard let linkedRoundID = seriesRound.roundID else { return nil }
        let awardValues = awardProjections(from: awards)
        let handicapValues = handicapProjections(from: handicapScores)
        let sourceRevision = sourceRevision(
            seriesRound: seriesRound,
            snapshot: snapshot,
            mappings: mappings,
            processingInputs: processingInputs,
            awards: awards,
            handicapScores: handicapScores
        )
        let generationID = generationID(
            sourceRevision: sourceRevision,
            policyFingerprint: policy.fingerprint,
            processorVersion: processorVersion
        )
        let metrics = performanceMetrics(
            from: scoringResult,
            seriesRound: seriesRound,
            snapshot: snapshot
        )
        let compatibilityValues = compatibilityProjections(compatibility)
        let predictionContext = predictionContext(snapshot: snapshot)
        let semanticHash = hash(SemanticResult(
            compatibility: compatibilityValues,
            performanceMetrics: metrics,
            pointAwards: awardValues,
            handicapSamples: handicapValues
        ))
        let policyRevisionID: String?
        switch policy.source {
        case .legacySnapshot:
            policyRevisionID = nil
        case .boundRevision(let id, _):
            policyRevisionID = id
        }

        return SeriesRoundResult(
            id: generationID,
            seriesRoundID: seriesRound.id,
            linkedRoundID: linkedRoundID,
            sourceRevision: sourceRevision,
            sourceUpdatedAt: sourceUpdatedAt(
                seriesRound: seriesRound,
                snapshot: snapshot,
                awards: awards,
                handicapScores: handicapScores
            ),
            policyRevisionID: policyRevisionID,
            policyFingerprint: policy.fingerprint,
            processorVersion: processorVersion,
            semanticHash: semanticHash,
            compatibility: compatibilityValues,
            performanceMetrics: metrics,
            pointAwards: awardValues,
            handicapSamples: handicapValues,
            cardProjection: SeriesRoundCardStateBuilder.projection(
                seriesRound: seriesRound,
                snapshot: snapshot,
                generatedAt: generatedAt
            ),
            predictionContext: predictionContext,
            processingInputs: processingInputs,
            generatedAt: generatedAt,
            createdAt: generatedAt,
            lastUpdatedAt: generatedAt,
            parentID: seriesID
        )
    }

    static func processingState(
        for result: SeriesRoundResult,
        previous: SeriesRoundProcessingState?,
        status: SeriesRoundProcessingStatus = .completed,
        now: Time = .init()
    ) -> SeriesRoundProcessingState {
        SeriesRoundProcessingState(
            id: result.seriesRoundID,
            latestGenerationID: result.id,
            sourceRevision: result.sourceRevision,
            sourceUpdatedAt: result.sourceUpdatedAt,
            policyFingerprint: result.policyFingerprint,
            processorVersion: result.processorVersion,
            resultSemanticHash: result.semanticHash,
            status: status,
            completedAt: status == .completed ? now : previous?.completedAt,
            createdAt: previous?.createdAt ?? now,
            lastUpdatedAt: now,
            parentID: result.parentID
        )
    }

    static func hash<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct GenerationKey: Codable {
        let sourceRevision: String
        let policyFingerprint: String
        let processorVersion: Int
    }

    private struct SemanticResult: Codable {
        let compatibility: [SeriesRoundRuleCompatibilityProjection]
        let performanceMetrics: [SeriesRoundPerformanceMetric]
        let pointAwards: [SeriesRoundPointAwardProjection]
        let handicapSamples: [SeriesRoundHandicapSampleProjection]
    }

    private struct CanonicalSource: Codable {
        let seriesRoundID: String
        let linkedRoundID: String?
        let roundConfiguration: SeriesRoundConfiguration
        let linkedRoundConfiguration: RoundConfiguration
        let courseOverride: SeriesCourseSelection?
        let policyBinding: SeriesRoundPolicyBinding?
        let teamScoringProfileID: String?
        let individualScoringProfileID: String?
        let matchupPlans: [SeriesRoundMatchupPlan]
        let plannedMatchups: [SeriesRoundPlannedMatchup]
        let plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
        let partnershipPlans: [SeriesRoundPartnershipPlan]
        let participants: [CanonicalParticipant]
        let teams: [CanonicalTeam]
        let teeGroups: [CanonicalTeeGroup]
        let segments: [CanonicalSegment]
        let scoringGroups: [CanonicalScoringGroup]
        let scoring: [CanonicalScore]
        let mappings: [CanonicalMapping]
        let processingInputs: SeriesRoundProcessingInputManifest?
        let pointAwards: [SeriesRoundPointAwardProjection]
        let handicapSamples: [SeriesRoundHandicapSampleProjection]

        init(
            seriesRound: SeriesRound,
            snapshot: RoundSnapshot,
            mappings: [SeriesRoundMapping],
            processingInputs: SeriesRoundProcessingInputManifest?,
            pointAwards: [SeriesRoundPointAwardProjection],
            handicapSamples: [SeriesRoundHandicapSampleProjection]
        ) {
            seriesRoundID = seriesRound.id
            linkedRoundID = seriesRound.roundID
            roundConfiguration = seriesRound.roundConfig
            linkedRoundConfiguration = snapshot.configuration
            courseOverride = seriesRound.courseOverride
            policyBinding = seriesRound.policyBinding
            teamScoringProfileID = seriesRound.teamScoringProfileID
            individualScoringProfileID = seriesRound.individualScoringProfileID
            matchupPlans = seriesRound.matchupPlans.sorted { $0.id < $1.id }
            plannedMatchups = seriesRound.plannedMatchups.sorted { $0.id < $1.id }
            plannedTeeGroups = seriesRound.plannedTeeGroups.sorted { $0.id < $1.id }
            partnershipPlans = seriesRound.partnershipPlans.sorted { $0.id < $1.id }
            participants = snapshot.participants.map(CanonicalParticipant.init).sorted { $0.id < $1.id }
            teams = snapshot.teams.map(CanonicalTeam.init).sorted { $0.id < $1.id }
            teeGroups = snapshot.teeGroups.map(CanonicalTeeGroup.init).sorted { $0.id < $1.id }
            segments = snapshot.segments.map(CanonicalSegment.init).sorted { $0.id < $1.id }
            scoringGroups = snapshot.scoringGroups.map(CanonicalScoringGroup.init).sorted { $0.id < $1.id }
            scoring = snapshot.scoring.map(CanonicalScore.init).sorted { $0.id < $1.id }
            self.mappings = mappings
                .filter { $0.seriesRoundID == seriesRound.id }
                .map(CanonicalMapping.init)
                .sorted { $0.id < $1.id }
            self.processingInputs = processingInputs
            self.pointAwards = pointAwards
            self.handicapSamples = handicapSamples
        }
    }

    private struct CanonicalParticipant: Codable {
        let id: String
        let playerID: String?
        let name: String
        let teeBoxID: String
        let originalHandicap: Int
        let adjustedHandicap: Int
        let handicapIndex: Double?
        let seriesMemberID: String?
        let teamID: String?
        let presenceStatus: RoundParticipantPresenceStatus?
        let isSubstitute: Bool
        let substituteForSeriesMemberID: String?

        init(_ participant: RoundParticipant) {
            id = participant.id
            playerID = participant.playerID
            name = participant.name.fullName
            teeBoxID = participant.teeBoxID
            originalHandicap = participant.originalHandicap
            adjustedHandicap = participant.adjustedHandicap
            handicapIndex = participant.handicapIndex
            seriesMemberID = participant.seriesMemberID
            teamID = participant.teamID
            presenceStatus = participant.presenceStatus
            isSubstitute = participant.isSubstitute
            substituteForSeriesMemberID = participant.substituteForSeriesMemberID
        }
    }

    private struct CanonicalTeam: Codable {
        let id: String
        let name: String
        let index: Int

        init(_ team: RoundTeam) {
            id = team.id
            name = team.name
            index = team.index
        }
    }

    private struct CanonicalTeeGroup: Codable {
        let id: String
        let index: Int
        let teeTime: String?
        let startingHole: Int
        let lastCompletedHole: Int?

        init(_ group: TeeTimeGroup) {
            id = group.id
            index = group.index
            teeTime = group.teeTime
            startingHole = group.startingHole
            lastCompletedHole = group.lastCompletedHole
        }
    }

    private struct CanonicalSegment: Codable {
        let id: String
        let roundID: String
        let holeRange: HoleRange
        let gameFormat: GameFormat
        let templateID: String?
        let scoringUnits: [ScoringUnit]
        let matchups: [TeamMatchup]?
        let competitionScope: CompetitionScope?

        init(_ segment: RoundSegment) {
            id = segment.id
            roundID = segment.roundID
            holeRange = segment.holeRange
            gameFormat = segment.gameFormat
            templateID = segment.templateID
            scoringUnits = segment.scoringUnits.sorted { $0.id < $1.id }
            matchups = segment.matchups?.sorted { $0.id < $1.id }
            competitionScope = segment.competitionScope
        }
    }

    private struct CanonicalScoringGroup: Codable {
        let id: String
        let teamID: String?
        let teeGroupID: String?
        let kind: RoundScoringGroupKind
        let memberIDs: [String]
        let label: String?
        let seedSeriesPodID: String?

        init(_ group: RoundScoringGroup) {
            id = group.id
            teamID = group.teamID
            teeGroupID = group.teeGroupID
            kind = group.kind
            memberIDs = group.memberIDs.sorted()
            label = group.label
            seedSeriesPodID = group.seedSeriesPodID
        }
    }

    private struct CanonicalScore: Codable {
        let id: String
        let holeNumber: Int
        let segmentID: String
        let scoringUnitID: String
        let participantIDs: [String]
        let strokes: Int?
        let relativeToPar: Int?
        let entryMode: ScoreEntryMode?
        let value: String?
        let pickedUp: Bool
        let gameTemplateID: String?
        let points: Double?
        let outcome: HoleOutcome?

        init(_ score: ScoreEntry) {
            id = score.id
            holeNumber = score.holeNumber
            segmentID = score.segmentID
            scoringUnitID = score.scoringUnitID
            participantIDs = score.participantIDs.sorted()
            strokes = score.strokes
            relativeToPar = score.relativeToPar
            entryMode = score.entryMode
            value = score.value
            pickedUp = score.pickedUp
            gameTemplateID = score.gameTemplateID
            points = score.points
            outcome = score.outcome
        }
    }

    private struct CanonicalMapping: Codable {
        let id: String
        let roundOwnerType: SeriesRoundOwnerType
        let roundOwnerID: String
        let competitorType: SeriesCompetitorType
        let competitorID: String
        let weight: Double

        init(_ mapping: SeriesRoundMapping) {
            id = mapping.id
            roundOwnerType = mapping.roundOwnerType
            roundOwnerID = mapping.roundOwnerID
            competitorType = mapping.competitorType
            competitorID = mapping.competitorID
            weight = mapping.weight
        }
    }
}

@MainActor
protocol SeriesRoundResultWriting: AnyObject {
    func publishIfNeeded(
        _ result: SeriesRoundResult
    ) async -> Result<SeriesRoundResultPublicationDecision, Error>
}

@MainActor
final class FirebaseSeriesRoundResultWriter: SeriesRoundResultWriting {
    func publishIfNeeded(
        _ result: SeriesRoundResult
    ) async -> Result<SeriesRoundResultPublicationDecision, Error> {
        await FirebaseService.shared.publishCanonicalRoundResultIfNeeded(result)
    }
}

@MainActor
final class SeriesRoundResultPublicationService {
    static let shared = SeriesRoundResultPublicationService()

    private let writer: any SeriesRoundResultWriting

    init(writer: (any SeriesRoundResultWriting)? = nil) {
        self.writer = writer ?? FirebaseSeriesRoundResultWriter()
    }

    func publish(
        _ result: SeriesRoundResult
    ) async -> Result<SeriesRoundResultPublicationDecision, Error> {
        guard !Task.isCancelled else { return .failure(CancellationError()) }
        return await writer.publishIfNeeded(result)
    }
}

struct SeriesStandingsPublicationPlan {
    let deleting: [SeriesStanding]
    let upserting: [SeriesStanding]
    let published: [SeriesStanding]

    var writeCount: Int {
        deleting.count + upserting.count
    }
}

enum SeriesStandingsPublicationPlanner {
    static func plan(
        existing: [SeriesStanding],
        computed: [SeriesStanding],
        track: SeriesAwardTrack?,
        now: Time = .init()
    ) -> SeriesStandingsPublicationPlan {
        let existingForTarget = track.map { target in
            existing.filter { $0.awardTrack == target }
        } ?? existing
        let untouched = track.map { target in
            existing.filter { $0.awardTrack != target }
        } ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existingForTarget.map { ($0.id, $0) })
        let computedIDs = Set(computed.map(\.id))
        let deleting = existingForTarget.filter { !computedIDs.contains($0.id) }

        var upserting: [SeriesStanding] = []
        let targetPublished = computed.map { candidate -> SeriesStanding in
            guard let current = existingByID[candidate.id] else {
                var inserted = candidate
                inserted.lastUpdatedAt = now
                upserting.append(inserted)
                return inserted
            }
            guard !semanticallyEqual(current, candidate) else {
                return current
            }

            var updated = candidate
            updated.createdAt = current.createdAt
            updated.lastUpdatedAt = now
            upserting.append(updated)
            return updated
        }

        return SeriesStandingsPublicationPlan(
            deleting: deleting,
            upserting: upserting,
            published: untouched + targetPublished
        )
    }

    static func semanticallyEqual(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        lhs.id == rhs.id
            && lhs.awardTrack == rhs.awardTrack
            && lhs.competitorType == rhs.competitorType
            && lhs.competitorID == rhs.competitorID
            && lhs.competitorName == rhs.competitorName
            && lhs.totalPoints == rhs.totalPoints
            && lhs.roundsCounted == rhs.roundsCounted
            && lhs.wins == rhs.wins
            && lhs.topThrees == rhs.topThrees
            && lhs.lastPlacement == rhs.lastPlacement
            && lhs.bestPlacement == rhs.bestPlacement
            && lhs.rank == rhs.rank
            && lhs.parentID == rhs.parentID
            && lhs.schema == rhs.schema
    }
}

@MainActor
protocol SeriesStandingsWriting: AnyObject {
    func replace(
        deleting: [SeriesStanding],
        upserting: [SeriesStanding]
    ) async -> Result<Void, Error>
}

@MainActor
final class FirebaseSeriesStandingsWriter: SeriesStandingsWriting {
    func replace(
        deleting: [SeriesStanding],
        upserting: [SeriesStanding]
    ) async -> Result<Void, Error> {
        await FirebaseService.shared.batchReplaceStandings(
            deleting: deleting,
            upserting: upserting
        )
    }
}

@MainActor
final class SeriesStandingsPublicationService {
    private let writer: any SeriesStandingsWriting

    init(writer: (any SeriesStandingsWriting)? = nil) {
        self.writer = writer ?? FirebaseSeriesStandingsWriter()
    }

    func publish(
        existing: [SeriesStanding],
        computed: [SeriesStanding],
        track: SeriesAwardTrack?
    ) async -> Result<SeriesStandingsPublicationPlan, Error> {
        let plan = SeriesStandingsPublicationPlanner.plan(
            existing: existing,
            computed: computed,
            track: track
        )
        guard plan.writeCount > 0 else { return .success(plan) }

        switch await writer.replace(deleting: plan.deleting, upserting: plan.upserting) {
        case .success:
            return .success(plan)
        case .failure(let error):
            return .failure(error)
        }
    }
}
