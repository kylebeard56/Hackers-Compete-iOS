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
    var scoringGroups: [RoundScoringGroup]
    var segments: [RoundSegment]
    var scoring: [ScoreEntry]
    
    // Computed for easy access
    var playerScores: [String: [ScoreEntry]] = [:]
    
    init(
        round: Round = .init(),
        participants: [RoundParticipant] = [],
        teams: [RoundTeam] = [],
        teeGroups: [TeeTimeGroup] = [],
        scoringGroups: [RoundScoringGroup] = [],
        segments: [RoundSegment] = [],
        scoring: [ScoreEntry] = []
    ) {
        self.round = round
        self.participants = participants
        self.teams = teams
        self.teeGroups = teeGroups
        self.scoringGroups = scoringGroups
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
    var handicapStrokeBasis: SeriesHandicapStrokeBasis {
        configuration.resolvedHandicapStrokeBasis(holeCount: holeRange?.count ?? holeSegment.holeCount)
    }
    var defaultTee: Tee? { courseInfo?.teeMap[courseSegment?.defaultTee ?? ""] }
    var tees: [Tee] { courseInfo?.tees ?? [] }
    
    var gameFormat: GameFormat { self.round.configuration.primaryFormat }
    var requiresTeams: Bool { configuration.primaryFormat.configuration.requiresTeams }
    var isSharedScoreSource: Bool { resolvedActiveTemplate.scoreSource == .shared }
    var hasScheduledTeamMatchups: Bool {
        let teamIDs = Set(teams.map(\.id))
        return roundSegment?.matchups?.contains { matchup in
            guard (matchup.mode ?? .team) == .team, matchup.isValid else { return false }
            let pairingIDs = matchup.pairingIDs()
            return pairingIDs.allSatisfy { teamIDs.contains($0) }
        } == true
    }
    var expectedMatchupMode: MatchupMode {
        if configuration.scoreOwnerScope != .individual {
            return .scoreOwner
        }
        if requiresTeams || hasScheduledTeamMatchups || (teams.isPopulated && configuration.teamScoring.isCountedSelection) {
            return .team
        }
        return .individual
    }
    var usesTeamScoringAggregates: Bool {
        guard !isVegasFormat,
              !isSharedScoreSource,
              configuration.scoreOwnerScope == .individual,
              scoringGroups.isEmpty,
              teams.isPopulated else {
            return false
        }

        return requiresTeams
            || hasScheduledTeamMatchups
            || configuration.teamScoring.isCountedSelection
    }
    var shouldAutoMirrorTeeGroupsToTeams: Bool {
        guard isSharedScoreSource && requiresTeams else { return false }
        return configuration.mirrorTeeGroupsAsTeams ?? (configuration.scoreOwnerScope == .individual)
    }
    var isVegasFormat: Bool { resolvedActiveTemplate.id == FormatTemplateRegistry.vegas.id }
    var isSecretScoring: Bool { configuration.isSecretScoring }
    var areScoresRevealed: Bool { configuration.areScoresRevealed }

    // MARK: - Template-Aware Helpers

    /// Resolves the active GameTemplate for the round (from formatSummary or registry fallback).
    var activeTemplate: GameTemplate { configuration.activeTemplate }

    /// Template with bestNSelected / bestWorstEnabled applied to select stages. Used for scoring.
    /// When competitionScope == .matchup, best_ball and stroke_play resolve to their matchup pipelines.
    var resolvedActiveTemplate: GameTemplate {
        var base = activeTemplate
        let usesTeamScoringBuilder = configuration.primaryFormat.configuration.requiresTeams

        // Resolve to matchup pipeline when scope is matchup and template supports it
        if configuration.resolvedCompetitionScope == .matchup, !usesTeamScoringBuilder {
            switch base.id {
            case "best_ball":
                base = FormatTemplateRegistry.bestBallMatchup
            case "stroke_play":
                base = FormatTemplateRegistry.strokePlayMatchupIndividual
            default:
                break
            }
        }

        guard base.pipeline.contains(where: { if case .select = $0 { return true }; return false }) else { return base }
        guard let bestN = configuration.bestNSelected, bestN > 0 else { return base }
        let includeRanks: [Int]
        if configuration.bestWorstEnabled == true {
            includeRanks = [bestN]
        } else {
            includeRanks = Array(1...bestN)
        }
        var modifiedPipeline = base.pipeline
        for i in modifiedPipeline.indices {
            if case .select = modifiedPipeline[i] {
                modifiedPipeline[i] = .select(RankSelection(includeRanks: includeRanks, scope: configuration.teamScoring.scope))
                break
            }
        }
        var modified = base
        modified.pipeline = modifiedPipeline
        return modified
    }

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

    /// Ordered segment document ids used to resolve `ScoreEntry` keys: primary segment first, then other loaded segments, then ids observed on scores. Keeps scoring correct when entries use a different segment id than `segments.first` (e.g. multi-segment or fetch order).
    var segmentScoreLookupSegmentIDs: [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        if let main = roundSegment?.id, !main.isEmpty {
            ordered.append(main)
            seen.insert(main)
        }
        for seg in segments where !seg.id.isEmpty && !seen.contains(seg.id) {
            ordered.append(seg.id)
            seen.insert(seg.id)
        }
        for entry in scoring where !entry.segmentID.isEmpty && !seen.contains(entry.segmentID) {
            ordered.append(entry.segmentID)
            seen.insert(entry.segmentID)
        }
        return ordered
    }
    
    func teamColor(for player: RoundParticipant) -> Color? {
        guard configuration.usesTeamColors else { return nil }
        return teams.first(where: { $0.id == player.teamID })?.displaySwatchColor
    }

    func scoringGroup(id: String?) -> RoundScoringGroup? {
        guard let id, id.isPopulated else { return nil }
        return scoringGroups.first(where: { $0.id == id })
    }
}

extension RoundSnapshot {
     static func mock() -> RoundSnapshot {
         .init(
             round: MockRound.strokePlay,
             participants: MockParticipants.all,
             teams: MockTeams.all,
             teeGroups: MockTeeGroups.all,
             scoringGroups: [],
             segments: [MockSegments.mainSegment],
             scoring: []
         )
    }
}
