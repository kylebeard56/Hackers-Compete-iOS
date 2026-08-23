//
//  SeriesRoundCardPresentation.swift
//  Hackers
//
//  Version-neutral presentation contracts for Series round list cards.
//

import Foundation

enum SeriesRoundCardLifecycle: String, Codable, Equatable {
    case upcoming
    case lobby
    case live
    case completed
    case needsReview
    case finalized
    case canceled
    case archived
}

enum SeriesRoundCardPresentationKind: String, Codable, Equatable {
    case matchup
    case leaderboard
    case sharedScore
}

enum SeriesRoundCardContributorRole: String, Codable, Equatable {
    /// The scoring engine selected this player for a per-round Best/Worst N result.
    case selectedForRound = "selected_for_round"
    /// Best/Worst N is selected independently on each hole, so no fixed pair owns the result.
    case variablePerHole = "variable_per_hole"
    /// Every eligible score contributes to the aggregate.
    case allScoresCount = "all_scores_count"
    /// Displayed for context only and not claimed as the sole source of the aggregate.
    case leaderOnly = "leader_only"
    /// Member of a partnership or other shared scoring owner.
    case sharedScoreMember = "shared_score_member"
}

enum SeriesRoundCardResult: String, Codable, Equatable {
    case leading
    case trailing
    case winner
    case loser
    case tied
    case none
}

enum SeriesRoundCardPrimaryAction: String, Codable, Equatable {
    case rsvp
    case openLobby = "open_lobby"
    case continuePlaying = "continue_playing"
    case watchLive = "watch_live"
    case viewResults = "view_results"
    case none
}

struct SeriesRoundCardViewerState: Codable, Equatable {
    enum Participation: String, Codable, Equatable {
        case playing
        case played
        case didNotPlay = "did_not_play"
        case declined
        case pending
        case unknown
    }

    var participation: Participation
    var scoreLabel: String?

    var label: String? {
        switch participation {
        case .playing:
            return scoreLabel.map { "You’re playing · \($0)" } ?? "You’re playing"
        case .played:
            return scoreLabel.map { "You played · \($0)" } ?? "You played"
        case .didNotPlay:
            return "You did not play"
        case .declined:
            return "You declined"
        case .pending:
            return "Your RSVP is pending"
        case .unknown:
            return nil
        }
    }
}

struct SeriesRoundCardContributor: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var scoreLabel: String?
    var handicapLabel: String?
    var progressLabel: String?
    var preRoundMetadataLabel: String? = nil
    var role: SeriesRoundCardContributorRole
    var isViewer: Bool
    var isSubstitute: Bool
    var countsTowardScore: Bool? = nil
}

struct SeriesRoundCardSide: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var subtitle: String?
    var scoreLabel: String?
    var result: SeriesRoundCardResult
    var contributors: [SeriesRoundCardContributor]
    var hiddenContributorCount: Int
}

struct SeriesRoundCardViewState: Identifiable, Codable, Equatable {
    static let projectionVersion = 1

    var id: String
    var canonicalRoundID: String?
    var title: String
    var courseName: String
    var scheduleLabel: String
    var lifecycle: SeriesRoundCardLifecycle
    var presentationKind: SeriesRoundCardPresentationKind
    var formatLabel: String
    var scoringRuleLabel: String
    var scoreBasis: ScoreBasis
    var showsHandicap: Bool
    var isProvisional: Bool
    var sides: [SeriesRoundCardSide]
    var viewer: SeriesRoundCardViewerState?
    var participantCountLabel: String?
    var substituteCountLabel: String? = nil
    var primaryAction: SeriesRoundCardPrimaryAction
    var isAdjusted: Bool
    var setupDiffers: Bool

    var statusLabel: String {
        switch lifecycle {
        case .upcoming: return "Upcoming"
        case .lobby: return "Lobby open"
        case .live: return "Live"
        case .completed: return resolvedResultLabel ?? "Completed"
        case .needsReview: return "Needs review"
        case .finalized: return resolvedResultLabel ?? "Final"
        case .canceled: return "Canceled"
        case .archived: return "Archived"
        }
    }

