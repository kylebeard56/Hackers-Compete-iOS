//
//  ScoreUtil+Stroke.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

extension ScoreUtil {
    struct Stroke {
        /// Compute the score for a single player on a single hole.
        static func computeScore(
            for player: Player,
            on hole: Int,
            using format: StrokeScoringFormat,
            handicaps: Bool = true
        ) -> String {
            let score = player.score(for: hole, handicaps: handicaps)
            if score == .none { return "-" }
            
            switch format {
            case .medal:
                return score.numericalValue.toGolfScore
            case .stableford:
                return "\(score.stablefordValue)"
            case .fibonacci:
                return "\(score.fibonacciValue)"
            }
        }
        
        /// Compute the total score over a given range of holes for a single player.
        static func computeTotal(
            for player: Player,
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> Int {
            var score: Int = 0
            if holes.isEmpty { return score }
            
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            for h in holes[0...last] {
                let s = player.score(for: h, handicaps: handicaps)
                switch format {
                case .medal:        score += s.numericalValue
                case .stableford:   score += s.stablefordValue
                case .fibonacci:    score += s.fibonacciValue
                }
            }
            return score
        }
        
        /// Compute the total score for a single team over a given range of holes for a group of players.
        static func computeTotal(
            for players: [Player],
            on team: String = "",
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> Int {
            let first = holes.first ?? hole ?? 0
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            return players.compactMap({
                $0.team[first] == team
                ? self.computeTotal(for: $0, over: Array(holes[0...last]), using: format, handicaps: handicaps)
                : nil
            }).reduce(0, +)
        }
        
        /// Compute the best ball score for a group of players on a single hole.
        static func bestBallScore(
            for players: [Player],
            on hole: Int,
            using format: StrokeScoringFormat = .medal,
            handicaps: Bool = true
        ) -> Int {
            let scores = players.compactMap({ $0.score(for: hole, handicaps: handicaps) })
            switch format {
            case .medal:
                return scores.map({ $0.numericalValue }).sorted(by: <).prefix(2).reduce(0, +)
            case .stableford:
                return scores.map({ $0.stablefordValue }).sorted(by: >).prefix(2).reduce(0, +)
            case .fibonacci:
                return scores.map({ $0.fibonacciValue }).sorted(by: >).prefix(2).reduce(0, +)
            }
        }
        
        /// Compute the best ball score for a group of players over a given range of holes.
        static func bestBallTotal(
            for players: [Player],
            over holes: [Int],
            using format: StrokeScoringFormat = .medal,
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> String {
            if holes.isEmpty { return "-" }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            let value = holes[0...last].reduce(0) {
                $0 + bestBallScore(for: players, on: $1, using: format, handicaps: handicaps)
            }
            return format == .medal ? value.toGolfScore : "\(value)"
        }
        
        /// NOTE: When expanding to tournaments, this will need to be revised for multiple rounds. Right now, it only applies
        /// to single parties of 4 or less players.
        static func banner(
            for players: [Player],
            over holes: [Int],
            for hole: Int,
            using format: StrokeScoringFormat = .medal,
            handicaps: Bool = true
        ) -> String {
            guard let first = holes.first, let last = holes.last else { return "" }
            
            /// 1a. Ensure everyone has been scored.
            let unscored = players.compactMap({ !$0.hasScore(in: hole...hole) }).filter({ $0 })
            print(unscored)
            if !unscored.isEmpty { return "" }
            
            /// 1b. Build tuple of teams and score
            let teams = players.compactMap({ $0.team[hole] }).filter({ !$0.isEmpty }).uniques
            let teamScores = teams.compactMap {
                let s = ScoreUtil.Stroke.computeTotal(
                    for: players,
                    on: $0,
                    over: holes,
                    using: format,
                    upTo: hole,
                    handicaps: handicaps
                )
                return ($0, s)
            }.sorted(by: { format == .medal ? $0.1 < $1.1 : $0.1 > $1.1 })
            
            /// 1c. Build tuple of players and scores
            let playerScores = players.compactMap {
                let s = ScoreUtil.Stroke.computeTotal(
                    for: $0,
                    over: holes,
                    using: format,
                    upTo: hole,
                    handicaps: handicaps
                )
                return ($0, s)
            }.sorted(by: { format == .medal ? $0.1 < $1.1 : $0.1 > $1.1 })
            
            /// 1c. Due diligence to ensure our data isn't empty (we don't want to show info if 1 player or 1 team either).
            if playerScores.count < 2 { return "" }
            if teamScores.count < 2 && !teams.isEmpty { return "" }
            
            /// 2. If the hole is the last in the array, we want to show final results.
            if hole == last {
                if teams.isEmpty {
                    if ScoreUtil.didTie(for: .first, with: playerScores) {
                        return "\(playerScores[0].0.name) and \(playerScores[1].0.name) finished tied."
                    } else {
                        return "\(playerScores[0].0.name) wins the game!"
                    }
                } else {
                    if ScoreUtil.didTie(for: .first, with: teamScores) {
                        return "Both teams finished tied!"
                    } else {
                        return "\(teamScores[0].0) wins the game!"
                    }
                }
            /// 3. If the hole is first in the array, we want to show a kickoff message.
            } else if hole == first {
                if teams.isEmpty {
                    if ScoreUtil.didTie(for: .first, with: playerScores) {
                        return "\(playerScores[0].0.name) and \(playerScores[1].0.name) start tied for 1st place."
                    } else {
                        return "\(playerScores[0].0.name) takes the early lead!"
                    }
                } else {
                    if ScoreUtil.didTie(for: .first, with: teamScores) {
                        return "After the first hole, you're both tied!"
                    } else {
                        return "\(teamScores[0].0) takes the early lead!"
                    }
                }
            /// 4. Compute label for intermediate holes, account for lead changes or ties.
            } else {
                if teams.isEmpty {
                    let previousPlayerScores = players.compactMap {
                        let s = ScoreUtil.Stroke.computeTotal(
                            for: $0,
                            over: holes,
                            using: format,
                            upTo: hole - 1,
                            handicaps: handicaps
                        )
                        return ($0, s)
                    }.sorted(by: { format == .medal ? $0.1 < $1.1 : $0.1 > $1.1 })
                    
                    if previousPlayerScores[0].0.id != playerScores[0].0.id {
                        /// 4a. Lead change
                        return "\(playerScores[0].0.name) takes the lead from \(previousPlayerScores[0].0.name)!"
                    } else if ScoreUtil.didTie(for: .first, with: playerScores) {
                        /// 4b. Tie for first
                        if ScoreUtil.didTie(for: .second, with: playerScores) {
                            return "The leaderboard is up from grabs with multiple ties for 1st place."
                        } else {
                            return "\(playerScores[0].0.name) and \(previousPlayerScores[1].0.name) are tied for 1st place."
                        }
                        
                    } else if ScoreUtil.didTie(for: .second, with: playerScores) {
                        /// 4c. Same leader, but tie for second
                        return "\(playerScores[0].0.name) keeps the lead, but there's a battle for 2nd place!"
                    } else if previousPlayerScores[1].0.id != playerScores[1].0.id {
                        /// 4d. Same leader, but change at second
                        return "\(playerScores[0].0.name) keeps the lead, but \(playerScores[1].0.name) jumps into 2nd place!"
                    } else {
                        /// 4e. Same first and second place
                        return "\(playerScores[0].0.name) remains the leader, with \(playerScores[1].0.name) still in 2nd place."
                    }
                    
                } else {
                    let previousTeamScores = teams.compactMap {
                        let s = ScoreUtil.Stroke.computeTotal(
                            for: players,
                            on: $0,
                            over: holes,
                            using: format,
                            upTo: hole - 1,
                            handicaps: handicaps
                        )
                        return ($0, s)
                    }.sorted(by: { format == .medal ? $0.1 < $1.1 : $0.1 > $1.1 })
                    
                    if previousTeamScores[0].0 != teamScores[0].0 {
                        /// 4a. Lead change
                        let q = teamScores[0].1 - teamScores[1].1
                        let unit = format == .medal ? "stroke\(q > 1 ? "s" : "")" : "point\(q > 1 ? "s" : "")"
                        return "\(teamScores[0].0) takes the lead by \(abs(q)) \(unit)!"
                    } else {
                        /// 4b. Compute deficit from last hole to current
                        let previousDeficit = previousTeamScores[0].1 - previousTeamScores[1].1
                        let deficit = teamScores[0].1 - teamScores[1].1

                        let q = deficit
                        let unit = format == .medal ? "stroke\(q > 1 ? "s" : "")" : "point\(q > 1 ? "s" : "")"
                        
                        if deficit == previousDeficit {
                            /// 4c. Same deficit
                            return "\(teamScores[0].0) keep their lead of \(abs(q)) \(unit)."
                        } else if deficit < previousDeficit {
                            /// 4d. Shrunk by 2nd place
                            return "\(teamScores[1].0) shrinks their gap to \(abs(q)) \(unit)."
                        } else {
                            /// 4e. Extended by 1st place
                            return "\(teamScores[0].0) extends their lead to \(abs(q)) \(unit)."
                        }
                    }
                }
            }
        }
    }
}
