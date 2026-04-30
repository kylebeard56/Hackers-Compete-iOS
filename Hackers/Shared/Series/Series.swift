//
//  Series.swift
//  Hackers
//
//  Created by Codex on 3/6/26.
//

import Foundation
import SwiftUI

// MARK: - Firestore shape
//
// series/{seriesId}                         // Series (root)
//   members/{memberId}                      // SeriesMember
//   invites/{inviteId}                      // SeriesInvite
//   teams/{teamId}                          // SeriesTeam
//   pods/{podId}                            // SeriesTeamPod
//   rounds/{seriesRoundId}                  // SeriesRound
//   attendance/{attendanceId}               // SeriesRoundAttendance
//   announcements/{announcementId}          // SeriesAnnouncement
//   scoring-profiles/{profileId}            // SeriesScoringProfile
//   mappings/{mappingId}                    // SeriesRoundMapping
//   point-awards/{awardId}                  // SeriesPointAward
//   standings/{standingId}                  // SeriesStanding
//   handicap-scores/{scoreId}               // SeriesHandicapScore
//   handicap-overrides/{overrideId}         // SeriesHandicapOverride

enum SeriesSubcollection: String, CaseIterable {
    case members = "members"
    case invites = "invites"
    case teams = "teams"
    case pods = "pods"
    case rounds = "rounds"
    case attendance = "attendance"
    case announcements = "announcements"
    case scoringProfiles = "scoring-profiles"
    case mappings = "mappings"
    case pointAwards = "point-awards"
    case standings = "standings"
    case handicapScores = "handicap-scores"
    case handicapOverrides = "handicap-overrides"
}

enum SeriesRoundAttendanceStatus: String, CaseIterable, Codable {
    case pending
    case accepted
    case no
    
    func labelColor(palette: DesignPalette) -> Color {
        switch self {
        case .pending:
            return palette.foregroundColor
        case .accepted:
            return Color.accentGreen
        case .no:
            return Color.systemError
        }
    }
    
    func buttonColor(palette: DesignPalette) -> Color {
        switch self {
        case .pending:
            return palette.whiteGlassButtonColor
        case .accepted:
            return Color.accentGreen.opacity(palette.scheme.translucent)
        case .no:
            return Color.systemError.opacity(palette.scheme.translucent)
        }
    }
    
    var buttonLabel: String {
        switch self {
        case .pending:
            return "RSVP"
        case .accepted:
            return "Playing"
        case .no:
            return "Declined"
        }
    }
    
    var buttonIcon: String? {
        switch self {
        case .pending:
            return nil
        case .accepted:
            return "f00c"
        case .no:
            return "f00d"
        }
    }
}

enum SeriesStatus: String, CaseIterable, Codable {
    case draft
    case active
    case completed
    case archived
}

enum SeriesVisibility: String, CaseIterable, Codable {
    case privateSeries = "private"
    case discoverable
}

enum SeriesExperiencePreset: String, CaseIterable {
    case league
    case trip
    case tournament
}

extension SeriesExperiencePreset: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "league": self = .league
        case "trip": self = .trip
        case "tournament": self = .tournament
        case "other": self = .tournament
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown SeriesExperiencePreset value: \(raw)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension SeriesExperiencePreset {
    var displayName: String {
        switch self {
        case .league:
            return "League"
        case .trip:
            return "Trip"
        case .tournament:
            return "Tournament"
        }
    }

    var settingsTitle: String {
        switch self {
        case .league:
            return "League Settings"
        case .trip:
            return "Trip Settings"
        case .tournament:
            return "Tournament Settings"
        }
    }

    var settingsSubtitle: String {
        switch self {
        case .league:
            return "Manage logistics and league configuration."
        case .trip:
            return "Manage trip logistics, pairings, and scoring defaults."
        case .tournament:
            return "Manage tournament logistics, pairings, and scoring defaults."
        }
    }

    var handicapDefaultMode: SeriesHandicapMode {
        switch self {
        case .league, .tournament:
            return .dynamic
        case .trip:
            return .fixed
        }
    }

    // MARK: - Preset-aware shell UI copy

    var nameEntryPlaceholder: String {
        switch self {
        case .league: return "Enter league name"
        case .trip: return "Enter trip name"
        case .tournament: return "Enter tournament name"
        }
    }

    /// Title for the new-experience sheet (e.g. "New League").
    var creationFlowTitle: String { "New \(displayName)" }

    var newExperienceDescription: String {
        switch self {
        case .league:
            return "Create a league with repeatable rules, standings, and commissioner controls."
        case .trip:
            return "Create a golf trip with flexible round formats, changing pairings, and trip-friendly defaults."
        case .tournament:
            return "Create a tournament with editable defaults and multi-round scoring you can shape as you go."
        }
    }

    var shareSheetTitle: String { "Share \(displayName.lowercased())" }

    /// Phrase used after "join" in share body copy (e.g. "this league").
    var shareInviteJoinPhrase: String {
        switch self {
        case .league: return "this league"
        case .trip: return "this trip"
        case .tournament: return "this tournament"
        }
    }

    var shareJoinPreviewFallbackNoun: String { displayName.lowercased() }

    var gearMenuSettingsLabel: String { "\(displayName) settings" }

    var leaveMenuLabel: String { "Leave \(displayName.lowercased())" }

    var leaveAlertTitle: String { "Leave \(displayName)" }

    var leaveAlertMessage: String {
        switch self {
        case .league:
            return "Your membership will be removed. Your historical scores and round data will be preserved, but you will lose access to this league."
        case .trip:
            return "Your membership will be removed. Your historical scores and round data will be preserved, but you will lose access to this trip."
        case .tournament:
            return "Your membership will be removed. Your historical scores and round data will be preserved, but you will lose access to this tournament."
        }
    }

    var checklistSetRulesRowTitle: String { "Set \(displayName.lowercased()) rules" }

    var checklistDefaultCourseReadySubtitle: String { "\(displayName) default is ready" }

    var roundsEmptyStateSubtitle: String {
        "Schedule your first round to get the \(displayName.lowercased()) calendar moving."
    }

    var unnamedExperienceNavTitle: String { displayName.uppercased() }

    var syncFromShellMenuLabel: String { "Sync from \(displayName.lowercased())…" }

    var csvExportSheetSubtitle: String {
        "Your \(displayName.lowercased()) round export is ready to share."
    }

    var csvExportReadyLine: String {
        "\(displayName) round export is ready."
    }

    var settingsBasicsGroupTitle: String { "\(displayName) Basics" }

    var defaultTeamPointsProfileSubtitle: String {
        "Choose the default team points profile for new \(displayName.lowercased()) rounds."
    }

    var defaultIndividualPointsProfileSubtitle: String {
        "Choose the default player points profile for new \(displayName.lowercased()) rounds."
    }

    var adjustRoundsFromShellSubtitle: String {
        "Keep round settings adjustable from the \(displayName.lowercased())."
    }

    var attendanceWhenScheduledSubtitle: String {
        "Choose the initial response state when a new \(displayName.lowercased()) round is scheduled."
    }

    var allPlayersAddedWhenAttendanceOff: String {
        switch self {
        case .league:
            return "All players in the league will be added to planned rounds."
        case .trip:
            return "All players on the trip will be added to planned rounds."
        case .tournament:
            return "All players in the tournament will be added to planned rounds."
        }
    }

    var rulesSectionHeader: String { "\(displayName) Rules" }

    var confirmRulesChipSaveAndConfirm: String {
        "Save & confirm \(displayName.lowercased()) rules"
    }

    var confirmRulesChipConfirm: String {
        "Confirm \(displayName.lowercased()) rules"
    }

    var noInvitesYetLine: String {
        "No \(displayName.lowercased()) invites yet."
    }

    var defaultPointsAwardsExplainer: String {
        "Individual points set how each round adds to the \(displayName.lowercased()) leaderboard."
    }

    var rulesConfirmedUntilGameplayChanges: String {
        "This stays complete until \(displayName.lowercased()) gameplay rules change."
    }

    var invitesSheetNavTitle: String { "\(displayName) Invites" }

    var invitesSheetNavSubtitle: String {
        "Search Hackers players and send \(displayName.lowercased()) invites without creating duplicate members."
    }

    var invitesSearchEmptyExplainer: String {
        "Search for existing Hackers players, then send a \(displayName.lowercased()) invite without adding a duplicate roster record."
    }

    var alreadyOnRosterLabel: String {
        "Already in \(displayName.lowercased())"
    }
}

enum SeriesCompetitorType: String, CaseIterable, Codable {
    case member
    case team
}

enum SeriesAwardTrack: String, CaseIterable, Codable {
    case team
    case individual

    var competitorType: SeriesCompetitorType {
        switch self {
        case .team: return .team
        case .individual: return .member
        }
    }
}

enum SeriesMemberRole: String, CaseIterable, Codable {
    case commissioner
    case captain
    case member
    case spectator
}

extension SeriesMemberRole {
    /// Commissioner > Captain > Member > Spectator
    var rank: Int {
        switch self {
        case .commissioner: return 3
        case .captain: return 2
        case .member: return 1
        case .spectator: return 0
        }
    }
}

enum SeriesInviteStatus: String, CaseIterable, Codable {
    case pending
    case accepted
    case declined
    case revoked
}

enum SeriesRoundStatus: String, CaseIterable, Codable {
    case planned
    case lobby
    case live
    case complete
    case canceled
}

extension SeriesRoundStatus {
    /// Maps a gameplay `RoundStatus` to the series subcollection status (paused rounds count as live; archived → canceled).
    init(linkedRoundStatus: RoundStatus) {
        switch linkedRoundStatus {
        case .lobby: self = .lobby
        case .live, .paused: self = .live
        case .complete: self = .complete
        case .archived: self = .canceled
        }
    }
}

enum SeriesAwardsStatus: String, CaseIterable, Codable {
    case pending
    case needsReview = "needs_review"
    case finalized
}

enum SeriesPodGroupingStrategy: String, CaseIterable, Codable {
    case disabled
    case alignByIndex = "align_by_index"
    case swapPairs = "swap_pairs"
}

extension SeriesPodGroupingStrategy {
    var usesPodAlignment: Bool {
        switch self {
        case .disabled:
            return false
        case .alignByIndex, .swapPairs:
            return true
        }
    }
}

enum SeriesDefaultCourseRotationMode: String, CaseIterable, Codable {
    case fixed
    case alternateFrontBack = "alternate_front_back"
}

enum SeriesMatchupMode: String, CaseIterable, Codable {
    case none
    case field
    case teamVsTeam = "team_vs_team"
    case individualVsIndividual = "individual_vs_individual"
    case teeGroupPartnerships = "tee_group_partnerships"
}

enum SeriesTeamAssignmentMode: String, CaseIterable, Codable {
    case seriesTeams = "series_teams"
    case manual
}

enum SeriesTeeGroupMode: String, CaseIterable, Codable {
    case auto
    case podAligned = "pod_aligned"
    case manual
}

enum SeriesRoundOwnerType: String, CaseIterable, Codable {
    case participant
    case team
    case scoreOwner = "score_owner"
}

enum SeriesOutcomeSource: String, CaseIterable, Codable {
    case roundIndividualLeaderboard = "round_individual_leaderboard"
    case roundTeamLeaderboard = "round_team_leaderboard"
    case roundMatchResult = "round_match_result"
    case individualAwardsAggregateToTeam = "individual_awards_aggregate_to_team"
    case manual
}

enum SeriesScoringProfileKind: String, CaseIterable, Codable {
    case placement
    case winTieLoss = "win_tie_loss"
    case accrueFromIndividual = "accrue_from_individual"
    case manual
}

enum SeriesTieHandling: String, CaseIterable, Codable {
    case splitPoints = "split_points"
    case samePointsSkipNext = "same_points_skip_next"
    case commissionerDecision = "commissioner_decision"
}

enum SeriesBonusRuleType: String, CaseIterable, Codable {
    case participation
    case manual
}

enum SeriesAwardSource: String, CaseIterable, Codable {
    case automatic
    case commissionerOverride = "commissioner_override"
    case manual
}

enum SeriesHandicapScoreSourceType: String, CaseIterable, Codable {
    case baseline
    case round
}

enum SeriesHandicapMode: String, CaseIterable, Codable {
    case off
    case fixed
    case dynamic
}

enum SeriesHandicapStrokeBasis: String, CaseIterable, Codable {
    case nineHole = "nine_hole"
    case eighteenHole = "eighteen_hole"

    var displayName: String {
        switch self {
        case .nineHole: return "9 holes"
        case .eighteenHole: return "18 holes"
        }
    }

    var holeCount: Int {
        switch self {
        case .nineHole: return 9
        case .eighteenHole: return 18
        }
    }

    static func defaultBasis(defaultParForIndex: Double) -> SeriesHandicapStrokeBasis {
        defaultParForIndex <= 40 ? .nineHole : .eighteenHole
    }

    static func defaultBasis(holeCount: Int) -> SeriesHandicapStrokeBasis {
        holeCount <= 9 ? .nineHole : .eighteenHole
    }
}

extension SeriesHandicapMode {
    var isEnabled: Bool {
        self != .off
    }