    private var resolvedResultLabel: String? {
        let results = Set(sides.map(\.result))
        if results.contains(.winner) { return "Final" }
        if results.contains(.tied) { return "Tied"
        }
        return nil
    }
}

/// Optional result-owned projection. It stores derived display facts only; round configuration
/// remains authoritative on the playable round (or the unlinked V1 SeriesRound while planned).
struct SeriesRoundCardProjection: Codable, Equatable {
    var version: Int
    var state: SeriesRoundCardViewState
    var generatedAt: Time

    init(state: SeriesRoundCardViewState, generatedAt: Time = .init()) {
        version = SeriesRoundCardViewState.projectionVersion
        self.state = state
        self.generatedAt = generatedAt
    }
}

struct SeriesRoundCardResolvedConfiguration: Equatable {
    var templateID: String
    var formatName: String
    var competitionScope: CompetitionScope
    var teamScoring: RoundTeamScoringConfiguration
    var scoreOwnerScope: RoundScoreOwnerScope
    var scoreBasis: ScoreBasis
    var usesHandicaps: Bool
    var highestWins: Bool

    var presentationKind: SeriesRoundCardPresentationKind {
        if competitionScope == .matchup { return .matchup }
        if scoreOwnerScope != .individual { return .sharedScore }
        return .leaderboard
    }

    var scoringRuleLabel: String {
        switch teamScoring.mode {
        case .all:
            return "All scores count"
        case .bestN:
            return "Best \(max(1, teamScoring.count)) per \(teamScoring.scope.cardLabel)"
        case .worstN:
            return "Worst \(max(1, teamScoring.count)) per \(teamScoring.scope.cardLabel)"
        }
    }

    var defaultContributorRole: SeriesRoundCardContributorRole {
        switch teamScoring.mode {
        case .all:
            return .allScoresCount
        case .bestN, .worstN:
            return teamScoring.scope == .perRound ? .selectedForRound : .variablePerHole
        }
    }
}

extension AggregationScope {
    fileprivate var cardLabel: String {
        switch self {
        case .perHole: return "hole"
        case .perRound: return "round"
        }
    }
}

enum V1SeriesRoundCardAdapter {
    static func resolvedConfiguration(
        seriesRound: SeriesRound,
        linkedRound: Round?,
        series: Series
    ) -> SeriesRoundCardResolvedConfiguration {
        if let linkedRound {
            let configuration = linkedRound.configuration
            let template = configuration.activeTemplate
            return .init(
                templateID: template.id,
                formatName: configuration.formatSummary?.name ?? template.name,
                competitionScope: configuration.resolvedCompetitionScope,
                teamScoring: configuration.teamScoring,
                scoreOwnerScope: configuration.scoreOwnerScope,
                scoreBasis: configuration.primaryFormat.configuration.basis,
                usesHandicaps: configuration.useHandicaps,
                highestWins: template.leaderboardSort == .highestWins
            )
        }

        let configuration = seriesRound.roundConfig
        let template = configuration.template
        let basis = configuration.scoreBasisOverride
            ?? (series.handicapConfig.isEnabled ? .net : template.requirements.defaultScoreBasis)
        return .init(
            templateID: template.id,
            formatName: template.name,
            competitionScope: configuration.resolvedCompetitionScope,
            teamScoring: configuration.teamScoring,
            scoreOwnerScope: configuration.scoreOwnerScope,
            scoreBasis: basis,
            usesHandicaps: basis == .net,
            highestWins: template.leaderboardSort == .highestWins
        )
    }

    static func lifecycle(status: SeriesRoundStatus, awardsStatus: SeriesAwardsStatus) -> SeriesRoundCardLifecycle {
        switch status {
        case .planned: return .upcoming
        case .lobby: return .lobby
        case .live: return .live
        case .complete:
            switch awardsStatus {
            case .pending: return .completed
            case .needsReview: return .needsReview
            case .finalized: return .finalized
            }
        case .canceled: return .canceled
        }
    }
}

