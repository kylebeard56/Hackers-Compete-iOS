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
    var configuration: RoundConfiguration { self.round.configuration }
    var roundSegment: RoundSegment? { self.segments.first }
    var hostName: Name? { participants.first(where: \.isHost)?.name }
    
    var course: Course? {
        guard let info = self.courseInfo else { return nil }
        return Course(info: info)
    }
    
    var courseSegment: CourseSegment? { configuration.courses.first }
    var courseInfo: CourseInfo? { courseSegment?.courseInfo }
    var holeRange: HoleRange? { configuration.courses.first?.holeRange }
    var holeSegment: HoleSegment { holeRange?.segment ?? .full18 }
    var defaultTee: Tee? { courseInfo?.teeMap[courseSegment?.defaultTee ?? ""] }
    
    var gameFormat: GameFormat { self.round.configuration.primaryFormat }
    var requiresTeams: Bool { self.roundSegment?.gameFormat.configuration.requiresTeams ?? false }
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
