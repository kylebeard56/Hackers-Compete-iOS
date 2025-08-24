//
//  RoundPlayer.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - RoundPlayer
struct RoundPlayer: Hashable, Codable, Playable {
    var id: String              // should match id in Player
    var userID: String?         // should match userID in Player
    var handicap: Int?
    var teeBoxID: String
    var groupID: String?
    var teamID: String?
    
    init(
        id: String = "",
        userID: String? = nil,
        handicap: Int? = nil,
        teeBoxID: String,
        groupID: String? = nil,
        teamID: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.handicap = handicap
        self.teeBoxID = teeBoxID
        self.groupID = groupID
        self.teamID = teamID
    }
    
    init(
        player: any Playable,
        handicap: Int? = nil,
        teeBoxID: String,
        groupID: String? = nil,
        teamID: String? = nil
    ) {
        self.id = player.id
        self.userID = player.userID
        self.handicap = handicap
        self.teeBoxID = teeBoxID
        self.groupID = groupID
        self.teamID = teamID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, handicap
        case userID = "user_id"
        case teeBoxID = "tee_box_id"
        case groupID = "group_id"
        case teamID = "team_id"
    }
}

// MARK: - PlayerScorecard
struct PlayerScorecard: Hashable, Codable {
    var id: String                  // Should match id in Playable
    var totalStrokes: Int           // Computed by value entered, or net summation if using friendly name
    var totalPar: Int               // Aggregated par value through round
    var scoreToPar: Int             // totalStrokes - totalPar
    var holesCompleted: Int         // How many holes down (i.e. Thru 2)
    var leaderboardPosition: Int    // Ranking on leaderboard from scoreToPar
    
    init(
        id: String = "",
        totalStrokes: Int = 0,
        totalPar: Int = 0,
        scoreToPar: Int = 0,
        holesCompleted: Int = 0,
        leaderboardPosition: Int = 0
    ) {
        self.id = id
        self.totalStrokes = totalStrokes
        self.totalPar = totalPar
        self.scoreToPar = scoreToPar
        self.holesCompleted = holesCompleted
        self.leaderboardPosition = leaderboardPosition
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case totalStrokes = "total_strokes"
        case totalPar = "total_par"
        case scoreToPar = "score_to_par"
        case holesCompleted = "holes_completed"
        case leaderboardPosition = "leaderboard_position"
    }
}
