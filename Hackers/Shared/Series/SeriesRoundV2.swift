//
//  SeriesRoundV2.swift
//  Hackers
//
//  Canonical V2 Series/Round contracts. V1 models and collections remain unchanged.
//

import Foundation

enum V2Collection {
    static let rounds = Collections.roundsV2.rawValue
    static let series = Collections.seriesV2.rawValue
    static let memberships = "series-memberships-v2"
    static let joinCodes = "join-codes-v2"
    static let commands = "commands-v2"
    static let routing = "series-routing-v2"
}

enum RoundV2Subcollection: String, CaseIterable {
    case participants
    case teams
    case teeGroups = "tee-groups"
    case scoringGroups = "scoring-groups"
    case segments
    case scores
}

enum SeriesV2Subcollection: String, CaseIterable {
    case members
    case teams
    case pods
    case announcements
    case scoringProfiles = "scoring-profiles"
    case handicapScores = "handicap-scores"
    case handicapOverrides = "handicap-overrides"
    case roundResults = "round-results"
    case roundResultStates = "round-result-states"
    case standings
}

// MARK: - Round lifecycle

enum RoundStatusV2: String, Codable, CaseIterable {
    case lobby
    case live
    case completed
    case archived
}

enum RoundProvisioningPhaseV2: String, Codable {
    case provisioning
    case ready
    case failed
}

struct RoundProvisioningStateV2: Hashable, Codable {
    var phase: RoundProvisioningPhaseV2
    var commandID: String
    var lastCompletedStage: String?
    var failureCode: String?
    var retryCount: Int

    init(
        phase: RoundProvisioningPhaseV2 = .provisioning,
        commandID: String = "",
        lastCompletedStage: String? = nil,
        failureCode: String? = nil,
        retryCount: Int = 0
    ) {
        self.phase = phase
        self.commandID = commandID
        self.lastCompletedStage = lastCompletedStage
        self.failureCode = failureCode
        self.retryCount = retryCount
    }

    enum CodingKeys: String, CodingKey {
        case phase
        case commandID = "command_id"
        case lastCompletedStage = "last_completed_stage"
        case failureCode = "failure_code"
        case retryCount = "retry_count"
    }
}

struct RoundScheduleV2: Hashable, Codable {
    var scheduledAt: Time
    var timeZoneIdentifier: String

    init(scheduledAt: Time, timeZoneIdentifier: String = TimeZone.current.identifier) {
        self.scheduledAt = scheduledAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case scheduledAt = "scheduled_at"
        case timeZoneIdentifier = "time_zone_identifier"
    }
}

/// Series-agnostic playable configuration. Series defaults resolve into this value once;
/// they never compete with a second mutable SeriesRound configuration.
struct RoundConfigurationV2: Hashable, Codable {
    var templateID: String
    var formatSummary: RoundFormatSummary
    var courses: [CourseSegment]
    var competitionScope: CompetitionScope
    var teamScoring: RoundTeamScoringConfiguration
    var stablefordPoints: RoundStablefordPoints?
    var scoreOwnerScope: RoundScoreOwnerScope
    var matchupScoringStyle: RoundMatchupScoringStyle
    var holeWinPoints: Double
    var matchWinnerBonusPoints: Double
    var matchTiePolicy: TiePolicy
    var selectionDomain: ScoringSelectionDomain?
    var scoreInputMode: RoundScoreInputMode
    var scoreBasis: ScoreBasis
    var maxScoreOverPar: MaxScoreOverPar
    var handicapStrokeBasis: SeriesHandicapStrokeBasis?
    var sharedScoreHandicapConfig: HandicapConfiguration?
    var handicapEntryFormat: HandicapEntryFormat
    var handicapNormalizationMode: HandicapNormalizationMode
    var handicapMaximum: Int?
    var secretScoring: Bool
    var scoresRevealed: Bool
    var teamColorsEnabled: Bool
    var substitutesScore: Bool

    init(
        templateID: String = FormatTemplateRegistry.strokePlay.id,
        formatSummary: RoundFormatSummary = .init(from: FormatTemplateRegistry.strokePlay),
        courses: [CourseSegment] = [],
        competitionScope: CompetitionScope = .field,
        teamScoring: RoundTeamScoringConfiguration = .init(),
        stablefordPoints: RoundStablefordPoints? = nil,
        scoreOwnerScope: RoundScoreOwnerScope = .individual,
        matchupScoringStyle: RoundMatchupScoringStyle = .aggregateRoundTotal,
        holeWinPoints: Double = 1,
        matchWinnerBonusPoints: Double = 0,
        matchTiePolicy: TiePolicy = .half,
        selectionDomain: ScoringSelectionDomain? = nil,
        scoreInputMode: RoundScoreInputMode = .strokes,
        scoreBasis: ScoreBasis = .gross,
        maxScoreOverPar: MaxScoreOverPar = .quad,
        handicapStrokeBasis: SeriesHandicapStrokeBasis? = nil,
        sharedScoreHandicapConfig: HandicapConfiguration? = nil,
        handicapEntryFormat: HandicapEntryFormat = .strokes,
        handicapNormalizationMode: HandicapNormalizationMode = .off,
        handicapMaximum: Int? = nil,
        secretScoring: Bool = false,
        scoresRevealed: Bool = false,
        teamColorsEnabled: Bool = true,
        substitutesScore: Bool = false
    ) {
        self.templateID = templateID
        self.formatSummary = formatSummary
        self.courses = courses
        self.competitionScope = competitionScope
        self.teamScoring = teamScoring
        self.stablefordPoints = stablefordPoints
        self.scoreOwnerScope = scoreOwnerScope
        self.matchupScoringStyle = matchupScoringStyle
        self.holeWinPoints = holeWinPoints
        self.matchWinnerBonusPoints = matchWinnerBonusPoints
        self.matchTiePolicy = matchTiePolicy
        self.selectionDomain = selectionDomain
        self.scoreInputMode = scoreInputMode
        self.scoreBasis = scoreBasis
        self.maxScoreOverPar = maxScoreOverPar
        self.handicapStrokeBasis = handicapStrokeBasis
        self.sharedScoreHandicapConfig = sharedScoreHandicapConfig
        self.handicapEntryFormat = handicapEntryFormat
        self.handicapNormalizationMode = handicapNormalizationMode
        self.handicapMaximum = handicapMaximum
        self.secretScoring = secretScoring
        self.scoresRevealed = scoresRevealed
        self.teamColorsEnabled = teamColorsEnabled
        self.substitutesScore = substitutesScore
    }

