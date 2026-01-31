//
//  BankerResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/13/23.
//

import SwiftUI

struct BankerResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [GameScoreData] = []
    @State private var average: Int = 0
    @State private var winner: String = ""
    
    var body: some View {
        SideGameResultsView(
            session: session,
            winnerLabel: winner,
            content: { content }
        )
        .onAppear() { compute() }
        .onReceive(roundSession.$players, perform: { _ in compute() })
    }
    
    // MARK: - Views
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 20) {
            ForEach(data, id: \.self) { d in
                if let player = roundSession.players.first(where: { $0.id == d.key }) {
                    HStack(spacing: 20) {
                        Text(player.name)
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundColor(player.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                        
                        Text("\(d.value)")
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundColor(player.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 40, alignment: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Computation

    private func compute() {
        data = ScoreUtil.Banker.computeTotal(
            for: roundSession.players,
            playing: session.banker,
            over: session.holes,
            handicaps: roundSession.usingHandicaps
        )
        .sorted(by: { $0.value > $1.value })
        
        winner = "Scores"
        if ScoreUtil.didTie(for: .first, with: data.compactMap { ($0.key, $0.value) }) {
            winner = "Players tied"
        } else if let player = roundSession.players.first(where: { $0.id == data.first?.key ?? "" }) {
            winner = "\(player.name) won"
        }
    }
}

struct BankerResultsView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo

        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "triple", 2: "birdie", 3: "triple", 4: "birdie"]
        m.score = [1: "bogey", 2: "par", 3: "par", 4: "par"]
        p.score = [1: "bogey", 2: "par", 3: "par", 4: "eagle"]
        
        return [k, s, m, p]
    }
    
    static var banker: BankerSession {
        var b = BankerSession()
        
        b.banker = [1: "kyle", 2: "sarah", 3: "murphy", 4: "pablo"]
        
        b.wagers = [
            1: ["sarah": 20, "murphy": 40, "pablo": 60],
            2: ["kyle": 20, "murphy": 40, "pablo": 60],
            3: ["sarah": 20, "kyle": 40, "pablo": 60],
            4: ["sarah": 20, "murphy": 40, "kyle": 60]
        ]
        
        b.presses = [
            1: ["kyle": false, "sarah": true, "murphy": false, "pablo": false],
            2: ["kyle": false, "sarah": false, "murphy": true, "pablo": false],
            3: ["kyle": true, "sarah": false, "murphy": false, "pablo": true],
            4: ["kyle": true, "sarah": true, "murphy": true, "pablo": true]
        ]
        
        b.parThree = [1: false, 2: true, 3: false, 4: false]
        
        return b
    }
    
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.banker.rawValue,
            holes: [1, 2, 3, 4],
            stroke: nil,
            match: nil,
            monkey: nil,
            bingo: nil,
            chaos: nil,
            survivor: nil,
            hotPotato: nil,
            hammer: nil,
            banker: banker,
            wolfHammer: nil
        )
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var previews: some View {
        BankerResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
