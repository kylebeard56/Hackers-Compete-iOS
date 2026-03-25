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

enum SeriesAwardsStatus: String, CaseIterable, Codable {
    case pending
    case needsReview = "needs_review"
    case finalized
}

enum SeriesPodGroupingStrategy: String, CaseIterable, Codable {
    case disabled
    case alignByIndex = "align_by_index"
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
}

enum SeriesOutcomeSource: String, CaseIterable, Codable {
    case roundIndividualLeaderboard = "round_individual_leaderboard"
    case roundTeamLeaderboard = "round_team_leaderboard"
    case roundMatchResult = "round_match_result"
    case manual
}

enum SeriesScoringProfileKind: String, CaseIterable, Codable {
    case placement
    case winTieLoss = "win_tie_loss"
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
    var sequentialTeeStartsEnabled: Bool?
    var matchupMode: SeriesMatchupMode
    var podGroupingStrategy: SeriesPodGroupingStrategy
    var teamAssignmentMode: SeriesTeamAssignmentMode
    var teeGroupMode: SeriesTeeGroupMode
    var notes: String?
    var allowCourseOverride: Bool
    var allowFormatOverride: Bool
    var allowLobbyBackPropagation: Bool

    init(
        formatTemplateID: String = FormatTemplateRegistry.strokePlay.id,
        competitionScope: CompetitionScope? = nil,
        teamScoring: RoundTeamScoringConfiguration = .init(),
        matchupResolutionStyle: RoundMatchupResolutionStyle = .roundAggregate,
        sequentialTeeStartsEnabled: Bool? = false,
        matchupMode: SeriesMatchupMode = .field,
        podGroupingStrategy: SeriesPodGroupingStrategy = .disabled,
        teamAssignmentMode: SeriesTeamAssignmentMode = .manual,
        teeGroupMode: SeriesTeeGroupMode = .auto,
        notes: String? = nil,
        allowCourseOverride: Bool = true,
        allowFormatOverride: Bool = true,
        allowLobbyBackPropagation: Bool = true
    ) {
        self.formatTemplateID = formatTemplateID
        self.competitionScope = competitionScope
        self.teamScoring = teamScoring
        self.matchupResolutionStyle = matchupResolutionStyle
        self.sequentialTeeStartsEnabled = sequentialTeeStartsEnabled
        self.matchupMode = matchupMode
        self.podGroupingStrategy = podGroupingStrategy
        self.teamAssignmentMode = teamAssignmentMode
        self.teeGroupMode = teeGroupMode
        self.notes = notes
        self.allowCourseOverride = allowCourseOverride
        self.allowFormatOverride = allowFormatOverride
        self.allowLobbyBackPropagation = allowLobbyBackPropagation
    }

    enum CodingKeys: String, CodingKey {
        case formatTemplateID = "format_template_id"
        case competitionScope = "competition_scope"
        case teamScoring = "team_scoring"
        case matchupResolutionStyle = "matchup_resolution_style"
        case legacyBestNSelected = "best_n_selected"
        case legacyBestWorstEnabled = "best_worst_enabled"
        case sequentialTeeStartsEnabled = "sequential_tee_starts_enabled"
        case matchupMode = "matchup_mode"
        case podGroupingStrategy = "pod_grouping_strategy"
        case teamAssignmentMode = "team_assignment_mode"
        case teeGroupMode = "tee_group_mode"
        case notes
        case allowCourseOverride = "allow_course_override"
        case allowFormatOverride = "allow_format_override"
        case allowLobbyBackPropagation = "allow_lobby_back_propagation"
    }

    var usesSequentialTeeStarts: Bool {
        sequentialTeeStartsEnabled == true
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
        sequentialTeeStartsEnabled = try c.decodeIfPresent(Bool.self, forKey: .sequentialTeeStartsEnabled) ?? false
        matchupMode = try c.decodeIfPresent(SeriesMatchupMode.self, forKey: .matchupMode) ?? .field
        podGroupingStrategy = try c.decodeIfPresent(SeriesPodGroupingStrategy.self, forKey: .podGroupingStrategy) ?? .disabled
        teamAssignmentMode = try c.decodeIfPresent(SeriesTeamAssignmentMode.self, forKey: .teamAssignmentMode) ?? .manual
        teeGroupMode = try c.decodeIfPresent(SeriesTeeGroupMode.self, forKey: .teeGroupMode) ?? .auto
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        allowCourseOverride = try c.decodeIfPresent(Bool.self, forKey: .allowCourseOverride) ?? true
        allowFormatOverride = try c.decodeIfPresent(Bool.self, forKey: .allowFormatOverride) ?? true
        allowLobbyBackPropagation = try c.decodeIfPresent(Bool.self, forKey: .allowLobbyBackPropagation) ?? true

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
        try c.encodeIfPresent(sequentialTeeStartsEnabled, forKey: .sequentialTeeStartsEnabled)
        try c.encode(matchupMode, forKey: .matchupMode)
        try c.encode(podGroupingStrategy, forKey: .podGroupingStrategy)
        try c.encode(teamAssignmentMode, forKey: .teamAssignmentMode)
        try c.encode(teeGroupMode, forKey: .teeGroupMode)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(allowCourseOverride, forKey: .allowCourseOverride)
        try c.encode(allowFormatOverride, forKey: .allowFormatOverride)
        try c.encode(allowLobbyBackPropagation, forKey: .allowLobbyBackPropagation)
    }
}

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

