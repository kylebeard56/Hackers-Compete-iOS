//
//  RoundSnapshot.swift
//  Hackers
//
//  Created by Kyle Beard on 8/28/25.
//

import Foundation

struct RoundSnapshot {
    var round: Round
    var participants: [RoundParticipant]
    var teams: [RoundTeam]
    var teeGroups: [TeeTimeGroup]
    var segments: [RoundSegment]
    var scoring: [ScoreEntry]
    
    // Computed for easy access
    var playerScores: [String: [ScoreEntry]] = [:]
    
    init(
        round: Round = .init(),
        participants: [RoundParticipant] = [],
        teams: [RoundTeam] = [],
        teeGroups: [TeeTimeGroup] = [],
        segments: [RoundSegment] = [],
        scoring: [ScoreEntry] = []
    ) {
        self.round = round
        self.participants = participants
        self.teams = teams
        self.teeGroups = teeGroups
        self.segments = segments
        self.scoring = scoring
    }
}

extension RoundSnapshot {
     static func mock() -> RoundSnapshot {
         .init(
             round: MockRound.strokePlay,
             participants: MockParticipants.all,
             teams: MockTeams.all,
             teeGroups: MockTeeGroups.all,
             segments: [MockSegments.mainSegment],
             scoring: []
         )
    }
}
