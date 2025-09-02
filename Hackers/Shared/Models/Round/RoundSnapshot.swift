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
    
    init(
        round: Round,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        teeGroups: [TeeTimeGroup],
        segments: [RoundSegment],
        scoring: [ScoreEntry]
    ) {
        self.round = round
        self.participants = participants
        self.teams = teams
        self.teeGroups = teeGroups
        self.segments = segments
        self.scoring = scoring
    }
}
