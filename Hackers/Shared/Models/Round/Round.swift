//
//  Round.swift
//  Hackers
//
//  Created by Kyle Beard on 8/20/25.
//

import SwiftUI

// MARK: - Round
struct Round: FirebaseIdentifiable {
    var id: String
    var shareCode: String                         // Unique six digit code for this
    var createdBy: String
    var status: String
    var configuration: RoundConfiguration
    
    var courseInfo: CourseInfo
    var players: [RoundPlayer]
    var scorecards: [PlayerScorecard]
    var groups: [TeeTimeGroup]
    var teams: [RoundTeam]
    var scores: [String: [Int: HoleScore]]      // ID of Playable or TeeTimeGroup as key : value as [hole number: score]
    var globalFormat: GlobalGameFormat
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection: String { Collections.rounds.name }
    
    init(
        id: String,
        shareCode: String,
        createdBy: String,
        status: String,
        configuration: RoundConfiguration,
        courseInfo: CourseInfo,
        players: [RoundPlayer] = [],
        scorecards: [PlayerScorecard] = [],
        groups: [TeeTimeGroup] = [],
        teams: [RoundTeam] = [],
        scores: [String : [Int : HoleScore]] = [:],
        globalFormat: GlobalGameFormat = .init(name: "", formatType: .strokePlay),
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.shareCode = shareCode
        self.createdBy = createdBy
        self.status = status
        self.configuration = configuration
        self.courseInfo = courseInfo
        self.players = players
        self.scorecards = scorecards
        self.groups = groups
        self.teams = teams
        self.scores = scores
        self.globalFormat = globalFormat
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    // TODO: CodingKeys here and everywhere
}

enum RoundStatus: String {
    case lobby, active, completed, cancelled
}

// MARK: - RoundConfiguration
struct RoundConfiguration: Hashable, Codable {
    var groupScoringEnabled: Bool       // Team format requires group scoring, makes many games ineligible.
    var useHandicaps: Bool              // Whether to apply handicaps or not
    
    init(
        groupScoringEnabled: Bool = false,
        useHandicaps: Bool = false
    ) {
        self.groupScoringEnabled = groupScoringEnabled
        self.useHandicaps = useHandicaps
    }
    
    enum CodingKeys: String, CodingKey {
        case groupScoringEnabled = "group_scoring_enabled"
        case useHandicaps = "use_handicaps"
    }
}



