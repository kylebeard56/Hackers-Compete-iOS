//
//  GameTemplate.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - GameTemplate

/// The single canonical model for scoring rules. Replaces GameFormat + GameConfiguration.
/// Contains a composable scoring pipeline and structural requirements for lobby validation.
/// Designed to be JSON-serializable for AI template generation.
struct GameTemplate: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var description: String
    var icon: String
    var category: TemplateCategory
    var aliases: [String]?

    var inputMode: InputMode
    var subject: ScoringSubject
    var scoreSource: ScoreSource
    var competitionScope: CompetitionScope?
    var pipeline: [ScoringStage]
    var leaderboardSort: LeaderboardSort
    var requirements: TemplateRequirements

    var resolvedScope: CompetitionScope { competitionScope ?? .field }

    init(
        id: String = "",
        name: String = "",
        description: String = "",
        icon: String = "f450",
        category: TemplateCategory = .stroke,
        aliases: [String]? = nil,
        inputMode: InputMode = .strokes,
        subject: ScoringSubject = .participant,
        scoreSource: ScoreSource = .individual,
        competitionScope: CompetitionScope? = nil,
        pipeline: [ScoringStage] = [],
        leaderboardSort: LeaderboardSort = .lowestWins,
        requirements: TemplateRequirements = .init()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.aliases = aliases
        self.inputMode = inputMode
        self.subject = subject
        self.scoreSource = scoreSource
        self.competitionScope = competitionScope
        self.pipeline = pipeline
        self.leaderboardSort = leaderboardSort
        self.requirements = requirements
    }
}

// MARK: - Template Category

enum TemplateCategory: String, Codable, CaseIterable {
    case stroke
    case match
    case points
    case team
    case event
    case custom
}

// MARK: - Input Mode

enum InputMode: String, Codable {
    case strokes
    case event
    case manualPoints = "manual_points"
}

// MARK: - Scoring Subject

enum ScoringSubject: String, Codable {
    case participant
    case team
    case competitionSide = "competition_side"
    case custom
}

// MARK: - Score Source

enum ScoreSource: String, Codable {
    case individual
    case shared
}

// MARK: - Competition Scope

enum CompetitionScope: String, Codable {
    /// All scoring units ranked on a single leaderboard (e.g. captain's choice, scramble, tournament best ball).
    case field
    /// Scoring units are paired head-to-head; compare stage runs per pairing (e.g. league play, Ryder Cup matches).
    case matchup
}

// MARK: - Leaderboard Sort

enum LeaderboardSort: String, Codable {
    case lowestWins = "lowest_wins"
    case highestWins = "highest_wins"
}

// MARK: - Validation

enum TemplateValidationError: Equatable {
    case selectRequiresRanks
    case selectCannotHaveBothIncludeAndExclude
    case parRelativeRequiresEntries
    case parDependentRequiresMultiplier
    case eventModeRequiresEventMap
    case teamSubjectRequiresTeams
    case reduceBeforeSelectNotAllowed
    case emptyPipeline
    case matchupScopeRequiresTeams
    case matchupScopeRequiresMatchups
    case fieldScopeWithCompareStage
}

extension GameTemplate {
    func validate() -> [TemplateValidationError] {
        var errors: [TemplateValidationError] = []

        if subject == .team && !requirements.requiresTeams {
            errors.append(.teamSubjectRequiresTeams)
        }

        if resolvedScope == .matchup {
            if !requirements.requiresTeams {
                errors.append(.matchupScopeRequiresTeams)
            }
            if !requirements.requiresMatchups {
                errors.append(.matchupScopeRequiresMatchups)
            }
        }

        var hasSeenSelect = false
        var hasCompare = false

        for stage in pipeline {
            switch stage {
            case .select(let sel):
                hasSeenSelect = true
                let hasInclude = sel.includeRanks != nil && !(sel.includeRanks?.isEmpty ?? true)
                let hasExclude = sel.excludeRanks != nil && !(sel.excludeRanks?.isEmpty ?? true)
                if !hasInclude && !hasExclude {
                    errors.append(.selectRequiresRanks)
                }
                if hasInclude && hasExclude {
                    errors.append(.selectCannotHaveBothIncludeAndExclude)
                }

            case .transform(let map):
                switch map.mode {
                case .parRelative:
                    if map.entries == nil || (map.entries?.isEmpty ?? true) {
                        errors.append(.parRelativeRequiresEntries)
                    }
                case .parDependent:
                    if map.parMultiplier == nil {
                        errors.append(.parDependentRequiresMultiplier)
                    }
                case .fixed, .custom:
                    break
                }

            case .reduce:
                if !hasSeenSelect && subject == .team {
                    // Reducing team scores before selection is a valid pattern for sum-all
                }

            case .compare:
                hasCompare = true

            case .modify:
                break
            }
        }

        if resolvedScope == .field && hasCompare && subject == .team {
            errors.append(.fieldScopeWithCompareStage)
        }

        return errors
    }
}
