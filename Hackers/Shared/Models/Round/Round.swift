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

//  MARK: - Subcollections

enum RoundSubcollection: String {
    case participants = "participants-v1"
    case teams = "teams-v1"
    case teeGroups = "tee-groups-v1"
    case scores = "scores-v1"
    case segments = "segments-v1"
}

struct Round: FirebaseIdentifiable {
    var id: String
    var shareCode: String
    var createdBy: String
    var status: RoundStatus
    var configuration: RoundConfiguration
    var createdAt: Time
    var lastUpdatedAt: Time
    
    var collection: String { Collections.rounds.name }
    
    init(
        id: String = "",
        shareCode: String = "",
        createdBy: String = "",
        status: RoundStatus = .lobby,
        configuration: RoundConfiguration = .init(),
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.shareCode = shareCode
        self.createdBy = createdBy
        self.status = status
        self.configuration = configuration
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case shareCode = "share_code"
        case createdBy = "created_by"
        case status
        case configuration
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

enum RoundStatus: String, Codable {
    case lobby, live, paused, complete, cancelled
}

struct RoundConfiguration: Hashable, Codable {
    var primaryFormat: GameFormat       // Primary game format for the round (inherited or deferred to round segment)
    var courses: [CourseSegment]        // Course metadata and hole sequence for each
    var scoringBasis: ScoreBasis        // Gross or net handicap usage
        
    init(
        primaryFormat: GameFormat = .strokePlay,
        courses: [CourseSegment] = [],
        scoringBasis: ScoreBasis = .gross
    ) {
        self.primaryFormat = primaryFormat
        self.courses = courses
        self.scoringBasis = scoringBasis
    }
    
    enum CodingKeys: String, CodingKey {
        case courses
        case primaryFormat = "primary_format"
        case scoringBasis = "scoring_basis"
    }
}
