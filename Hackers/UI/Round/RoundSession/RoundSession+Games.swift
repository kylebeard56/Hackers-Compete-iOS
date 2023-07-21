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
    
    func changeSideGame(to game: SideGame, on hole: Int) {
        if let i = sideGameSessions.firstIndex(where: { $0.holes.contains(currentHole) }) {
            let session = sideGameSessions[i]
            if let split = session.holes.firstIndex(of: hole) {
                let left = Array(session.holes[0..<split])
                let right = Array(session.holes[split...])
                sideGameSessions[i].holes = left
                
                let newGameSession = SideGameUtil.buildSideGameSession(for: game, withHoleRange: right)
                sideGameSessions.append(newGameSession)
            }
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
                sideGameSessions[i] = SideGameUtil.buildSideGameSession(
                    for: .none,
                    withHoleRange: sideGameSessions[i].holes
                )
            }
        }
    }
}
