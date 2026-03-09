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
            matchPlayIndividual,
            bestBall,
        ]
    }

    /// Returns a template by its stable ID. Maps legacy IDs to consolidated templates for backward compatibility.
    static func template(for id: String) -> GameTemplate {
        switch id {
        case "stroke_play_gross", "stroke_play_net":
            return strokePlay
        case "best_ball", "best_2_of_4", "best_ball_matchup", "best_2_of_4_matchup":
            return bestBall
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
            description: "Best score(s) from each team per hole count. Lowest team total wins.",
            icon: "f0c0",
            category: .team,
            aliases: ["twoball", "two ball", "best 2", "best 2 of 4", "best ball matchup"],
            inputMode: .strokes,
            subject: .team,
            scoreSource: .individual,
            competitionScope: nil,
            pipeline: [
                .select(RankSelection(includeRanks: [1, 2, 3])),
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

    /// Legacy aliases for backward compatibility.
    static var bestTwoOfFour: GameTemplate { bestBall }
    static var bestBallMatchup: GameTemplate { bestBall }
    static var bestTwoOfFourMatchup: GameTemplate { bestBall }
}
