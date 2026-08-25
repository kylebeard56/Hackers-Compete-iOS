import CryptoKit
import Foundation

enum SeriesPolicyResolutionSource: Hashable {
    case legacySnapshot
    case boundRevision(id: String, sequence: Int)
}

struct ResolvedSeriesStandingsPolicy: Hashable {
    let policy: SeriesStandingsPolicy
    let source: SeriesPolicyResolutionSource
    let fingerprint: String
    let hasValidFingerprint: Bool
}

enum SeriesRoundPolicyCompatibilityReason: Hashable {
    case emptyRuleID
    case duplicateRuleID(String)
    case ambiguousTrack(SeriesAwardTrack)
    case invalidTiebreakRule(String)
    case policyFingerprintMismatch
    case missingCourse
    case formatTemplate(expected: [String], actual: String)
    case scoreBasis(expected: [ScoreBasis], actual: ScoreBasis)
    case holeCount(expected: [Int], actual: Int)
    case scoringFamily(expected: [SeriesRoundScoringFamily], actual: SeriesRoundScoringFamily)
    case teamScoring(expected: RoundTeamScoringConfiguration, actual: RoundTeamScoringConfiguration)
    case substitutesScore(expected: Bool, actual: Bool)
}

enum SeriesRoundPolicyNormalization: Hashable {
    case holeCount(from: Int, to: Int)
}

enum SeriesRoundPolicyCompatibility: Hashable {
    case eligible
    case normalized([SeriesRoundPolicyNormalization])
    case excluded([SeriesRoundPolicyCompatibilityReason])
    case invalid([SeriesRoundPolicyCompatibilityReason])
}

struct SeriesStandingsRuleCompatibility: Hashable, Identifiable {
    let rule: SeriesStandingsRule
    let classification: SeriesRoundPolicyCompatibility

    var id: String { rule.id }
}

struct SeriesRoundScoreContract: Hashable {
    let course: SeriesCourseSelection?
    let policyBinding: SeriesRoundPolicyBinding?
    let formatTemplateID: String
    let competitionScope: CompetitionScope
    let teamScoring: RoundTeamScoringConfiguration
    let matchupResolutionStyle: RoundMatchupResolutionStyle
    let scoreOwnerScope: RoundScoreOwnerScope
    let matchupScoringStyle: RoundMatchupScoringStyle
    let holeWinPoints: Double
    let matchWinnerBonusPoints: Double
    let matchTiePolicy: TiePolicy
    let selectionDomain: ScoringSelectionDomain?
    let matchupMode: SeriesMatchupMode
    let podGroupingStrategy: SeriesPodGroupingStrategy
    let teamAssignmentMode: SeriesTeamAssignmentMode
    let teeGroupMode: SeriesTeeGroupMode
    let scoreBasis: ScoreBasis
    let sharedScoreHandicapConfig: HandicapConfiguration?
    let maxScoreOverPar: MaxScoreOverPar
    let handicapStrokeBasis: SeriesHandicapStrokeBasis?
    let handicapEntryFormat: HandicapEntryFormat
    let handicapNormalizationMode: HandicapNormalizationMode
    let teamScoringProfileID: String?
    let individualScoringProfileID: String?
    let matchupPlans: [SeriesRoundMatchupPlan]
    let plannedMatchups: [SeriesRoundPlannedMatchup]
    let plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    let partnershipPlans: [SeriesRoundPartnershipPlan]
    let substitutesScore: Bool
}