    var allowsAccrual: Bool {
        self == .dynamic
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct SeriesCourseSelection: Hashable, Codable {
    var courseID: String
    var cachedName: String
    var defaultTeeBoxID: String
    var holeSegment: HoleSegment

    init(
        courseID: String = "",
        cachedName: String = "",
        defaultTeeBoxID: String = "",
        holeSegment: HoleSegment = .full18
    ) {
        self.courseID = courseID
        self.cachedName = cachedName
        self.defaultTeeBoxID = defaultTeeBoxID
        self.holeSegment = holeSegment
    }

    enum CodingKeys: String, CodingKey {
        case courseID = "course_id"
        case cachedName = "cached_name"
        case defaultTeeBoxID = "default_tee_box_id"
        case holeSegment = "hole_segment"
    }

    var isConfigured: Bool { courseID.isPopulated }
}

struct SeriesRoundConfiguration: Hashable, Codable {
    var formatTemplateID: String
    var competitionScope: CompetitionScope?
    var teamScoring: RoundTeamScoringConfiguration
    var matchupResolutionStyle: RoundMatchupResolutionStyle
    var scoreOwnerScope: RoundScoreOwnerScope
    var matchupScoringStyle: RoundMatchupScoringStyle
    var holeWinPoints: Double?
    var matchWinnerBonusPoints: Double?
    var matchTiePolicy: TiePolicy?
    var sequentialTeeStartsEnabled: Bool?
    var selectionDomain: ScoringSelectionDomain?
    var matchupMode: SeriesMatchupMode
    var podGroupingStrategy: SeriesPodGroupingStrategy
    var teamAssignmentMode: SeriesTeamAssignmentMode
    var teeGroupMode: SeriesTeeGroupMode
    var notes: String?
    var allowCourseOverride: Bool
    var allowFormatOverride: Bool
    var allowLobbyBackPropagation: Bool
    /// When non-nil, overrides the template's `defaultScoreBasis` (gross/net).
    var scoreBasisOverride: ScoreBasis?
    /// Optional format-specific allowance for shared-score scoring units, applied by handicap rank.
    var sharedScoreHandicapConfig: HandicapConfiguration?
    var countsTowardHandicapPool: Bool
    var excludedHandicapMemberIDs: [String]

    init(
        formatTemplateID: String = FormatTemplateRegistry.strokePlay.id,
        competitionScope: CompetitionScope? = nil,
        teamScoring: RoundTeamScoringConfiguration = .init(),
        matchupResolutionStyle: RoundMatchupResolutionStyle = .roundAggregate,
        scoreOwnerScope: RoundScoreOwnerScope = .individual,
        matchupScoringStyle: RoundMatchupScoringStyle = .aggregateRoundTotal,
        holeWinPoints: Double? = nil,
        matchWinnerBonusPoints: Double? = nil,
        matchTiePolicy: TiePolicy? = nil,
        sequentialTeeStartsEnabled: Bool? = false,
        selectionDomain: ScoringSelectionDomain? = nil,
        matchupMode: SeriesMatchupMode = .field,
        podGroupingStrategy: SeriesPodGroupingStrategy = .disabled,
        teamAssignmentMode: SeriesTeamAssignmentMode = .manual,
        teeGroupMode: SeriesTeeGroupMode = .auto,
        notes: String? = nil,
        allowCourseOverride: Bool = true,
        allowFormatOverride: Bool = true,
        allowLobbyBackPropagation: Bool = true,
        scoreBasisOverride: ScoreBasis? = nil,
        sharedScoreHandicapConfig: HandicapConfiguration? = nil,
        countsTowardHandicapPool: Bool = true,
        excludedHandicapMemberIDs: [String] = []
    ) {
        self.formatTemplateID = formatTemplateID
        self.competitionScope = competitionScope
        self.teamScoring = teamScoring
        self.matchupResolutionStyle = matchupResolutionStyle
        self.scoreOwnerScope = scoreOwnerScope
        self.matchupScoringStyle = matchupScoringStyle
        self.holeWinPoints = holeWinPoints
        self.matchWinnerBonusPoints = matchWinnerBonusPoints
        self.matchTiePolicy = matchTiePolicy
        self.sequentialTeeStartsEnabled = sequentialTeeStartsEnabled
        self.selectionDomain = selectionDomain
        self.matchupMode = matchupMode
        self.podGroupingStrategy = podGroupingStrategy
        self.teamAssignmentMode = teamAssignmentMode
        self.teeGroupMode = teeGroupMode
        self.notes = notes
        self.allowCourseOverride = allowCourseOverride
        self.allowFormatOverride = allowFormatOverride
        self.allowLobbyBackPropagation = allowLobbyBackPropagation
        self.scoreBasisOverride = scoreBasisOverride
        self.sharedScoreHandicapConfig = sharedScoreHandicapConfig
        self.countsTowardHandicapPool = countsTowardHandicapPool
        self.excludedHandicapMemberIDs = Self.normalizedMemberIDs(excludedHandicapMemberIDs)
    }

    enum CodingKeys: String, CodingKey {
        case formatTemplateID = "format_template_id"
        case competitionScope = "competition_scope"
        case teamScoring = "team_scoring"
        case matchupResolutionStyle = "matchup_resolution_style"
        case scoreOwnerScope = "score_owner_scope"
        case matchupScoringStyle = "matchup_scoring_style"
        case holeWinPoints = "hole_win_points"
        case matchWinnerBonusPoints = "match_winner_bonus_points"
        case matchTiePolicy = "match_tie_policy"
        case legacyBestNSelected = "best_n_selected"
        case legacyBestWorstEnabled = "best_worst_enabled"
        case sequentialTeeStartsEnabled = "sequential_tee_starts_enabled"
        case selectionDomain = "selection_domain"
        case matchupMode = "matchup_mode"
        case podGroupingStrategy = "pod_grouping_strategy"
        case teamAssignmentMode = "team_assignment_mode"
        case teeGroupMode = "tee_group_mode"
        case notes
        case allowCourseOverride = "allow_course_override"
        case allowFormatOverride = "allow_format_override"
        case allowLobbyBackPropagation = "allow_lobby_back_propagation"
        case scoreBasisOverride = "score_basis_override"
        case sharedScoreHandicapConfig = "shared_score_handicap_config"
        case countsTowardHandicapPool = "counts_toward_handicap_pool"
        case excludedHandicapMemberIDs = "excluded_handicap_member_ids"
    }

    var usesSequentialTeeStarts: Bool {
        sequentialTeeStartsEnabled == true
    }

    var resolvedHoleWinPoints: Double {
        holeWinPoints ?? 1.0
    }

    var resolvedMatchWinnerBonusPoints: Double {
        matchWinnerBonusPoints ?? 0
    }

    var resolvedMatchTiePolicy: TiePolicy {
        matchTiePolicy ?? .half
    }

    var bestNSelected: Int? {
        switch teamScoring.mode {
        case .all:
            return nil
        case .bestN, .worstN:
            return teamScoring.count
        }
    }

    var bestWorstEnabled: Bool {
        teamScoring.mode == .worstN
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatTemplateID = try c.decodeIfPresent(String.self, forKey: .formatTemplateID) ?? FormatTemplateRegistry.strokePlay.id
        competitionScope = try c.decodeIfPresent(CompetitionScope.self, forKey: .competitionScope)
        matchupResolutionStyle = try c.decodeIfPresent(RoundMatchupResolutionStyle.self, forKey: .matchupResolutionStyle) ?? .roundAggregate
        scoreOwnerScope = try c.decodeIfPresent(RoundScoreOwnerScope.self, forKey: .scoreOwnerScope) ?? .individual
        matchupScoringStyle = try c.decodeIfPresent(RoundMatchupScoringStyle.self, forKey: .matchupScoringStyle) ?? .aggregateRoundTotal
        holeWinPoints = try c.decodeIfPresent(Double.self, forKey: .holeWinPoints)
        matchWinnerBonusPoints = try c.decodeIfPresent(Double.self, forKey: .matchWinnerBonusPoints)
        matchTiePolicy = try c.decodeIfPresent(TiePolicy.self, forKey: .matchTiePolicy)
        sequentialTeeStartsEnabled = try c.decodeIfPresent(Bool.self, forKey: .sequentialTeeStartsEnabled) ?? false
        selectionDomain = try c.decodeIfPresent(ScoringSelectionDomain.self, forKey: .selectionDomain)
        matchupMode = try c.decodeIfPresent(SeriesMatchupMode.self, forKey: .matchupMode) ?? .field
        podGroupingStrategy = try c.decodeIfPresent(SeriesPodGroupingStrategy.self, forKey: .podGroupingStrategy) ?? .disabled
        teamAssignmentMode = try c.decodeIfPresent(SeriesTeamAssignmentMode.self, forKey: .teamAssignmentMode) ?? .manual
        teeGroupMode = try c.decodeIfPresent(SeriesTeeGroupMode.self, forKey: .teeGroupMode) ?? .auto
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        allowCourseOverride = try c.decodeIfPresent(Bool.self, forKey: .allowCourseOverride) ?? true
        allowFormatOverride = try c.decodeIfPresent(Bool.self, forKey: .allowFormatOverride) ?? true
        allowLobbyBackPropagation = try c.decodeIfPresent(Bool.self, forKey: .allowLobbyBackPropagation) ?? true
        scoreBasisOverride = try c.decodeIfPresent(ScoreBasis.self, forKey: .scoreBasisOverride)
        sharedScoreHandicapConfig = try c.decodeIfPresent(HandicapConfiguration.self, forKey: .sharedScoreHandicapConfig)
        countsTowardHandicapPool = try c.decodeIfPresent(Bool.self, forKey: .countsTowardHandicapPool) ?? true
        excludedHandicapMemberIDs = Self.normalizedMemberIDs(
            try c.decodeIfPresent([String].self, forKey: .excludedHandicapMemberIDs) ?? []
        )

        if let decodedTeamScoring = try c.decodeIfPresent(RoundTeamScoringConfiguration.self, forKey: .teamScoring) {
            teamScoring = decodedTeamScoring
        } else {
            let legacyBestN = try c.decodeIfPresent(Int.self, forKey: .legacyBestNSelected)
            let legacyBestWorst = try c.decodeIfPresent(Bool.self, forKey: .legacyBestWorstEnabled) ?? false
            if let legacyBestN, legacyBestN > 0 {
                teamScoring = .init(
                    mode: legacyBestWorst ? .worstN : .bestN,
                    count: legacyBestN,
                    scope: .perHole
                )
            } else {
                teamScoring = .init()
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(formatTemplateID, forKey: .formatTemplateID)
        try c.encodeIfPresent(competitionScope, forKey: .competitionScope)
        try c.encode(teamScoring, forKey: .teamScoring)
        try c.encode(matchupResolutionStyle, forKey: .matchupResolutionStyle)
        try c.encode(scoreOwnerScope, forKey: .scoreOwnerScope)
        try c.encode(matchupScoringStyle, forKey: .matchupScoringStyle)
        try c.encodeIfPresent(holeWinPoints, forKey: .holeWinPoints)
        try c.encodeIfPresent(matchWinnerBonusPoints, forKey: .matchWinnerBonusPoints)
        try c.encodeIfPresent(matchTiePolicy, forKey: .matchTiePolicy)
        try c.encodeIfPresent(sequentialTeeStartsEnabled, forKey: .sequentialTeeStartsEnabled)
        try c.encodeIfPresent(selectionDomain, forKey: .selectionDomain)
        try c.encode(matchupMode, forKey: .matchupMode)
        try c.encode(podGroupingStrategy, forKey: .podGroupingStrategy)
        try c.encode(teamAssignmentMode, forKey: .teamAssignmentMode)
        try c.encode(teeGroupMode, forKey: .teeGroupMode)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(allowCourseOverride, forKey: .allowCourseOverride)
        try c.encode(allowFormatOverride, forKey: .allowFormatOverride)
        try c.encode(allowLobbyBackPropagation, forKey: .allowLobbyBackPropagation)
        try c.encodeIfPresent(scoreBasisOverride, forKey: .scoreBasisOverride)
        try c.encodeIfPresent(sharedScoreHandicapConfig, forKey: .sharedScoreHandicapConfig)
        try c.encode(countsTowardHandicapPool, forKey: .countsTowardHandicapPool)
        try c.encode(Self.normalizedMemberIDs(excludedHandicapMemberIDs), forKey: .excludedHandicapMemberIDs)
    }

    private static func normalizedMemberIDs(_ memberIDs: [String]) -> [String] {
        Array(Set(memberIDs.filter(\.isPopulated))).sorted()
    }
}

struct SeriesHandicapConfig: Hashable, Codable {
    var mode: SeriesHandicapMode
    var config: HandicapComputationConfigDTO
    var strokeBasis: SeriesHandicapStrokeBasis

    var isEnabled: Bool {
        get { mode.isEnabled }
        set {
            if newValue {
                if mode == .off {
                    mode = .dynamic
                }
            } else {
                mode = .off
            }
        }
    }

    init(
        mode: SeriesHandicapMode = .off,
        config: HandicapComputationConfigDTO = .league2025,
        strokeBasis: SeriesHandicapStrokeBasis? = nil
    ) {
        self.mode = mode
        self.config = config
        self.strokeBasis = strokeBasis ?? SeriesHandicapStrokeBasis.defaultBasis(defaultParForIndex: config.defaultParForIndex)
    }

    init(
        isEnabled: Bool,
        config: HandicapComputationConfigDTO = .league2025,
        strokeBasis: SeriesHandicapStrokeBasis? = nil
    ) {
        self.mode = isEnabled ? .dynamic : .off
        self.config = config
        self.strokeBasis = strokeBasis ?? SeriesHandicapStrokeBasis.defaultBasis(defaultParForIndex: config.defaultParForIndex)
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case isEnabled = "is_enabled"
        case config
        case strokeBasis = "stroke_basis"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMode = try c.decodeIfPresent(SeriesHandicapMode.self, forKey: .mode)
        let decodedEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled)
        mode = decodedMode ?? ((decodedEnabled ?? false) ? .dynamic : .off)
        config = try c.decodeIfPresent(HandicapComputationConfigDTO.self, forKey: .config) ?? .league2025
        strokeBasis = try c.decodeIfPresent(SeriesHandicapStrokeBasis.self, forKey: .strokeBasis)
            ?? SeriesHandicapStrokeBasis.defaultBasis(defaultParForIndex: config.defaultParForIndex)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mode, forKey: .mode)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(config, forKey: .config)
        try c.encode(strokeBasis, forKey: .strokeBasis)
    }
}

struct SeriesSettings: Hashable, Codable {
    var experiencePreset: SeriesExperiencePreset
    var defaultCourse: SeriesCourseSelection?
    var defaultCourseRotationMode: SeriesDefaultCourseRotationMode
    var defaultRoundConfig: SeriesRoundConfiguration
    var defaultTeamScoringProfileID: String?
    var defaultIndividualScoringProfileID: String?
    var handicapConfig: SeriesHandicapConfig
    var allowRoundEditsAfterLobbyCreation: Bool
    var allowManualAwardOverrides: Bool
    var isAttendanceEnabled: Bool
    var attendanceDefault: SeriesRoundAttendanceStatus
    var podGroupingDefault: SeriesPodGroupingStrategy
    var useTeams: Bool
    var useIndividualStandings: Bool
    var useTeamStandings: Bool
    var showScoreboardTile: Bool
    /// Minutes since local midnight for default round tee time (e.g. 990 = 4:30 PM).
    var defaultScheduledTeeTimeMinutesFromMidnight: Int?
    /// `Calendar` weekday integers (1 = Sunday … 7 = Saturday). Empty/nil = no fixed play-day filter.
    var recurringPlayWeekdays: [Int]?

    init(
        experiencePreset: SeriesExperiencePreset = .league,
        defaultCourse: SeriesCourseSelection? = nil,
        defaultCourseRotationMode: SeriesDefaultCourseRotationMode = .fixed,
        defaultRoundConfig: SeriesRoundConfiguration = .init(),
        defaultTeamScoringProfileID: String? = nil,
        defaultIndividualScoringProfileID: String? = nil,
        handicapConfig: SeriesHandicapConfig = .init(),
        allowRoundEditsAfterLobbyCreation: Bool = true,
        allowManualAwardOverrides: Bool = true,
        isAttendanceEnabled: Bool = true,
        attendanceDefault: SeriesRoundAttendanceStatus = .pending,
        podGroupingDefault: SeriesPodGroupingStrategy = .disabled,
        useTeams: Bool = false,
        useIndividualStandings: Bool = true,
        useTeamStandings: Bool = false,
        showScoreboardTile: Bool = false,
        defaultScheduledTeeTimeMinutesFromMidnight: Int? = nil,
        recurringPlayWeekdays: [Int]? = nil
    ) {
        self.experiencePreset = experiencePreset
        self.defaultCourse = defaultCourse
        self.defaultCourseRotationMode = defaultCourseRotationMode
        self.defaultRoundConfig = defaultRoundConfig
        self.defaultTeamScoringProfileID = defaultTeamScoringProfileID
        self.defaultIndividualScoringProfileID = defaultIndividualScoringProfileID
        self.handicapConfig = handicapConfig
        self.allowRoundEditsAfterLobbyCreation = allowRoundEditsAfterLobbyCreation
        self.allowManualAwardOverrides = allowManualAwardOverrides
        self.isAttendanceEnabled = isAttendanceEnabled
        self.attendanceDefault = attendanceDefault
        self.podGroupingDefault = podGroupingDefault
        self.useTeams = useTeams
        self.useIndividualStandings = useIndividualStandings
        self.useTeamStandings = useTeamStandings
        self.showScoreboardTile = showScoreboardTile
        self.defaultScheduledTeeTimeMinutesFromMidnight = defaultScheduledTeeTimeMinutesFromMidnight
        self.recurringPlayWeekdays = recurringPlayWeekdays
    }

    enum CodingKeys: String, CodingKey {
        case experiencePreset = "experience_preset"
        case defaultCourse = "default_course"
        case defaultCourseRotationMode = "default_course_rotation_mode"
        case defaultRoundConfig = "default_round_config"
        case defaultTeamScoringProfileID = "default_team_scoring_profile_id"
        case defaultIndividualScoringProfileID = "default_individual_scoring_profile_id"
        case handicapConfig = "handicap_config"
        case allowRoundEditsAfterLobbyCreation = "allow_round_edits_after_lobby_creation"
        case allowManualAwardOverrides = "allow_manual_award_overrides"
        case isAttendanceEnabled = "is_attendance_enabled"
        case attendanceDefault = "attendance_default"
        case podGroupingDefault = "pod_grouping_default"
        case useTeams = "use_teams"
        case useIndividualStandings = "use_individual_standings"
        case useTeamStandings = "use_team_standings"
        case showScoreboardTile = "show_scoreboard_tile"
        case defaultScheduledTeeTimeMinutesFromMidnight = "default_scheduled_tee_time_minutes_from_midnight"
        case recurringPlayWeekdays = "recurring_play_weekdays"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        experiencePreset = try c.decodeIfPresent(SeriesExperiencePreset.self, forKey: .experiencePreset) ?? .league
        defaultCourse = try c.decodeIfPresent(SeriesCourseSelection.self, forKey: .defaultCourse)
        defaultCourseRotationMode = try c.decodeIfPresent(SeriesDefaultCourseRotationMode.self, forKey: .defaultCourseRotationMode) ?? .fixed
        defaultRoundConfig = try c.decodeIfPresent(SeriesRoundConfiguration.self, forKey: .defaultRoundConfig) ?? .init()
        defaultTeamScoringProfileID = try c.decodeIfPresent(String.self, forKey: .defaultTeamScoringProfileID)
        defaultIndividualScoringProfileID = try c.decodeIfPresent(String.self, forKey: .defaultIndividualScoringProfileID)
        handicapConfig = try c.decodeIfPresent(SeriesHandicapConfig.self, forKey: .handicapConfig) ?? .init()
        allowRoundEditsAfterLobbyCreation = try c.decodeIfPresent(Bool.self, forKey: .allowRoundEditsAfterLobbyCreation) ?? true
        allowManualAwardOverrides = try c.decodeIfPresent(Bool.self, forKey: .allowManualAwardOverrides) ?? true
        isAttendanceEnabled = try c.decodeIfPresent(Bool.self, forKey: .isAttendanceEnabled) ?? true
        attendanceDefault = try c.decodeIfPresent(SeriesRoundAttendanceStatus.self, forKey: .attendanceDefault) ?? .pending
        podGroupingDefault = try c.decodeIfPresent(SeriesPodGroupingStrategy.self, forKey: .podGroupingDefault) ?? .disabled
        useTeams = try c.decodeIfPresent(Bool.self, forKey: .useTeams) ?? false
        useIndividualStandings = try c.decodeIfPresent(Bool.self, forKey: .useIndividualStandings) ?? true
        useTeamStandings = try c.decodeIfPresent(Bool.self, forKey: .useTeamStandings) ?? false
        showScoreboardTile = try c.decodeIfPresent(Bool.self, forKey: .showScoreboardTile) ?? false
        defaultScheduledTeeTimeMinutesFromMidnight = try c.decodeIfPresent(Int.self, forKey: .defaultScheduledTeeTimeMinutesFromMidnight)
        recurringPlayWeekdays = try c.decodeIfPresent([Int].self, forKey: .recurringPlayWeekdays)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(experiencePreset, forKey: .experiencePreset)
        try c.encodeIfPresent(defaultCourse, forKey: .defaultCourse)
        try c.encode(defaultCourseRotationMode, forKey: .defaultCourseRotationMode)
        try c.encode(defaultRoundConfig, forKey: .defaultRoundConfig)
        try c.encodeIfPresent(defaultTeamScoringProfileID, forKey: .defaultTeamScoringProfileID)
        try c.encodeIfPresent(defaultIndividualScoringProfileID, forKey: .defaultIndividualScoringProfileID)
        try c.encode(handicapConfig, forKey: .handicapConfig)
        try c.encode(allowRoundEditsAfterLobbyCreation, forKey: .allowRoundEditsAfterLobbyCreation)
        try c.encode(allowManualAwardOverrides, forKey: .allowManualAwardOverrides)
        try c.encode(isAttendanceEnabled, forKey: .isAttendanceEnabled)
        try c.encode(attendanceDefault, forKey: .attendanceDefault)
        try c.encode(podGroupingDefault, forKey: .podGroupingDefault)
        try c.encode(useTeams, forKey: .useTeams)
        try c.encode(useIndividualStandings, forKey: .useIndividualStandings)
        try c.encode(useTeamStandings, forKey: .useTeamStandings)
        try c.encode(showScoreboardTile, forKey: .showScoreboardTile)
        try c.encodeIfPresent(defaultScheduledTeeTimeMinutesFromMidnight, forKey: .defaultScheduledTeeTimeMinutesFromMidnight)
        try c.encodeIfPresent(recurringPlayWeekdays, forKey: .recurringPlayWeekdays)
    }

    static func seeded(for preset: SeriesExperiencePreset) -> SeriesSettings {
        var settings = SeriesSettings(experiencePreset: preset)
        switch preset {
        case .league:
            break
        case .trip:
            settings.defaultRoundConfig.countsTowardHandicapPool = false
            settings.showScoreboardTile = true
        case .tournament:
            break
        }
        return settings
    }

    var presentationLabel: String {
        experiencePreset.displayName
    }

    /// Default 4:30 PM when league has not set a time.
    static let fallbackDefaultTeeMinutesFromMidnight = 16 * 60 + 30

    func resolvedDefaultTeeMinutesFromMidnight() -> Int {
        defaultScheduledTeeTimeMinutesFromMidnight ?? Self.fallbackDefaultTeeMinutesFromMidnight
    }

    func resolvedPlayWeekdaySet() -> Set<Int> {
        Set(recurringPlayWeekdays ?? [])
    }
}

enum SeriesScheduleDefaultDatePicker {
    static func nextPresetDate(for settings: SeriesSettings, from now: Date = Date(), calendar: Calendar = .current) -> Date {
        let minutes = settings.resolvedDefaultTeeMinutesFromMidnight()
        let hour = minutes / 60
        let minute = minutes % 60
        let weekdays = settings.resolvedPlayWeekdaySet()

        func atPresetTime(on dayStart: Date) -> Date {
            var c = calendar.dateComponents([.year, .month, .day], from: dayStart)
            c.hour = hour
            c.minute = minute
            c.second = 0
            return calendar.date(from: c) ?? dayStart
        }

        if weekdays.isEmpty {
            let start = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return atPresetTime(on: tomorrow)
        }

        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            let wd = calendar.component(.weekday, from: day)
            guard weekdays.contains(wd) else { continue }
            let candidate = atPresetTime(on: day)
            if candidate > now { return candidate }
        }

        guard let fallbackDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return now }
        return atPresetTime(on: fallbackDay)
    }
}

