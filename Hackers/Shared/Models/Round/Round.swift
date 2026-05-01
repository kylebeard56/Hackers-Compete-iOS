//
//  Round.swift
//  Hackers
//
//  Created by Kyle Beard on 8/20/25.
//
//  rounds-v1/{roundId}                      // Round (root doc; small, static-ish)
//    participants/{participantId}           // RoundParticipant (round-local snapshot)
//    teams/{teamId}                         // RoundTeam (optional; used for colors/grouping)
//    groups/{groupId}                       // TeeTimeGroup (tee sheet / shotgun)
//    scores/{scoreId}                       // ScoreEntry (flexible owner: individual or team)
//    segments/{segmentId}                   // RoundSegment (tracks format/team changes mid-round)

import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import SwiftUI

// MARK: - Storage Asset

struct StorageAsset: Hashable, Codable {
    var id: String
    /// Relative path within the Firebase Storage bucket.
    /// e.g. "scorecards/{roundID}/{playerID}.jpg"
    /// Bucket root: gs://hackers-compete-sandbox.firebasestorage.app
    var path: String
    var lastModifiedAt: Time

    enum CodingKeys: String, CodingKey {
        case id, path
        case lastModifiedAt = "last_modified_at"
    }
}

// MARK: - Round Completion

enum RoundCompletionType: String, Codable {
    case signedScorecard = "signed_scorecard"
    case keepOpen = "keep_open"
    case commissionerOverride = "commissioner_override"
}

struct CompletedPlayer: Hashable, Codable {
    var playerID: String
    /// Denormalized display name so the dashboard prompt can show a name without an extra fetch.
    var playerDisplayName: String?
    var completedAt: Time
    var type: RoundCompletionType
    var scorecardStorageID: StorageAsset?

    enum CodingKeys: String, CodingKey {
        case type
        case playerID = "player_id"
        case playerDisplayName = "player_display_name"
        case completedAt = "completed_at"
        case scorecardStorageID = "scorecard_storage_id"
    }
}

//  MARK: - Subcollections

enum RoundSubcollection: String, CaseIterable {
    case participants = "participants"
    case teams = "teams"
    case teeGroups = "tee-groups"
    case scoringGroups = "scoring-groups"
    case scores = "scores"
    case segments = "segments"
}

struct Round: FirebaseIdentifiable {
    var id: String
    var shareCode: String
    var createdBy: String
    var status: RoundStatus
    var configuration: RoundConfiguration
    var players: [String]
    var completedPlayers: [CompletedPlayer]
    var createdAt: Time
    var lastUpdatedAt: Time
    
    var collection: String { Collections.rounds.name }
    var schema: Int = 1
    
