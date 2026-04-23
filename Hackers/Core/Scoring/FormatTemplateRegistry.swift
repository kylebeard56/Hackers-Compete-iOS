//
//  FormatTemplateRegistry.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

/// App-owned catalog of selectable game templates and presets.
/// Phase 0: only stroke play. Phase 1+: stableford, match play, best ball, etc.
struct FormatTemplateRegistry {

    // MARK: - All Templates

    static var allTemplates: [GameTemplate] {
        [
            strokePlay,
            stableford,
            vegas,
            bestBall,
            matchPlayIndividual,
            alternateShot,
            captainsChoice,
        ]
    }

    static var seriesTemplates: [GameTemplate] {
        allTemplates.filter { $0.id != vegas.id }
    }

    static func builderTemplates(requiresTeams: Bool) -> [GameTemplate] {
        if requiresTeams {
            return allTemplates
        }
        return allTemplates.filter { !$0.requirements.requiresTeams }
    }

    /// Returns a template by its stable ID. Maps legacy IDs to consolidated templates for backward compatibility.
    static func template(for id: String) -> GameTemplate {
        switch id {
        case "stroke_play_gross", "stroke_play_net":
            return strokePlay
        case "best_ball", "best_2_of_4", "better_ball", "better ball", "shamble", "two_man_shamble", "two-man shamble":
            return bestBall
        case "vegas":
            return vegas
        case "best_ball_matchup", "best_2_of_4_matchup":
            return bestBallMatchup
        case "stroke_play_matchup", "individual_matchup":
            return strokePlayMatchupIndividual
        case "alternate_shot":
            return alternateShot
        case "captains_choice", "scramble":
            return captainsChoice
        default:
            return allTemplates.first(where: { $0.id == id }) ?? strokePlay
        }
    }

    // MARK: - Stroke Play

    static var strokePlay: GameTemplate {
        GameTemplate(
            id: "stroke_play",
            name: "Stroke Play",
            description: "Lowest total strokes wins",
            icon: "f450",
            category: .stroke,
            aliases: ["gross", "net"],
            inputMode: .strokes,
            subject: .participant,
            scoreSource: .individual,
            pipeline: [
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                requiresTeams: false,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    /// Legacy alias for backward compatibility.
    static var strokePlayGross: GameTemplate { strokePlay }
    static var strokePlayNet: GameTemplate { strokePlay }

    // MARK: - Stableford

    static var stableford: GameTemplate {
        GameTemplate(
            id: "stableford",
            name: "Stableford",
            description: "Points awarded based on score relative to par. Highest total wins.",
            icon: "f005",
            category: .points,
            inputMode: .strokes,
            subject: .participant,
            scoreSource: .individual,
            pipeline: [
                .transform(.stableford),
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .highestWins,
            requirements: TemplateRequirements(
                requiresTeams: false,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Match Play

    static var vegas: GameTemplate {
        GameTemplate(
            id: "vegas",
            name: "Vegas",
            description: "Pairs combine two scores into an accrual total. Lowest cumulative Vegas score wins.",
            icon: "e3ce",
            category: .team,
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: .field,
            pipeline: [],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                minPlayers: 4,
                maxPlayers: nil,
                teamSize: .range(min: 2, max: 99),
                requiresTeams: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Match Play

    static var matchPlayIndividual: GameTemplate {
        GameTemplate(
            id: "match_play_individual",
            name: "Match Play",
            description: "Win individual holes to earn points. Most holes won wins.",
            icon: "f71d",
            category: .match,
            inputMode: .strokes,
            subject: .participant,
            scoreSource: .individual,
            competitionScope: .matchup,
            pipeline: [
                .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half))
            ],
            leaderboardSort: .highestWins,
            requirements: TemplateRequirements(
                minPlayers: 2,
                maxPlayers: nil,
                requiresTeams: false,
                requiresMatchups: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualMatchPlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Individual Matchup (Stroke Play)

    /// Stroke play with head-to-head matchups between individual players. No teams required.
    static var strokePlayMatchupIndividual: GameTemplate {
        GameTemplate(
            id: "stroke_play_matchup",
            name: "Individual Matchup",
            description: "Head-to-head stroke play between paired players.",
            icon: "f450",
            category: .match,
            inputMode: .strokes,
            subject: .participant,
            scoreSource: .individual,
            competitionScope: .matchup,
            pipeline: [
                .reduce(Reduction(mode: .sum, scope: .perRound)),
                .compare(ComparisonRule(mode: .strokeDifference, tiePolicy: .half))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                requiresTeams: false,
                requiresMatchups: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Best Ball (Field Scope)

    static var bestBall: GameTemplate {
        GameTemplate(
            id: "best_ball",
            name: "Best Ball",
            description: "Best score(s) from each team per hole count. Lowest team total wins.",
            icon: "f648",
            category: .team,
            aliases: ["twoball", "two ball", "better ball", "better_ball", "shamble", "two man shamble", "two-man shamble"],
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: nil,
            pipeline: [
                .select(RankSelection(includeRanks: [1])),
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                teamSize: .range(min: 2, max: 4),
                requiresTeams: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Best Ball Matchup (Matchup Scope)

    static var bestBallMatchup: GameTemplate {
        GameTemplate(
            id: "best_ball_matchup",
            name: "Best Ball Matchup",
            description: "Best ball with head-to-head matchups. Win holes to earn points.",
            icon: "f0c0",
            category: .team,
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: .matchup,
            pipeline: [
                .select(RankSelection(includeRanks: [1])),
                .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half))
            ],
            leaderboardSort: .highestWins,
            requirements: TemplateRequirements(
                teamSize: .range(min: 2, max: 4),
                requiresTeams: true,
                requiresMatchups: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Alternate Shot

    static var alternateShot: GameTemplate {
        GameTemplate(
            id: "alternate_shot",
            name: "Alternate Shot",
            description: "Partners alternate hitting the same ball each hole. One score per pair.",
            icon: "f7a0",
            category: .team,
            inputMode: .strokes,
            subject: .team,
            scoreSource: .shared,
            pipeline: [
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                teamSize: .exact(2),
                requiresTeams: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Captain's Choice (Scramble)

    static var captainsChoice: GameTemplate {
        GameTemplate(
            id: "captains_choice",
            name: "Captain's Choice",
            description: "All players hit, then the team plays from the best shot. One score per team.",
            icon: "e533",
            category: .team,
            aliases: ["scramble", "two man scramble", "two-man scramble", "2 man scramble", "2-man scramble"],
            inputMode: .strokes,
            subject: .team,
            scoreSource: .shared,
            pipeline: [
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                teamSize: .range(min: 2, max: 4),
                requiresTeams: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .scramble2Player,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

}