// MARK: - Root series document

struct Series: FirebaseIdentifiable {
    var id: String
    var name: String
    var description: String?
    /// Short join code (same namespace as round `share_code`; unique across rounds and series).
    var shareCode: String
    var commissionerUserID: String
    var commissionerPlayerID: String?
    var memberPlayerIDs: [String]
    var status: SeriesStatus
    var visibility: SeriesVisibility
    var settings: SeriesSettings
    var createdAt: Time
    var lastUpdatedAt: Time
    var startsAt: Time?
    var endsAt: Time?
    var roundCount: Int
    var completedRoundCount: Int
    var activeAnnouncementCount: Int
    var leagueRulesConfirmedAt: Time?
    var leagueRulesConfirmedByUserID: String?
    var leagueRulesSignature: String?
    var collection: String { Collections.series.rawValue }
    var schema: Int = 1

    init(
        id: String = "",
        name: String = "",
        description: String? = nil,
        shareCode: String = "",
        commissionerUserID: String = "",
        commissionerPlayerID: String? = nil,
        memberPlayerIDs: [String] = [],
        status: SeriesStatus = .draft,
        visibility: SeriesVisibility = .privateSeries,
        settings: SeriesSettings = .init(),
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        startsAt: Time? = nil,
        endsAt: Time? = nil,
        roundCount: Int = 0,
        completedRoundCount: Int = 0,
        activeAnnouncementCount: Int = 0,
        leagueRulesConfirmedAt: Time? = nil,
        leagueRulesConfirmedByUserID: String? = nil,
        leagueRulesSignature: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.shareCode = shareCode
        self.commissionerUserID = commissionerUserID
        self.commissionerPlayerID = commissionerPlayerID
        self.memberPlayerIDs = memberPlayerIDs
        self.status = status
        self.visibility = visibility
        self.settings = settings
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.roundCount = roundCount
        self.completedRoundCount = completedRoundCount
        self.activeAnnouncementCount = activeAnnouncementCount
        self.leagueRulesConfirmedAt = leagueRulesConfirmedAt
        self.leagueRulesConfirmedByUserID = leagueRulesConfirmedByUserID
        self.leagueRulesSignature = leagueRulesSignature
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, status, visibility, settings, schema
        case shareCode = "share_code"
        case commissionerUserID = "commissioner_user_id"
        case commissionerPlayerID = "commissioner_player_id"
        case memberPlayerIDs = "member_player_ids"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case roundCount = "round_count"
        case completedRoundCount = "completed_round_count"
        case activeAnnouncementCount = "active_announcement_count"
        case leagueRulesConfirmedAt = "league_rules_confirmed_at"
        case leagueRulesConfirmedByUserID = "league_rules_confirmed_by_user_id"
        case leagueRulesSignature = "league_rules_signature"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        shareCode = try c.decodeIfPresent(String.self, forKey: .shareCode) ?? ""
        commissionerUserID = try c.decode(String.self, forKey: .commissionerUserID)
        commissionerPlayerID = try c.decodeIfPresent(String.self, forKey: .commissionerPlayerID)
        memberPlayerIDs = try c.decodeIfPresent([String].self, forKey: .memberPlayerIDs) ?? []
        status = try c.decode(SeriesStatus.self, forKey: .status)
        visibility = try c.decode(SeriesVisibility.self, forKey: .visibility)
        settings = try c.decode(SeriesSettings.self, forKey: .settings)
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        createdAt = try c.decode(Time.self, forKey: .createdAt)
        lastUpdatedAt = try c.decode(Time.self, forKey: .lastUpdatedAt)
        startsAt = try c.decodeIfPresent(Time.self, forKey: .startsAt)
        endsAt = try c.decodeIfPresent(Time.self, forKey: .endsAt)
        roundCount = try c.decodeIfPresent(Int.self, forKey: .roundCount) ?? 0
        completedRoundCount = try c.decodeIfPresent(Int.self, forKey: .completedRoundCount) ?? 0
        activeAnnouncementCount = try c.decodeIfPresent(Int.self, forKey: .activeAnnouncementCount) ?? 0
        leagueRulesConfirmedAt = try c.decodeIfPresent(Time.self, forKey: .leagueRulesConfirmedAt)
        leagueRulesConfirmedByUserID = try c.decodeIfPresent(String.self, forKey: .leagueRulesConfirmedByUserID)
        leagueRulesSignature = try c.decodeIfPresent(String.self, forKey: .leagueRulesSignature)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(shareCode, forKey: .shareCode)
        try c.encode(commissionerUserID, forKey: .commissionerUserID)
        try c.encodeIfPresent(commissionerPlayerID, forKey: .commissionerPlayerID)
        try c.encode(memberPlayerIDs, forKey: .memberPlayerIDs)
        try c.encode(status, forKey: .status)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(settings, forKey: .settings)
        try c.encode(schema, forKey: .schema)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try c.encodeIfPresent(startsAt, forKey: .startsAt)
        try c.encodeIfPresent(endsAt, forKey: .endsAt)
        try c.encode(roundCount, forKey: .roundCount)
        try c.encode(completedRoundCount, forKey: .completedRoundCount)
        try c.encode(activeAnnouncementCount, forKey: .activeAnnouncementCount)
        try c.encodeIfPresent(leagueRulesConfirmedAt, forKey: .leagueRulesConfirmedAt)
        try c.encodeIfPresent(leagueRulesConfirmedByUserID, forKey: .leagueRulesConfirmedByUserID)
        try c.encodeIfPresent(leagueRulesSignature, forKey: .leagueRulesSignature)
    }
}

