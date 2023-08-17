//
//  ScoreUtil+Nines.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

extension ScoreUtil {
    struct Nines {
        static func computeScore(
            for players: [Player],
            on hole: Int,
            handicaps: Bool = true
        ) -> [GameScoreData] {
            var data: [GameScoreData] = []
            var scores: [String: Int] = [:]
            
            for p in players {
                let v = p.score(for: hole, handicaps: handicaps)
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
                        data.append(GameScoreData(key: k, value: 5))
                    }
                    /// 1b. Second place since second index of sorted raw scores is this value.
                    if raw[1] == v {
                        data.append(GameScoreData(key: k, value: 3))
                    }
                    /// 1c. Third place since third index of sorted raw scores is this value.
                    if raw[2] == v {
                        data.append(GameScoreData(key: k, value: 1))
                    }
                }
            /// 2. At least two players tied
            } else {
                for (k, v) in scores {
                    /// 2a. Everyone tied
                    if raw.uniques.count == 1 {
                        data.append(GameScoreData(key: k, value: 3))
                    /// 2b. Check whether the raw scores contains tie on best value to figure out tie for first or second place.
                    } else {
                        if raw.filter({ $0 == best }).count == 2 {
                            data.append(GameScoreData(key: k, value: v == best ? 4 : 1))
                        } else {
                            data.append(GameScoreData(key: k, value: v == best ? 5 : 2))
                        }
                    }
                }
            }
            
            return data
        }
        
        static func computeResults(
            for players: [Player],
            over holes: [Int],
            handicaps: Bool = true
        ) -> [GameScoreData] {
            var data: [GameScoreData] = []
            for h in holes {
                for score in self.computeScore(for: players, on: h, handicaps: handicaps) {
                    if let i = data.firstIndex(where: { $0.key == score.key }) {
                        data[i].value += score.value
                    } else {
                        data.append(score)
                    }
                }
            }
            return data
        }
        
        static func banner(
            for players: [Player],
            over holes: [Int],
            on hole: Int,
            handicaps: Bool = true
        ) -> String {
            guard let first = holes.first, let last = holes.last else { return "" }
            
            /// 1a. Check if scores exist for current hole
            if ScoreUtil.Nines.computeScore(for: players, on: hole, handicaps: handicaps).isEmpty { return "" }
            
            /// 1b. Compute and build tuple for players and scores
            let currentScores = ScoreUtil.Nines
                .computeResults(for: players, over: holes, handicaps: handicaps)
                .compactMap({
                    let id = $0.key
                    if let p = players.first(where: { $0.id == id }) {
                        return (p, $0.value)
                    }
                    return nil
                }).sorted(by: { $0.1 > $1.1 })
            
            /// 1c. If current scores are less than 3, we should return since we didn't get 3 player scores.
            if currentScores.count < 3 { return "" }
            
            /// 2. If the hole is the last in the array, we want to show final results.
            if hole == last {
                
                if ScoreUtil.didTie(for: .first, with: currentScores) {
                    if ScoreUtil.didTie(for: .second, with: currentScores) {
                        return "Everyone finished tied."
                    } else {
                        return "\(currentScores[0].0.name) and \(currentScores[1].0.name) finished tied."
                    }
                } else {
                    return "\(currentScores[0].0.name) wins the game!"
                }
                
            /// 3. If the hole is first in the array, we want to show a kickoff message.
            } else if hole == first {

                if ScoreUtil.didTie(for: .first, with: currentScores) {
                    if ScoreUtil.didTie(for: .second, with: currentScores) {
                        return "Everyone starts tied."
                    } else {
                        return "\(currentScores[0].0.name) and \(currentScores[1].0.name) start tied for 1st place."
                    }
                } else {
                    return "\(currentScores[0].0.name) takes the early lead!"
                }
                
            /// 4. Compute label for intermediate holes, account for lead changes or ties.
            } else {
                
                let previousScores = ScoreUtil.Nines
                    .computeResults(for: players, over: holes, handicaps: handicaps)
                    .compactMap({
                        let id = $0.key
                        if let p = players.first(where: { $0.id == id }) {
                            return (p, $0.value)
                        }
                        return nil
                    }).sorted(by: { $0.1 > $1.1 })
                
                if previousScores[0].0.id != currentScores[0].0.id {
                    /// 4a. Lead change
                    if ScoreUtil.didTie(for: .first, with: currentScores) {
                        return "\(currentScores[0].0.name) jumps up to tie \(previousScores[0].0.name)!"
                    } else {
                        return "\(currentScores[0].0.name) takes the lead from \(previousScores[0].0.name)!"
                    }
                } else if ScoreUtil.didTie(for: .first, with: currentScores) {
                    /// 4b. Tie for first
                    if ScoreUtil.didTie(for: .second, with: currentScores) {
                        return "The leaderboard is up from grabs with multiple ties for 1st place."
                    } else {
                        return "\(currentScores[0].0.name) and \(previousScores[1].0.name) are tied for 1st place."
                    }
                    
                } else if ScoreUtil.didTie(for: .second, with: currentScores) {
                    /// 4c. Same leader, but tie for second
                    return "\(currentScores[0].0.name) keeps the lead, but there's a battle for 2nd place!"
                } else if previousScores[1].0.id != currentScores[1].0.id {
                    /// 4d. Same leader, but change at second
                    return "\(currentScores[0].0.name) keeps the lead, but \(currentScores[1].0.name) jumps into 2nd place!"
                } else {
                    /// 4e. Same first and second place
                    return "\(currentScores[0].0.name) remains the leader, with \(currentScores[1].0.name) still in 2nd place."
                }
                
            }
        }
    }
}
