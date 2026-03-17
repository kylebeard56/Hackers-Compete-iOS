//
//  Series.swift
//  Hackers
//
//  Created by Codex on 3/6/26.
//

import Foundation

// MARK: - Firestore shape
//
// series/{seriesId}                         // Series (root)
//   members/{memberId}                      // SeriesMember
//   teams/{teamId}                          // SeriesTeam
//   rounds/{seriesRoundId}                  // SeriesRound (links to rounds/{roundId})
//   scoring-profiles/{profileId}            // SeriesScoringProfile
//   mappings/{mappingId}                    // SeriesRoundMapping
//   point-awards/{awardId}                  // SeriesPointAward (round-level awarded points)
//   standings/{standingId}                  // SeriesStanding (aggregated totals)

enum SeriesSubcollection: String, CaseIterable {
    /// Roster of players that belong to the series.
    case members = "members"

    /// Optional fixed teams used at the series level (e.g. Ryder Cup style).
    case teams = "teams"

    /// Planned or completed rounds that belong to the series schedule.
    case rounds = "rounds"

    /// Reusable points logic (F1, Fibonacci, W/T/L, custom).
    case scoringProfiles = "scoring-profiles"

    /// Mapping from round scoring entities to series competitors.
    case mappings = "mappings"

    /// Immutable point entries awarded per round.
    case pointAwards = "point-awards"

    /// Denormalized aggregate leaderboard for quick reads.
    case standings = "standings"

    /// Handicap scores used for league handicap computation.
    case handicapScores = "handicap-scores"

    /// Attendance responses for upcoming rounds (keyed by roundId_memberId).
    case roundAttendance = "round-attendance"
}

enum SeriesRoundAttendanceStatus: String, CaseIterable, Codable {
    case pending
    case accepted
    case no
}

// MARK: - Root enums

enum SeriesStatus: String, CaseIterable, Codable {
    /// Series being configured; rounds can be planned without being live.
    case draft

    /// Series is currently in play.
    case active

    /// Series finished and standings are frozen.
    case completed

    /// Soft-deleted from normal queries.
    case archived
}

enum SeriesVisibility: String, CaseIterable, Codable {
    /// Only invited members can discover or join.
    case privateSeries = "private"

    /// Publicly discoverable in future list/search surfaces.
    case discoverable
}

enum SeriesFormatStrategy: String, CaseIterable, Codable {
    /// New rounds default to a series-level format, but can still be overridden.
    case defaultFormatWithOverrides = "default_with_overrides"

    /// Every round explicitly chooses its format.
    case choosePerRound = "choose_per_round"
}

enum SeriesCompetitorType: String, CaseIterable, Codable {
    /// Points awarded directly to individual members.
    case member

    /// Points awarded to series teams.
    case team
}

enum SeriesMemberRole: String, CaseIterable, Codable {
    /// Full admin powers for schedule + points finalization.
    case commissioner

    /// Team-level manager for team-based competitions.
    case captain

    /// Default competitor role.
    case member

    /// Read-only role, can follow standings but not compete.
    case spectator
}

// MARK: - Root series document

struct Series: FirebaseIdentifiable {
    /// Stable Firestore document id.
    var id: String

    /// Display title shown in dashboard lists and headers.
    var name: String

    /// Optional rich context (trip name, league season, rules summary).
    var description: String?

    /// Authenticated user who administratively owns the series.
    var commissionerUserID: String

    /// Player profile id used for scoring identity of commissioner.
    var commissionerPlayerID: String?

    /// Denormalized member player IDs for fast `arrayContains` series fetches.
    var players: [String]

    /// Current lifecycle state.
    var status: SeriesStatus

    /// Access/discovery policy.
    var visibility: SeriesVisibility

    /// How format defaults are applied during round creation.
    var formatStrategy: SeriesFormatStrategy

    /// Defaults applied when creating new rounds in this series.
    var defaults: SeriesDefaults

    /// League handicap configuration and tunable parameters.
    var handicapConfig: SeriesHandicapConfig

    /// Scheduled start timestamp for calendar and sorting.
    var startsAt: Time?

    /// Optional planned/actual end timestamp.
    var endsAt: Time?

    /// Cached number of rounds planned in this series.
    var roundCount: Int

    /// Cached number of rounds that are fully complete.
    var completedRoundCount: Int

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Schema version for migration handling.
    var schema: Int = 1