    init(legacy: RoundConfiguration) {
        let template = legacy.activeTemplate
        self.init(
            templateID: template.id,
            formatSummary: legacy.formatSummary ?? .init(from: template),
            courses: legacy.courses,
            competitionScope: legacy.resolvedCompetitionScope,
            teamScoring: legacy.teamScoring,
            stablefordPoints: legacy.stablefordPoints,
            scoreOwnerScope: legacy.scoreOwnerScope,
            matchupScoringStyle: legacy.matchupScoringStyle,
            holeWinPoints: legacy.resolvedHoleWinPoints,
            matchWinnerBonusPoints: legacy.resolvedMatchWinnerBonusPoints,
            matchTiePolicy: legacy.resolvedMatchTiePolicy,
            selectionDomain: legacy.selectionDomain,
            scoreInputMode: legacy.scoreInputMode,
            scoreBasis: legacy.primaryFormat.configuration.basis,
            maxScoreOverPar: legacy.primaryFormat.configuration.maxScoreOverPar,
            handicapStrokeBasis: legacy.handicapStrokeBasis,
            sharedScoreHandicapConfig: legacy.sharedScoreHandicapConfig,
            handicapEntryFormat: legacy.handicapEntryFormat,
            handicapNormalizationMode: legacy.handicapNormalizationMode,
            handicapMaximum: legacy.leagueHandicapMaximum,
            secretScoring: legacy.isSecretScoring,
            scoresRevealed: legacy.areScoresRevealed,
            teamColorsEnabled: legacy.teamColorsEnabled,
            substitutesScore: legacy.substitutesScore
        )
    }

    enum CodingKeys: String, CodingKey {
        case courses
        case templateID = "template_id"
        case formatSummary = "format_summary"
        case competitionScope = "competition_scope"
        case teamScoring = "team_scoring"
        case stablefordPoints = "stableford_points"
        case scoreOwnerScope = "score_owner_scope"
        case matchupScoringStyle = "matchup_scoring_style"
        case holeWinPoints = "hole_win_points"
        case matchWinnerBonusPoints = "match_winner_bonus_points"
        case matchTiePolicy = "match_tie_policy"
        case selectionDomain = "selection_domain"
        case scoreInputMode = "score_input_mode"
        case scoreBasis = "score_basis"
        case maxScoreOverPar = "max_score_over_par"
        case handicapStrokeBasis = "handicap_stroke_basis"
        case sharedScoreHandicapConfig = "shared_score_handicap_config"
        case handicapEntryFormat = "handicap_entry_format"
        case handicapNormalizationMode = "handicap_normalization_mode"
        case handicapMaximum = "handicap_maximum"
        case secretScoring = "secret_scoring"
        case scoresRevealed = "scores_revealed"
        case teamColorsEnabled = "team_colors_enabled"
        case substitutesScore = "substitutes_score"
    }
}

// MARK: - Series context

enum SeriesRosterApplicationPolicyV2: String, Codable {
    case untilLive = "until_live"
    case manual
}

struct ScoringProfileBindingV2: Hashable, Codable {
    var profileID: String
    var revisionRootID: String
    var revisionSequence: Int

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case revisionRootID = "revision_root_id"
        case revisionSequence = "revision_sequence"
    }
}

struct SeriesRoundRulesSnapshotV2: Hashable, Codable {
    var attendanceEnabled: Bool
    var attendanceDefault: SeriesRoundAttendanceStatus
    var rosterApplicationPolicy: SeriesRosterApplicationPolicyV2
    var matchupMode: SeriesMatchupMode
    var podGroupingStrategy: SeriesPodGroupingStrategy
    var teamAssignmentMode: SeriesTeamAssignmentMode
    var teeGroupMode: SeriesTeeGroupMode
    var countsTowardHandicapPool: Bool
    var excludedHandicapMemberIDs: [String]
    var commissionerOnlyStructureEdits: Bool

