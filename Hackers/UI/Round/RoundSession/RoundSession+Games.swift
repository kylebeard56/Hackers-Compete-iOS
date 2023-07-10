//
//  RoundSession+Games.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import Foundation

extension RoundSession {
    
    func updateGames(for hole: Int) {
        guard let session = self.sideGameSessions.first(where: { $0.holes.contains(hole) }) else {
            self.addBreadcrumb(.error, .sideGame, "Side game session not found on update")
            return
        }
        
        guard let game = SideGame(rawValue: session.game) else {
            self.addBreadcrumb(.error, .sideGame, "Side game enum not found from session game [\(session.game)]")
            return
        }
        
        self.sideGame = game
        
//        switch game {
//        case .medalPlay, .stableford, .football:
//            computeStrokeGame(for: session, and: game)
//        default: print("todo: compute game that isn't handled yet")
//        }
    }
    
    // MARK: - Stroke
    
//    private func computeStrokeGame(for session: SideGameSession, and game: SideGame) {
//        if game == .stableford {
//            self.strokeScoringFormat = .stableford
//        } else if game == .football {
//            self.strokeScoringFormat = .football
//        } else {
//            self.strokeScoringFormat = .medal
//        }
//
//        self.isPlayingTwoBall = session.stroke?.twoBall ?? false
//    }
}