    /// Collection path for root series docs.
    var collection: String { Collections.series.rawValue }

    init(
        id: String = "",
        name: String = "",
        description: String? = nil,
        commissionerUserID: String = "",
        commissionerPlayerID: String? = nil,
        players: [String] = [],
        status: SeriesStatus = .draft,
        visibility: SeriesVisibility = .privateSeries,
        formatStrategy: SeriesFormatStrategy = .defaultFormatWithOverrides,
        defaults: SeriesDefaults = .init(),
        handicapConfig: SeriesHandicapConfig = .init(),
        startsAt: Time? = nil,
        endsAt: Time? = nil,
        roundCount: Int = 0,
        completedRoundCount: Int = 0,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.commissionerUserID = commissionerUserID
        self.commissionerPlayerID = commissionerPlayerID
        self.players = players
        self.status = status
        self.visibility = visibility
        self.formatStrategy = formatStrategy
        self.defaults = defaults
        self.handicapConfig = handicapConfig
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.roundCount = roundCount
        self.completedRoundCount = completedRoundCount
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, players, status, visibility, defaults, schema
        case handicapConfig = "handicap_config"
        case commissionerUserID = "commissioner_user_id"
        case commissionerPlayerID = "commissioner_player_id"
        case formatStrategy = "format_strategy"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case roundCount = "round_count"
        case completedRoundCount = "completed_round_count"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

// MARK: - Default Course

struct SeriesDefaultCourse: Hashable, Codable {
    var courseID: String
    var cachedName: String
    var defaultTeeID: String

    init(
        courseID: String = "",
        cachedName: String = "",
        defaultTeeID: String = ""
    ) {
        self.courseID = courseID
        self.cachedName = cachedName
        self.defaultTeeID = defaultTeeID
    }

    enum CodingKeys: String, CodingKey {
        case courseID = "course_id"
        case cachedName = "cached_name"
        case defaultTeeID = "default_tee_id"
    }
}

struct SeriesDefaults: Hashable, Codable {
    /// Preferred round format for new rounds.
    var defaultFormat: GameFormat?

    /// If set, new rounds start with this scoring profile.
    var defaultScoringProfileID: String?

    /// Snapshot fallback so defaults still render if profile doc is deleted.
    var defaultScoringProfileSnapshot: SeriesScoringProfile?

    /// Series-level default course and tee box.
    var defaultCourse: SeriesDefaultCourse?

    /// True means round editors can override default format/profile.
    var allowRoundOverrides: Bool

    /// True means commissioner can manually modify awarded points after compute.
    var allowManualPointOverrides: Bool

    /// If true, points are auto-generated when linked round completes.
    var autoFinalizeAwardsOnRoundCompletion: Bool

    /// When true, commissioner skipped setting default course; treat checklist as complete.
    var skippedDefaultCourse: Bool

    init(
        defaultFormat: GameFormat? = nil,
        defaultScoringProfileID: String? = nil,
        defaultScoringProfileSnapshot: SeriesScoringProfile? = nil,
        defaultCourse: SeriesDefaultCourse? = nil,
        allowRoundOverrides: Bool = true,
        allowManualPointOverrides: Bool = true,
        autoFinalizeAwardsOnRoundCompletion: Bool = false,
        skippedDefaultCourse: Bool = false
    ) {
        self.defaultFormat = defaultFormat
        self.defaultScoringProfileID = defaultScoringProfileID
        self.defaultScoringProfileSnapshot = defaultScoringProfileSnapshot
        self.defaultCourse = defaultCourse
        self.allowRoundOverrides = allowRoundOverrides
        self.allowManualPointOverrides = allowManualPointOverrides
        self.autoFinalizeAwardsOnRoundCompletion = autoFinalizeAwardsOnRoundCompletion
        self.skippedDefaultCourse = skippedDefaultCourse
    }

    enum CodingKeys: String, CodingKey {
        case defaultFormat = "default_format"
        case defaultScoringProfileID = "default_scoring_profile_id"
        case defaultScoringProfileSnapshot = "default_scoring_profile_snapshot"
        case defaultCourse = "default_course"
        case allowRoundOverrides = "allow_round_overrides"
        case allowManualPointOverrides = "allow_manual_point_overrides"
        case autoFinalizeAwardsOnRoundCompletion = "auto_finalize_awards_on_round_completion"
        case skippedDefaultCourse = "skipped_default_course"
    }
}

extension SeriesDefaults {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultFormat = try c.decodeIfPresent(GameFormat.self, forKey: .defaultFormat)
        defaultScoringProfileID = try c.decodeIfPresent(String.self, forKey: .defaultScoringProfileID)
        defaultScoringProfileSnapshot = try c.decodeIfPresent(SeriesScoringProfile.self, forKey: .defaultScoringProfileSnapshot)
        defaultCourse = try c.decodeIfPresent(SeriesDefaultCourse.self, forKey: .defaultCourse)
        allowRoundOverrides = try c.decodeIfPresent(Bool.self, forKey: .allowRoundOverrides) ?? true
        allowManualPointOverrides = try c.decodeIfPresent(Bool.self, forKey: .allowManualPointOverrides) ?? true
        autoFinalizeAwardsOnRoundCompletion = try c.decodeIfPresent(Bool.self, forKey: .autoFinalizeAwardsOnRoundCompletion) ?? false
        skippedDefaultCourse = try c.decodeIfPresent(Bool.self, forKey: .skippedDefaultCourse) ?? false
    }
}

// MARK: - Members

struct SeriesMember: FirebaseSubcollectable {
    /// Stable subcollection doc id.
    var id: String