    init(
        attendanceEnabled: Bool = true,
        attendanceDefault: SeriesRoundAttendanceStatus = .pending,
        rosterApplicationPolicy: SeriesRosterApplicationPolicyV2 = .untilLive,
        matchupMode: SeriesMatchupMode = .field,
        podGroupingStrategy: SeriesPodGroupingStrategy = .disabled,
        teamAssignmentMode: SeriesTeamAssignmentMode = .manual,
        teeGroupMode: SeriesTeeGroupMode = .auto,
        countsTowardHandicapPool: Bool = true,
        excludedHandicapMemberIDs: [String] = [],
        commissionerOnlyStructureEdits: Bool = true
    ) {
        self.attendanceEnabled = attendanceEnabled
        self.attendanceDefault = attendanceDefault
        self.rosterApplicationPolicy = rosterApplicationPolicy
        self.matchupMode = matchupMode
        self.podGroupingStrategy = podGroupingStrategy
        self.teamAssignmentMode = teamAssignmentMode
        self.teeGroupMode = teeGroupMode
        self.countsTowardHandicapPool = countsTowardHandicapPool
        self.excludedHandicapMemberIDs = Array(Set(excludedHandicapMemberIDs.filter(\.isPopulated))).sorted()
        self.commissionerOnlyStructureEdits = commissionerOnlyStructureEdits
    }

    enum CodingKeys: String, CodingKey {
        case attendanceEnabled = "attendance_enabled"
        case attendanceDefault = "attendance_default"
        case rosterApplicationPolicy = "roster_application_policy"
        case matchupMode = "matchup_mode"
        case podGroupingStrategy = "pod_grouping_strategy"
        case teamAssignmentMode = "team_assignment_mode"
        case teeGroupMode = "tee_group_mode"
        case countsTowardHandicapPool = "counts_toward_handicap_pool"
        case excludedHandicapMemberIDs = "excluded_handicap_member_ids"
        case commissionerOnlyStructureEdits = "commissioner_only_structure_edits"
    }
}

struct SeriesContextV2: Hashable, Codable {
    var seriesID: String
    var roundIndex: Int
    var appliedDefaultsRevision: Int
    var lobbyActivatedAt: Time?
    var standingsPolicyBinding: SeriesRoundPolicyBinding?
    var teamScoringProfileBinding: ScoringProfileBindingV2?
    var individualScoringProfileBinding: ScoringProfileBindingV2?
    var rules: SeriesRoundRulesSnapshotV2
    var legacySeriesRoundID: String?
    var migratedFromV1: Bool

    enum CodingKeys: String, CodingKey {
        case rules
        case seriesID = "series_id"
        case roundIndex = "round_index"
        case appliedDefaultsRevision = "applied_defaults_revision"
        case lobbyActivatedAt = "lobby_activated_at"
        case standingsPolicyBinding = "standings_policy_binding"
        case teamScoringProfileBinding = "team_scoring_profile_binding"
        case individualScoringProfileBinding = "individual_scoring_profile_binding"
        case legacySeriesRoundID = "legacy_series_round_id"
        case migratedFromV1 = "migrated_from_v1"
    }
}

struct RoundV2: FirebaseIdentifiable {
    var id: String
    var name: String?
    var shareCode: String
    var createdByUserID: String
    var status: RoundStatusV2
    var schedule: RoundScheduleV2?
    var configuration: RoundConfigurationV2
    var seriesContext: SeriesContextV2?
    var participantPlayerIDs: [String]
    var provisioning: RoundProvisioningStateV2
    var revision: Int
    var scoringPaused: Bool
    var canceledAt: Time?
    var canceledByUserID: String?
    var cancellationReason: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var schema: Int = 2

    var collection: String { V2Collection.rounds }
    var isCanceled: Bool { canceledAt != nil }
    var isReady: Bool { provisioning.phase == .ready }