    init(
        id: String = "",
        shareCode: String = "",
        createdBy: String = "",
        status: RoundStatus = .lobby,
        players: [String] = [],
        completedPlayers: [CompletedPlayer] = [],
        configuration: RoundConfiguration = .init(),
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.shareCode = shareCode
        self.createdBy = createdBy
        self.status = status
        self.players = players
        self.completedPlayers = completedPlayers
        self.configuration = configuration
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, status, players, configuration, schema
        case shareCode = "share_code"
        case createdBy = "created_by"
        case completedPlayers = "completed_players"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        shareCode = try c.decode(String.self, forKey: .shareCode)
        createdBy = try c.decode(String.self, forKey: .createdBy)
        status = try c.decode(RoundStatus.self, forKey: .status)
        configuration = try c.decode(RoundConfiguration.self, forKey: .configuration)
        players = try c.decode([String].self, forKey: .players)
        completedPlayers = try c.decodeIfPresent([CompletedPlayer].self, forKey: .completedPlayers) ?? []
        createdAt = try c.decode(Time.self, forKey: .createdAt)
        lastUpdatedAt = try c.decode(Time.self, forKey: .lastUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(shareCode, forKey: .shareCode)
        try c.encode(createdBy, forKey: .createdBy)
        try c.encode(status, forKey: .status)
        try c.encode(configuration, forKey: .configuration)
        try c.encode(players, forKey: .players)
        try c.encode(completedPlayers, forKey: .completedPlayers)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
}

enum RoundStatus: String, Codable {
    /// Pre-round game lobby to configure
    case lobby
    
    /// Active scorekeeping
    case live
    
    /// Segment of live where mutability is not allowed while configuration changes occur.
    case paused
    
    /// Finshed and no longer mutable. Scoring may or may not have been fully provided.
    case complete
    
    /// Soft deleted and therefore hidden from queries. Only settable by the creator.
    case archived
}

enum RoundTeamScoringMode: String, Codable, CaseIterable {
    case all
    case bestN = "best_n"
    case worstN = "worst_n"
}

enum RoundMatchupResolutionStyle: String, Codable, CaseIterable {
    case roundAggregate = "round_aggregate"
}

enum RoundScoreOwnerScope: String, Codable, CaseIterable {
    case individual
    case partnership
    case teeGroup = "tee_group"
}

enum ScoringSelectionDomain: String, Codable, CaseIterable {
    case participant
    case team
    case partnership
    case teeGroup = "tee_group"
}

enum RoundMatchupScoringStyle: String, Codable, CaseIterable {
    case aggregateRoundTotal = "aggregate_round_total"
    case holeByHolePoints = "hole_by_hole_points"
}

enum RoundVegasMode: String, Codable, CaseIterable {
    case exactPair = "exact_pair"
    case partnershipAggregate = "partnership_aggregate"
    case selectedPair = "selected_pair"
}

enum RoundVegasSelectionRule: String, Codable, CaseIterable {
    case best2 = "best_2"
    case worst2 = "worst_2"
    case bestAndWorst = "best_and_worst"
}

enum RoundScoreInputMode: String, Codable {
    case strokes
    case friendlyRelativeToPar = "friendly_relative_to_par"
}

struct RoundTeamScoringConfiguration: Hashable, Codable {
    var mode: RoundTeamScoringMode
    var count: Int
    var scope: AggregationScope

    init(
        mode: RoundTeamScoringMode = .all,
        count: Int = 1,
        scope: AggregationScope = .perHole
    ) {
        self.mode = mode
        self.count = count
        self.scope = scope
    }

    enum CodingKeys: String, CodingKey {
        case mode, count, scope
    }

    var isCountedSelection: Bool {
        mode != .all
    }
}

struct RoundConfiguration: Hashable, Codable {
    var primaryFormat: GameFormat       // @deprecated -- use formatSummary + templateID on segments
    var formatSummary: RoundFormatSummary?  // Display-only summary derived from the active GameTemplate
    var courses: [CourseSegment]        // Course metadata and hole sequence for each
    var competitionScope: CompetitionScope?  // Overrides template when teams enabled (field vs matchup)
    var teamScoring: RoundTeamScoringConfiguration
    var matchupResolutionStyle: RoundMatchupResolutionStyle
    var scoreOwnerScope: RoundScoreOwnerScope
    var matchupScoringStyle: RoundMatchupScoringStyle
    var holeWinPoints: Double?
    var matchWinnerBonusPoints: Double?
    var matchTiePolicy: TiePolicy?
    var vegasMode: RoundVegasMode?
    var vegasSelectionRule: RoundVegasSelectionRule?
    var vegasSelectionScope: AggregationScope?
    var selectionDomain: ScoringSelectionDomain?
    var scoreInputMode: RoundScoreInputMode
    var sequentialTeeStartsEnabled: Bool?  // When true, new tee groups rotate across the active hole range.
    var secretScoring: Bool?               // When true, other teams' scores are hidden until revealed
    var scoresRevealed: Bool?              // Host flips this to true to unveil all scores
    /// Basis for interpreting participant handicap values in net scoring. Missing legacy docs infer from hole count.
    var handicapStrokeBasis: SeriesHandicapStrokeBasis?
    /// Optional format-specific allowance for shared-score scoring units, applied by handicap rank.
    var sharedScoreHandicapConfig: HandicapConfiguration?
    /// When false, team avatars and dots use neutral styling; team names follow indexed "Team N" when reset from lobby.
    var teamColorsEnabled: Bool
    /// When true, round teams are kept in sync with tee groups for shared team formats.
    var mirrorTeeGroupsAsTeams: Bool?
    /// When true, live scoring can ask players/commissioners to confirm round attendance.
    var attendanceConfirmationEnabled: Bool?

    var isSecretScoring: Bool { secretScoring == true }
    var areScoresRevealed: Bool { scoresRevealed == true }

    var usesTeamColors: Bool { teamColorsEnabled }

    init(
        primaryFormat: GameFormat = .strokePlay,
        formatSummary: RoundFormatSummary? = nil,
        courses: [CourseSegment] = [],
        competitionScope: CompetitionScope? = nil,
        teamScoring: RoundTeamScoringConfiguration = .init(),
        matchupResolutionStyle: RoundMatchupResolutionStyle = .roundAggregate,
        scoreOwnerScope: RoundScoreOwnerScope = .individual,
        matchupScoringStyle: RoundMatchupScoringStyle = .aggregateRoundTotal,
        holeWinPoints: Double? = nil,
        matchWinnerBonusPoints: Double? = nil,
        matchTiePolicy: TiePolicy? = nil,
        vegasMode: RoundVegasMode? = nil,
        vegasSelectionRule: RoundVegasSelectionRule? = nil,
        vegasSelectionScope: AggregationScope? = nil,
        selectionDomain: ScoringSelectionDomain? = nil,
        scoreInputMode: RoundScoreInputMode = .strokes,
        sequentialTeeStartsEnabled: Bool? = false,
        secretScoring: Bool? = nil,
        scoresRevealed: Bool? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis? = nil,
        sharedScoreHandicapConfig: HandicapConfiguration? = nil,
        teamColorsEnabled: Bool = true,
        mirrorTeeGroupsAsTeams: Bool? = nil,
        attendanceConfirmationEnabled: Bool? = nil
    ) {
        self.primaryFormat = primaryFormat
        self.formatSummary = formatSummary
        self.courses = courses
        self.competitionScope = competitionScope
        self.teamScoring = teamScoring
        self.matchupResolutionStyle = matchupResolutionStyle
        self.scoreOwnerScope = scoreOwnerScope
        self.matchupScoringStyle = matchupScoringStyle
        self.holeWinPoints = holeWinPoints
        self.matchWinnerBonusPoints = matchWinnerBonusPoints
        self.matchTiePolicy = matchTiePolicy
        self.vegasMode = vegasMode
        self.vegasSelectionRule = vegasSelectionRule
        self.vegasSelectionScope = vegasSelectionScope
        self.selectionDomain = selectionDomain
        self.scoreInputMode = scoreInputMode
        self.sequentialTeeStartsEnabled = sequentialTeeStartsEnabled
        self.secretScoring = secretScoring
        self.scoresRevealed = scoresRevealed
        self.handicapStrokeBasis = handicapStrokeBasis
        self.sharedScoreHandicapConfig = sharedScoreHandicapConfig
        self.teamColorsEnabled = teamColorsEnabled
        self.mirrorTeeGroupsAsTeams = mirrorTeeGroupsAsTeams
        self.attendanceConfirmationEnabled = attendanceConfirmationEnabled
    }

    /// Resolved scope: config override or template default.
    var resolvedCompetitionScope: CompetitionScope {
        competitionScope ?? activeTemplate.resolvedScope
    }

    enum CodingKeys: String, CodingKey {
        case courses
        case primaryFormat = "primary_format"
        case formatSummary = "format_summary"
        case competitionScope = "competition_scope"
        case teamScoring = "team_scoring"
        case matchupResolutionStyle = "matchup_resolution_style"
        case scoreOwnerScope = "score_owner_scope"
        case matchupScoringStyle = "matchup_scoring_style"
        case holeWinPoints = "hole_win_points"
        case matchWinnerBonusPoints = "match_winner_bonus_points"
        case matchTiePolicy = "match_tie_policy"
        case vegasMode = "vegas_mode"
        case vegasSelectionRule = "vegas_selection_rule"
        case vegasSelectionScope = "vegas_selection_scope"
        case selectionDomain = "selection_domain"
        case scoreInputMode = "score_input_mode"
        case legacyBestNSelected = "best_n_selected"
        case legacyBestWorstEnabled = "best_worst_enabled"
        case sequentialTeeStartsEnabled = "sequential_tee_starts_enabled"
        case secretScoring = "secret_scoring"
        case scoresRevealed = "scores_revealed"
        case handicapStrokeBasis = "handicap_stroke_basis"
        case sharedScoreHandicapConfig = "shared_score_handicap_config"
        case teamColorsEnabled = "team_colors_enabled"
        case mirrorTeeGroupsAsTeams = "mirror_tee_groups_as_teams"
        case attendanceConfirmationEnabled = "attendance_confirmation_enabled"
    }

    var useHandicaps: Bool {
        primaryFormat.configuration.basis == .net
    }

    func resolvedHandicapStrokeBasis(holeCount: Int) -> SeriesHandicapStrokeBasis {
        handicapStrokeBasis ?? SeriesHandicapStrokeBasis.defaultBasis(holeCount: holeCount)
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

    var resolvedVegasMode: RoundVegasMode {
        vegasMode ?? .exactPair
    }

    var resolvedVegasSelectionRule: RoundVegasSelectionRule {
        vegasSelectionRule ?? .best2
    }

    var resolvedVegasSelectionScope: AggregationScope {
        vegasSelectionScope ?? .perHole
    }

    /// Resolved template from registry. Falls back to stroke play.
    var activeTemplate: GameTemplate {
        if let id = formatSummary?.templateID, !id.isEmpty {
            return FormatTemplateRegistry.template(for: id)
        }
        return FormatTemplateRegistry.strokePlayGross
    }

    var bestNSelected: Int? {
        switch teamScoring.mode {
        case .all:
            return nil
        case .bestN, .worstN:
            return teamScoring.count
        }
    }

    var bestWorstEnabled: Bool? {
        teamScoring.mode == .worstN
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        primaryFormat = try c.decodeIfPresent(GameFormat.self, forKey: .primaryFormat) ?? .strokePlay
        formatSummary = try c.decodeIfPresent(RoundFormatSummary.self, forKey: .formatSummary)
        courses = try c.decodeIfPresent([CourseSegment].self, forKey: .courses) ?? []
        competitionScope = try c.decodeIfPresent(CompetitionScope.self, forKey: .competitionScope)
        scoreOwnerScope = try c.decodeIfPresent(RoundScoreOwnerScope.self, forKey: .scoreOwnerScope) ?? .individual
        matchupScoringStyle = try c.decodeIfPresent(RoundMatchupScoringStyle.self, forKey: .matchupScoringStyle) ?? .aggregateRoundTotal
        holeWinPoints = try c.decodeIfPresent(Double.self, forKey: .holeWinPoints)
        matchWinnerBonusPoints = try c.decodeIfPresent(Double.self, forKey: .matchWinnerBonusPoints)
        matchTiePolicy = try c.decodeIfPresent(TiePolicy.self, forKey: .matchTiePolicy)
        vegasMode = try c.decodeIfPresent(RoundVegasMode.self, forKey: .vegasMode)
        vegasSelectionRule = try c.decodeIfPresent(RoundVegasSelectionRule.self, forKey: .vegasSelectionRule)
        vegasSelectionScope = try c.decodeIfPresent(AggregationScope.self, forKey: .vegasSelectionScope)
        selectionDomain = try c.decodeIfPresent(ScoringSelectionDomain.self, forKey: .selectionDomain)
        scoreInputMode = try c.decodeIfPresent(RoundScoreInputMode.self, forKey: .scoreInputMode) ?? .strokes
        sequentialTeeStartsEnabled = try c.decodeIfPresent(Bool.self, forKey: .sequentialTeeStartsEnabled) ?? false
        secretScoring = try c.decodeIfPresent(Bool.self, forKey: .secretScoring)
        scoresRevealed = try c.decodeIfPresent(Bool.self, forKey: .scoresRevealed)
        handicapStrokeBasis = try c.decodeIfPresent(SeriesHandicapStrokeBasis.self, forKey: .handicapStrokeBasis)
        sharedScoreHandicapConfig = try c.decodeIfPresent(HandicapConfiguration.self, forKey: .sharedScoreHandicapConfig)
        teamColorsEnabled = try c.decodeIfPresent(Bool.self, forKey: .teamColorsEnabled) ?? true
        mirrorTeeGroupsAsTeams = try c.decodeIfPresent(Bool.self, forKey: .mirrorTeeGroupsAsTeams)
        attendanceConfirmationEnabled = try c.decodeIfPresent(Bool.self, forKey: .attendanceConfirmationEnabled)
        matchupResolutionStyle = try c.decodeIfPresent(RoundMatchupResolutionStyle.self, forKey: .matchupResolutionStyle) ?? .roundAggregate

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
        try c.encode(primaryFormat, forKey: .primaryFormat)
        try c.encodeIfPresent(formatSummary, forKey: .formatSummary)
        try c.encode(courses, forKey: .courses)
        try c.encodeIfPresent(competitionScope, forKey: .competitionScope)
        try c.encode(teamScoring, forKey: .teamScoring)
        try c.encode(matchupResolutionStyle, forKey: .matchupResolutionStyle)
        try c.encode(scoreOwnerScope, forKey: .scoreOwnerScope)
        try c.encode(matchupScoringStyle, forKey: .matchupScoringStyle)
        try c.encodeIfPresent(holeWinPoints, forKey: .holeWinPoints)
        try c.encodeIfPresent(matchWinnerBonusPoints, forKey: .matchWinnerBonusPoints)
        try c.encodeIfPresent(matchTiePolicy, forKey: .matchTiePolicy)
        try c.encodeIfPresent(vegasMode, forKey: .vegasMode)
        try c.encodeIfPresent(vegasSelectionRule, forKey: .vegasSelectionRule)
        try c.encodeIfPresent(vegasSelectionScope, forKey: .vegasSelectionScope)
        try c.encodeIfPresent(selectionDomain, forKey: .selectionDomain)
        try c.encode(scoreInputMode, forKey: .scoreInputMode)
        try c.encodeIfPresent(sequentialTeeStartsEnabled, forKey: .sequentialTeeStartsEnabled)
        try c.encodeIfPresent(secretScoring, forKey: .secretScoring)
        try c.encodeIfPresent(scoresRevealed, forKey: .scoresRevealed)
        try c.encodeIfPresent(handicapStrokeBasis, forKey: .handicapStrokeBasis)
        try c.encodeIfPresent(sharedScoreHandicapConfig, forKey: .sharedScoreHandicapConfig)
        try c.encode(teamColorsEnabled, forKey: .teamColorsEnabled)
        try c.encodeIfPresent(mirrorTeeGroupsAsTeams, forKey: .mirrorTeeGroupsAsTeams)
        try c.encodeIfPresent(attendanceConfirmationEnabled, forKey: .attendanceConfirmationEnabled)
    }
}
