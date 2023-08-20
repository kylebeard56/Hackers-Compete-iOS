//
//  ScoreUtil+Banker.swift
//  Hackers
//
//  Created by Kyle Beard on 8/17/23.
//

import Foundation

extension ScoreUtil {
    struct Banker {
        static func computeScores(
            for players: [Player],
            playing session: BankerSession?,
            on hole: Int,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            guard let id = session?.banker[hole],
                  let banker = players.first(where: { $0.id == id }),
                  let wagers = session?.wagers[hole],
                  let presses = session?.presses[hole]
            else { return [] }
            
            var data: [GameScoreData] = []
            var scores: [String: Int] = [:]
            
            for p in players {
                let v = p.score(for: hole, handicaps: handicaps)
                /// Don't compute until all scores are in.
                if v == .none { return [] }
                scores.updateValue(v.numericalValue, forKey: p.id)
            }
            
            var bankerWinnings: Int = 0
            
            let bankerPressed = presses[banker.id] ?? false
            let isParThree = session?.parThree[hole] ?? false
            
            for player in players {
                if player.id == banker.id { continue }

                let playerScore = scores[player.id] ?? 99
                let bankerScore = scores[banker.id] ?? 99
                var d = GameScoreData(key: player.id, value: 0)
                
                if playerScore != bankerScore {
                    
                    /// 1. Get press and wager for this player
                    let pressed = presses[player.id] ?? false
                    let wager = wagers[player.id] ?? 0
                    
                    var multiplier = 1
                    if pressed || bankerPressed {
                        if pressed && bankerPressed {
                            multiplier = isParThree ? 9 : 4
                        } else {
                            multiplier = isParThree ? 3 : 2
                        }
                    }
                    
                    let value = wager * multiplier
                    if playerScore > bankerScore {
                        d.value = -value
                        bankerWinnings += value
                    } else {
                        d.value = value
                        bankerWinnings -= value
                    }
                }
                
                data.append(d)
            }
            
            data.append(GameScoreData(key: banker.id, value: bankerWinnings))
            return data.sorted(by: { $0.value > $1.value })
        }
   
        static func computeTotal(
            for players: [Player],
            playing banker: BankerSession?,
            over holes: [Int],
            on hole: Int? = nil,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            if holes.isEmpty { return [] }
            let last = holes.firstIndex(of: hole ?? holes.last ?? 0) ?? 0
            
            var scores: [String: Int] = [:]
            
            for h in holes[0...last] {
                for s in ScoreUtil.Banker.computeScores(for: players, playing: banker, on: h, handicaps: handicaps) {
                    let v = scores[s.key] ?? 0
                    scores.updateValue(v + s.value, forKey: s.key)
                }
            }
            
            return scores.compactMap({ GameScoreData(key: $0.key, value: $0.value) })
        }
        
        // TODO: Banner
    }
}
