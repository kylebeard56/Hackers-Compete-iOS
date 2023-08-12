//
//  ScoreUtil+Monkey.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import Foundation

extension ScoreUtil {
    struct Monkey {
        /// Returns best ball score for a group of players on each hole. No teams. Returns `tie` if they tied.
        static func computeScore(
            for players: [Player],
            on hole: Int,
            monkey: String,
            teams: Bool = false,
            handicaps: Bool = true
        ) -> String {
            
            /// 1. Construct (Player, PlayerScore) tuple for each on this hole.
            let scores = players.compactMap { ($0.id, $0.score(for: hole, handicaps: handicaps)) }
            if scores.map({ $0.1 }).contains(.none) { return "" }

            /// 2. Sort by lowest score
            let tuple = scores
                .compactMap( { ($0.0, $0.1.numericalValue * ($0.0 == monkey ? 2 : 1)) })
                .sorted(by: { $0.1 < $1.1 })
            
            /// 3. Return tie (if push) or winning player tie
            if ScoreUtil.didTie(for: .first, with: tuple) {
                return "tie"
            } else {
                return tuple.first?.0 ?? ""
            }
        }
        
        /// Compute the total points won over a given hole range by each player.
        /// Returns `[player_id: score]`
        static func computeTotal(
            for players: [Player],
            over holes: [Int],
            monkeys: [Int: String],
            upTo hole: Int? = nil,
            skins: Bool = false,
            handicaps: Bool = true
        ) -> [String: Int] {
            if holes.isEmpty { return [:] }

            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            var skinValue: Int = 1
            var map = [String: Int]()
            
            /// 1. Initialize the map with default key for players since if they never win a hole, theoretically,
            /// the map will never add them and won't be shown.
            for p in players {
                map.updateValue(0, forKey: p.id)
            }
            
            /// 2. For each hole, we compute the winning ID (player id or team name) to add to the map, or if tie increment skins.
            for h in holes[0...last] {
                let monkey = monkeys[h] ?? ""
                if monkey.isEmpty { continue }
                
                let winner = ScoreUtil.Monkey.computeScore(for: players, on: h, monkey: monkey, handicaps: handicaps)
                if winner.isEmpty { continue }
                
                if winner == "tie" {
                    /// 2a. It's a push so skin rolls over if set.
                    skinValue += skins ? 1 : 0
                } else {
                    /// 2b. Winner is the monkey they get 2x whatever skins value is.
                    if winner == monkey {
                        let previousScore = map[winner] ?? 0
                        map.updateValue(previousScore + skinValue * 2, forKey: monkey)
                        skinValue = 1
                    } else {
                        /// 2c. Winner is the field, they get 1x whatever skins value is.
                        for p in players.filter({ $0.id != monkey }) {
                            let previousScore = map[p.id] ?? 0
                            map.updateValue(previousScore + skinValue, forKey: p.id)
                        }
                        skinValue = 1
                    }
                }
            }
            
            return map
        }
        
        static func skinsRollover(
            for players: [Player],
            over holes: [Int],
            for hole: Int? = nil,
            monkeys: [Int: String]
        ) -> Int {
            var count = 0
            if holes.isEmpty { return count }

            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            
            for h in holes[0...last] {
                guard let monkey = monkeys[h] else { return 0 }
                let v = ScoreUtil.Monkey.computeScore(for: players, on: h, monkey: monkey)
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
            monkeys: [Int: String],
            skins: Bool = false,
            handicaps: Bool = true
        ) -> String {
            guard let first = holes.first, let last = holes.last else { return "" }
            
            /// 1a. Ensure everyone has been scored.
            let unscored = players.compactMap({ !$0.hasScore(in: hole...hole) }).filter({ $0 })
            if !unscored.isEmpty { return "" }
            
            let skinsRollover = ScoreUtil.Monkey.skinsRollover(
                for: players,
                over: holes,
                for: hole,
                monkeys: monkeys
            )
            
            if hole == last {

                let totalOutcome = ScoreUtil.Monkey.computeTotal(
                    for: players,
                    over: holes,
                    monkeys: monkeys,
                    upTo: hole,
                    skins: skins,
                    handicaps: handicaps
                )
                .sorted(by: { $0.value > $1.value })
                .compactMap({ ($0.key, $0.value) })
                
                if ScoreUtil.didTie(for: .first, with: totalOutcome) {
                    return "We finish in a tie!"
                } else if let id = totalOutcome.first?.0 {
                    let winner = players.first(where: { $0.id == id })?.name ?? ""
                    if winner.isEmpty { return "" }
                    return "\(winner) won the game!"
                }
                return ""
                
            } else {

                guard let monkey = monkeys[hole] else { return "" }
                
                let holeOutcome = ScoreUtil.Monkey.computeScore(
                    for: players,
                    on: hole,
                    monkey: monkey,
                    handicaps: handicaps
                )
                
                if holeOutcome.isEmpty { return "" }

                let previousRollover = ScoreUtil.Monkey.skinsRollover(
                    for: players,
                    over: holes,
                    for: min(hole - 1, first),
                    monkeys: monkeys
                )
                
                if holeOutcome == "tie" {
                    if skins {
                        let skinsCount = (skinsRollover + 1) * 2
                        return "Push! \(skinsCount) point\(skinsCount > 1 ? "s" : "") up for grabs on the next hole."
                    } else {
                        return "Push! No points awarded this hole."
                    }
                } else if holeOutcome == monkey {
                    /// XXX gets x points!
                    
                    let winner = players.first(where: { $0.id == holeOutcome })?.name ?? ""
                    if winner.isEmpty { return "" }
                    
                    let pts = 2 + (skins ? previousRollover : 0) * 2
                    
                    if pts > 2 {
                        return "Jackpot! \(winner) wins \(pts) points!"
                    } else {
                        return "\(winner) wins \(pts) points."
                    }
                    
                } else {
                    /// YYY and ZZZ get x points each
                    
                    let winners = players.filter({ $0.id != monkey })
                    if winners.count != 2 { return "" }
                    
                    let pts = 1 + (skins ? previousRollover : 0)
                    if pts > 1 {
                        return "Jackpot! \(winners[0].name) and \(winners[1].name) win \(pts) points each!"
                    } else {
                        return "\(winners[0].name) and \(winners[1].name) win \(pts) point each."
                    }
                }
            }
        }
    }
}
