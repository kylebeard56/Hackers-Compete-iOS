//
//  ScoreUtil+Nines.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

struct NinesData: Hashable, Identifiable {
    var id: UUID = UUID()
    var player: String
    var value: Int
}

extension ScoreUtil {
    struct Nines {
        static func computeScore(for players: [Player], on hole: Int) -> [NinesData] {
            var data: [NinesData] = []
            var scores: [String: Int] = [:]
            
            for p in players {
                let v = (PlayerScore(rawValue: p.score[hole] ?? "") ?? .none)
                /// Don't compute until all scores are in.
                if v == .none { return [] }
                scores.updateValue(v.numericalValue, forKey: p.id)
            }
            
            let raw = scores.values.sorted(by: <)
            let best = raw.min() ?? -99
            
            /// 1. No ties, allocate points based on sorting order
            if scores.values.count == Array(scores.values).uniques.count {
                for (k,v) in scores {
                    /// 1a. First place since first index of sorted raw scores is this value.
                    if raw[0] == v {
                        data.append(NinesData(player: k, value: 5))
                    }
                    /// 1b. Second place since second index of sorted raw scores is this value.
                    if raw[1] == v {
                        data.append(NinesData(player: k, value: 3))
                    }
                    /// 1c. Third place since third index of sorted raw scores is this value.
                    if raw[2] == v {
                        data.append(NinesData(player: k, value: 1))
                    }
                }
            /// 2. At least two players tied
            } else {
                for (k, v) in scores {
                    /// 2a. Everyone tied
                    if raw.uniques.count == 1 {
                        data.append(NinesData(player: k, value: 3))
                    /// 2b. Check whether the raw scores contains tie on best value to figure out tie for first or second place.
                    } else {
                        if raw.filter({ $0 == best }).count == 2 {
                            data.append(NinesData(player: k, value: v == best ? 4 : 1))
                        } else {
                            data.append(NinesData(player: k, value: v == best ? 5 : 2))
                        }
                    }
                }
            }
            
            return data
        }
        
        static func computeResults(for players: [Player], over holes: [Int]) -> [NinesData] {
            var data: [NinesData] = []
            for h in holes {
                for score in self.computeScore(for: players, on: h) {
                    if let i = data.firstIndex(where: { $0.player == score.player }) {
                        data[i].value += score.value
                    } else {
                        data.append(score)
                    }
                }
            }
            return data
        }
    }
}
