//
//  RoundSession+Games.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import Foundation

extension RoundSession {
    func updateGames(for hole: Int) {
        guard let session = self.sideGameSessions.first(where: { $0.holes.contains(hole) }) else { return }
        guard let game = SideGame(rawValue: session.game) else { return }
        self.sideGame = game
    }
    
    func startSideGame(_ game: SideGame, on hole: Int) {
        /// If I start a side game mid-round, I build a range from the current hole onward, imaging the first unplayed holes as
        /// a blank side game in the scheme of how we'll partition.
        
        /// 1. Chip away at range that removes all holes up until the current OR first side game in range.
        var range = holeRange
        var soonestSideGame = sideGameSessions.compactMap({ $0.holes }).flatMap({ $0 }).uniques
        for h in range {
            if h == hole || soonestSideGame.contains(h) {
                /// If we've hit current hole or a hole in the range sequence that contains another game, stop.
                break
            } else {
                /// Deduct hole from potential new side game range
                range.removeAll(where: { $0 == h })
            }
        }
        
        sideGameSessions.append(SideGameUtil.buildSideGameSession(for: game, withHoleRange: range))
    }
    
    func changeSideGame(to game: SideGame, on hole: Int) {
        /// If I end a side game, I take the current game's range and cut it in two at the current hole.
        
        if let i = sideGameSessions.firstIndex(where: { $0.holes.contains(currentHole) }) {
            let session = sideGameSessions[i]
            
            var endingRange = session.holes
            for h in endingRange {
                if h != hole {
                    endingRange.removeAll(where: { $0 == h })
                } else { break }
            }
            let startingRange = Set(session.holes).subtracting(Set(endingRange))
            
            sideGameSessions[i].holes = Array(startingRange)
            
            let newGameSession = SideGameUtil.buildSideGameSession(for: game, withHoleRange: endingRange)
            sideGameSessions.append(newGameSession)
        }
    }
    
    func quitCurrentSideGame(on hole: Int, keep: Bool) {
        /// If I change a side game, I take the current game's range and split it. The current hole is included in the ending game
        /// if the hole was scored, otherwise it goes with the new game.
        
        if let i = sideGameSessions.firstIndex(where: { $0.holes.contains(currentHole) }) {
            /// 1. Preserve past holes, so partition range
            if keep {
                let session = sideGameSessions[i]
                var endingRange = session.holes
                for h in endingRange {
                    if h != hole {
                        endingRange.removeAll(where: { $0 == h })
                    } else { break }
                }
                let startingRange = Set(session.holes).subtracting(Set(endingRange))
                
                sideGameSessions[i].holes = Array(startingRange)
            /// 2. Remove all history of this game
            } else {
                sideGameSessions.remove(at: i)
            }
        }
    }
}
