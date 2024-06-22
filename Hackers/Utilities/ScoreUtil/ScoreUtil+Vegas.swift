//
//  ScoreUtil+Vegas.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

extension ScoreUtil {
    struct Vegas {
        static func computeScore(
            for players: [Player],
            on team: String,
            on hole: Int,
            handicaps: Bool = true
        ) -> Int {
            var scores: [Int] = []
            
            for p in players {
                if p.team[hole] == team {
                    let score = p.score(for: hole, handicaps: handicaps)
                    if score != .none {
                        scores.append(score.numericalValue)
                    } else {
                        return 0
                    }
                }
            }
            
            let min = scores.min() ?? 0
            let max = scores.max() ?? 0
            return min * 10 + max
        }
        
        static func computeTotal(
            for players: [Player],
            for team: String,
            over holes: [Int],
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> Int {
            if holes.isEmpty { return 0 }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            return holes[0...last].reduce(0) {
                $0 + computeScore(for: players, on: team, on: $1, handicaps: handicaps)
            }
        }
        
        static func computePoints(
            for players: [Player],
            on hole: Int,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            let teams = players.compactMap({ $0.team[hole] }).filter({ !$0.isEmpty }).uniques
            guard let teamOne = teams.first, let teamTwo = teams.last else { return [] }
            
            var data = teams.reduce(into: [:], { $0[$1] = 0 })
            
            if players.filter({ $0.score(for: hole) == .none }).count > 0 { return [] }
            
            let x = computeScore(for: players, on: teamOne, on: hole, handicaps: handicaps)
            let y = computeScore(for: players, on: teamTwo, on: hole, handicaps: handicaps)
            
            if x > y {
                // Team two gets x-y pts
                data.updateValue(x - y, forKey: teamTwo)
            }
            
            if y > x {
                // Team one gets y-x past
                data.updateValue(y - x, forKey: teamOne)
            }
            
            return data.compactMap({ GameScoreData(key: $0.key, value: $0.value) })
        }
        
        static func computeTotal(
            for players: [Player],
            over holes: [Int],
            upTo hole: Int? = nil,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            if holes.isEmpty { return [] }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            
            let teams = players.compactMap({ $0.team[holes.last ?? 0] }).uniques
            var data = teams.reduce(into: [:], { $0[$1] = 0 })
            
            guard let teamOne = teams.first, let teamTwo = teams.last else { return [] }
            
            for h in holes[0...last] {
                let scores = ScoreUtil.Vegas.computePoints(for: players, on: h, handicaps: handicaps)
                for s in scores {
                    let pv = data[s.key] ?? 0
                    data.updateValue(pv + s.value, forKey: s.key)
                }
            }
            
            return data.compactMap({ GameScoreData(key: $0.key, value: $0.value) })
        }
        
        // TODO: Banner
    }
}