enum SeriesRoundLifecycleGuard {
    static func scoreContract(for round: SeriesRound, in series: Series) -> SeriesRoundScoreContract {
        let config = round.roundConfig
        return SeriesRoundScoreContract(
            course: round.resolvedCourse(using: series),
            policyBinding: round.policyBinding,
            formatTemplateID: config.formatTemplateID,
            competitionScope: config.resolvedCompetitionScope,
            teamScoring: config.teamScoring,
            matchupResolutionStyle: config.matchupResolutionStyle,
            scoreOwnerScope: config.scoreOwnerScope,
            matchupScoringStyle: config.matchupScoringStyle,
            holeWinPoints: config.resolvedHoleWinPoints,
            matchWinnerBonusPoints: config.resolvedMatchWinnerBonusPoints,
            matchTiePolicy: config.resolvedMatchTiePolicy,
            selectionDomain: config.selectionDomain,
            matchupMode: config.matchupMode,
            podGroupingStrategy: config.podGroupingStrategy,
            teamAssignmentMode: config.teamAssignmentMode,
            teeGroupMode: config.teeGroupMode,
            scoreBasis: config.scoreBasisOverride ?? config.template.requirements.defaultScoreBasis,
            sharedScoreHandicapConfig: config.sharedScoreHandicapConfig,
            maxScoreOverPar: config.maxScoreOverPar ?? config.template.requirements.defaultMaxScoreOverPar,
            handicapStrokeBasis: config.handicapStrokeBasis,
            handicapEntryFormat: config.handicapEntryFormat,
            handicapNormalizationMode: config.handicapNormalizationMode,
            teamScoringProfileID: round.teamScoringProfileID,
            individualScoringProfileID: round.individualScoringProfileID,
            matchupPlans: round.matchupPlans,
            plannedMatchups: round.plannedMatchups,
            plannedTeeGroups: round.plannedTeeGroups,
            partnershipPlans: round.partnershipPlans,
            substitutesScore: round.policyBinding?.resolvedSubstitutesScore ?? series.settings.substitutesScore
        )
    }

    static func permitsScoreContractChange(
        from previous: SeriesRound,
        to proposed: SeriesRound,
        effectiveStatus: SeriesRoundStatus,
        in series: Series
    ) -> Bool {
        switch effectiveStatus {
        case .planned, .lobby:
            return true
        case .live, .complete, .canceled:
            return scoreContract(for: previous, in: series) == scoreContract(for: proposed, in: series)
        }
    }
}

enum SeriesStandingsPolicyResolver {
    static func makeRevision(
        id: String,
        sequence: Int,
        policy: SeriesStandingsPolicy,
        createdAt: Time = .init()
    ) -> SeriesPolicyRevision {
        SeriesPolicyRevision(
            id: id,
            sequence: sequence,
            policy: policy,
            resolvedPolicyFingerprint: fingerprint(for: policy),
            createdAt: createdAt
        )
    }

    static func binding(
        for revision: SeriesPolicyRevision,
        substitutesScore: Bool
    ) -> SeriesRoundPolicyBinding {
        SeriesRoundPolicyBinding(
            revisionID: revision.id,
            revisionSequence: revision.sequence,
            policy: revision.policy,
            resolvedPolicyFingerprint: revision.resolvedPolicyFingerprint,
            resolvedSubstitutesScore: substitutesScore
        )
    }

    static func bindingForNewRound(settings: SeriesSettings) -> SeriesRoundPolicyBinding? {
        guard let revision = settings.standingsPolicyRevision else { return nil }
        return binding(for: revision, substitutesScore: settings.substitutesScore)
    }

    static func resolve(round: SeriesRound, settings: SeriesSettings) -> ResolvedSeriesStandingsPolicy {
        guard let binding = round.policyBinding else {
            let policy = legacySnapshotPolicy(settings: settings)
            return ResolvedSeriesStandingsPolicy(
                policy: policy,
                source: .legacySnapshot,
                fingerprint: fingerprint(for: policy),
                hasValidFingerprint: true
            )
        }

        let resolvedFingerprint = fingerprint(for: binding.policy)
        return ResolvedSeriesStandingsPolicy(
            policy: binding.policy,
            source: .boundRevision(id: binding.revisionID, sequence: binding.revisionSequence),
            fingerprint: resolvedFingerprint,
            hasValidFingerprint: resolvedFingerprint == binding.resolvedPolicyFingerprint
        )
    }

