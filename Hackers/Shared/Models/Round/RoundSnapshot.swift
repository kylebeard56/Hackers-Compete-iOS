//
//  RoundSnapshot.swift
//  Hackers
//
//  Created by Kyle Beard on 8/28/25.
//

import SwiftUI

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
    var tees: [Tee] { courseInfo?.tees ?? [] }
    
    var gameFormat: GameFormat { self.round.configuration.primaryFormat }
    var requiresTeams: Bool { configuration.primaryFormat.configuration.requiresTeams }

    // MARK: - Template-Aware Helpers

    /// Resolves the active GameTemplate for the round (from formatSummary or registry fallback).
    var activeTemplate: GameTemplate { configuration.activeTemplate }

    /// Returns the segment covering a given hole number.
    func segment(forHole holeNumber: Int) -> RoundSegment? {
        SegmentResolver.segment(forHole: holeNumber, in: segments)
    }

    /// Returns the GameTemplate for the segment covering a given hole.
    func activeTemplate(forHole holeNumber: Int) -> GameTemplate {
        let seg = segment(forHole: holeNumber)
        if let tid = seg?.templateID, !tid.isEmpty {
            return FormatTemplateRegistry.template(for: tid)
        }
        return activeTemplate
    }

    /// Returns scoring units for the segment covering a given hole.
    func scoringUnits(forHole holeNumber: Int) -> [ScoringUnit] {
        segment(forHole: holeNumber)?.scoringUnits ?? []
    }
    
    func teamColor(for player: RoundParticipant) -> Color? {
        self.teams.first(where: { $0.id == player.teamID })?.teamColor.value
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