enum V2SeriesRoundCardAdapter {
    static func resolvedConfiguration(round: RoundV2) -> SeriesRoundCardResolvedConfiguration {
        let configuration = round.configuration
        let template = FormatTemplateRegistry.template(for: configuration.templateID)
        return .init(
            templateID: configuration.templateID,
            formatName: configuration.formatSummary.name,
            competitionScope: configuration.competitionScope,
            teamScoring: configuration.teamScoring,
            scoreOwnerScope: configuration.scoreOwnerScope,
            scoreBasis: configuration.scoreBasis,
            usesHandicaps: configuration.scoreBasis == .net,
            highestWins: template.leaderboardSort == .highestWins
        )
    }

    static func lifecycle(
        round: RoundV2,
        resultState: SeriesRoundResultStateV2?,
        now: Date = .init()
    ) -> SeriesRoundCardLifecycle {
        switch SeriesRoundPresentationResolverV2.resolve(round: round, resultState: resultState, now: now) {
        case .pending, .scheduled: return .upcoming
        case .lobby: return .lobby
        case .live: return .live
        case .completed: return .completed
        case .needsReview: return .needsReview
        case .finalized: return .finalized
        case .canceled: return .canceled
        case .archived: return .archived
        }
    }

    static func primaryAction(
        round: RoundV2,
        resultState: SeriesRoundResultStateV2?,
        isViewerParticipant: Bool = false,
        now: Date = .init()
    ) -> SeriesRoundCardPrimaryAction {
        switch lifecycle(round: round, resultState: resultState, now: now) {
        case .upcoming:
            return round.seriesContext?.rules.attendanceEnabled == true ? .rsvp : .openLobby
        case .lobby:
            return .openLobby
        case .live:
            return isViewerParticipant ? .continuePlaying : .watchLive
        case .completed, .needsReview, .finalized:
            return .viewResults
        case .canceled, .archived:
            return .none
        }
    }
}

enum SeriesRoundCardFormatting {
    static func playerName(_ fullName: String) -> String {
        let name = Name(fullName).normalizedForStorage
        let given = name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let initial = family.first else { return given }
        return "\(given) \(String(initial).uppercased())"
    }

    static func preRoundMetadataLabel(
        handicap: String?,
        teeGroup: String?
    ) -> String? {
        var components: [String] = []
        if let handicap, handicap.isPopulated {
            components.append("\(handicap) HCP")
        }
        if let teeGroup, teeGroup.isPopulated {
            components.append(teeGroup)
        }
        return components.isEmpty ? nil : components.joined(separator: " · ")
    }

    static func scheduleLabel(
        lifecycle: SeriesRoundCardLifecycle,
        scheduledAt: Time?,
        completedAt: Time? = nil,
        now: Date = .init(),
        calendar: Calendar = .current
    ) -> String {
        let value = completedAt ?? scheduledAt
        guard let value else { return lifecycle == .upcoming ? "Schedule TBD" : "Date unavailable" }
        let date = Date(timeIntervalSince1970: value.unix)
        if lifecycle == .upcoming || lifecycle == .lobby {
            if calendar.isDateInToday(date) { return "Today · \(date.toTimeFormat)" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow · \(date.toTimeFormat)" }
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func scoreLabel(total: Double, highestWins: Bool) -> String {
        if highestWins {
            let rounded = total.rounded()
            return abs(total - rounded) < 0.001 ? "\(Int(rounded))" : String(format: "%.1f", total)
        }
        let value = Int(total.rounded())
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    static func participantCountLabel(
        playing: Int,
        total: Int,
        lifecycle: SeriesRoundCardLifecycle
    ) -> String? {
        guard total > 0 else { return nil }
        let verb: String
        switch lifecycle {
        case .completed, .needsReview, .finalized, .archived:
            verb = "played"
        case .upcoming, .lobby, .live, .canceled:
            verb = "playing"
        }
        return "\(min(playing, total)) of \(total) \(verb)"
    }

    static func substituteCountLabel(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? "sub" : "subs")"
    }
}