    static func compatibility(
        for round: SeriesRound,
        in series: Series
    ) -> [SeriesStandingsRuleCompatibility] {
        let resolved = resolve(round: round, settings: series.settings)
        let duplicateIDs = Set(
            Dictionary(grouping: resolved.policy.rules, by: \SeriesStandingsRule.id)
                .filter { $0.value.count > 1 }
                .keys
        )
        let ambiguousTracks = Set(
            Dictionary(grouping: resolved.policy.rules, by: \SeriesStandingsRule.track)
                .filter { $0.value.count > 1 }
                .keys
        )
        let context = context(for: round, in: series)

        return resolved.policy.rules.map { rule in
            let invalidReasons = invalidReasons(
                for: rule,
                duplicateIDs: duplicateIDs,
                ambiguousTracks: ambiguousTracks,
                context: context,
                fingerprintIsValid: resolved.hasValidFingerprint
            )
            if invalidReasons.isPopulated {
                return SeriesStandingsRuleCompatibility(rule: rule, classification: .invalid(invalidReasons))
            }

            let result = compatibilityReasons(for: rule, context: context)
            let classification: SeriesRoundPolicyCompatibility
            if result.exclusions.isPopulated {
                classification = .excluded(result.exclusions)
            } else if result.normalizations.isPopulated {
                classification = .normalized(result.normalizations)
            } else {
                classification = .eligible
            }
            return SeriesStandingsRuleCompatibility(rule: rule, classification: classification)
        }
    }

    static func legacySnapshotPolicy(settings: SeriesSettings) -> SeriesStandingsPolicy {
        SeriesStandingsPolicy(rules: enabledTracks(settings: settings).map { track in
            SeriesStandingsRule(id: "legacy_\(track.rawValue)", track: track)
        })
    }

    static func strictPolicy(
        settings: SeriesSettings,
        normalizationPolicy: SeriesRoundNormalizationPolicy = .none
    ) -> SeriesStandingsPolicy {
        let defaults = settings.roundDefaults
        let config = defaults.configuration
        let holeCounts = defaults.course.map { [$0.holeSegment.holeCount] }
        let scoreBasis = config.scoreBasisOverride ?? config.template.requirements.defaultScoreBasis
        let family = scoringFamily(for: config)

        return SeriesStandingsPolicy(rules: enabledTracks(settings: settings).map { track in
            SeriesStandingsRule(
                id: "\(track.rawValue)_primary",
                track: track,
                acceptedFormatTemplateIDs: [config.formatTemplateID],
                acceptedScoreBases: [scoreBasis],
                acceptedHoleCounts: holeCounts,
                acceptedScoringFamilies: [family],
                requiredTeamScoring: track == .team ? config.teamScoring : nil,
                requiredSubstitutesScore: settings.substitutesScore,
                normalizationPolicy: normalizationPolicy
            )
        })
    }

    static func fingerprint(for policy: SeriesStandingsPolicy) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(canonicalized(policy)) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct CompatibilityContext {
        let formatTemplateID: String
        let scoreBasis: ScoreBasis
        let holeCount: Int?
        let scoringFamily: SeriesRoundScoringFamily
        let teamScoring: RoundTeamScoringConfiguration
        let substitutesScore: Bool
    }

    private static func context(for round: SeriesRound, in series: Series) -> CompatibilityContext {
        let config = round.roundConfig
        return CompatibilityContext(
            formatTemplateID: config.formatTemplateID,
            scoreBasis: config.scoreBasisOverride ?? config.template.requirements.defaultScoreBasis,
            holeCount: round.resolvedCourse(using: series)?.holeSegment.holeCount,
            scoringFamily: scoringFamily(for: config),
            teamScoring: config.teamScoring,
            substitutesScore: round.policyBinding?.resolvedSubstitutesScore ?? series.settings.substitutesScore
        )
    }

    private static func enabledTracks(settings: SeriesSettings) -> [SeriesAwardTrack] {
        SeriesAwardTrack.allCases.filter { track in
            switch track {
            case .team: return settings.useTeamStandings
            case .individual: return settings.useIndividualStandings
            }
        }
    }

    static func scoringFamily(for config: SeriesRoundConfiguration) -> SeriesRoundScoringFamily {
        let comparesScores = config.template.pipeline.contains { stage in
            if case .compare = stage { return true }
            return false
        }
        return config.template.category == .match || comparesScores ? .matchPlay : .strokePlay
    }

