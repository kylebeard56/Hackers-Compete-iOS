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
            sideGameSession.match = MatchSession()
        case .bingo:
            sideGameSession.bingo = BingoSession()
        case .cardsOfChaos:
            sideGameSession.chaos = ChaosSession()
        case .checkpoint:
            print("WARNING: Side game session wasn't initialized!")
        case .fibonacci:
            sideGameSession.stroke = StrokeSession()
        case .football:
            sideGameSession.football = FootballSession()
        case .golfBingo:
            print("WARNING: Side game session wasn't initialized!")
        case .hammer:
            print("WARNING: Side game session wasn't initialized!")
        case .hotPotato:
            print("WARNING: Side game session wasn't initialized!")
        case .jackpot:
            print("WARNING: Side game session wasn't initialized!")
        case .medalPlay:
            sideGameSession.stroke = StrokeSession()
        case .monkeyInTheMiddle:
            sideGameSession.monkey = MonkeySession()
        case .nines:
            print("do nothing -> nines game has no secondary session to keep track")
        case .stableford:
            sideGameSession.stroke = StrokeSession()
        case .survivor:
            print("WARNING: Side game session wasn't initialized!")
        case .twentyOne:
            print("WARNING: Side game session wasn't initialized!")
        case .vegas:
            print("do nothing -> vegas game has no secondary session to keep track")
        case .wolfHammer:
            print("WARNING: Side game session wasn't initialized!")
        case .none:
            print("do nothing -> none")
        }
        
        return sideGameSession
    }
}