extension Series {
    var experiencePreset: SeriesExperiencePreset {
        get { settings.experiencePreset }
        set { settings.experiencePreset = newValue }
    }

    var handicapConfig: SeriesHandicapConfig {
        get { settings.handicapConfig }
        set { settings.handicapConfig = newValue }
    }

    var defaultCourse: SeriesCourseSelection? {
        get { settings.defaultCourse }
        set { settings.defaultCourse = newValue }
    }

    var useTeams: Bool {
        get { settings.useTeams }
        set { settings.useTeams = newValue }
    }
}

// MARK: - Members

struct SeriesMember: FirebaseSubcollectable {
    var id: String
    var userID: String?
    var playerID: String?
    var name: Name
    var role: SeriesMemberRole
    var teamID: String?
    var defaultTeeBoxID: String?
    var isActive: Bool
    var joinedAt: Time
    var leftAt: Time?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.members.rawValue }

    init(
        id: String = "",
        userID: String? = nil,
        playerID: String? = nil,
        name: Name = .init(),
        role: SeriesMemberRole = .member,
        teamID: String? = nil,
        defaultTeeBoxID: String? = nil,
        isActive: Bool = true,
        joinedAt: Time = .init(),
        leftAt: Time? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.userID = userID
        self.playerID = playerID
        self.name = name
        self.role = role
        self.teamID = teamID
        self.defaultTeeBoxID = defaultTeeBoxID
        self.isActive = isActive
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, role, schema
        case userID = "user_id"
        case playerID = "player_id"
        case teamID = "team_id"
        case defaultTeeBoxID = "default_tee_box_id"
        case isActive = "is_active"
        case joinedAt = "joined_at"
        case leftAt = "left_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesInvite: FirebaseSubcollectable {
    var id: String
    var seriesID: String
    var invitedUserID: String?
    var invitedPlayerID: String?
    var invitedName: String
    var status: SeriesInviteStatus
    var invitedByMemberID: String
    var invitedAt: Time
    var respondedAt: Time?
    var resolvedMemberID: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.invites.rawValue }

    init(
        id: String = "",
        seriesID: String = "",
        invitedUserID: String? = nil,
        invitedPlayerID: String? = nil,
        invitedName: String = "",
        status: SeriesInviteStatus = .pending,
        invitedByMemberID: String = "",
        invitedAt: Time = .init(),
        respondedAt: Time? = nil,
        resolvedMemberID: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.seriesID = seriesID
        self.invitedUserID = invitedUserID
        self.invitedPlayerID = invitedPlayerID
        self.invitedName = invitedName
        self.status = status
        self.invitedByMemberID = invitedByMemberID
        self.invitedAt = invitedAt
        self.respondedAt = respondedAt
        self.resolvedMemberID = resolvedMemberID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, status, schema
        case seriesID = "series_id"
        case invitedUserID = "invited_user_id"
        case invitedPlayerID = "invited_player_id"
        case invitedName = "invited_name"
        case invitedByMemberID = "invited_by_member_id"
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
        case resolvedMemberID = "resolved_member_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Teams + Pods

struct SeriesTeam: FirebaseSubcollectable, IndexIterable {
    var id: String
    var name: String
    var color: String
    /// When set (e.g. `#RRGGBB`), overrides `color` for display and is copied to round teams as the `color` token.
    var customColorHex: String?
    var index: Int
    var isLocked: Bool
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.teams.rawValue }

    init(
        id: String = "",
        name: String = "",
        color: String = "",
        customColorHex: String? = nil,
        index: Int = 0,
        isLocked: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.customColorHex = customColorHex
        self.index = index
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, index, schema
        case customColorHex = "custom_color_hex"
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

extension SeriesTeam {
    /// Accent when present; `nil` for none, empty color, unknown, or when only custom hex is invalid.
    var displaySwatchColor: Color? {
        if let hex = customColorHex?.trimmingCharacters(in: .whitespacesAndNewlines),
           hex.hasPrefix("#") {
            return ColorValue(hex: hex).color
        }
        let c = color.trimmingCharacters(in: .whitespacesAndNewlines)
        guard c.isPopulated else { return nil }
        let tc = TeamColor(rawValue: c) ?? .unknown
        switch tc {
        case .none, .unknown:
            return nil
        case .red, .blue, .green, .purple, .orange:
            return tc.value
        }
    }

    /// Value written to `RoundTeam.color` when creating a live round.
    var roundColorToken: String {
        if let hex = customColorHex?.trimmingCharacters(in: .whitespacesAndNewlines),
           hex.hasPrefix("#") {
            return hex
        }
        if color.isPopulated { return color }
        return TeamColor.teamValue(for: index).0.rawValue
    }
}

struct SeriesTeamPod: FirebaseSubcollectable, IndexIterable {
    var id: String
    var teamID: String
    var label: String
    var index: Int
    var memberIDs: [String]
    var isActive: Bool
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.pods.rawValue }

    init(
        id: String = "",
        teamID: String = "",
        label: String = "",
        index: Int = 0,
        memberIDs: [String] = [],
        isActive: Bool = true,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.teamID = teamID
        self.label = label
        self.index = index
        self.memberIDs = memberIDs
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, label, index, schema
        case teamID = "team_id"
        case memberIDs = "member_ids"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }

    var isSchedulable: Bool { isActive && memberIDs.count == 2 }
    var resolvedLabel: String {
        if label.isPopulated { return label }
        let scalars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard index >= 0, index < scalars.count else { return "Pod \(index + 1)" }
        return String(scalars[index])
    }
}

// MARK: - Rounds

struct SeriesRoundMatchupPlan: Hashable, Codable, Identifiable {
    var id: String
    var teamAID: String
    var teamBID: String
    var memberAID: String?
    var memberBID: String?
    var pairAID: String?
    var pairBID: String?
    var index: Int
    var podGroupingStrategy: SeriesPodGroupingStrategy
    var notes: String?
    var isLocked: Bool
    var createdAt: Time
    var lastUpdatedAt: Time

    init(
        id: String = "",
        teamAID: String = "",
        teamBID: String = "",
        memberAID: String? = nil,
        memberBID: String? = nil,
        pairAID: String? = nil,
        pairBID: String? = nil,
        index: Int = 0,
        podGroupingStrategy: SeriesPodGroupingStrategy = .disabled,
        notes: String? = nil,
        isLocked: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.teamAID = teamAID
        self.teamBID = teamBID
        self.memberAID = memberAID
        self.memberBID = memberBID
        self.pairAID = pairAID
        self.pairBID = pairBID
        self.index = index
        self.podGroupingStrategy = podGroupingStrategy
        self.notes = notes
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, index, notes
        case teamAID = "team_a_id"
        case teamBID = "team_b_id"
        case memberAID = "member_a_id"
        case memberBID = "member_b_id"
        case pairAID = "pair_a_id"
        case pairBID = "pair_b_id"
        case podGroupingStrategy = "pod_grouping_strategy"
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }

    var validTeamPairing: Bool { teamAID.isPopulated && teamBID.isPopulated && teamAID != teamBID }
    var validMemberPairing: Bool {
        guard let memberAID, let memberBID else { return false }
        return memberAID.isPopulated && memberBID.isPopulated && memberAID != memberBID
    }
    var validPairPairing: Bool {
        guard let pairAID, let pairBID else { return false }
        return pairAID.isPopulated && pairBID.isPopulated && pairAID != pairBID
    }
    var isValid: Bool { validTeamPairing || validMemberPairing || validPairPairing }
}

enum SeriesRoundPlanSource: String, CaseIterable, Codable {
    case autoGenerated = "auto_generated"
    case manualOverride = "manual_override"
}

struct SeriesRoundPlannedMatchup: Hashable, Codable, Identifiable {
    var id: String
    var plan: SeriesRoundMatchupPlan
    var source: SeriesRoundPlanSource

    init(
        id: String? = nil,
        plan: SeriesRoundMatchupPlan = .init(),
        source: SeriesRoundPlanSource = .autoGenerated
    ) {
        self.id = id ?? plan.id
        self.plan = plan
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id, plan, source
    }

    var matchupPlan: SeriesRoundMatchupPlan {
        var updated = plan
        updated.id = id
        return updated
    }
}

struct SeriesRoundPlannedSeat: Hashable, Codable, Identifiable {
    var id: String
    var memberID: String
    var teeOrder: Int
    var source: SeriesRoundPlanSource

    init(
        id: String = "",
        memberID: String = "",
        teeOrder: Int = 0,
        source: SeriesRoundPlanSource = .autoGenerated
    ) {
        self.id = id.isPopulated ? id : memberID
        self.memberID = memberID
        self.teeOrder = teeOrder
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id
        case memberID = "member_id"
        case teeOrder = "tee_order"
        case source
    }
}

struct SeriesRoundPlannedTeeGroup: Hashable, Codable, Identifiable {
    var id: String
    var index: Int
    var teeTime: String?
    var startingHole: Int
    var seats: [SeriesRoundPlannedSeat]
    var source: SeriesRoundPlanSource

    init(
        id: String = "",
        index: Int = 0,
        teeTime: String? = nil,
        startingHole: Int = 1,
        seats: [SeriesRoundPlannedSeat] = [],
        source: SeriesRoundPlanSource = .autoGenerated
    ) {
        self.id = id
        self.index = index
        self.teeTime = teeTime
        self.startingHole = startingHole
        self.seats = seats.sorted { lhs, rhs in
            if lhs.teeOrder != rhs.teeOrder { return lhs.teeOrder < rhs.teeOrder }
            return lhs.memberID < rhs.memberID
        }
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id, index, seats, source
        case teeTime = "tee_time"
        case startingHole = "starting_hole"
    }

    var memberIDs: [String] {
        seats.map(\.memberID)
    }

    var hasManualOverrides: Bool {
        source == .manualOverride || seats.contains(where: { $0.source == .manualOverride })
    }

    /// Renumbers `teeOrder` to 1…n following **current** `seats` array order (tee sheet editor swaps).
    func renumberedPreservingSeatOrder() -> SeriesRoundPlannedTeeGroup {
        var g = self
        g.seats = g.seats.enumerated().map { offset, seat in
            var s = seat
            s.teeOrder = offset + 1
            return s
        }
        return g
    }
}

struct SeriesRoundPlannedStructure: Hashable {
    var matchups: [SeriesRoundPlannedMatchup]
    var teeGroups: [SeriesRoundPlannedTeeGroup]

    init(
        matchups: [SeriesRoundPlannedMatchup] = [],
        teeGroups: [SeriesRoundPlannedTeeGroup] = []
    ) {
        self.matchups = matchups
        self.teeGroups = teeGroups
    }

    var hasManualOverrides: Bool {
        matchups.contains(where: { $0.source == .manualOverride })
            || teeGroups.contains(where: \.hasManualOverrides)
    }
}

struct SeriesRoundPartnershipPlan: Hashable, Codable, Identifiable {
    var id: String
    var teamID: String
    var memberIDs: [String]
    var label: String?
    var seedSeriesPodID: String?
    var createdAt: Time
    var lastUpdatedAt: Time

    init(
        id: String = "",
        teamID: String = "",
        memberIDs: [String] = [],
        label: String? = nil,
        seedSeriesPodID: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.teamID = teamID
        self.memberIDs = Self.normalizedMemberIDs(memberIDs)
        self.label = label
        self.seedSeriesPodID = seedSeriesPodID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, label
        case teamID = "team_id"
        case memberIDs = "member_ids"
        case seedSeriesPodID = "seed_series_pod_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }

    var isValid: Bool {
        teamID.isPopulated && memberIDs.count == 2
    }

    private static func normalizedMemberIDs(_ memberIDs: [String]) -> [String] {
        Array(Set(memberIDs.filter(\.isPopulated))).sorted()
    }
}

enum SeriesTeeGroupMirrorStatus: String, Equatable {
    case ready
    case needsTwoOpposingPairs
    case sameTeamOnly
    case tooManyPairs

    var label: String {
        switch self {
        case .ready: return "Matchup ready"
        case .needsTwoOpposingPairs: return "Needs two opposing pairs"
        case .sameTeamOnly: return "Same team only"
        case .tooManyPairs: return "Too many pairs"
        }
    }
}

struct SeriesTeeGroupMirrorPair: Hashable {
    var id: String
    var teamID: String
    var memberIDs: [String]
}

enum SeriesTeeGroupMirrorAnalyzer {
    static func pairs(
        for group: SeriesRoundPlannedTeeGroup,
        partnershipPlans: [SeriesRoundPartnershipPlan],
        membersByID: [String: SeriesMember]
    ) -> [SeriesTeeGroupMirrorPair] {
        let groupMemberIDs = Set(group.memberIDs)
        let storedPairs = partnershipPlans.compactMap { plan -> SeriesTeeGroupMirrorPair? in
            guard plan.isValid, Set(plan.memberIDs).isSubset(of: groupMemberIDs) else { return nil }
            return SeriesTeeGroupMirrorPair(id: plan.id, teamID: plan.teamID, memberIDs: plan.memberIDs)
        }
        if storedPairs.isPopulated { return storedPairs }

        let orderedSeats = group.seats.sorted { $0.teeOrder < $1.teeOrder }
        guard orderedSeats.count == 4 else { return [] }
        let candidatePairs = [
            Array(orderedSeats[0...1]).map(\.memberID),
            Array(orderedSeats[2...3]).map(\.memberID)
        ]
        return candidatePairs.enumerated().compactMap { index, memberIDs -> SeriesTeeGroupMirrorPair? in
            let teamIDs = Set(memberIDs.compactMap { membersByID[$0]?.teamID }.filter(\.isPopulated))
            guard teamIDs.count == 1, let teamID = teamIDs.first else { return nil }
            return SeriesTeeGroupMirrorPair(
                id: "derived_pair_\(group.id)_\(index)",
                teamID: teamID,
                memberIDs: memberIDs
            )
        }
    }

    static func status(
        for group: SeriesRoundPlannedTeeGroup,
        partnershipPlans: [SeriesRoundPartnershipPlan],
        membersByID: [String: SeriesMember]
    ) -> SeriesTeeGroupMirrorStatus {
        let pairs = pairs(for: group, partnershipPlans: partnershipPlans, membersByID: membersByID)
        if pairs.count > 2 { return .tooManyPairs }
        guard pairs.count == 2 else { return .needsTwoOpposingPairs }
        let teamIDs = Set(pairs.map(\.teamID).filter(\.isPopulated))
        if teamIDs.count == 2 { return .ready }
        if teamIDs.count == 1 { return .sameTeamOnly }
        return .needsTwoOpposingPairs
    }
}

struct SeriesRoundPointsConfidenceSummary: Equatable {
    var example: String
}

enum SeriesRoundPointsConfidenceBuilder {
    static func summary(
        roundConfig: SeriesRoundConfiguration,
        teamProfile: SeriesScoringProfile?,
        individualProfile: SeriesScoringProfile?,
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup],
        partnershipPlans: [SeriesRoundPartnershipPlan],
        members: [SeriesMember],
        teams: [SeriesTeam],
        courseSelection: SeriesCourseSelection?
    ) -> SeriesRoundPointsConfidenceSummary {
        let membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        let teamsByID = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let readyGroups = plannedTeeGroups.sorted { $0.index < $1.index }.filter {
            SeriesTeeGroupMirrorAnalyzer.status(
                for: $0,
                partnershipPlans: partnershipPlans,
                membersByID: membersByID
            ) == .ready
        }
        return SeriesRoundPointsConfidenceSummary(
            example: example(
                roundConfig: roundConfig,
                teamProfile: teamProfile,
                individualProfile: individualProfile,
                readyGroups: readyGroups,
                partnershipPlans: partnershipPlans,
                membersByID: membersByID,
                teamsByID: teamsByID,
                allMembers: members,
                allTeams: teams,
                courseSelection: courseSelection
            )
        )
    }

    private static func example(
        roundConfig: SeriesRoundConfiguration,
        teamProfile: SeriesScoringProfile?,
        individualProfile: SeriesScoringProfile?,
        readyGroups: [SeriesRoundPlannedTeeGroup],
        partnershipPlans: [SeriesRoundPartnershipPlan],
        membersByID: [String: SeriesMember],
        teamsByID: [String: SeriesTeam],
        allMembers: [SeriesMember],
        allTeams: [SeriesTeam],
        courseSelection: SeriesCourseSelection?
    ) -> String {
        if roundConfig.matchupMode == .teeGroupPartnerships {
            return pairMatchupExample(
                roundConfig: roundConfig,
                teamProfile: teamProfile,
                individualProfile: individualProfile,
                readyGroups: readyGroups,
                partnershipPlans: partnershipPlans,
                membersByID: membersByID,
                teamsByID: teamsByID,
                courseSelection: courseSelection
            )
        }
        return generalExample(
            roundConfig: roundConfig,
            teamProfile: teamProfile,
            individualProfile: individualProfile,
            members: allMembers,
            teams: allTeams
        )
    }

    private static func pairMatchupExample(
        roundConfig: SeriesRoundConfiguration,
        teamProfile: SeriesScoringProfile?,
        individualProfile: SeriesScoringProfile?,
        readyGroups: [SeriesRoundPlannedTeeGroup],
        partnershipPlans: [SeriesRoundPartnershipPlan],
        membersByID: [String: SeriesMember],
        teamsByID: [String: SeriesTeam],
        courseSelection: SeriesCourseSelection?
    ) -> String {
        var fragments: [String] = []

        if let group = readyGroups.first {
            let pairs = SeriesTeeGroupMirrorAnalyzer.pairs(
                for: group,
                partnershipPlans: partnershipPlans,
                membersByID: membersByID
            )
            if pairs.count == 2 {
                let leftPair = pairName(pairs[0], membersByID: membersByID)
                let rightPair = pairName(pairs[1], membersByID: membersByID)
                let leftTeam = teamsByID[pairs[0].teamID]?.name ?? "Team A"
                let rightTeam = teamsByID[pairs[1].teamID]?.name ?? "Team B"

                if let teamProfile {
                    fragments.append(
                        teamExampleText(
                            profile: teamProfile,
                            winnerName: leftTeam,
                            loserName: rightTeam,
                            winningScoreText: "\(leftPair) beat \(rightPair)",
                            roundConfig: roundConfig,
                            courseSelection: courseSelection
                        )
                    )
                }

                if let individualProfile {
                    fragments.append(
                        individualProfile.kind == .accrueFromIndividual
                            ? ""
                            : "\(leftPair) and \(rightPair) still use the selected individual awards for player standings."
                    )
                }
            }
        }

        if fragments.isEmpty {
            if teamProfile == nil, individualProfile == nil {
                return "No team or individual series points will be awarded until a scoring profile is selected."
            }
            if teamProfile == nil {
                return "Set a team scoring profile to award pair-vs-pair tee sheet results."
            }
            return "Set two same-team pairs in a tee group to preview the scoring example."
        }

        return fragments.filter(\.isPopulated).joined(separator: " ")
    }

    private static func generalExample(
        roundConfig: SeriesRoundConfiguration,
        teamProfile: SeriesScoringProfile?,
        individualProfile: SeriesScoringProfile?,
        members: [SeriesMember],
        teams: [SeriesTeam]
    ) -> String {
        var fragments: [String] = []

        if let teamProfile {
            let orderedTeams = teams.sorted { $0.index < $1.index }
            let winner = orderedTeams.first?.name ?? "Team A"
            let runnerUp = orderedTeams.dropFirst().first?.name ?? "Team B"
            fragments.append(
                teamExampleText(
                    profile: teamProfile,
                    winnerName: winner,
                    loserName: runnerUp,
                    winningScoreText: "\(winner) finish ahead of \(runnerUp)",
                    roundConfig: roundConfig,
                    courseSelection: nil
                )
            )
        }

        if let individualProfile {
            let orderedMembers = members.sorted {
                $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
            }
            let first = orderedMembers.first?.name.fullName ?? "Player A"
            let second = orderedMembers.dropFirst().first?.name.fullName ?? "Player B"
            fragments.append(individualExampleText(profile: individualProfile, winnerName: first, loserName: second))
        }

        if fragments.isEmpty {
            return "No team or individual series points will be awarded until a scoring profile is selected."
        }
        return fragments.joined(separator: " ")
    }

    private static func teamExampleText(
        profile: SeriesScoringProfile,
        winnerName: String,
        loserName: String,
        winningScoreText: String,
        roundConfig: SeriesRoundConfiguration,
        courseSelection: SeriesCourseSelection?
    ) -> String {
        switch profile.kind {
        case .placement:
            let rules = profile.placementRules.sorted { $0.rankStart < $1.rankStart }
            guard let firstRule = rules.first else {
                return "\(winnerName) earn team points from leaderboard finish once the placement spread is configured."
            }
            if let secondRule = rules.dropFirst().first {
                return "If \(winnerName) finish 1st and \(loserName) finish 2nd, teams earn \(numberText(firstRule.points)) and \(numberText(secondRule.points)) points."
            }
            return "If \(winnerName) win the round, they earn \(numberText(firstRule.points)) team points."
        case .winTieLoss:
            let points = profile.resultPoints ?? .init()
            if roundConfig.matchupScoringStyle == .holeByHolePoints {
                let holeCount = courseSelection?.holeSegment.holeCount ?? 18
                let winnerTotal = Double(holeCount) * roundConfig.resolvedHoleWinPoints + roundConfig.resolvedMatchWinnerBonusPoints
                return "If \(winningScoreText), \(winnerName) can bank up to \(numberText(winnerTotal)) team points from hole wins and winner bonus."
            }
            return "If \(winningScoreText), \(winnerName) earn \(numberText(points.winPoints)) team points and \(loserName) earn \(numberText(points.lossPoints))."
        case .accrueFromIndividual:
            if roundConfig.matchupScoringStyle == .holeByHolePoints {
                return "Each team's total is the sum of its players' hole points and any match winner bonus from this round."
            }
            return "Team standings add up the individual points awarded to each player on the roster this round."
        case .manual:
            return "Team points are assigned manually after the round is complete."
        }
    }

    private static func individualExampleText(
        profile: SeriesScoringProfile,
        winnerName: String,
        loserName: String
    ) -> String {
        switch profile.kind {
        case .placement:
            let rules = profile.placementRules.sorted { $0.rankStart < $1.rankStart }
            guard let firstRule = rules.first else {
                return "\(winnerName) earn individual points from leaderboard finish once the placement spread is configured."
            }
            if let secondRule = rules.dropFirst().first {
                return "If \(winnerName) finishes 1st and \(loserName) finishes 2nd, players earn \(numberText(firstRule.points)) and \(numberText(secondRule.points)) points."
            }
            return "If \(winnerName) wins the round, they earn \(numberText(firstRule.points)) individual points."
        case .winTieLoss:
            let points = profile.resultPoints ?? .init()
            return "If \(winnerName) beats \(loserName), they earn \(numberText(points.winPoints)) individual points while \(loserName) earn \(numberText(points.lossPoints))."
        case .accrueFromIndividual:
            return "Individual points feed directly into the selected team scoring model."
        case .manual:
            return "Individual points are assigned manually after the round is complete."
        }
    }

    private static func pairName(
        _ pair: SeriesTeeGroupMirrorPair,
        membersByID: [String: SeriesMember]
    ) -> String {
        let names = pair.memberIDs.compactMap { membersByID[$0]?.name.givenName }.filter(\.isPopulated)
        if names.count == 2 { return names.joined(separator: " + ") }
        return pair.memberIDs.compactMap { membersByID[$0]?.name.fullName }.joined(separator: " + ")
    }

    private static func numberText(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        if formatted.hasSuffix("00") {
            return String(formatted.dropLast(3))
        }
        if formatted.hasSuffix("0") {
            return String(formatted.dropLast(1))
        }
        return formatted
    }
}

struct SeriesRound: FirebaseSubcollectable, IndexIterable {
    var id: String
    var title: String
    var index: Int
    var status: SeriesRoundStatus
    var scheduledAt: Time?
    var roundID: String?
    var startedAt: Time?
    var completedAt: Time?
    var courseOverride: SeriesCourseSelection?
    var roundConfig: SeriesRoundConfiguration
    var teamScoringProfileID: String?
    var individualScoringProfileID: String?
    var matchupPlans: [SeriesRoundMatchupPlan]
    var plannedMatchups: [SeriesRoundPlannedMatchup]
    var plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    var partnershipPlans: [SeriesRoundPartnershipPlan]
    var notes: String?
    var awardsStatus: SeriesAwardsStatus
    var awardsFinalizedAt: Time?
    var lastScoreAdjustmentAt: Time?
    var lastScoreAdjustmentByMemberID: String?
    var lastScoreAdjustmentReason: String?
    var scoreAdjustmentCount: Int
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.rounds.rawValue }

    init(
        id: String = "",
        title: String = "",
        index: Int = 0,
        status: SeriesRoundStatus = .planned,
        scheduledAt: Time? = nil,
        roundID: String? = nil,
        startedAt: Time? = nil,
        completedAt: Time? = nil,
        courseOverride: SeriesCourseSelection? = nil,
        roundConfig: SeriesRoundConfiguration = .init(),
        teamScoringProfileID: String? = nil,
        individualScoringProfileID: String? = nil,
        matchupPlans: [SeriesRoundMatchupPlan] = [],
        plannedMatchups: [SeriesRoundPlannedMatchup] = [],
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup] = [],
        partnershipPlans: [SeriesRoundPartnershipPlan] = [],
        notes: String? = nil,
        awardsStatus: SeriesAwardsStatus = .pending,
        awardsFinalizedAt: Time? = nil,
        lastScoreAdjustmentAt: Time? = nil,
        lastScoreAdjustmentByMemberID: String? = nil,
        lastScoreAdjustmentReason: String? = nil,
        scoreAdjustmentCount: Int = 0,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.title = title
        self.index = index
        self.status = status
        self.scheduledAt = scheduledAt
        self.roundID = roundID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.courseOverride = courseOverride
        self.roundConfig = roundConfig
        self.teamScoringProfileID = teamScoringProfileID
        self.individualScoringProfileID = individualScoringProfileID
        self.matchupPlans = matchupPlans
        self.plannedMatchups = plannedMatchups
        self.plannedTeeGroups = plannedTeeGroups
        self.partnershipPlans = partnershipPlans
        self.notes = notes
        self.awardsStatus = awardsStatus
        self.awardsFinalizedAt = awardsFinalizedAt
        self.lastScoreAdjustmentAt = lastScoreAdjustmentAt
        self.lastScoreAdjustmentByMemberID = lastScoreAdjustmentByMemberID
        self.lastScoreAdjustmentReason = lastScoreAdjustmentReason
        self.scoreAdjustmentCount = scoreAdjustmentCount
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, title, index, status, notes, schema
        case scheduledAt = "scheduled_at"
        case roundID = "round_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case courseOverride = "course_override"
        case roundConfig = "round_config"
        case teamScoringProfileID = "team_scoring_profile_id"
        case individualScoringProfileID = "individual_scoring_profile_id"
        case matchupPlans = "matchup_plans"
        case plannedMatchups = "planned_matchups"
        case plannedTeeGroups = "planned_tee_groups"
        case partnershipPlans = "partnership_plans"
        case awardsStatus = "awards_status"
        case awardsFinalizedAt = "awards_finalized_at"
        case lastScoreAdjustmentAt = "last_score_adjustment_at"
        case lastScoreAdjustmentByMemberID = "last_score_adjustment_by_member_id"
        case lastScoreAdjustmentReason = "last_score_adjustment_reason"
        case scoreAdjustmentCount = "score_adjustment_count"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        index = try c.decode(Int.self, forKey: .index)
        status = try c.decodeIfPresent(SeriesRoundStatus.self, forKey: .status) ?? .planned
        scheduledAt = try c.decodeIfPresent(Time.self, forKey: .scheduledAt)
        roundID = try c.decodeIfPresent(String.self, forKey: .roundID)
        startedAt = try c.decodeIfPresent(Time.self, forKey: .startedAt)
        completedAt = try c.decodeIfPresent(Time.self, forKey: .completedAt)
        courseOverride = try c.decodeIfPresent(SeriesCourseSelection.self, forKey: .courseOverride)
        roundConfig = try c.decodeIfPresent(SeriesRoundConfiguration.self, forKey: .roundConfig) ?? .init()
        teamScoringProfileID = try c.decodeIfPresent(String.self, forKey: .teamScoringProfileID)
        individualScoringProfileID = try c.decodeIfPresent(String.self, forKey: .individualScoringProfileID)
        matchupPlans = try c.decodeIfPresent([SeriesRoundMatchupPlan].self, forKey: .matchupPlans) ?? []
        plannedMatchups = try c.decodeIfPresent([SeriesRoundPlannedMatchup].self, forKey: .plannedMatchups) ?? []
        plannedTeeGroups = try c.decodeIfPresent([SeriesRoundPlannedTeeGroup].self, forKey: .plannedTeeGroups) ?? []
        partnershipPlans = try c.decodeIfPresent([SeriesRoundPartnershipPlan].self, forKey: .partnershipPlans) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        awardsStatus = try c.decodeIfPresent(SeriesAwardsStatus.self, forKey: .awardsStatus) ?? .pending
        awardsFinalizedAt = try c.decodeIfPresent(Time.self, forKey: .awardsFinalizedAt)
        lastScoreAdjustmentAt = try c.decodeIfPresent(Time.self, forKey: .lastScoreAdjustmentAt)
        lastScoreAdjustmentByMemberID = try c.decodeIfPresent(String.self, forKey: .lastScoreAdjustmentByMemberID)
        lastScoreAdjustmentReason = try c.decodeIfPresent(String.self, forKey: .lastScoreAdjustmentReason)
        scoreAdjustmentCount = try c.decodeIfPresent(Int.self, forKey: .scoreAdjustmentCount) ?? 0
        createdAt = try c.decodeIfPresent(Time.self, forKey: .createdAt) ?? .init()
        lastUpdatedAt = try c.decodeIfPresent(Time.self, forKey: .lastUpdatedAt) ?? .init()
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(index, forKey: .index)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(scheduledAt, forKey: .scheduledAt)
        try c.encodeIfPresent(roundID, forKey: .roundID)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encodeIfPresent(courseOverride, forKey: .courseOverride)
        try c.encode(roundConfig, forKey: .roundConfig)
        try c.encodeIfPresent(teamScoringProfileID, forKey: .teamScoringProfileID)
        try c.encodeIfPresent(individualScoringProfileID, forKey: .individualScoringProfileID)
        try c.encode(matchupPlans, forKey: .matchupPlans)
        try c.encode(plannedMatchups, forKey: .plannedMatchups)
        try c.encode(plannedTeeGroups, forKey: .plannedTeeGroups)
        try c.encode(partnershipPlans, forKey: .partnershipPlans)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(awardsStatus, forKey: .awardsStatus)
        try c.encodeIfPresent(awardsFinalizedAt, forKey: .awardsFinalizedAt)
        try c.encodeIfPresent(lastScoreAdjustmentAt, forKey: .lastScoreAdjustmentAt)
        try c.encodeIfPresent(lastScoreAdjustmentByMemberID, forKey: .lastScoreAdjustmentByMemberID)
        try c.encodeIfPresent(lastScoreAdjustmentReason, forKey: .lastScoreAdjustmentReason)
        try c.encode(scoreAdjustmentCount, forKey: .scoreAdjustmentCount)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try c.encode(parentID, forKey: .parentID)
        try c.encode(1, forKey: .schema)
    }
}

