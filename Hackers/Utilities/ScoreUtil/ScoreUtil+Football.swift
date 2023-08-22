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
            
            var offensePoints = 0
            var defensePoints = 0
            
            /// 1a. Determine if the defense got a safety for prior possession
            let onside = session?.onsideKick[hole] ?? OnsideKick()
            if onside.attempted && !(onside.successful ?? true) && !ignoreSafety {
                defensePoints += 2
            }
            
            /// 1b. Determine who is offense/defense for this hole (might not exist yet).
            guard let offense = session?.possession[hole],
                  let defense = teams.filter({ $0 != offense }).first
            else {
                /// 1c. if they don't exist yet
                if let previousOffsense = session?.possession[hole - 1],
                   let defense = teams.filter({ $0 != previousOffsense }).first {
                    return [GameScoreData(key: defense, value: defensePoints)]
                }
                return []
            }
            
            /// 2. Determine if the possession team won/tied the hole once offense has been set.
            let outcome = ScoreUtil.Match.computeScore(for: players, on: hole, teams: true, handicaps: handicaps)
            if !offense.isEmpty {
                if outcome == "tie" {
                    // Field Goal
                    offensePoints += 3
                } else if outcome == offense {
                    // Touchdown
                    offensePoints += 7
                } else if outcome != "" {
                    // Check for birdie for pick six
                    let didBirdie = players
                        .filter({ $0.team[hole] != offense })
                        .compactMap({ $0.score(for: hole, handicaps: handicaps).numericalValue })
                        .filter({ $0 <= PlayerScore.birdie.numericalValue })
                        .count > 0 // TODO: Change this to > 1 for both players needing a birdie if we decide to.
                    
                    if didBirdie {
                        defensePoints += 6
                    }
                }
            }
            
            var data: [GameScoreData] = []
            for t in teams {
                if t == offense {
                    data.append(GameScoreData(key: offense, value: offensePoints))
                }
                if t == defense {
                    data.append(GameScoreData(key: defense, value: defensePoints))
                }
            }
            
            return data
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
            
            return ""
        }
    }
}