    /// Related authenticated user id, if member is online.
    var userID: String?

    /// Player profile used for scoring identity.
    var playerID: String?

    /// Denormalized display name for fast list rendering.
    var name: Name

    /// Authorization and series responsibility level.
    var role: SeriesMemberRole

    /// Optional fixed series team assignment.
    var teamID: String?

    /// Overrides the series default tee box (e.g., women's tees).
    var defaultTeeBoxID: String?

    /// Sort priority used for deterministic standings or drafts.
    var seedIndex: Int?

    /// Member status flag without deleting historical data.
    var isActive: Bool

    /// When the member joined the series.
    var joinedAt: Time

    /// Optional timestamp when member left/deactivated.
    var leftAt: Time?

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.members.rawValue }

    init(
        id: String = "",
        userID: String? = nil,
        playerID: String? = nil,
        name: Name = .init(),
        role: SeriesMemberRole = .member,
        teamID: String? = nil,
        defaultTeeBoxID: String? = nil,
        seedIndex: Int? = nil,
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
        self.seedIndex = seedIndex
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
        case seedIndex = "seed_index"
        case isActive = "is_active"
        case joinedAt = "joined_at"
        case leftAt = "left_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Teams

struct SeriesTeam: FirebaseSubcollectable, IndexIterable {
    /// Stable team doc id.
    var id: String

    /// Team display name.
    var name: String

    /// Visual color token (e.g. `red`, `blue`, etc.).
    var color: String

    /// Explicit order for UI.
    var index: Int

    /// Active player IDs in this series team.
    var memberPlayerIDs: [String]

    /// True locks membership except commissioner edits.
    var isLocked: Bool

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.teams.rawValue }

    init(
        id: String = "",
        name: String = "",
        color: String = "",
        index: Int = 0,
        memberPlayerIDs: [String] = [],
        isLocked: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.index = index
        self.memberPlayerIDs = memberPlayerIDs
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, index, schema
        case memberPlayerIDs = "member_player_ids"
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Round schedule

enum SeriesRoundStatus: String, CaseIterable, Codable {
    /// Slot exists in schedule but round not yet created.
    case planned

    /// Linked round exists and is in lobby setup.
    case lobby

    /// Linked round is currently in progress.
    case live

    /// Linked round completed, but points may still be pending finalization.
    case complete

    /// Round slot cancelled from this series.
    case canceled
}

struct SeriesRound: FirebaseSubcollectable, IndexIterable {
    /// Stable series-round doc id.
    var id: String

    /// Human-friendly title (e.g. "Friday Four-Ball").
    var title: String

    /// Stable sequence position for the schedule.
    var index: Int

    /// Linked `rounds/{roundId}` document.
    var roundID: String?

    /// Current schedule/round lifecycle state.
    var status: SeriesRoundStatus

    /// Planned tee-off timestamp.
    var scheduledAt: Time?

    /// Actual round start timestamp.
    var startedAt: Time?

    /// Actual round completion timestamp.
    var completedAt: Time?

    /// Format snapshot used by this round slot.
    var format: GameFormat

    /// Selected scoring profile id.
    var scoringProfileID: String?

    /// Snapshot of scoring profile for historical stability.
    var scoringProfileSnapshot: SeriesScoringProfile?

    /// Timestamp when round awards were last finalized into the ledger.
    var awardsFinalizedAt: Time?

    /// Optional commissioner notes/instructions for this round.
    var notes: String?

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.rounds.rawValue }

    init(
        id: String = "",
        title: String = "",
        index: Int = 0,
        roundID: String? = nil,
        status: SeriesRoundStatus = .planned,
        scheduledAt: Time? = nil,
        startedAt: Time? = nil,
        completedAt: Time? = nil,
        format: GameFormat = .strokePlay,
        scoringProfileID: String? = nil,
        scoringProfileSnapshot: SeriesScoringProfile? = nil,
        awardsFinalizedAt: Time? = nil,
        notes: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.title = title
        self.index = index
        self.roundID = roundID
        self.status = status
        self.scheduledAt = scheduledAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.format = format
        self.scoringProfileID = scoringProfileID
        self.scoringProfileSnapshot = scoringProfileSnapshot
        self.awardsFinalizedAt = awardsFinalizedAt
        self.notes = notes
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, title, index, status, format, notes, schema
        case roundID = "round_id"
        case scheduledAt = "scheduled_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case scoringProfileID = "scoring_profile_id"
        case scoringProfileSnapshot = "scoring_profile_snapshot"
        case awardsFinalizedAt = "awards_finalized_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Round Attendance

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
    static var subcollectionName: String { SeriesSubcollection.roundAttendance.rawValue }

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

// MARK: - Scoring profile

enum SeriesOutcomeSource: String, CaseIterable, Codable {
    /// Use individual leaderboard from linked round.
    case roundIndividualLeaderboard = "round_individual_leaderboard"

    /// Use team leaderboard from linked round.
    case roundTeamLeaderboard = "round_team_leaderboard"

    /// Use explicit match winner/tie outcomes.
    case roundMatchResult = "round_match_result"

    /// Commissioner enters/approves placements manually.
    case manual
}

enum SeriesTieHandling: String, CaseIterable, Codable {
    /// Equal split across tied competitors (e.g. 2nd/3rd pooled).
    case splitPoints = "split_points"

    /// All tied competitors receive same place points, then next place skipped.
    case samePointsSkipNext = "same_points_skip_next"

    /// No automatic tie math; commissioner must finalize manually.
    case commissionerDecision = "commissioner_decision"
}

enum SeriesPointsTemplate: String, CaseIterable, Codable {
    case custom
    case winTieLoss = "win_tie_loss"
    case fibonacci
    case formula1
}

struct SeriesPlacementRule: Hashable, Codable, Identifiable {
    /// Stable rule id for editing/reordering.
    var id: String

    /// Inclusive start rank (1 = first place).
    var rankStart: Int

    /// Inclusive end rank (same as `rankStart` for single-place rule).
    var rankEnd: Int

    /// Points awarded for each qualifying rank after tie policy.
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

enum SeriesBonusRuleType: String, CaseIterable, Codable {
    /// Flat bonus for round participation.
    case participation

    /// Manual commissioner-entered bonus.
    case manual
}

struct SeriesBonusRule: Hashable, Codable, Identifiable {
    /// Stable bonus rule id.
    var id: String

    /// Type of bonus behavior.
    var type: SeriesBonusRuleType

    /// Signed points value (+ bonus / - penalty).
    var points: Double

    /// Optional display label shown in finalization UI.
    var label: String

    /// Whether the rule is active for calculations.
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

struct SeriesScoringProfile: FirebaseSubcollectable {
    /// Stable profile id.
    var id: String

    /// Profile name visible in picker (e.g. "F1 Top 10").
    var name: String

    /// Optional summary/help text.
    var summary: String?

    /// Origin template before customization.
    var template: SeriesPointsTemplate

    /// Source of outcome data from the linked round.
    var outcomeSource: SeriesOutcomeSource

    /// Whether points are awarded to series members or teams.
    var competitorType: SeriesCompetitorType

    /// Tie behavior for point allocation.
    var tieHandling: SeriesTieHandling

    /// Placement->points rules in priority order.
    var placementRules: [SeriesPlacementRule]

    /// Optional additive rules for bonus/penalty scoring.
    var bonusRules: [SeriesBonusRule]

    /// If true, profile is available for default assignment.
    var isDefault: Bool

    /// Soft archive flag for profile lifecycle management.
    var isArchived: Bool

    /// Player id of profile creator/editor.
    var createdByPlayerID: String?

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.scoringProfiles.rawValue }

    init(
        id: String = "",
        name: String = "",
        summary: String? = nil,
        template: SeriesPointsTemplate = .custom,
        outcomeSource: SeriesOutcomeSource = .roundIndividualLeaderboard,
        competitorType: SeriesCompetitorType = .member,
        tieHandling: SeriesTieHandling = .splitPoints,
        placementRules: [SeriesPlacementRule] = [],
        bonusRules: [SeriesBonusRule] = [],
        isDefault: Bool = false,
        isArchived: Bool = false,
        createdByPlayerID: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.template = template
        self.outcomeSource = outcomeSource
        self.competitorType = competitorType
        self.tieHandling = tieHandling
        self.placementRules = placementRules
        self.bonusRules = bonusRules
        self.isDefault = isDefault
        self.isArchived = isArchived
        self.createdByPlayerID = createdByPlayerID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, summary, template, schema
        case outcomeSource = "outcome_source"
        case competitorType = "competitor_type"
        case tieHandling = "tie_handling"
        case placementRules = "placement_rules"
        case bonusRules = "bonus_rules"
        case isDefault = "is_default"
        case isArchived = "is_archived"
        case createdByPlayerID = "created_by_player_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

// MARK: - Mapping from round entities to series competitors

enum SeriesRoundOwnerType: String, CaseIterable, Codable {
    /// Mapping source points at a round participant id.
    case participant

    /// Mapping source points at a round team id.
    case team
}

struct SeriesRoundMapping: FirebaseSubcollectable {
    /// Stable mapping doc id.
    var id: String

    /// Related series round id.
    var seriesRoundID: String

    /// Type of round entity used as source.
    var roundOwnerType: SeriesRoundOwnerType

    /// Source id in linked round (`participant.id` or `team.id`).
    var roundOwnerID: String

    /// Destination competitor scope for standings.
    var competitorType: SeriesCompetitorType

    /// Destination competitor id in series space (`member.id` or `team.id`).
    var competitorID: String

    /// Fractional weight for split mappings (default 1.0).
    var weight: Double

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
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

// MARK: - Award ledger + standings

enum SeriesAwardSource: String, CaseIterable, Codable {
    /// Computed directly from scoring profile + round outcome.
    case automatic

    /// Commissioner changed computed values.
    case commissionerOverride = "commissioner_override"

    /// Fully manual entry (no compute source).
    case manual
}

struct SeriesPointAward: FirebaseSubcollectable {
    /// Stable award id; deterministic ids recommended (`{seriesRoundID}_{competitorID}`).
    var id: String

    /// Owning series round id.
    var seriesRoundID: String

    /// Competitor scope for this award row.
    var competitorType: SeriesCompetitorType

    /// Competitor id receiving points.
    var competitorID: String

    /// Denormalized display name for historical readability.
    var competitorName: String

    /// Final round placement used for this award.
    var placement: Int?

    /// Number of competitors tied at this placement.
    var tieGroupSize: Int?

    /// Base points from placement rules.
    var basePoints: Double

    /// Extra manual/bonus/penalty points.
    var bonusPoints: Double

    /// Total points = base + bonus.
    var totalPoints: Double

    /// How this award was produced.
    var source: SeriesAwardSource

    /// Optional round source id (`participant.id` / `team.id`) used in compute.
    var roundOwnerID: String?

    /// Optional justification for override/manual awards.
    var reason: String?

    /// Player id who finalized this award.
    var awardedByPlayerID: String?

    /// Timestamp when points were finalized.
    var awardedAt: Time

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.pointAwards.rawValue }

    init(
        id: String = "",
        seriesRoundID: String = "",
        competitorType: SeriesCompetitorType = .member,
        competitorID: String = "",
        competitorName: String = "",
        placement: Int? = nil,
        tieGroupSize: Int? = nil,
        basePoints: Double = 0,
        bonusPoints: Double = 0,
        totalPoints: Double = 0,
        source: SeriesAwardSource = .automatic,
        roundOwnerID: String? = nil,
        reason: String? = nil,
        awardedByPlayerID: String? = nil,
        awardedAt: Time = .init(),
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.seriesRoundID = seriesRoundID
        self.competitorType = competitorType
        self.competitorID = competitorID
        self.competitorName = competitorName
        self.placement = placement
        self.tieGroupSize = tieGroupSize
        self.basePoints = basePoints
        self.bonusPoints = bonusPoints
        self.totalPoints = totalPoints
        self.source = source
        self.roundOwnerID = roundOwnerID
        self.reason = reason
        self.awardedByPlayerID = awardedByPlayerID
        self.awardedAt = awardedAt
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, placement, source, reason, schema
        case seriesRoundID = "series_round_id"
        case competitorType = "competitor_type"
        case competitorID = "competitor_id"
        case competitorName = "competitor_name"
        case tieGroupSize = "tie_group_size"
        case basePoints = "base_points"
        case bonusPoints = "bonus_points"
        case totalPoints = "total_points"
        case roundOwnerID = "round_owner_id"
        case awardedByPlayerID = "awarded_by_player_id"
        case awardedAt = "awarded_at"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

struct SeriesStanding: FirebaseSubcollectable {
    /// Stable standing id; recommended as competitor id.
    var id: String

    /// Competitor scope.
    var competitorType: SeriesCompetitorType

    /// Competitor id this row represents.
    var competitorID: String

    /// Denormalized display name for quick leaderboard rendering.
    var competitorName: String

    /// Aggregated points total across finalized awards.
    var totalPoints: Double

    /// Number of rounds with non-zero points for this competitor.
    var roundsCounted: Int

    /// Count of first-place finishes.
    var wins: Int

    /// Count of top-3 finishes.
    var topThrees: Int

    /// Most recent placement.
    var lastPlacement: Int?

    /// Best placement in series so far.
    var bestPlacement: Int?

    /// Current leaderboard rank.
    var rank: Int?

    /// Created timestamp.
    var createdAt: Time

    /// Last mutation timestamp.
    var lastUpdatedAt: Time

    /// Parent series id.
    var parentID: String

    /// Schema version for migration handling.
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.standings.rawValue }

    init(
        id: String = "",
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

// MARK: - Handicap configuration

struct SeriesHandicapConfig: Hashable, Codable {
    var isEnabled: Bool
    var config: HandicapComputationConfigDTO

    init(
        isEnabled: Bool = false,
        config: HandicapComputationConfigDTO = .league2025
    ) {
        self.isEnabled = isEnabled
        self.config = config
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case config
    }
}

// MARK: - Member handicap (embedded on SeriesMember or standalone)

struct SeriesMemberHandicap: Hashable, Codable, Identifiable {
    var id: String
    var memberID: String
    var computedIndex: Double?
    var overrideIndex: Double?
    var isOverridden: Bool

    var effectiveIndex: Double? {
        isOverridden ? overrideIndex : computedIndex
    }

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

    enum CodingKeys: String, CodingKey {
        case id
        case memberID = "member_id"
        case computedIndex = "computed_index"
        case overrideIndex = "override_index"
        case isOverridden = "is_overridden"
    }
}

// MARK: - Handicap scores

enum SeriesHandicapScoreSource: Hashable, Codable {
    case baseline
    case round(roundID: String)

    enum CodingKeys: String, CodingKey {
        case type, roundID = "round_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        if type == "round", let rid = try c.decodeIfPresent(String.self, forKey: .roundID) {
            self = .round(roundID: rid)
        } else {
            self = .baseline
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .baseline:
            try c.encode("baseline", forKey: .type)
        case .round(let roundID):
            try c.encode("round", forKey: .type)
            try c.encode(roundID, forKey: .roundID)
        }
    }
}

struct SeriesHandicapScore: FirebaseSubcollectable {
    var id: String
    var memberID: String
    var score: Double
    var holeSegment: HoleSegment
    var par: Double
    var source: SeriesHandicapScoreSource
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { "series" }
    static var subcollectionName: String { SeriesSubcollection.handicapScores.rawValue }

    init(
        id: String = "",
        memberID: String = "",
        score: Double = 0,
        holeSegment: HoleSegment = .front9,
        par: Double = 36,
        source: SeriesHandicapScoreSource = .baseline,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.memberID = memberID
        self.score = score
        self.holeSegment = holeSegment
        self.par = par
        self.source = source
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, score, source, par, schema
        case memberID = "member_id"
        case holeSegment = "hole_segment"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

