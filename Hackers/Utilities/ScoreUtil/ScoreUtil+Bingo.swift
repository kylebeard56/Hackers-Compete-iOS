//
//  ScoreUtil+Bingo.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import Foundation

extension ScoreUtil {
    struct Bingo {
        static func computeScore(
            for players: [Player],
            in session: BingoSession?,
            on hole: Int
        ) -> [String: Int] {
            guard let scores = session?.play else { return [:] }
            var map: [String: Int] = [:]
            
            for p in players {
                var sum = 0
                if scores[hole]?.bingo ?? "" == p.id { sum += 1 }
                if scores[hole]?.bango ?? "" == p.id { sum += 1 }
                if scores[hole]?.bongo ?? "" == p.id { sum += 1 }
                map.updateValue(sum, forKey: p.id)
            }
            
            return map
        }
        
        static func computeTotal(
            for players: [Player],
            playing bingo: BingoSession?,
            over holes: [Int],
            upTo hole: Int? = nil
        ) -> [String: Int] {
            if holes.isEmpty { return [:] }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            
            var map: [String: Int] = [:]
            for h in holes[0...last] {
                for (k,v) in computeScore(for: players, in: bingo, on: h) {
                    map.updateValue(v + (map[k] ?? 0), forKey: k)
                }
            }
            return map
        }
        
        static func computeTotal(
            for players: [Player],
            on team: String = "",
            playing bingo: BingoSession?,
            over holes: [Int],
            upTo hole: Int? = nil
        ) -> Int {
            let first = holes.first ?? hole ?? 0
            return ScoreUtil.Bingo.computeTotal(
                for: players,
                playing: bingo,
                over: holes,
                upTo: hole
            )
            .compactMap {
                let id = $0.key
                if let player = players.first(where: { $0.id == id }), player.team[first] == team {
                    return $0.value
                }
                return nil
            }
            .reduce(0, +)
        }
    }
}
