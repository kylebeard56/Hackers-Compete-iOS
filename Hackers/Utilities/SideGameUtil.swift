//
//  SideGameUtil.swift
//  Hackers
//
//  Created by Kyle Beard on 7/11/23.
//

import Foundation

struct SideGameUtil {
    static func buildSideGameSession(for game: SideGame, withHoleRange range: [Int]) -> SideGameSession {
        var sideGameSession = SideGameSession(id: UUID().uuidString, game: game.rawValue, holes: range)
        
        switch game {
        case .banker:
            print("")
        case .bestBall:
            print("")
        case .bingoBangoBongo:
            print("")
        case .cardsOfChaos:
            print("")
        case .football:
            sideGameSession.stroke = StrokeSession(twoBall: false)
        case .hammer:
            print("")
        case .hotPotato:
            print("")
        case .medalPlay:
            sideGameSession.stroke = StrokeSession(twoBall: false)
        case .monkeyInTheMiddle:
            print("")
        case .nines:
            print("")
        case .stableford:
            sideGameSession.stroke = StrokeSession(twoBall: false)
        case .survivor:
            print("")
        case .vegas:
            print("")
        case .wolfHammer:
            print("")
        case .none:
            print("")
        }
        
        return sideGameSession
    }
}