    init(
        id: String = "",
        name: String? = nil,
        shareCode: String = "",
        createdByUserID: String = "",
        status: RoundStatusV2 = .lobby,
        schedule: RoundScheduleV2? = nil,
        configuration: RoundConfigurationV2 = .init(),
        seriesContext: SeriesContextV2? = nil,
        participantPlayerIDs: [String] = [],
        provisioning: RoundProvisioningStateV2 = .init(),
        revision: Int = 0,
        scoringPaused: Bool = false,
        canceledAt: Time? = nil,
        canceledByUserID: String? = nil,
        cancellationReason: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.name = Round.normalizedName(name)
        self.shareCode = shareCode
        self.createdByUserID = createdByUserID
        self.status = status
        self.schedule = schedule
        self.configuration = configuration
        self.seriesContext = seriesContext
        self.participantPlayerIDs = Array(Set(participantPlayerIDs.filter(\.isPopulated))).sorted()
        self.provisioning = provisioning
        self.revision = revision
        self.scoringPaused = scoringPaused
        self.canceledAt = canceledAt
        self.canceledByUserID = canceledByUserID
        self.cancellationReason = cancellationReason
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, schedule, configuration, provisioning, revision, schema
        case shareCode = "share_code"
        case createdByUserID = "created_by_user_id"
        case seriesContext = "series_context"
        case participantPlayerIDs = "participant_player_ids"
        case scoringPaused = "scoring_paused"
        case canceledAt = "canceled_at"
        case canceledByUserID = "canceled_by_user_id"
        case cancellationReason = "cancellation_reason"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

// MARK: - Series root

struct SeriesRoundDefaultsV2: Hashable, Codable {
    var configuration: RoundConfigurationV2
    var rules: SeriesRoundRulesSnapshotV2
    var defaultTeamScoringProfileID: String?
    var defaultIndividualScoringProfileID: String?
    var scheduledTeeTimeMinutesFromMidnight: Int?
    var recurringPlayWeekdays: [Int]

    init(
        configuration: RoundConfigurationV2 = .init(),
        rules: SeriesRoundRulesSnapshotV2 = .init(),
        defaultTeamScoringProfileID: String? = nil,
        defaultIndividualScoringProfileID: String? = nil,
        scheduledTeeTimeMinutesFromMidnight: Int? = nil,
        recurringPlayWeekdays: [Int] = []
    ) {
        self.configuration = configuration
        self.rules = rules
        self.defaultTeamScoringProfileID = defaultTeamScoringProfileID
        self.defaultIndividualScoringProfileID = defaultIndividualScoringProfileID
        self.scheduledTeeTimeMinutesFromMidnight = scheduledTeeTimeMinutesFromMidnight
        self.recurringPlayWeekdays = Array(Set(recurringPlayWeekdays.filter { (1...7).contains($0) })).sorted()
    }

    enum CodingKeys: String, CodingKey {
        case configuration, rules
        case defaultTeamScoringProfileID = "default_team_scoring_profile_id"
        case defaultIndividualScoringProfileID = "default_individual_scoring_profile_id"
        case scheduledTeeTimeMinutesFromMidnight = "scheduled_tee_time_minutes_from_midnight"
        case recurringPlayWeekdays = "recurring_play_weekdays"
    }
}

struct SeriesSettingsV2: Hashable, Codable {
    var experiencePreset: SeriesExperiencePreset
    var roundDefaults: SeriesRoundDefaultsV2
    var roundDefaultsRevision: Int
    var handicapConfig: SeriesHandicapConfig
    var allowManualAwardOverrides: Bool
    var useTeams: Bool
    var useIndividualStandings: Bool
    var useTeamStandings: Bool
    var showScoreboardTile: Bool
    var standingsPolicyRevision: SeriesPolicyRevision?
    var standingsReadAuthority: SeriesStandingsReadAuthority

    init(
        experiencePreset: SeriesExperiencePreset = .league,
        roundDefaults: SeriesRoundDefaultsV2 = .init(),
        roundDefaultsRevision: Int = 1,
        handicapConfig: SeriesHandicapConfig = .init(),
        allowManualAwardOverrides: Bool = true,
        useTeams: Bool = false,
        useIndividualStandings: Bool = true,
        useTeamStandings: Bool = false,
        showScoreboardTile: Bool = false,
        standingsPolicyRevision: SeriesPolicyRevision? = nil,
        standingsReadAuthority: SeriesStandingsReadAuthority = .canonicalWhenReady
    ) {
        self.experiencePreset = experiencePreset
        self.roundDefaults = roundDefaults
        self.roundDefaultsRevision = max(1, roundDefaultsRevision)
        self.handicapConfig = handicapConfig
        self.allowManualAwardOverrides = allowManualAwardOverrides
        self.useTeams = useTeams
        self.useIndividualStandings = useIndividualStandings
        self.useTeamStandings = useTeamStandings
        self.showScoreboardTile = showScoreboardTile
        self.standingsPolicyRevision = standingsPolicyRevision
        self.standingsReadAuthority = standingsReadAuthority
    }

    enum CodingKeys: String, CodingKey {
        case experiencePreset = "experience_preset"
        case roundDefaults = "round_defaults"
        case roundDefaultsRevision = "round_defaults_revision"
        case handicapConfig = "handicap_config"
        case allowManualAwardOverrides = "allow_manual_award_overrides"
        case useTeams = "use_teams"
        case useIndividualStandings = "use_individual_standings"
        case useTeamStandings = "use_team_standings"
        case showScoreboardTile = "show_scoreboard_tile"
        case standingsPolicyRevision = "standings_policy_revision"
        case standingsReadAuthority = "standings_read_authority"
    }
}

enum SeriesMigrationPhaseV2: String, Codable, CaseIterable {
    case copying
    case validating
    case ready
    case active
    case rolledBack = "rolled_back"
    case failed

    var prefersV2: Bool { self == .active }
    var isStaged: Bool { self == .copying || self == .validating || self == .ready }
}

struct SeriesMigrationMetadataV2: Hashable, Codable {
    var sourceSeriesID: String?
    var phase: SeriesMigrationPhaseV2
    var cutoverRevision: Int
    var migratedAt: Time?
    var validatedAt: Time?
    var activatedAt: Time?
    var rolledBackAt: Time?
    var sourceSemanticHash: String?

    init(
        sourceSeriesID: String? = nil,
        phase: SeriesMigrationPhaseV2 = .copying,
        cutoverRevision: Int = 0,
        migratedAt: Time? = nil,
        validatedAt: Time? = nil,
        activatedAt: Time? = nil,
        rolledBackAt: Time? = nil,
        sourceSemanticHash: String? = nil
    ) {
        self.sourceSeriesID = sourceSeriesID
        self.phase = phase
        self.cutoverRevision = cutoverRevision
        self.migratedAt = migratedAt
        self.validatedAt = validatedAt
        self.activatedAt = activatedAt
        self.rolledBackAt = rolledBackAt
        self.sourceSemanticHash = sourceSemanticHash
    }

    enum CodingKeys: String, CodingKey {
        case phase
        case sourceSeriesID = "source_series_id"
        case cutoverRevision = "cutover_revision"
        case migratedAt = "migrated_at"
        case validatedAt = "validated_at"
        case activatedAt = "activated_at"
        case rolledBackAt = "rolled_back_at"
        case sourceSemanticHash = "source_semantic_hash"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceSeriesID = try container.decodeIfPresent(String.self, forKey: .sourceSeriesID)
        migratedAt = try container.decodeIfPresent(Time.self, forKey: .migratedAt)
        validatedAt = try container.decodeIfPresent(Time.self, forKey: .validatedAt)
        activatedAt = try container.decodeIfPresent(Time.self, forKey: .activatedAt)
        rolledBackAt = try container.decodeIfPresent(Time.self, forKey: .rolledBackAt)
        sourceSemanticHash = try container.decodeIfPresent(String.self, forKey: .sourceSemanticHash)
        cutoverRevision = try container.decodeIfPresent(Int.self, forKey: .cutoverRevision) ?? 0
        phase = try container.decodeIfPresent(SeriesMigrationPhaseV2.self, forKey: .phase)
            ?? (validatedAt == nil ? .copying : .ready)
    }
}

/// Server-owned switch for choosing one visible version of a logical Series.
/// It lives outside V1, so migration and rollback never mutate the V1 document.
struct SeriesRoutingV2: FirebaseIdentifiable {
    var id: String
    var sourceSeriesID: String
    var targetSeriesID: String
    var phase: SeriesMigrationPhaseV2
    var revision: Int
    var minimumClientVersion: String
    var activatedAt: Time?
    var rolledBackAt: Time?
    var createdAt: Time
    var lastUpdatedAt: Time
    var schema: Int = 2

    var collection: String { V2Collection.routing }

    enum CodingKeys: String, CodingKey {
        case id, phase, revision, schema
        case sourceSeriesID = "source_series_id"
        case targetSeriesID = "target_series_id"
        case minimumClientVersion = "minimum_client_version"
        case activatedAt = "activated_at"
        case rolledBackAt = "rolled_back_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

struct SeriesV2: FirebaseIdentifiable {
    var id: String
    var name: String
    var description: String?
    var shareCode: String
    var commissionerUserID: String
    var commissionerPlayerID: String?
    var status: SeriesStatus
    var visibility: SeriesVisibility
    var settings: SeriesSettingsV2
    var roundCount: Int
    var completedRoundCount: Int
    var activeAnnouncementCount: Int
    var minimumClientVersion: String?
    var migration: SeriesMigrationMetadataV2?
    var createdAt: Time
    var lastUpdatedAt: Time
    var startsAt: Time?
    var endsAt: Time?
    var schema: Int = 2

    var collection: String { V2Collection.series }

    init(
        id: String = "",
        name: String = "",
        description: String? = nil,
        shareCode: String = "",
        commissionerUserID: String = "",
        commissionerPlayerID: String? = nil,
        status: SeriesStatus = .draft,
        visibility: SeriesVisibility = .privateSeries,
        settings: SeriesSettingsV2 = .init(),
        roundCount: Int = 0,
        completedRoundCount: Int = 0,
        activeAnnouncementCount: Int = 0,
        minimumClientVersion: String? = nil,
        migration: SeriesMigrationMetadataV2? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        startsAt: Time? = nil,
        endsAt: Time? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.shareCode = shareCode
        self.commissionerUserID = commissionerUserID
        self.commissionerPlayerID = commissionerPlayerID
        self.status = status
        self.visibility = visibility
        self.settings = settings
        self.roundCount = roundCount
        self.completedRoundCount = completedRoundCount
        self.activeAnnouncementCount = activeAnnouncementCount
        self.minimumClientVersion = minimumClientVersion
        self.migration = migration
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, status, visibility, settings, migration, schema
        case shareCode = "share_code"
        case commissionerUserID = "commissioner_user_id"
        case commissionerPlayerID = "commissioner_player_id"
        case roundCount = "round_count"
        case completedRoundCount = "completed_round_count"
        case activeAnnouncementCount = "active_announcement_count"
        case minimumClientVersion = "minimum_client_version"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }
}

struct SeriesMemberV2: FirebaseSubcollectable {
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
    var legacyMemberID: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.series }
    static var subcollectionName: String { SeriesV2Subcollection.members.rawValue }

    init(legacy: SeriesMember, parentID: String) {
        id = legacy.id
        userID = legacy.userID
        playerID = legacy.playerID
        name = legacy.name
        role = legacy.role
        teamID = legacy.teamID
        defaultTeeBoxID = legacy.defaultTeeBoxID
        isActive = legacy.isActive
        joinedAt = legacy.joinedAt
        leftAt = legacy.leftAt
        legacyMemberID = legacy.id
        createdAt = legacy.createdAt
        lastUpdatedAt = legacy.lastUpdatedAt
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
        case legacyMemberID = "legacy_member_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesTeamV2: FirebaseSubcollectable, IndexIterable {
    var id: String
    var name: String
    var color: String
    var customColorHex: String?
    var index: Int
    var isLocked: Bool
    var legacyTeamID: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.series }
    static var subcollectionName: String { SeriesV2Subcollection.teams.rawValue }

    init(legacy: SeriesTeam, parentID: String) {
        id = legacy.id
        name = legacy.name
        color = legacy.color
        customColorHex = legacy.customColorHex
        index = legacy.index
        isLocked = legacy.isLocked
        legacyTeamID = legacy.id
        createdAt = legacy.createdAt
        lastUpdatedAt = legacy.lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, index, schema
        case customColorHex = "custom_color_hex"
        case isLocked = "is_locked"
        case legacyTeamID = "legacy_team_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesMembershipIndexV2: FirebaseIdentifiable {
    var id: String
    var seriesID: String
    var memberID: String
    var playerID: String
    var userID: String?
    var role: SeriesMemberRole
    var isActive: Bool
    var createdAt: Time
    var lastUpdatedAt: Time
    var schema: Int = 2

    var collection: String { V2Collection.memberships }

    static func makeID(seriesID: String, playerID: String) -> String {
        "\(seriesID)_\(playerID)"
    }

    enum CodingKeys: String, CodingKey {
        case id, role, schema
        case seriesID = "series_id"
        case memberID = "member_id"
        case playerID = "player_id"
        case userID = "user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

enum JoinCodeTargetTypeV2: String, Codable {
    case round
    case series
}

struct JoinCodeReservationV2: FirebaseIdentifiable {
    var id: String
    var targetType: JoinCodeTargetTypeV2
    var targetID: String
    var modelVersion: Int
    var createdAt: Time
    var lastUpdatedAt: Time
    var schema: Int = 2

    var collection: String { V2Collection.joinCodes }

    enum CodingKeys: String, CodingKey {
        case id, schema
        case targetType = "target_type"
        case targetID = "target_id"
        case modelVersion = "model_version"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

// MARK: - Round-local V2 entities

enum RoundParticipationStatusV2: String, Codable, CaseIterable {
    case pending
    case confirmed
    case declined
    case withdrawn
    case noShow = "no_show"

    var isScoringEligible: Bool {
        self == .pending || self == .confirmed
    }
}

struct RoundParticipantV2: FirebaseSubcollectable {
    var id: String
    var userID: String?
    var playerID: String?
    var seriesMemberID: String?
    var name: Name
    var participationStatus: RoundParticipationStatusV2
    var teeBoxID: String
    var originalHandicap: Int
    var adjustedHandicap: Int
    var handicapIndex: Double?
    var teamID: String?
    var teeGroupID: String?
    var teeOrder: Int?
    var isHost: Bool
    var isSubstitute: Bool
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.rounds }
    static var subcollectionName: String { RoundV2Subcollection.participants.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, name, schema
        case userID = "user_id"
        case playerID = "player_id"
        case seriesMemberID = "series_member_id"
        case participationStatus = "participation_status"
        case teeBoxID = "tee_box_id"
        case originalHandicap = "original_handicap"
        case adjustedHandicap = "adjusted_handicap"
        case handicapIndex = "handicap_index"
        case teamID = "team_id"
        case teeGroupID = "tee_group_id"
        case teeOrder = "tee_order"
        case isHost = "is_host"
        case isSubstitute = "is_substitute"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct RoundTeamV2: FirebaseSubcollectable, IndexIterable {
    var id: String
    var seriesTeamID: String?
    var name: String
    var color: String
    var index: Int
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.rounds }
    static var subcollectionName: String { RoundV2Subcollection.teams.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, name, color, index, schema
        case seriesTeamID = "series_team_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct RoundTeeGroupV2: FirebaseSubcollectable, IndexIterable {
    var id: String
    var sourcePlanID: String?
    var index: Int
    var teeTime: String?
    var startingHole: Int
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.rounds }
    static var subcollectionName: String { RoundV2Subcollection.teeGroups.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, index, schema
        case sourcePlanID = "source_plan_id"
        case teeTime = "tee_time"
        case startingHole = "starting_hole"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct RoundScoringGroupV2: FirebaseSubcollectable {
    var id: String
    var sourceSeriesPodID: String?
    var sourcePartnershipPlanID: String?
    var teamID: String?
    var teeGroupID: String?
    var kind: RoundScoringGroupKind
    var participantIDs: [String]
    var label: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.rounds }
    static var subcollectionName: String { RoundV2Subcollection.scoringGroups.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, kind, label, schema
        case sourceSeriesPodID = "source_series_pod_id"
        case sourcePartnershipPlanID = "source_partnership_plan_id"
        case teamID = "team_id"
        case teeGroupID = "tee_group_id"
        case participantIDs = "participant_ids"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct RoundSegmentV2: FirebaseSubcollectable {
    var id: String
    var holeRange: HoleRange
    var templateID: String
    var scoringUnits: [ScoringUnit]
    var matchups: [TeamMatchup]
    var competitionScope: CompetitionScope
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.rounds }
    static var subcollectionName: String { RoundV2Subcollection.segments.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, matchups, schema
        case holeRange = "hole_range"
        case templateID = "template_id"
        case scoringUnits = "scoring_units"
        case competitionScope = "competition_scope"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct ScoreEntryV2: FirebaseSubcollectable {
    var id: String
    var holeNumber: Int
    var segmentID: String
    var teeGroupID: String
    var scoringUnitID: String
    var participantIDs: [String]
    var strokes: Int?
    var relativeToPar: Int?
    var entryMode: ScoreEntryMode?
    var value: String?
    var pickedUp: Bool
    var gameTemplateID: String?
    var points: Double?
    var outcome: HoleOutcome?
    var entryID: String
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.rounds }
    static var subcollectionName: String { RoundV2Subcollection.scores.rawValue }

    static func makeID(hole: Int, segment: String, scoringUnit: String) -> String {
        ScoreEntry.makeID(hole: hole, segment: segment, scoringUnit: scoringUnit)
    }

    enum CodingKeys: String, CodingKey {
        case id, strokes, value, points, outcome, schema
        case holeNumber = "hole_number"
        case segmentID = "segment_id"
        case teeGroupID = "tee_group_id"
        case scoringUnitID = "scoring_unit_id"
        case participantIDs = "participant_ids"
        case relativeToPar = "relative_to_par"
        case entryMode = "entry_mode"
        case pickedUp = "picked_up"
        case gameTemplateID = "game_template_id"
        case entryID = "entry_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct RoundSnapshotV2 {
    var round: RoundV2
    var participants: [RoundParticipantV2]
    var teams: [RoundTeamV2]
    var teeGroups: [RoundTeeGroupV2]
    var scoringGroups: [RoundScoringGroupV2]
    var segments: [RoundSegmentV2]
    var scores: [ScoreEntryV2]
}

// MARK: - Result and presentation states

enum SeriesResultStatusV2: String, Codable, CaseIterable {
    case pending
    case processing
    case needsReview = "needs_review"
    case finalized
    case failed
}

struct SeriesRoundResultStateV2: FirebaseSubcollectable {
    var id: String
    var status: SeriesResultStatusV2
    var latestGenerationID: String?
    var semanticHash: String?
    var failureCode: String?
    var finalizedAt: Time?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 2

    static var parentCollection: String { V2Collection.series }
    static var subcollectionName: String { SeriesV2Subcollection.roundResultStates.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, status, schema
        case latestGenerationID = "latest_generation_id"
        case semanticHash = "semantic_hash"
        case failureCode = "failure_code"
        case finalizedAt = "finalized_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

enum SeriesRoundPresentationStateV2: String, Equatable {
    case pending
    case scheduled
    case lobby
    case live
    case completed
    case needsReview = "needs_review"
    case finalized
    case canceled
    case archived
}

enum SeriesRoundPresentationResolverV2 {
    static let lobbyWindow: TimeInterval = 24 * 60 * 60

    static func resolve(
        round: RoundV2,
        resultState: SeriesRoundResultStateV2? = nil,
        now: Date = Date()
    ) -> SeriesRoundPresentationStateV2 {
        if round.status == .archived { return .archived }
        if round.isCanceled { return .canceled }
        if round.status == .live { return .live }
        if round.status == .completed {
            switch resultState?.status {
            case .needsReview: return .needsReview
            case .finalized: return .finalized
            default: return .completed
            }
        }
        if round.seriesContext?.lobbyActivatedAt != nil { return .lobby }
        guard let scheduledAt = round.schedule?.scheduledAt.unix else { return .pending }
        return scheduledAt - now.timeIntervalSince1970 <= lobbyWindow ? .lobby : .scheduled
    }
}

// MARK: - Version routing and command contracts

enum SeriesRecord {
    case v1(Series)
    case v2(SeriesV2)

    var id: String {
        switch self {
        case .v1(let value): return value.id
        case .v2(let value): return value.id
        }
    }

    var name: String {
        switch self {
        case .v1(let value): return value.name
        case .v2(let value): return value.name
        }
    }

    var status: SeriesStatus {
        switch self {
        case .v1(let value): return value.status
        case .v2(let value): return value.status
        }
    }

    var lastUpdatedAt: Time {
        switch self {
        case .v1(let value): return value.lastUpdatedAt
        case .v2(let value): return value.lastUpdatedAt
        }
    }
}

enum SeriesVersionSelectorV2 {
    /// Returns one visible record for a logical Series. A migrated V2 copy is hidden
    /// until the server-owned route becomes active; active routes never fall back to stale V1.
    static func select(
        v1: Series?,
        v2: SeriesV2?,
        routing: SeriesRoutingV2? = nil
    ) -> SeriesRecord? {
        guard let v2 else { return routing?.phase == .active ? nil : v1.map(SeriesRecord.v1) }
        guard v2.migration != nil || routing != nil else { return .v2(v2) }

        let phase = routing?.phase ?? v2.migration?.phase ?? .copying
        if phase.prefersV2 { return .v2(v2) }
        return v1.map(SeriesRecord.v1)
    }
}

enum RoundRecord {
    case v1(Round)
    case v2(RoundV2)

    var id: String {
        switch self {
        case .v1(let value): return value.id
        case .v2(let value): return value.id
        }
    }
}

struct CreateSeriesRoundV2Command: Hashable, Codable {
    var commandID: String
    var seriesID: String
    var title: String
    var scheduledAt: Time?
    var timeZoneIdentifier: String

    init(
        commandID: String = HackersID.string(),
        seriesID: String,
        title: String,
        scheduledAt: Time? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.commandID = commandID
        self.seriesID = seriesID
        self.title = title
        self.scheduledAt = scheduledAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case title
        case commandID = "command_id"
        case seriesID = "series_id"
        case scheduledAt = "scheduled_at"
        case timeZoneIdentifier = "time_zone_identifier"
    }
}

struct CreateSeriesV2Command: Hashable, Codable {
    var commandID: String
    var name: String
    var description: String?
    var visibility: SeriesVisibility
    var settings: SeriesSettingsV2
    var commissionerPlayerID: String?
    var commissionerName: Name
    var minimumClientVersion: String?

    init(
        commandID: String = HackersID.string(),
        name: String,
        description: String? = nil,
        visibility: SeriesVisibility = .privateSeries,
        settings: SeriesSettingsV2 = .init(),
        commissionerPlayerID: String? = nil,
        commissionerName: Name = .init(),
        minimumClientVersion: String? = nil
    ) {
        self.commandID = commandID
        self.name = name
        self.description = description
        self.visibility = visibility
        self.settings = settings
        self.commissionerPlayerID = commissionerPlayerID
        self.commissionerName = commissionerName
        self.minimumClientVersion = minimumClientVersion
    }

    enum CodingKeys: String, CodingKey {
        case name, description, visibility, settings
        case commandID = "command_id"
        case commissionerPlayerID = "commissioner_player_id"
        case commissionerName = "commissioner_name"
        case minimumClientVersion = "minimum_client_version"
    }
}

struct TransitionRoundV2Command: Hashable, Codable {
    var commandID: String
    var roundID: String
    var expectedRevision: Int
    var targetStatus: RoundStatusV2

    enum CodingKeys: String, CodingKey {
        case commandID = "command_id"
        case roundID = "round_id"
        case expectedRevision = "expected_revision"
        case targetStatus = "target_status"
    }
}

struct ApplySeriesDefaultsV2Command: Hashable, Codable {
    var commandID: String
    var roundID: String
    var expectedRevision: Int

    init(
        commandID: String = HackersID.string(),
        roundID: String,
        expectedRevision: Int
    ) {
        self.commandID = commandID
        self.roundID = roundID
        self.expectedRevision = expectedRevision
    }

    enum CodingKeys: String, CodingKey {
        case commandID = "command_id"
        case roundID = "round_id"
        case expectedRevision = "expected_revision"
    }
}

struct AdoptRoundIntoSeriesV2Command: Hashable, Codable {
    var commandID: String
    var roundID: String
    var seriesID: String
    var expectedRevision: Int
    var applySeriesDefaults: Bool

    init(
        commandID: String = HackersID.string(),
        roundID: String,
        seriesID: String,
        expectedRevision: Int,
        applySeriesDefaults: Bool = false
    ) {
        self.commandID = commandID
        self.roundID = roundID
        self.seriesID = seriesID
        self.expectedRevision = expectedRevision
        self.applySeriesDefaults = applySeriesDefaults
    }

    enum CodingKeys: String, CodingKey {
        case commandID = "command_id"
        case roundID = "round_id"
        case seriesID = "series_id"
        case expectedRevision = "expected_revision"
        case applySeriesDefaults = "apply_series_defaults"
    }
}

struct SetSeriesMigrationPhaseV2Command: Hashable, Codable {
    var commandID: String
    var seriesID: String
    var expectedRevision: Int
    var targetPhase: SeriesMigrationPhaseV2

    init(
        commandID: String = HackersID.string(),
        seriesID: String,
        expectedRevision: Int,
        targetPhase: SeriesMigrationPhaseV2
    ) {
        self.commandID = commandID
        self.seriesID = seriesID
        self.expectedRevision = expectedRevision
        self.targetPhase = targetPhase
    }

    enum CodingKeys: String, CodingKey {
        case commandID = "command_id"
        case seriesID = "series_id"
        case expectedRevision = "expected_revision"
        case targetPhase = "target_phase"
    }
}

struct SeriesDefaultsPreviewV2: Hashable {
    var appliedRevision: Int
    var availableRevision: Int
    var changedFields: [String]

    var hasChanges: Bool { changedFields.isPopulated || appliedRevision != availableRevision }

    static func make(round: RoundV2, series: SeriesV2) -> Self {
        var fields: [String] = []
        let defaults = series.settings.roundDefaults
        if round.configuration != defaults.configuration { fields.append("configuration") }
        if round.seriesContext?.rules != defaults.rules { fields.append("series rules") }
        return .init(
            appliedRevision: round.seriesContext?.appliedDefaultsRevision ?? 0,
            availableRevision: series.settings.roundDefaultsRevision,
            changedFields: fields
        )
    }
}

struct V2CommandResponse: Hashable, Codable {
    var ok: Bool
    var commandID: String
    var entityID: String
    var revision: Int
    var replayed: Bool

    enum CodingKeys: String, CodingKey {
        case ok, revision, replayed
        case commandID = "command_id"
        case entityID = "entity_id"
    }
}

enum SeriesRoundV2Error: Error, LocalizedError {
    case malformedCommandResponse
    case unresolvedToken

    var errorDescription: String? {
        switch self {
        case .malformedCommandResponse:
            return "The server returned an invalid Series/Round V2 command response."
        case .unresolvedToken:
            return "No V1 or V2 Series/Round matched that identifier or share code."
        }
    }
}
