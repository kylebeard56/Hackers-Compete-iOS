import Foundation

struct SeriesStandingsTrackTiebreakDraft: Equatable {
    var isEnabled: Bool
    var direction: SeriesTiebreakDirection
    var scoreComponent: SeriesTiebreakScoreComponent
    var minimumEligibleRounds: Int

    init(
        isEnabled: Bool = false,
        direction: SeriesTiebreakDirection = .lowestFirst,
        scoreComponent: SeriesTiebreakScoreComponent = .total,
        minimumEligibleRounds: Int = 1
    ) {
        self.isEnabled = isEnabled
        self.direction = direction
        self.scoreComponent = scoreComponent
        self.minimumEligibleRounds = max(1, minimumEligibleRounds)
    }
}

struct SeriesStandingsTiebreakDraft: Equatable {
    var team: SeriesStandingsTrackTiebreakDraft
    var individual: SeriesStandingsTrackTiebreakDraft

    init(
        team: SeriesStandingsTrackTiebreakDraft = .init(),
        individual: SeriesStandingsTrackTiebreakDraft = .init()
    ) {
        self.team = team
        self.individual = individual
    }

    subscript(track: SeriesAwardTrack) -> SeriesStandingsTrackTiebreakDraft {
        get {
            switch track {
            case .team: return team
            case .individual: return individual
            }
        }
        set {
            switch track {
            case .team: team = newValue
            case .individual: individual = newValue
            }
        }
    }

    var hasEnabledTiebreaker: Bool {
        team.isEnabled || individual.isEnabled
    }
}

enum SeriesStandingsRolloutPolicyError: Error, Equatable, LocalizedError {
    case noEnabledStandingsTrack
    case noEnabledTiebreaker
    case disabledTrack(SeriesAwardTrack)
    case missingDefaultCourse
    case invalidTiebreakPolicy(SeriesAwardTrack)

    var errorDescription: String? {
        switch self {
        case .noEnabledStandingsTrack:
            return "Turn on team or individual standings before configuring a tiebreaker."
        case .noEnabledTiebreaker:
            return "Turn on at least one scoring-average tiebreaker."
        case .disabledTrack(let track):
            return "Turn on \(track.rawValue) standings before configuring its tiebreaker."
        case .missingDefaultCourse:
            return "Choose a default course and hole segment before configuring a scoring average."
        case .invalidTiebreakPolicy(let track):
            return "The \(track.rawValue) scoring format is not compatible with this tiebreaker."
        }
    }
}

struct SeriesStandingsRolloutTrackPreview: Equatable {
    var eligibleRoundCount = 0
    var normalizedRoundCount = 0
    var excludedRoundCount = 0
    var invalidRoundCount = 0
}

struct SeriesStandingsRolloutPreview: Equatable {
    let completedRoundCount: Int
    let tracks: [SeriesAwardTrack: SeriesStandingsRolloutTrackPreview]
}

struct SeriesStandingsRolloutProgress: Equatable {
    let completedCount: Int
    let totalCount: Int

    var fractionCompleted: Double {
        guard totalCount > 0 else { return 1 }
        return Double(completedCount) / Double(totalCount)
    }
}

enum SeriesStandingsRolloutOperationError: Error, LocalizedError {
    case commissionerRequired
    case operationInProgress
    case policyNotConfigured
    case missingLinkedRound(String)
    case snapshotUnavailable(String)
    case sourceReadFailed
    case roundWriteFailed(String)
    case roundProcessingFailed(String)
    case canonicalReadFailed
    case projectionFailed(SeriesCanonicalStandingsProjectionError)
    case seriesWriteFailed

    var errorDescription: String? {
        switch self {
        case .commissionerRequired:
            return "Commissioner access is required to change standings policy."
        case .operationInProgress:
            return "A standings update is already in progress."
        case .policyNotConfigured:
            return "Save a scoring-average policy before preparing standings."
        case .missingLinkedRound(let title):
            return "\(title) is not linked to a scoring round."
        case .snapshotUnavailable(let title):
            return "The scoring snapshot for \(title) could not be loaded."
        case .sourceReadFailed:
            return "Round mappings or point awards could not be loaded."
        case .roundWriteFailed(let title):
            return "The policy could not be applied to \(title)."
        case .roundProcessingFailed(let title):
            return "Canonical results could not be prepared for \(title)."
        case .canonicalReadFailed:
            return "Prepared canonical results could not be verified."
        case .projectionFailed(let error):
            return "Canonical standings are not ready (\(error.telemetryValue))."
        case .seriesWriteFailed:
            return "The standings setting could not be saved."
        }
    }
}

enum SeriesStandingsRollout {
    static func draft(from settings: SeriesSettings) -> SeriesStandingsTiebreakDraft {
        var draft = SeriesStandingsTiebreakDraft()
        guard let policy = settings.standingsPolicyRevision?.policy else { return draft }

        for track in SeriesAwardTrack.allCases {
            guard let rule = policy.rules.first(where: { $0.track == track }),
                  let tiebreaker = rule.resolvedTiebreakers.first else { continue }
            draft[track] = SeriesStandingsTrackTiebreakDraft(
                isEnabled: true,
                direction: tiebreaker.direction,
                scoreComponent: tiebreaker.scoreComponent,
                minimumEligibleRounds: tiebreaker.minimumEligibleRounds
            )
        }
        return draft
    }