struct SeriesSettings: Hashable, Codable {
    var defaultCourse: SeriesCourseSelection?
    var defaultCourseRotationMode: SeriesDefaultCourseRotationMode
    var defaultRoundConfig: SeriesRoundConfiguration
    var defaultTeamScoringProfileID: String?
    var defaultIndividualScoringProfileID: String?
    var handicapConfig: SeriesHandicapConfig
    var allowRoundEditsAfterLobbyCreation: Bool
    var autoFinalizeAwardsOnRoundCompletion: Bool
    var allowManualAwardOverrides: Bool
    var attendanceDefault: SeriesRoundAttendanceStatus
    var podGroupingDefault: SeriesPodGroupingStrategy
    var useTeams: Bool
    var useIndividualStandings: Bool
    var useTeamStandings: Bool

    init(
        defaultCourse: SeriesCourseSelection? = nil,
        defaultCourseRotationMode: SeriesDefaultCourseRotationMode = .fixed,
        defaultRoundConfig: SeriesRoundConfiguration = .init(),
        defaultTeamScoringProfileID: String? = nil,
        defaultIndividualScoringProfileID: String? = nil,
        handicapConfig: SeriesHandicapConfig = .init(),
        allowRoundEditsAfterLobbyCreation: Bool = true,
        autoFinalizeAwardsOnRoundCompletion: Bool = false,
        allowManualAwardOverrides: Bool = true,
        attendanceDefault: SeriesRoundAttendanceStatus = .pending,
        podGroupingDefault: SeriesPodGroupingStrategy = .disabled,
        useTeams: Bool = false,
        useIndividualStandings: Bool = true,
        useTeamStandings: Bool = false
    ) {
        self.defaultCourse = defaultCourse
        self.defaultCourseRotationMode = defaultCourseRotationMode
        self.defaultRoundConfig = defaultRoundConfig
        self.defaultTeamScoringProfileID = defaultTeamScoringProfileID
        self.defaultIndividualScoringProfileID = defaultIndividualScoringProfileID
        self.handicapConfig = handicapConfig
        self.allowRoundEditsAfterLobbyCreation = allowRoundEditsAfterLobbyCreation
        self.autoFinalizeAwardsOnRoundCompletion = autoFinalizeAwardsOnRoundCompletion
        self.allowManualAwardOverrides = allowManualAwardOverrides
        self.attendanceDefault = attendanceDefault
        self.podGroupingDefault = podGroupingDefault
        self.useTeams = useTeams
        self.useIndividualStandings = useIndividualStandings
        self.useTeamStandings = useTeamStandings
    }

    enum CodingKeys: String, CodingKey {
        case defaultCourse = "default_course"
        case defaultCourseRotationMode = "default_course_rotation_mode"
        case defaultRoundConfig = "default_round_config"
        case defaultTeamScoringProfileID = "default_team_scoring_profile_id"
        case defaultIndividualScoringProfileID = "default_individual_scoring_profile_id"
        case handicapConfig = "handicap_config"
        case allowRoundEditsAfterLobbyCreation = "allow_round_edits_after_lobby_creation"
        case autoFinalizeAwardsOnRoundCompletion = "auto_finalize_awards_on_round_completion"
        case allowManualAwardOverrides = "allow_manual_award_overrides"
        case attendanceDefault = "attendance_default"
        case podGroupingDefault = "pod_grouping_default"
        case useTeams = "use_teams"
        case useIndividualStandings = "use_individual_standings"
        case useTeamStandings = "use_team_standings"
    }
}

// MARK: - Root series document

struct Series: FirebaseIdentifiable {
    var id: String
    var name: String
    var description: String?
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
}

extension Series {
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
        index: Int = 0,
        isLocked: Bool = false,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.index = index
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, index, schema
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
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
    var isValid: Bool { validTeamPairing || validMemberPairing }
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
    func isActive(at time: Time = .init()) -> Bool {
        startsAt.unix <= time.unix && time.unix < endsAt.unix
    }
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

// MARK: - Handicap

struct SeriesHandicapScore: FirebaseSubcollectable {
    var id: String
    var memberID: String
    var score: Double
    var par: Double
    var holeSegment: HoleSegment
    var source: SeriesHandicapScoreSourceType
    var sourceRoundID: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.series.rawValue }
    static var subcollectionName: String { SeriesSubcollection.handicapScores.rawValue }

    init(
        id: String = "",
        memberID: String = "",
        score: Double = 0,
        par: Double = 0,
        holeSegment: HoleSegment = .front9,
        source: SeriesHandicapScoreSourceType = .baseline,
        sourceRoundID: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.memberID = memberID
        self.score = score
        self.par = par
        self.holeSegment = holeSegment
        self.source = source
        self.sourceRoundID = sourceRoundID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, score, par, source, schema
        case memberID = "member_id"
        case holeSegment = "hole_segment"
        case sourceRoundID = "source_round_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
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
}

// MARK: - Helpers

extension SeriesMember {
    var isOffline: Bool { userID == nil }
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
        let config = GameConfiguration(
            method: requiresTeams ? .aggregate : .individual,
            aggregation: aggregation,
            basis: template.requirements.defaultScoreBasis,
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
