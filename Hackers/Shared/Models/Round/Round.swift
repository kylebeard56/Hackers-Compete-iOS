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

struct RoundConfiguration: Hashable, Codable {
    var primaryFormat: GameFormat       // @deprecated -- use formatSummary + templateID on segments
    var formatSummary: RoundFormatSummary?  // Display-only summary derived from the active GameTemplate
    var courses: [CourseSegment]        // Course metadata and hole sequence for each
    var competitionScope: CompetitionScope?  // Overrides template when teams enabled (field vs matchup)
    var bestNSelected: Int?  // For formats with configurable best N (e.g. best 2 of 4)

    init(
        primaryFormat: GameFormat = .strokePlay,
        formatSummary: RoundFormatSummary? = nil,
        courses: [CourseSegment] = [],
        competitionScope: CompetitionScope? = nil,
        bestNSelected: Int? = nil
    ) {
        self.primaryFormat = primaryFormat
        self.formatSummary = formatSummary
        self.courses = courses
        self.competitionScope = competitionScope
        self.bestNSelected = bestNSelected
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
        case bestNSelected = "best_n_selected"
    }

    var useHandicaps: Bool {
        primaryFormat.configuration.basis == .net
    }

    /// Resolved template from registry. Falls back to stroke play.
    var activeTemplate: GameTemplate {
        if let id = formatSummary?.templateID, !id.isEmpty {
            return FormatTemplateRegistry.template(for: id)
        }
        return FormatTemplateRegistry.strokePlayGross
    }
}