    static func makeRevision(
        settings: SeriesSettings,
        draft: SeriesStandingsTiebreakDraft,
        id: String,
        createdAt: Time = .init()
    ) -> Result<SeriesPolicyRevision, SeriesStandingsRolloutPolicyError> {
        let enabledTracks = Set(SeriesAwardTrack.allCases.filter { track in
            switch track {
            case .team: return settings.useTeamStandings
            case .individual: return settings.useIndividualStandings
            }
        })
        guard enabledTracks.isPopulated else {
            return .failure(.noEnabledStandingsTrack)
        }
        guard draft.hasEnabledTiebreaker else {
            return .failure(.noEnabledTiebreaker)
        }
        for track in SeriesAwardTrack.allCases where draft[track].isEnabled && !enabledTracks.contains(track) {
            return .failure(.disabledTrack(track))
        }
        guard settings.defaultCourse != nil else {
            return .failure(.missingDefaultCourse)
        }

        let strictPolicy = SeriesStandingsPolicyResolver.strictPolicy(settings: settings)
        let rules = strictPolicy.rules.map { rule -> SeriesStandingsRule in
            let trackDraft = draft[rule.track]
            let tiebreakers = trackDraft.isEnabled ? [SeriesTiebreakRule(
                id: "\(rule.track.rawValue)_scoring_average",
                direction: trackDraft.direction,
                scoreComponent: trackDraft.scoreComponent,
                minimumEligibleRounds: trackDraft.minimumEligibleRounds
            )] : nil
            return SeriesStandingsRule(
                id: rule.id,
                track: rule.track,
                acceptedFormatTemplateIDs: rule.acceptedFormatTemplateIDs,
                acceptedScoreBases: rule.acceptedScoreBases,
                acceptedHoleCounts: rule.acceptedHoleCounts,
                acceptedScoringFamilies: rule.acceptedScoringFamilies,
                requiredTeamScoring: rule.requiredTeamScoring,
                requiredSubstitutesScore: rule.requiredSubstitutesScore,
                normalizationPolicy: rule.normalizationPolicy,
                tiebreakers: tiebreakers
            )
        }
        let policy = SeriesStandingsPolicy(rules: rules)
        for rule in policy.rules where draft[rule.track].isEnabled {
            guard SeriesStandingsPolicyResolver.isValidTiebreakPolicy(rule) else {
                return .failure(.invalidTiebreakPolicy(rule.track))
            }
        }

        return .success(SeriesStandingsPolicyResolver.makeRevision(
            id: id,
            sequence: (settings.standingsPolicyRevision?.sequence ?? 0) + 1,
            policy: policy,
            createdAt: createdAt
        ))
    }

    static func preview(
        series: Series,
        completedRounds: [SeriesRound],
        revision: SeriesPolicyRevision
    ) -> SeriesStandingsRolloutPreview {
        let binding = SeriesStandingsPolicyResolver.binding(
            for: revision,
            substitutesScore: series.settings.substitutesScore
        )
        var tracks = Dictionary(uniqueKeysWithValues: SeriesAwardTrack.allCases.map {
            ($0, SeriesStandingsRolloutTrackPreview())
        })

        for sourceRound in completedRounds {
            var round = sourceRound
            round.policyBinding = binding
            for compatibility in SeriesStandingsPolicyResolver.compatibility(for: round, in: series) {
                var track = tracks[compatibility.rule.track] ?? .init()
                switch compatibility.classification {
                case .eligible:
                    track.eligibleRoundCount += 1
                case .normalized:
                    track.normalizedRoundCount += 1
                case .excluded:
                    track.excludedRoundCount += 1
                case .invalid:
                    track.invalidRoundCount += 1
                }
                tracks[compatibility.rule.track] = track
            }
        }

        return SeriesStandingsRolloutPreview(
            completedRoundCount: completedRounds.count,
            tracks: tracks
        )
    }

    static func preservingManagedSettings(
        draft: SeriesSettings,
        current: SeriesSettings
    ) -> SeriesSettings {
        var protected = draft
        protected.standingsPolicyRevision = current.standingsPolicyRevision
        protected.standingsReadAuthority = current.standingsReadAuthority
        let currentContract = SeriesStandingsPolicyResolver.strictPolicy(settings: current)
        let proposedContract = SeriesStandingsPolicyResolver.strictPolicy(settings: protected)
        if SeriesStandingsPolicyResolver.fingerprint(for: currentContract)
            != SeriesStandingsPolicyResolver.fingerprint(for: proposedContract) {
            protected.standingsReadAuthority = .legacy
        }
        return protected
    }
}

enum SeriesStandingsAverageFormatter {
    static func string(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.1f", value)
    }
}
