//
//  ScoreUtil+Banker.swift
//  Hackers
//
//  Created by Kyle Beard on 8/17/23.
//

import Foundation

//struct BankerGameData: Hashable, Codable {
//    var id: String = UUID().uuidString
//    var player: String
//    var isPush: Bool
//    var value: Int
//
//    init(player: String, isPush: Bool = false, value: Int) {
//        self.player = player
//        self.isPush = isPush
//        self.value = value
//    }
//}

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
                            multiplier = isParThree ? 6 : 4
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
            
            var d = GameScoreData(key: banker.id, value: bankerWinnings)
            data.append(d)
            
            return data.sorted(by: { $0.value > $1.value })
        }
        
//        private static func computeOutcome(
//            for players: [Player],
//            playing session: BankerSession?,
//            on hole: Int,
//            using data: inout [BankerGameData]
//        ) {
//            guard let id = session?.banker[hole],
//                  let banker = players.first(where: { $0.id == id }),
//                  let wagers = session?.wagers[hole],
//                  let presses = session?.presses[hole]
//            else { return }
//
//            let scores: [String: PlayerScore] = players.reduce(into: [:], {
//                $0[$1.id] = PlayerScore(rawValue: $1.score[hole] ?? "_") ?? PlayerScore.none
//            })
//
//            var bankerWinnings: Int = 0
//
//            let bankerPressed = presses[banker.id] ?? false
//            let isParThree = session?.parThree[hole] ?? false
//
//            for player in players {
//                /// 1. Get scores for banker and player
//                let playerScore = scores[player.id] ?? .none
//                let bankerScore = scores[banker.id] ?? .none
//
//                /// 2. If player is banker OR either score DNE then continue.
//                if player.id == banker.id { continue }
//                if playerScore == .none || bankerScore == .none { continue }
//
//                /// Get class
//                var d = data.first(where: { $0.player == player.id })
//
//                d?.isPush = false
//                if playerScore == bankerScore {
//                    d?.isPush = true
//                    // do nothing with totals since it'd be zero.
//                } else {
//                    let loss = playerScore.numericalValue > bankerScore.numericalValue
//                    let pressed = presses[player.id] ?? false
//                    let multiplier = pressed ? bankerPressed ? (isParThree ? 6 : 3) : (isParThree ? 4 : 2) : 1
//                    let wager = wagers[player.id] ?? 0
//                    let value = wager * multiplier
//
//                    if playerScore.numericalValue > bankerScore.numericalValue {
//                        d?.outcome = -value
//                        d?.total -= value
//                        bankerWinnings += value
//                    } else {
//                        d?.outcome = value
//                        d?.total += value
//                        bankerWinnings -= value
//                    }
//                }
//            }
//
//            var d = data.first(where: { $0.player == banker.id })
//            d?.outcome = bankerWinnings
//            d?.total += bankerWinnings
//        }
        
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