extension SeriesRound {
    /// Best timestamp for attributing an ingested handicap score to this league round.
    var handicapScoreRecordedAt: Time {
        completedAt ?? scheduledAt ?? startedAt ?? createdAt
    }

    var planningMode: SeriesRoundPlanSource {
        plannedStructure.hasManualOverrides ? .manualOverride : .autoGenerated
    }

    var plannedStructure: SeriesRoundPlannedStructure {
        .init(matchups: plannedMatchups, teeGroups: plannedTeeGroups)
    }
}

// MARK: - Attendance

struct SeriesRoundAttendance: FirebaseSubcollectable {
    var id: String
    var seriesRoundID: String
    var memberID: String
    var status: String
    var declinedNote: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.attendance.rawValue }

    init(
        id: String = "",
        seriesRoundID: String = "",
        memberID: String = "",
        status: String = SeriesRoundAttendanceStatus.pending.rawValue,
        declinedNote: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.seriesRoundID = seriesRoundID
        self.memberID = memberID
        self.status = status
        self.declinedNote = declinedNote
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, status, schema
        case seriesRoundID = "series_round_id"
        case memberID = "member_id"
        case declinedNote = "declined_note"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Announcements

struct SeriesAnnouncement: FirebaseSubcollectable {
    var id: String
    var title: String
    var message: String
    var createdByMemberID: String
    var startsAt: Time
    var endsAt: Time
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.announcements.rawValue }

    init(
        id: String = "",
        title: String = "",
        message: String = "",
        createdByMemberID: String = "",
        startsAt: Time = .init(),
        endsAt: Time = .init(),
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.createdByMemberID = createdByMemberID
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, title, message, schema
        case createdByMemberID = "created_by_member_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

extension SeriesAnnouncement {
    /// Epoch start = no explicit schedule; show as soon as posted (matches `Time.beginningOfTime`).
    static let announcementOpenStartUnix: Double = 0
    /// Far-future end = no expiry (matches `Time.endOfTIme`).
    static var announcementOpenEndUnix: Double { Time().endOfTIme.unix }

    func isActive(at time: Time = .init()) -> Bool {
        startsAt.unix <= time.unix && time.unix < endsAt.unix
    }

    /// `true` when start was omitted in the editor (stored as open-start sentinel).
    var usesOpenStart: Bool { startsAt.unix <= Self.announcementOpenStartUnix + 1 }
    /// `true` when end was omitted (stored as open-end sentinel).
    var usesOpenEnd: Bool { endsAt.unix >= Self.announcementOpenEndUnix - 86_400 }
}

// MARK: - Scoring profile

struct SeriesPlacementRule: Hashable, Codable, Identifiable {
    var id: String
    var rankStart: Int
    var rankEnd: Int
    var points: Double

    init(
        id: String = "",
        rankStart: Int = 1,
        rankEnd: Int = 1,
        points: Double = 0
    ) {
        self.id = id
        self.rankStart = rankStart
        self.rankEnd = rankEnd
        self.points = points
    }

    enum CodingKeys: String, CodingKey {
        case id, points
        case rankStart = "rank_start"
        case rankEnd = "rank_end"
    }
}

struct SeriesBonusRule: Hashable, Codable, Identifiable {
    var id: String
    var type: SeriesBonusRuleType
    var points: Double
    var label: String
    var isEnabled: Bool

    init(
        id: String = "",
        type: SeriesBonusRuleType = .manual,
        points: Double = 0,
        label: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.label = label
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, type, points, label
        case isEnabled = "is_enabled"
    }
}

struct SeriesResultPoints: Hashable, Codable {
    var winPoints: Double
    var tiePoints: Double
    var lossPoints: Double

    init(
        winPoints: Double = 1,
        tiePoints: Double = 0.5,
        lossPoints: Double = 0
    ) {
        self.winPoints = winPoints
        self.tiePoints = tiePoints
        self.lossPoints = lossPoints
    }

    enum CodingKeys: String, CodingKey {
        case winPoints = "win_points"
        case tiePoints = "tie_points"
        case lossPoints = "loss_points"
    }
}

struct SeriesScoringProfile: FirebaseSubcollectable {
    var id: String
    var name: String
    var summary: String?
    var outcomeSource: SeriesOutcomeSource
    var competitorType: SeriesCompetitorType
    var kind: SeriesScoringProfileKind
    var tieHandling: SeriesTieHandling
    var placementRules: [SeriesPlacementRule]
    var resultPoints: SeriesResultPoints?
    var bonusRules: [SeriesBonusRule]
    var isArchived: Bool
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.scoringProfiles.rawValue }

    init(
        id: String = "",
        name: String = "",
        summary: String? = nil,
        outcomeSource: SeriesOutcomeSource = .roundIndividualLeaderboard,
        competitorType: SeriesCompetitorType = .member,
        kind: SeriesScoringProfileKind = .placement,
        tieHandling: SeriesTieHandling = .splitPoints,
        placementRules: [SeriesPlacementRule] = [],
        resultPoints: SeriesResultPoints? = nil,
        bonusRules: [SeriesBonusRule] = [],
        isArchived: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.outcomeSource = outcomeSource
        self.competitorType = competitorType
        self.kind = kind
        self.tieHandling = tieHandling
        self.placementRules = placementRules
        self.resultPoints = resultPoints
        self.bonusRules = bonusRules
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, summary, schema
        case outcomeSource = "outcome_source"
        case competitorType = "competitor_type"
        case kind
        case tieHandling = "tie_handling"
        case placementRules = "placement_rules"
        case resultPoints = "result_points"
        case bonusRules = "bonus_rules"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Mapping / awards / standings

struct SeriesRoundMapping: FirebaseSubcollectable {
    var id: String
    var seriesRoundID: String
    var roundOwnerType: SeriesRoundOwnerType
    var roundOwnerID: String
    var competitorType: SeriesCompetitorType
    var competitorID: String
    var weight: Double
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.mappings.rawValue }

    init(
        id: String = "",
        seriesRoundID: String = "",
        roundOwnerType: SeriesRoundOwnerType = .participant,
        roundOwnerID: String = "",
        competitorType: SeriesCompetitorType = .member,
        competitorID: String = "",
        weight: Double = 1.0,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.seriesRoundID = seriesRoundID
        self.roundOwnerType = roundOwnerType
        self.roundOwnerID = roundOwnerID
        self.competitorType = competitorType
        self.competitorID = competitorID
        self.weight = weight
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, weight, schema
        case seriesRoundID = "series_round_id"
        case roundOwnerType = "round_owner_type"
        case roundOwnerID = "round_owner_id"
        case competitorType = "competitor_type"
        case competitorID = "competitor_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesPointAward: FirebaseSubcollectable {
    var id: String
    var seriesRoundID: String
    var awardTrack: SeriesAwardTrack
    var competitorType: SeriesCompetitorType
    var competitorID: String
    var competitorName: String
    var profileKind: SeriesScoringProfileKind
    var placement: Int?
    var tieGroupSize: Int?
    var basePoints: Double
    var bonusPoints: Double
    var totalPoints: Double
    var source: SeriesAwardSource
    var roundOwnerID: String?
    var reason: String?
    var awardedByMemberID: String?
    var awardedAt: Time
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.pointAwards.rawValue }

    init(
        id: String = "",
        seriesRoundID: String = "",
        awardTrack: SeriesAwardTrack = .individual,
        competitorType: SeriesCompetitorType = .member,
        competitorID: String = "",
        competitorName: String = "",
        profileKind: SeriesScoringProfileKind = .placement,
        placement: Int? = nil,
        tieGroupSize: Int? = nil,
        basePoints: Double = 0,
        bonusPoints: Double = 0,
        totalPoints: Double = 0,
        source: SeriesAwardSource = .automatic,
        roundOwnerID: String? = nil,
        reason: String? = nil,
        awardedByMemberID: String? = nil,
        awardedAt: Time = .init(),
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.seriesRoundID = seriesRoundID
        self.awardTrack = awardTrack
        self.competitorType = competitorType
        self.competitorID = competitorID
        self.competitorName = competitorName
        self.profileKind = profileKind
        self.placement = placement
        self.tieGroupSize = tieGroupSize
        self.basePoints = basePoints
        self.bonusPoints = bonusPoints
        self.totalPoints = totalPoints
        self.source = source
        self.roundOwnerID = roundOwnerID
        self.reason = reason
        self.awardedByMemberID = awardedByMemberID
        self.awardedAt = awardedAt
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, placement, source, reason, schema
        case seriesRoundID = "series_round_id"
        case awardTrack = "award_track"
        case competitorType = "competitor_type"
        case competitorID = "competitor_id"
        case competitorName = "competitor_name"
        case profileKind = "profile_kind"
        case tieGroupSize = "tie_group_size"
        case basePoints = "base_points"
        case bonusPoints = "bonus_points"
        case totalPoints = "total_points"
        case roundOwnerID = "round_owner_id"
        case awardedByMemberID = "awarded_by_member_id"
        case awardedAt = "awarded_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesStanding: FirebaseSubcollectable {
    var id: String
    var awardTrack: SeriesAwardTrack
    var competitorType: SeriesCompetitorType
    var competitorID: String
    var competitorName: String
    var totalPoints: Double
    var roundsCounted: Int
    var wins: Int
    var topThrees: Int
    var lastPlacement: Int?
    var bestPlacement: Int?
    var rank: Int?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.standings.rawValue }

    init(
        id: String = "",
        awardTrack: SeriesAwardTrack = .individual,
        competitorType: SeriesCompetitorType = .member,
        competitorID: String = "",
        competitorName: String = "",
        totalPoints: Double = 0,
        roundsCounted: Int = 0,
        wins: Int = 0,
        topThrees: Int = 0,
        lastPlacement: Int? = nil,
        bestPlacement: Int? = nil,
        rank: Int? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.awardTrack = awardTrack
        self.competitorType = competitorType
        self.competitorID = competitorID
        self.competitorName = competitorName
        self.totalPoints = totalPoints
        self.roundsCounted = roundsCounted
        self.wins = wins
        self.topThrees = topThrees
        self.lastPlacement = lastPlacement
        self.bestPlacement = bestPlacement
        self.rank = rank
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, wins, rank, schema
        case awardTrack = "award_track"
        case competitorType = "competitor_type"
        case competitorID = "competitor_id"
        case competitorName = "competitor_name"
        case totalPoints = "total_points"
        case roundsCounted = "rounds_counted"
        case topThrees = "top_threes"
        case lastPlacement = "last_placement"
        case bestPlacement = "best_placement"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

extension SeriesStanding {
    static func standingID(for track: SeriesAwardTrack, competitorID: String) -> String {
        "\(track.rawValue)_\(competitorID)"
    }
}

/// Outcome summary for a linked matchup round (Round Awards sheet).
struct SeriesMatchupOutcome: Identifiable {
    let id: String
    let title: String
    let detail: String
    let mode: MatchupMode
    let sides: [Side]
    let players: [Player]
    let winningSideID: String?
    let isTie: Bool
    let showsResultChip: Bool
    let usesNetScores: Bool

    struct Side: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let score: String
        let accentColor: Color?
    }

    struct Player: Identifiable {
        let id: String
        let ownerID: String
        let name: String
        let handicap: String
        let gross: String
        let net: String?
        let scoreCounts: Bool
        let accentColor: Color?
    }
}

extension Double {
    /// Standings / award points: show integer when whole, otherwise one decimal max.
    var seriesPointsDisplayString: String {
        let roundedTenth = (self * 10).rounded() / 10
        if abs(roundedTenth - roundedTenth.rounded(.towardZero)) < 1e-9 {
            return "\(Int(roundedTenth.rounded(.towardZero)))"
        }
        return String(format: "%.1f", roundedTenth)
    }
}

struct SeriesScoreboardEntry: Identifiable, Equatable {
    var id: String { competitorID }
    let competitorID: String
    let competitorName: String
    let competitorType: SeriesCompetitorType
    let officialPoints: Double
    let projectedPoints: Double
}

struct SeriesScoreboardRoundSummary: Identifiable, Equatable {
    let id: String
    let roundTitle: String
    let availablePoints: Double?
    let officialPointsAwarded: Double
    let isFinalized: Bool
}

struct SeriesScoreboardSnapshot: Equatable {
    let awardTrack: SeriesAwardTrack
    let entries: [SeriesScoreboardEntry]
    let roundSummaries: [SeriesScoreboardRoundSummary]
    let totalAvailablePoints: Double?
    let officialPointsAwarded: Double
    let projectedPointsAwarded: Double
    let usesProjectedTotals: Bool

    var pointsRemaining: Double? {
        totalAvailablePoints.map { max(0, $0 - projectedPointsAwarded) }
    }

    var winThreshold: Double? {
        guard entries.count == 2, let totalAvailablePoints else { return nil }
        return floor(totalAvailablePoints / 2) + 0.5
    }

    var leaderText: String {
        guard let first = entries.first else { return "No points yet" }
        guard entries.count > 1 else { return "\(first.competitorName) leads" }
        let second = entries[1]
        let margin = first.projectedPoints - second.projectedPoints
        if abs(margin) < 0.000_001 { return "All square" }
        return "\(first.competitorName) leads by \(margin.seriesPointsDisplayString)"
    }
}

enum SeriesScoreboardEligibility {
    static func isEligible(teams: [SeriesTeam]) -> Bool {
        teams.count == 2
    }
}

enum SeriesScoreboardCalculator {
    static func snapshot(
        series: Series,
        rounds: [SeriesRound],
        scoringProfiles: [SeriesScoringProfile],
        pointAwards: [SeriesPointAward],
        teams: [SeriesTeam],
        members: [SeriesMember],
        projectedAwards: [SeriesPointAward] = []
    ) -> SeriesScoreboardSnapshot? {
        let track = preferredTrack(series: series, teams: teams)
        let competitors = scoreboardCompetitors(track: track, teams: teams, members: members)
        guard competitors.isPopulated else { return nil }

        let profilesByID = Dictionary(uniqueKeysWithValues: scoringProfiles.map { ($0.id, $0) })
        let awardsForTrack = pointAwards.filter { $0.awardTrack == track }
        let projectedAwardsForTrack = projectedAwards.filter { $0.awardTrack == track }

        let roundSummaries = rounds.sorted { $0.index < $1.index }.map { round in
            let profile = profile(for: round, track: track, profilesByID: profilesByID)
            let available = profile.flatMap {
                availablePoints(
                    for: round,
                    profile: $0,
                    track: track,
                    series: series,
                    teams: teams,
                    members: members,
                    profilesByID: profilesByID,
                    awards: pointAwards
                )
            }
            let official = awardsForTrack
                .filter { $0.seriesRoundID == round.id }
                .reduce(0.0) { $0 + $1.totalPoints }
            return SeriesScoreboardRoundSummary(
                id: round.id,
                roundTitle: round.title.isPopulated ? round.title : "Round \(round.index + 1)",
                availablePoints: available,
                officialPointsAwarded: official,
                isFinalized: round.awardsStatus == .finalized
            )
        }

        let officialTotals = Dictionary(grouping: awardsForTrack, by: \.competitorID)
            .mapValues { awards in awards.reduce(0.0) { $0 + $1.totalPoints } }
        let projectedTotals = Dictionary(grouping: projectedAwardsForTrack, by: \.competitorID)
            .mapValues { awards in awards.reduce(0.0) { $0 + $1.totalPoints } }

        let entries = competitors.map { competitor in
            let official = officialTotals[competitor.id] ?? 0
            let projected = official + (projectedTotals[competitor.id] ?? 0)
            return SeriesScoreboardEntry(
                competitorID: competitor.id,
                competitorName: competitor.name,
                competitorType: competitor.type,
                officialPoints: official,
                projectedPoints: projected
            )
        }
        .sorted {
            if $0.projectedPoints != $1.projectedPoints {
                return $0.projectedPoints > $1.projectedPoints
            }
            return $0.competitorName.localizedCaseInsensitiveCompare($1.competitorName) == .orderedAscending
        }

        let availableValues = roundSummaries.compactMap(\.availablePoints)
        let totalAvailable = availableValues.count == roundSummaries.count
            ? availableValues.reduce(0.0, +)
            : nil
        let officialAwarded = entries.reduce(0.0) { $0 + $1.officialPoints }
        let projectedAwarded = entries.reduce(0.0) { $0 + $1.projectedPoints }

        return SeriesScoreboardSnapshot(
            awardTrack: track,
            entries: entries,
            roundSummaries: roundSummaries,
            totalAvailablePoints: totalAvailable,
            officialPointsAwarded: officialAwarded,
            projectedPointsAwarded: projectedAwarded,
            usesProjectedTotals: projectedAwardsForTrack.isPopulated
        )
    }

    static func availablePoints(
        for round: SeriesRound,
        profile: SeriesScoringProfile,
        track: SeriesAwardTrack,
        series: Series,
        teams: [SeriesTeam],
        members: [SeriesMember],
        profilesByID: [String: SeriesScoringProfile],
        awards: [SeriesPointAward] = []
    ) -> Double? {
        switch profile.kind {
        case .placement:
            let count = competitorCount(track: track, teams: teams, members: members)
            guard count > 0 else { return 0 }
            let placementTotal = (1...count).reduce(0.0) { partial, rank in
                partial + placementPoints(rank: rank, profile: profile)
            }
            return placementTotal + enabledParticipationBonus(profile: profile) * Double(count)

        case .winTieLoss:
            let matchupCount = resolvedMatchupCount(for: round, track: track, teams: teams, members: members)
            guard matchupCount > 0 else { return 0 }
            if round.roundConfig.matchupScoringStyle == .holeByHolePoints {
                let holePoints = Double(round.resolvedCourse(using: series)?.holeSegment.holeCount ?? 18)
                    * round.roundConfig.resolvedHoleWinPoints
                return Double(matchupCount) * (holePoints + round.roundConfig.resolvedMatchWinnerBonusPoints)
            }
            let resultPoints = profile.resultPoints ?? .init()
            let perMatch = max(resultPoints.winPoints + resultPoints.lossPoints, resultPoints.tiePoints * 2)
            return Double(matchupCount) * perMatch

        case .accrueFromIndividual:
            guard let individualProfileID = round.individualScoringProfileID,
                  let individualProfile = profilesByID[individualProfileID] else {
                return nil
            }
            return availablePoints(
                for: round,
                profile: individualProfile,
                track: .individual,
                series: series,
                teams: teams,
                members: members,
                profilesByID: profilesByID,
                awards: awards
            )

        case .manual:
            let existing = awards
                .filter { $0.seriesRoundID == round.id && $0.awardTrack == track }
                .reduce(0.0) { $0 + $1.totalPoints }
            return existing > 0 ? existing : nil
        }
    }

    private static func preferredTrack(series: Series, teams: [SeriesTeam]) -> SeriesAwardTrack {
        if series.settings.useTeamStandings || teams.isPopulated {
            return .team
        }
        return .individual
    }

    private static func scoreboardCompetitors(
        track: SeriesAwardTrack,
        teams: [SeriesTeam],
        members: [SeriesMember]
    ) -> [(id: String, name: String, type: SeriesCompetitorType)] {
        switch track {
        case .team:
            return teams
                .sorted { $0.index < $1.index }
                .map { ($0.id, $0.name, .team) }
        case .individual:
            return members
                .filter(\.isActive)
                .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
                .map { ($0.id, $0.name.fullName, .member) }
        }
    }

    private static func profile(
        for round: SeriesRound,
        track: SeriesAwardTrack,
        profilesByID: [String: SeriesScoringProfile]
    ) -> SeriesScoringProfile? {
        switch track {
        case .team:
            return round.teamScoringProfileID.flatMap { profilesByID[$0] }
        case .individual:
            return round.individualScoringProfileID.flatMap { profilesByID[$0] }
        }
    }

    private static func competitorCount(
        track: SeriesAwardTrack,
        teams: [SeriesTeam],
        members: [SeriesMember]
    ) -> Int {
        switch track {
        case .team:
            return teams.count
        case .individual:
            return members.filter(\.isActive).count
        }
    }

    private static func placementPoints(rank: Int, profile: SeriesScoringProfile) -> Double {
        profile.placementRules.first { rank >= $0.rankStart && rank <= $0.rankEnd }?.points ?? 0
    }

    private static func enabledParticipationBonus(profile: SeriesScoringProfile) -> Double {
        profile.bonusRules
            .filter { $0.isEnabled && $0.type == .participation }
            .reduce(0.0) { $0 + $1.points }
    }

    private static func resolvedMatchupCount(
        for round: SeriesRound,
        track: SeriesAwardTrack,
        teams: [SeriesTeam],
        members: [SeriesMember]
    ) -> Int {
        if round.roundConfig.matchupMode == .individualVsIndividual || track == .individual {
            let planned = round.plannedMatchups.filter { $0.matchupPlan.validMemberPairing }.count
            if planned > 0 { return planned }
            let explicit = round.matchupPlans.filter(\.validMemberPairing).count
            if explicit > 0 { return explicit }
            return members.filter(\.isActive).count / 2
        }

        if round.roundConfig.matchupMode == .teeGroupPartnerships {
            let planned = round.plannedMatchups.filter { $0.matchupPlan.validPairPairing }.count
            if planned > 0 { return planned }
            let explicit = round.matchupPlans.filter(\.validPairPairing).count
            if explicit > 0 { return explicit }
        }

        if round.roundConfig.matchupMode == .teeGroupPartnerships, round.plannedTeeGroups.isPopulated {
            let memberTeamIDs = Dictionary(uniqueKeysWithValues: members.compactMap { member -> (String, String)? in
                guard let teamID = member.teamID, teamID.isPopulated else { return nil }
                return (member.id, teamID)
            })
            let pairsByMemberID = round.partnershipPlans
                .filter(\.isValid)
                .reduce(into: [String: SeriesRoundPartnershipPlan]()) { partial, pair in
                    for memberID in pair.memberIDs {
                        partial[memberID] = pair
                    }
                }

            let mirroredCount = round.plannedTeeGroups.reduce(0) { partial, group in
                var pairIDs: Set<String> = []
                var pairTeamIDs: Set<String> = []
                for memberID in group.memberIDs {
                    guard let pair = pairsByMemberID[memberID] else { continue }
                    pairIDs.insert(pair.id)
                    if let teamID = pair.memberIDs.compactMap({ memberTeamIDs[$0] }).first {
                        pairTeamIDs.insert(teamID)
                    }
                }
                return partial + (pairIDs.count == 2 && pairTeamIDs.count == 2 ? 1 : 0)
            }
            if mirroredCount > 0 { return mirroredCount }
        }

        if round.roundConfig.scoreOwnerScope == .partnership {

            let byTeam = Dictionary(grouping: round.partnershipPlans.filter(\.isValid), by: \.teamID)
            let counts = byTeam.values.map(\.count)
            if counts.count >= 2, let minimum = counts.min(), minimum > 0 {
                return minimum
            }
        }

        let planned = round.plannedMatchups.filter { $0.matchupPlan.validTeamPairing }.count
        if planned > 0 { return planned }
        let explicit = round.matchupPlans.filter(\.validTeamPairing).count
        if explicit > 0 { return explicit }
        return teams.count / 2
    }
}

extension String {
    /// True for stored matchup / document ids we should not show as human-readable award subtitles.
    var looksLikeOpaqueAwardReasonID: Bool {
        // Standard UUID
        if count == 36, split(separator: "-").count == 5, unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF-").contains($0) }) {
            return true
        }
        // Typical Firestore auto-id length
        if count == 20, allSatisfy({ $0.isLetter || $0.isNumber }) {
            return true
        }
        return false
    }
}

// MARK: - Handicap

struct SeriesHandicapScore: FirebaseSubcollectable {
    var id: String
    var memberID: String
    var score: Double
    var par: Double
    var holeSegment: HoleSegment
    var teeBoxID: String?
    var courseRating: Double?
    var courseSlope: Int?
    var source: SeriesHandicapScoreSourceType
    var sourceRoundID: String?
    /// Optional display title for manual/baseline rows; empty UI falls back to "Baseline".
    var caption: String?
    /// When this score counts for ordering/display (defaults to `createdAt` for legacy docs).
    var recordedAt: Time
    /// Commissioner-controlled list order within a member’s history.
    var sortOrder: Int
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2
    /// When false, the score stays visible in history but is excluded from league index math.
    var countsTowardHandicapIndex: Bool = true

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.handicapScores.rawValue }

    init(
        id: String = "",
        memberID: String = "",
        score: Double = 0,
        par: Double = 0,
        holeSegment: HoleSegment = .front9,
        teeBoxID: String? = nil,
        courseRating: Double? = nil,
        courseSlope: Int? = nil,
        source: SeriesHandicapScoreSourceType = .baseline,
        sourceRoundID: String? = nil,
        caption: String? = nil,
        recordedAt: Time? = nil,
        sortOrder: Int = 0,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = "",
        countsTowardHandicapIndex: Bool = true
    ) {
        self.id = id
        self.memberID = memberID
        self.score = score
        self.par = par
        self.holeSegment = holeSegment
        self.teeBoxID = teeBoxID
        self.courseRating = courseRating
        self.courseSlope = courseSlope
        self.source = source
        self.sourceRoundID = sourceRoundID
        self.caption = caption
        let created = createdAt
        self.createdAt = created
        self.recordedAt = recordedAt ?? created
        self.sortOrder = sortOrder
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
        self.countsTowardHandicapIndex = countsTowardHandicapIndex
    }

    enum CodingKeys: String, CodingKey {
        case id, score, par, source, schema, caption
        case memberID = "member_id"
        case holeSegment = "hole_segment"
        case teeBoxID = "tee_box_id"
        case courseRating = "course_rating"
        case courseSlope = "course_slope"
        case sourceRoundID = "source_round_id"
        case recordedAt = "recorded_at"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
        case countsTowardHandicapIndex = "counts_toward_handicap_index"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        memberID = try c.decode(String.self, forKey: .memberID)
        score = try c.decode(Double.self, forKey: .score)
        par = try c.decode(Double.self, forKey: .par)
        holeSegment = try c.decode(HoleSegment.self, forKey: .holeSegment)
        teeBoxID = try c.decodeIfPresent(String.self, forKey: .teeBoxID)
        courseRating = try c.decodeIfPresent(Double.self, forKey: .courseRating)
        courseSlope = try c.decodeIfPresent(Int.self, forKey: .courseSlope)
        source = try c.decode(SeriesHandicapScoreSourceType.self, forKey: .source)
        sourceRoundID = try c.decodeIfPresent(String.self, forKey: .sourceRoundID)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        createdAt = try c.decodeIfPresent(Time.self, forKey: .createdAt) ?? .init()
        lastUpdatedAt = try c.decodeIfPresent(Time.self, forKey: .lastUpdatedAt) ?? .init()
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID) ?? ""
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        recordedAt = try c.decodeIfPresent(Time.self, forKey: .recordedAt) ?? createdAt
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        countsTowardHandicapIndex = try c.decodeIfPresent(Bool.self, forKey: .countsTowardHandicapIndex) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(memberID, forKey: .memberID)
        try c.encode(score, forKey: .score)
        try c.encode(par, forKey: .par)
        try c.encode(holeSegment, forKey: .holeSegment)
        try c.encodeIfPresent(teeBoxID, forKey: .teeBoxID)
        try c.encodeIfPresent(courseRating, forKey: .courseRating)
        try c.encodeIfPresent(courseSlope, forKey: .courseSlope)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(sourceRoundID, forKey: .sourceRoundID)
        try c.encodeIfPresent(caption, forKey: .caption)
        try c.encode(recordedAt, forKey: .recordedAt)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try c.encode(parentID, forKey: .parentID)
        try c.encode(schema, forKey: .schema)
        try c.encode(countsTowardHandicapIndex, forKey: .countsTowardHandicapIndex)
    }
}

