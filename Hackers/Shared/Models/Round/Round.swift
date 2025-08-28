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
//    sideGames/{gameId}                     // SideGame (future: bingo/bango, wolf, etc)

import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import SwiftUI

//  MARK: - Subcollections

enum RoundSubcollection: String {
    case participants = "participants-v1"
    case teams = "teams-v1"
    case groups = "groups-v1"
    case scores = "scores-v1"
    case segments = "segments-v1"
    case sideGames = "side-games-v1"
}

// MARK: - Round
enum RoundStatus: String, Codable { case lobby, live, paused, complete, cancelled }

struct Round: FirebaseIdentifiable {
    var id: String
    
    var shareCode: String                           // Unique six digit code for this
    var createdBy: String
    var status: String
    
    var configuration: RoundConfiguration
    var courses: [CourseSegment]
    
    var currentSegmentID: String?                   // Current active segment (could be for Nassau for front/back/full)
    var segmentHistory: [String]                    // Array of format segments (groups, teams, format, hole range)
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection: String { Collections.rounds.name }
    
    init(
        id: String = "",
        shareCode: String = "",
        createdBy: String = "",
        status: String = "",
        configuration: RoundConfiguration,
        courses: [CourseSegment] = [],
        currentSegmentID: String? = nil,
        segmentHistory: [String],
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.shareCode = shareCode
        self.createdBy = createdBy
        self.status = status
        self.configuration = configuration
        self.courses = courses
        self.currentSegmentID = currentSegmentID
        self.segmentHistory = segmentHistory
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case shareCode = "share_code"
        case createdBy = "created_by"
        case status
        case configuration
        case courses
        case currentSegmentID = "current_segment_id"
        case segmentHistory = "segment_history"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
}

struct HoleRange: Codable, Hashable {
    var startHole: Int
    var endHole: Int
    
    init(
        startHole: Int = 0,
        endHole: Int = 0
    ) {
        self.startHole = startHole
        self.endHole = endHole
    }
    
    init(segment: HoleSegment) {
        let range = segment.holeRange
        self.startHole = range.startHole
        self.endHole = range.endHole
    }
    
    var count: Int { endHole - startHole + 1 }
    var segment: HoleSegment { HoleSegment(range: self) }
    func contains(_ hole: Int) -> Bool { hole >= startHole && hole <= endHole }
}

// MARK: - RoundConfiguration
struct RoundConfiguration: Hashable, Codable {
    var useHandicaps: Bool              // Gross vs Net computation
    
    init(
        useHandicaps: Bool = false
    ) {
        self.useHandicaps = useHandicaps
    }
    
    enum CodingKeys: String, CodingKey {
        case useHandicaps = "use_handicaps"
    }
}



