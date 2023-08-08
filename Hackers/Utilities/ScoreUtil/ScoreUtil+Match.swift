//
//  ScoreUtil+Match.swift
//  Hackers
//
//  Created by Kyle Beard on 8/7/23.
//

import Foundation

extension ScoreUtil {
    struct Match {
        /// Returns best ball score for a group of players on each hole. No teams. Returns `tie` if they tied
        static func computeScore(
            for players: [Player],
            on hole: Int,
            teams: Bool = false,
            handicaps: Bool = true
        ) -> String {
            
            if teams {
                
                /// 1. Construct (Player, PlayerScore) tuple for each on this hole.
                let scores = players.compactMap { ($0.id, $0.score(for: hole, handicaps: handicaps)) }
                if scores.map({ $0.1 }).contains(.none) { return "" }

                /// 2. Sort by lowest score
                let tuple = scores
                    .compactMap( { ($0.0, $0.1.numericalValue) })
                    .sorted(by: { $0.1 < $1.1 })
                
                /// Need to find lowest for each team
                let teams = players.compactMap({ $0.team[hole] }).uniques
                var lowest = [String: Int]()
                
                /// 3. For each value in the tuple, we then deconstruct the players into a best value per team.
                for value in tuple {
                    if let player = players.first(where: { $0.id == value.0 }) {
                        if let t = player.team[hole], let s = lowest[t], s < value.1 {
                            lowest[t] = s
                        }
                    }
                }
                
                let teamBest = lowest.compactMap({ ($0.key, $0.value) })
                
                /// 4. Determine outcome
                if ScoreUtil.didTie(for: .first, with: teamBest) {
                    return "tie"
                } else if let winner = lowest.sorted(by: { $0.value < $1.value }).first?.key {
                    return winner
                } else {
                    return ""
                }
                
            } else {
                
                /// 1. Construct (Player, PlayerScore) tuple for each on this hole.
                let scores = players.compactMap { ($0.id, $0.score(for: hole, handicaps: handicaps)) }
                if scores.map({ $0.1 }).contains(.none) { return "" }

                /// 2. Sort by lowest score
                let tuple = scores
                    .compactMap( { ($0.0, $0.1.numericalValue) })
                    .sorted(by: { $0.1 < $1.1 })
                
                /// 3. Return tie (if push) or winning player tie
                if ScoreUtil.didTie(for: .first, with: tuple) {
                    return "tie"
                } else {
                    return tuple.first?.0 ?? ""
                }
            }
        }
        
        /// Compute the total points won over a given hole range by each player.
        /// Returns `[player_id: score]` or `[team_name: score]` if team is non-empty.
        static func computeTotal(
            for players: [Player],
            over holes: [Int],
            upTo hole: Int? = nil,
            teams: Bool = false,
            skins: Bool = false,
            handicaps: Bool = true
        ) -> [String: Int] {
            
            if holes.isEmpty { return [:] }

            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            var skinValue: Int = 1
            var map = [String: Int]()
            
            for h in holes[0...last] {
                let winner = ScoreUtil.Match.computeScore(for: players, on: h, teams: teams, handicaps: handicaps)
                if winner.isEmpty { continue }

                if winner == "tie" {
                    skinValue += skins ? 1 : 0
                } else {
                    if let currentScore = map[winner] {
                        map.updateValue(currentScore + skinValue, forKey: winner)
                    } else {
                        map.updateValue(skinValue, forKey: winner)
                    }
                    skinValue = 1
                }
            }
            
            return map
        }
        
        static func skinsRollover(
            for players: [Player],
            over holes: [Int],
            for hole: Int? = nil
        ) -> Int {
            var count = 0
            if holes.isEmpty { return count }

            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            
            for h in holes[0...last] {
                let v = ScoreUtil.Match.computeScore(for: players, on: h)
                if v.isEmpty { continue }
                
                if v == "tie" {
                    count += 1
                    continue
                } else {
                    count = 0
                }
            }
            
            return count
        }
        
        static func banner(
            for players: [Player],
            over holes: [Int],
            for hole: Int,
            teams: Bool = false,
            skins: Bool = false,
            handicaps: Bool = true
        ) -> String {
            guard let first = holes.first, let last = holes.last else { return "" }
            
            /// 1a. Ensure everyone has been scored.
            let unscored = players.compactMap({ !$0.hasScore(in: hole...hole) }).filter({ $0 })
            if !unscored.isEmpty { return "" }

            let skinsRollover = ScoreUtil.Match.skinsRollover(for: players, over: holes, for: hole)
            
            if hole == last {

                let totalOutcome = ScoreUtil.Match.computeTotal(
                    for: players,
                    over: holes,
                    upTo: hole,
                    teams: teams,
                    skins: skins,
                    handicaps: handicaps
                )
                .sorted(by: { $0.value > $1.value })
                .compactMap({ ($0.key, $0.value) })
                
                if ScoreUtil.didTie(for: .first, with: totalOutcome) {
                    return "We finish in a tie!"
                } else if let id = totalOutcome.first?.0, let winner = players.first(where: { $0.id == id })?.name {
                    return "\(winner) won the game!"
                } else {
                    return ""
                }
                
            } else {

                let holeOutcome = ScoreUtil.Match.computeScore(
                    for: players,
                    on: hole,
                    teams: teams,
                    handicaps: handicaps
                )
                if holeOutcome.isEmpty { return "" }

                if holeOutcome == "tie" {
                    if skins {
                        let skinsCount = skinsRollover + 1
                        return "Push! \(skinsCount) point\(skinsCount > 1 ? "s" : "") up for grabs on the next hole."
                    } else {
                        return "Push! No points awarded this hole."
                    }
                } else {
                    if let winner = players.first(where: { $0.id == holeOutcome }) {
                        if first != hole {
                            let previousRollover = ScoreUtil.Match.skinsRollover(
                                for: players,
                                over: holes,
                                for: hole - 1
                            )
                            let pts = 1 + (skins ? previousRollover : 0)
                            if pts > 1 {
                                return "Jackpot! \(winner.name) won \(pts) points!"
                            } else {
                                return "\(winner.name) won 1 point."
                            }
                        } else {
                            return "\(winner.name) won 1 point."
                        }
                    } else {
                        return ""
                    }
                }
            }
        }
    }
}
