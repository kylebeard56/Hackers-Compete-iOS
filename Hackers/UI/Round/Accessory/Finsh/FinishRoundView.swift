//
//  FinishRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/27/23.
//

import SwiftUI

struct FinishRoundView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    leaderboardView
                    sideGameView
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
            
            VStack(spacing: 20) {
                Divider()
                
                // TODO: Hackers v2.1
//                SmallButton(title: "Share round", isDisabled: .false, isLoading: .false)
//                    .onTapAsync {
//                        print("todo: show share sheet with PNG generated picture of round with side game outcomes that people can share w/ branding")
//                
//                    }
//                    .padding(.horizontal, 20)
                
                BigButton(title: "Finish round", isDisabled: .false, isLoading: .false)
                    .onTapAsync {
                        await appSession.leaveRound()
                    }
                    .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder private var leaderboardView: some View {
        VStack(spacing: 12) {
            Text("Leaderboard")
                .font(.dmSans, size: 20, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            // TODO: How to show teams here?
            if roundSession.teams.isEmpty {
                ForEach(roundSession.players, id: \.self) { player in
                    FinishRoundPlayerRow(player: player)
                }
            } else {
                ForEach(roundSession.teams, id: \.self) { team in
                    
                }
            }
        }
    }
    
    @ViewBuilder private var sideGameView: some View {
        VStack(spacing: 12) {
            Text("Side games")
                .font(.dmSans, size: 20, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            ForEach(roundSession.sideGameSessions, id: \.id) { session in
                AnyView(sideGameResultView(for: session))
            }
        }
    }
    
    @ViewBuilder private func sideGameResultView(for session: SideGameSession) -> any View {
        let game = SideGame(rawValue: session.game) ?? .none
        switch game {
        case .none:                 EmptyView()
        case .medalPlay:            StrokePlayResultsView(session: session)
        case .stableford:           StrokePlayResultsView(session: session)
        case .fibonacci:            StrokePlayResultsView(session: session)
        case .nines:                NinesResultsView(session: session)
        case .vegas:                VegasResultsView(session: session)
        case .bingo:      BingoResultsView(session: session)
        case .bestBall:             MatchPlayResultsView(session: session)
        case .monkeyInTheMiddle:    MonkeyResultsView(session: session)
        case .cardsOfChaos:         ChaosResultsView(session: session)
        case .banker:               BankerResultsView(session: session)
        case .football:             FootballResultsView(session: session)
        default:                    EmptyView()
        }
    }
}

struct FinishRoundView_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        rs.sideGameSessions = [fibonacci, football, bestBall, chaos]
        return rs
    }
    
    static var fibonacci: SideGameSession {
        var s = SideGameSession()
        return s
    }
    
    static var football: SideGameSession {
        var s = SideGameSession()
        return s
    }
    
    static var bestBall: SideGameSession {
        var s = SideGameSession()
        return s
    }
    
    static var chaos: SideGameSession {
        var s = SideGameSession()
        return s
    }
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
//        k.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
//        s.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
//        m.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
//        p.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
        
        k.score = [
            1: "par",
            2: "par",
            3: "bogey",
            4: "double",
            5: "bogey",
            6: "tripe",
            7: "par",
            8: "birdie",
            9: "par"
        ]
        
        s.score = [
            1: "bogey",
            2: "par",
            3: "bogey",
            4: "birdie",
            5: "eagle",
            6: "tripe",
            7: "par",
            8: "double",
            9: "par"
        ]
        
        m.score = [
            1: "bogey",
            2: "par",
            3: "bogey",
            4: "birdie",
            5: "bogey",
            6: "eagle",
            7: "par",
            8: "double",
            9: "par"
        ]
        
        p.score = [
            1: "birdie",
            2: "double",
            3: "bogey",
            4: "double",
            5: "birdie",
            6: "tripe",
            7: "par",
            8: "bogey",
            9: "par"
        ]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        FinishRoundView()
            .environmentObject(AppSession())
            .environmentObject(roundSession)
            .holisticPreview()
    }
}
