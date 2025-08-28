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
    var groups: [TeeTimeGroup]
    var segments: [RoundSegment]
    
    private var scoringCache: [String: ScoreEntry] = [:]
    
    init(
        round: Round,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        groups: [TeeTimeGroup],
        segments: [RoundSegment]
    ) {
        self.round = round
        self.participants = participants
        self.teams = teams
        self.groups = groups
        self.segments = segments
    }
    
    // Efficient single score update
    mutating func updateScore(_ entry: ScoreEntry) {
        guard let id = entry.id else { return }
        scoresCache[id] = entry
    }
    
    // Batch update for initial load
    mutating func updateScores(_ entries: [ScoreEntry]) {
        for entry in entries {
            if let id = entry.id {
                scoresCache[id] = entry
            }
        }
    }
}