struct SeriesHandicapOverride: FirebaseSubcollectable {
    var id: String
    var memberID: String
    var overrideIndex: Double?
    var isEnabled: Bool
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.handicapOverrides.rawValue }

    init(
        id: String = "",
        memberID: String = "",
        overrideIndex: Double? = nil,
        isEnabled: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.memberID = memberID
        self.overrideIndex = overrideIndex
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, schema
        case memberID = "member_id"
        case overrideIndex = "override_index"
        case isEnabled = "is_enabled"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesMemberHandicap: Hashable, Codable, Identifiable {
    var id: String
    var memberID: String
    var computedIndex: Double?
    var overrideIndex: Double?
    var isOverridden: Bool

    init(
        id: String = "",
        memberID: String = "",
        computedIndex: Double? = nil,
        overrideIndex: Double? = nil,
        isOverridden: Bool = false
    ) {
        self.id = id
        self.memberID = memberID
        self.computedIndex = computedIndex
        self.overrideIndex = overrideIndex
        self.isOverridden = isOverridden
    }

    var effectiveIndex: Double? {
        isOverridden ? overrideIndex : computedIndex
    }

    func effectiveStrokes(maximumHandicap: Int?) -> Int {
        let rounded = Int((effectiveIndex ?? 0).rounded())
        let nonNegative = max(rounded, 0)
        guard let maximumHandicap else { return nonNegative }
        return min(nonNegative, maximumHandicap)
    }

    func isCappedByMaximumHandicap(_ maximumHandicap: Int) -> Bool {
        guard let effectiveIndex else { return false }
        return max(Int(effectiveIndex.rounded()), 0) > maximumHandicap
    }

    func cappedDisplayText(maximumHandicap: Int) -> String? {
        guard effectiveIndex != nil else { return nil }
        let strokes = effectiveStrokes(maximumHandicap: maximumHandicap)
        return isCappedByMaximumHandicap(maximumHandicap) ? "\(strokes)*" : "\(strokes)"
    }
}

// MARK: - Helpers

extension SeriesMember {
    var isOffline: Bool { userID == nil }

    /// Linked Hackers account (non-empty `user_id`). Used for roster “online” status and commissioner eligibility.
    var hasLinkedUserID: Bool { userID?.isPopulated == true }
}

extension SeriesCourseSelection {
    func applying(holeSegment: HoleSegment) -> SeriesCourseSelection {
        var updated = self
        updated.holeSegment = holeSegment
        return updated
    }
}

extension SeriesRoundConfiguration {
    var template: GameTemplate {
        FormatTemplateRegistry.template(for: formatTemplateID)
    }

    var normalizedExcludedHandicapMemberIDs: [String] {
        Array(Set(excludedHandicapMemberIDs.filter(\.isPopulated))).sorted()
    }

    var supportsLeagueHandicapAccrual: Bool {
        template.supportsLeagueHandicapAccrual
    }

    var resolvedCompetitionScope: CompetitionScope {
        competitionScope ?? template.resolvedScope
    }

    var legacyGameFormat: GameFormat {
        let requiresTeams = matchupMode == .teamVsTeam || teamAssignmentMode == .seriesTeams
        let isMatchPlay = !requiresTeams && template.pipeline.contains { stage in
            if case .compare = stage { return true }
            return false
        }
        let type: GameFormatType = isMatchPlay ? .matchPlay : .strokePlay
        let aggregation: Aggregation? = requiresTeams
            ? Aggregation(
                mode: teamScoring.mode == .all ? .sumAll : .countBest,
                scope: teamScoring.scope,
                bestN: teamScoring.mode == .all ? nil : teamScoring.count
            )
            : nil
        let resolvedBasis = scoreBasisOverride ?? template.requirements.defaultScoreBasis
        let config = GameConfiguration(
            method: requiresTeams ? .aggregate : .individual,
            aggregation: aggregation,
            basis: resolvedBasis,
            handicap: template.requirements.defaultHandicapConfig,
            requiresTeams: requiresTeams,
            maxScoreOverPar: template.requirements.defaultMaxScoreOverPar
        )
        return GameFormat(type: type, configuration: config)
    }
}

extension SeriesRound {
    var effectiveTeamScoringProfileID: String? { teamScoringProfileID }
    var effectiveIndividualScoringProfileID: String? { individualScoringProfileID }
    var isAdjusted: Bool { scoreAdjustmentCount > 0 }

    func resolvedCourse(using series: Series) -> SeriesCourseSelection? {
        courseOverride ?? series.settings.defaultCourse
    }
}

extension SeriesRoundAttendance {
    static func documentID(seriesRoundID: String, memberID: String) -> String {
        "\(seriesRoundID)_\(memberID)"
    }
}

extension HoleSegment {
    var isNineHoleLeagueSegment: Bool {
        switch self {
        case .front9, .back9:
            return true
        case .full18, .custom:
            return false
        }
    }

    var alternatingPairSegment: HoleSegment {
        switch self {
        case .back9:
            return .front9
        case .front9, .full18, .custom:
            return .back9
        }
    }
}