    static func isValidTiebreakPolicy(_ rule: SeriesStandingsRule) -> Bool {
        let tiebreakers = rule.resolvedTiebreakers
        guard tiebreakers.isPopulated else { return true }
        let ids = tiebreakers.map(\.id)
        guard ids.allSatisfy(\.isPopulated), Set(ids).count == ids.count else { return false }
        guard rule.acceptedScoringFamilies == [.strokePlay],
              rule.acceptedScoreBases?.count == 1,
              rule.acceptedHoleCounts?.count == 1 else {
            return false
        }
        if rule.track == .team, rule.requiredTeamScoring == nil { return false }
        return tiebreakers.allSatisfy { $0.minimumEligibleRounds >= 1 }
    }

    private static func canonicalized(_ policy: SeriesStandingsPolicy) -> SeriesStandingsPolicy {
        SeriesStandingsPolicy(
            schemaVersion: policy.schemaVersion,
            rules: policy.rules.map { rule in
                SeriesStandingsRule(
                    id: rule.id,
                    track: rule.track,
                    acceptedFormatTemplateIDs: rule.acceptedFormatTemplateIDs,
                    acceptedScoreBases: rule.acceptedScoreBases,
                    acceptedHoleCounts: rule.acceptedHoleCounts,
                    acceptedScoringFamilies: rule.acceptedScoringFamilies,
                    requiredTeamScoring: rule.requiredTeamScoring,
                    requiredSubstitutesScore: rule.requiredSubstitutesScore,
                    normalizationPolicy: rule.normalizationPolicy,
                    tiebreakers: rule.tiebreakers
                )
            }
        )
    }

    private static func invalidReasons(
        for rule: SeriesStandingsRule,
        duplicateIDs: Set<String>,
        ambiguousTracks: Set<SeriesAwardTrack>,
        context: CompatibilityContext,
        fingerprintIsValid: Bool
    ) -> [SeriesRoundPolicyCompatibilityReason] {
        var reasons: [SeriesRoundPolicyCompatibilityReason] = []
        if !rule.id.isPopulated { reasons.append(.emptyRuleID) }
        if duplicateIDs.contains(rule.id) { reasons.append(.duplicateRuleID(rule.id)) }
        if ambiguousTracks.contains(rule.track) { reasons.append(.ambiguousTrack(rule.track)) }
        if !isValidTiebreakPolicy(rule) { reasons.append(.invalidTiebreakRule(rule.id)) }
        if !fingerprintIsValid { reasons.append(.policyFingerprintMismatch) }
        if rule.acceptedHoleCounts != nil, context.holeCount == nil { reasons.append(.missingCourse) }
        return reasons
    }

    private static func compatibilityReasons(
        for rule: SeriesStandingsRule,
        context: CompatibilityContext
    ) -> (exclusions: [SeriesRoundPolicyCompatibilityReason], normalizations: [SeriesRoundPolicyNormalization]) {
        var exclusions: [SeriesRoundPolicyCompatibilityReason] = []
        var normalizations: [SeriesRoundPolicyNormalization] = []

        if let expected = rule.acceptedFormatTemplateIDs, !expected.contains(context.formatTemplateID) {
            exclusions.append(.formatTemplate(expected: expected, actual: context.formatTemplateID))
        }
        if let expected = rule.acceptedScoreBases, !expected.contains(context.scoreBasis) {
            exclusions.append(.scoreBasis(expected: expected, actual: context.scoreBasis))
        }
        if let expected = rule.acceptedScoringFamilies, !expected.contains(context.scoringFamily) {
            exclusions.append(.scoringFamily(expected: expected, actual: context.scoringFamily))
        }
        if let expected = rule.requiredTeamScoring, expected != context.teamScoring {
            exclusions.append(.teamScoring(expected: expected, actual: context.teamScoring))
        }
        if let expected = rule.requiredSubstitutesScore, expected != context.substitutesScore {
            exclusions.append(.substitutesScore(expected: expected, actual: context.substitutesScore))
        }
        if let expected = rule.acceptedHoleCounts,
           let actual = context.holeCount,
           !expected.contains(actual) {
            if rule.normalizationPolicy == .nineHoleToEighteenHole,
               actual == 9,
               expected.contains(18) {
                normalizations.append(.holeCount(from: 9, to: 18))
            } else {
                exclusions.append(.holeCount(expected: expected, actual: actual))
            }
        }
        return (exclusions, normalizations)
    }
}
