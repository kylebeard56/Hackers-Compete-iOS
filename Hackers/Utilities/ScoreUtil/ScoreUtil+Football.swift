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
            let teams = players.compactMap({ $0.team[hole] }).uniques
            
            // TODO: Instead of off/def points, it needs to be a map of keys to team.
            
            /// 1. Check if possession exists on previous hole:
            ///    - If onside occured and FAILED, give 2 pts to the key which was defense on previous hole.
            /// 2. Check if possession exists on current hole:
            ///    - If not set, return current game data (which is either 0pts or 2 pts)
            ///    - If set, dish out points to key for off/def for TD, FG, or P6
            
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
            // ============================================================
            
//            var offensePoints = 0
//            var defensePoints = 0
//            var safety: Bool = false
//
//            /// 1a. Determine if the defense got a safety for prior possession
//            let onside = session?.onsideKick[hole] ?? OnsideKick()
//            if onside.attempted && !(onside.successful ?? true) && !ignoreSafety {
//                // TODO: This is causing wrong team to get pts if defense finishes on offense.
//                //defensePoints += 2
//                safety = true
//            }
//
//            /// 1b. Determine who is offense/defense for this hole (might not exist yet).
//            guard let offense = session?.possession[hole],
//                  let defense = teams.filter({ $0 != offense }).first
//            else {
//                /// 1c. if they don't exist yet
//                if let previousOffsense = session?.possession[hole - 1],
//                   let defense = teams.filter({ $0 != previousOffsense }).first {
//                    return [GameScoreData(key: defense, value: safety ? 2 : 0)]
//                }
//                return []
//            }
//
//            /// 2. Determine if the possession team won/tied the hole once offense has been set.
//            let outcome = ScoreUtil.Match.computeScore(for: players, on: hole, teams: true, handicaps: handicaps)
//            if !offense.isEmpty {
//                if outcome == "tie" {
//                    // Field Goal
//                    offensePoints += 3
//                } else if outcome == offense {
//                    // Touchdown
//                    offensePoints += 7
//                } else if outcome != "" {
//                    // Check for birdie for pick six
//                    let didBirdie = players
//                        .filter({ $0.team[hole] != offense })
//                        .compactMap({ $0.score(for: hole, handicaps: handicaps).numericalValue })
//                        .filter({ $0 <= PlayerScore.birdie.numericalValue })
//                        .count > 0 // TODO: Change this to > 1 for both players needing a birdie if we decide to.
//
//                    if didBirdie {
//                        defensePoints += 6
//                    }
//                }
//            }
//
//            var data: [GameScoreData] = []
//            for t in teams {
//                if t == offense {
//                    data.append(GameScoreData(key: offense, value: offensePoints))
//                }
//                if t == defense {
//                    data.append(GameScoreData(key: defense, value: defensePoints))
//                }
//            }
//
//            return data
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
        
        // TODO: Banner
        
        static func computeBanner(
            for players: [Player],
            playing session: FootballSession?,
            on hole: Int,
            handicaps: Bool = true
        ) -> String {
            let data = ScoreUtil.Football.computeScores(
                for: players,
                playing: session,
                on: hole,
                ignoreSafety: true,
                handicaps: handicaps
            )
            
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
            
            return "Turnover on downs! No points scored."
        }
    }
}
