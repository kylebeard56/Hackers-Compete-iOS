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
            sideGameSession.banker = BankerSession()
        case .bestBall:
            sideGameSession.match = MatchSession(skins: false)
        case .bingoBangoBongo:
            sideGameSession.bingo = BingoSession(play: [:])
        case .cardsOfChaos:
            sideGameSession.chaos = ChaosSession()
        case .fibonacci:
            sideGameSession.stroke = StrokeSession(twoBall: false)
        case .football:
            print("")
        case .hammer:
            print("")
        case .hotPotato:
            print("")
        case .medalPlay:
            sideGameSession.stroke = StrokeSession(twoBall: false)
        case .monkeyInTheMiddle:
            sideGameSession.monkey = MonkeySession(play: [:], skins: false)
        case .nines:
            print("do nothing -> nines game has no secondary session to keep track")
        case .stableford:
            sideGameSession.stroke = StrokeSession(twoBall: false)
        case .survivor:
            print("")
        case .vegas:
            print("do nothing -> vegas game has no secondary session to keep track")
        case .wolfHammer:
            print("")
        case .none:
            print("do nothing -> none")
        }
        
        return sideGameSession
    }
}
