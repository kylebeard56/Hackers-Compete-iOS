//
//  ScoreUtil+Football.swift
//  Hackers
//
//  Created by Kyle Beard on 8/21/23.
//

import Foundation

extension ScoreUtil {
    struct Football {
        static func computeScores(
            for players: [Player],
            playing session: FootballSession?,
            on hole: Int,
            ignoreSafety: Bool = false,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            let teams = players.compactMap({ $0.team[hole] }).filter({ !$0.isEmpty }).uniques

            var data = teams.reduce(into: [:], { $0[$1] = 0 })
            
            /// 1. Check if onside kick was attempted and failed to give points to appropriate team.
            if let prevOffense = session?.possession[hole - 1],
               let prevDefense = teams.filter({ $0 != prevOffense }).first,
               let onside = session?.onsideKick[hole],
               onside.attempted && !(onside.successful ?? true) && !ignoreSafety {
                /// Give key for whoever was on defense previously 2 pts
                data.updateValue(2, forKey: prevDefense)
            }
            
            /// 2. Determine if offense has been chosen yet for this hole and if scores are in
            guard let offense = session?.possession[hole],
                  let defense = teams.filter({ $0 != offense }).first
            else {
                return data.compactMap({ GameScoreData(key: $0.key, value: $0.value) })
            }
            
            /// 3. Award points for hole outcome (if outcome is empty then we don't have all scores).
            let outcome = ScoreUtil.Match.computeScore(for: players, on: hole, teams: true, handicaps: handicaps)
            if !offense.isEmpty {
                if outcome == "tie" {
                    /// 3a. Field Goal
                    let pv = data[offense] ?? 0
                    data.updateValue(pv + 3, forKey: offense)
                } else if outcome == offense {
                    /// 3b. Touchdown
                    let pv = data[offense] ?? 0
                    data.updateValue(pv + 7, forKey: offense)
                } else if outcome != "" {
                    /// 3c. Pick Six for defense
                    let didBirdie = players
                        .filter({ $0.team[hole] != offense })
                        .compactMap({ $0.score(for: hole, handicaps: handicaps).numericalValue })
                        .filter({ $0 <= PlayerScore.birdie.numericalValue })
                        .count > 0 /// NOTE: Change this to > 1 for both players needing a birdie if we decide to.

                    if didBirdie {
                        let pv = data[defense] ?? 0
                        data.updateValue(pv + 6, forKey: defense)
                    }
                }
            }
            
            return data.compactMap({ GameScoreData(key: $0.key, value: $0.value) })
        }
        
        static func computeTotal(
            for players: [Player],
            playing football: FootballSession?,
            over holes: [Int],
            on hole: Int? = nil,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            if holes.isEmpty { return [] }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            
            var scores: [String: Int] = [:]
            
            for h in holes[0...last] {
                for s in ScoreUtil.Football.computeScores(for: players, playing: football, on: h, handicaps: handicaps) {
                    let v = scores[s.key] ?? 0
                    scores.updateValue(v + s.value, forKey: s.key)
                }
            }
            
            return scores.compactMap({ GameScoreData(key: $0.key, value: $0.value) })
        }
        
        static func computeBanner(
            for players: [Player],
            playing session: FootballSession?,
            on hole: Int,
            handicaps: Bool = true
        ) -> String {
            /// 1. If not all of the scores are computed, we need to return a blank string
            for p in players {
                let v = p.score(for: hole, handicaps: handicaps)
                if v == .none { return "" }
            }
            
            /// 2. Compute scores for this hole
            let data = ScoreUtil.Football.computeScores(
                for: players,
                playing: session,
                on: hole,
                ignoreSafety: true,
                handicaps: handicaps
            )
            
            /// 3. Return the appropriate string based on points.
            for d in data {
                if d.value != 0 {
                    if d.value == 7 {
                        return "Touchdown! \(d.key) scored 7 points!"
                    }
                    if d.value == 6 {
                        return "Pick six! \(d.key) scored 6 points!"
                    }
                    if d.value == 3 {
                        return "Field Goal! \(d.key) scored 3 points!"
                    }
                }
            }
            
            /// 4. Return default for no scores
            return "Turnover on downs! No points scored."
        }
    }
}
