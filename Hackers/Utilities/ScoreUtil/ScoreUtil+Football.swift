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
            teams: Bool = false,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            let teams = players.compactMap({ $0.team[hole] }).uniques
            
            guard let offense = session?.possession[hole],
                  let defense = teams.filter({ $0 != offense }).first
            else { return [] }
            
            var offensePoints = 0
            var defensePoints = 0
            
            /// 1. Determine if the possession team won/tied the hole
            let outcome = ScoreUtil.Match.computeScore(for: players, on: hole, teams: true, handicaps: handicaps)
            if outcome == "tie" {
                // Field Goal
                offensePoints += 3
            } else if outcome == offense {
                // Touchdown
                offensePoints += 7
            } else {
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
            
            /// 2. Determine if the defense got a safety
            let onside = session?.onsideKick[hole] ?? OnsideKick()
            if onside.attempted && !(onside.successful ?? false) {
                defensePoints += 2
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
    }
}
