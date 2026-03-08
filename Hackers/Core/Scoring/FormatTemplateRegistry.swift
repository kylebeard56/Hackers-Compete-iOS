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
            strokePlayGross,
            strokePlayNet,
            stableford,
            matchPlayIndividual,
            bestBall,
            bestTwoOfFour,
            bestBallMatchup,
            bestTwoOfFourMatchup,
        ]
    }

    /// Returns a template by its stable ID, falling back to stroke play gross.
    static func template(for id: String) -> GameTemplate {
        allTemplates.first(where: { $0.id == id }) ?? strokePlayGross
    }

    // MARK: - Stroke Play

    static var strokePlayGross: GameTemplate {
        GameTemplate(
            id: "stroke_play_gross",
            name: "Stroke Play",
            description: "Lowest total strokes wins",
            icon: "f450",
            category: .stroke,
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

    static var strokePlayNet: GameTemplate {
        GameTemplate(
            id: "stroke_play_net",
            name: "Stroke Play (Net)",
            description: "Lowest net strokes wins with handicap adjustments",
            icon: "f450",
            category: .stroke,
            inputMode: .strokes,
            subject: .participant,
            scoreSource: .individual,
            pipeline: [
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                requiresTeams: false,
                requiresHandicaps: true,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .net
            )
        )
    }

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

    static var matchPlayIndividual: GameTemplate {
        GameTemplate(
            id: "match_play_individual",
            name: "Match Play",
            description: "Win individual holes to earn points. Most holes won wins.",
            icon: "e4e6",
            category: .match,
            inputMode: .strokes,
            subject: .participant,
            scoreSource: .individual,
            pipeline: [
                .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half))
            ],
            leaderboardSort: .highestWins,
            requirements: TemplateRequirements(
                minPlayers: 2,
                maxPlayers: 2,
                requiresTeams: false,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualMatchPlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Best Ball

    static var bestBall: GameTemplate {
        GameTemplate(
            id: "best_ball",
            name: "Best Ball",
            description: "Best score from each team per hole counts. Lowest team total wins.",
            icon: "f0c0",
            category: .team,
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: .field,
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

    // MARK: - Best 2 of 4

    static var bestTwoOfFour: GameTemplate {
        GameTemplate(
            id: "best_2_of_4",
            name: "Best 2 of 4",
            description: "Two best scores from each team of four per hole count.",
            icon: "f0c0",
            category: .team,
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: .field,
            pipeline: [
                .select(RankSelection(includeRanks: [1, 2])),
                .reduce(Reduction(mode: .sum, scope: .perRound))
            ],
            leaderboardSort: .lowestWins,
            requirements: TemplateRequirements(
                teamSize: .exact(4),
                requiresTeams: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    // MARK: - Best Ball (Matchup)

    static var bestBallMatchup: GameTemplate {
        GameTemplate(
            id: "best_ball_matchup",
            name: "Best Ball (Matchup)",
            description: "Best ball per team, head-to-head matchup. Win holes to earn points.",
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

    // MARK: - Best 2 of 4 (Matchup)

    static var bestTwoOfFourMatchup: GameTemplate {
        GameTemplate(
            id: "best_2_of_4_matchup",
            name: "Best 2 of 4 (Matchup)",
            description: "Two best scores per team of four, head-to-head matchup.",
            icon: "f0c0",
            category: .team,
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: .matchup,
            pipeline: [
                .select(RankSelection(includeRanks: [1, 2])),
                .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half))
            ],
            leaderboardSort: .highestWins,
            requirements: TemplateRequirements(
                teamSize: .exact(4),
                requiresTeams: true,
                requiresMatchups: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }
}
