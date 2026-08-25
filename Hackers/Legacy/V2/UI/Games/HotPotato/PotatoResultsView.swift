//
//  PotatoResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/6/24.
//

import SwiftUI

struct PotatoResultsView: View {
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
        data.removeAll()
        for p in roundSession.players {
            let score = ScoreUtil.HotPotato.computeTotal(
                for: roundSession.players,
                over: session.holes,
                with: session.hotPotato,
                handicaps: roundSession.usingHandicaps
            )
            data.append(GameScoreData(key: p.id, value: score))
        }
        data = data.sorted(by: { $0.value > $1.value })

        winner = "Scores"
        if ScoreUtil.didTie(for: .first, with: data.compactMap { ($0.key, $0.value) }) {
            winner = "Players tied"
        } else if let player = roundSession.players.first(where: { $0.id == data.first?.key ?? "" }) {
            winner = "\(player.name) won"
        }
    }
}


struct PotatoResultsView_Previews: PreviewProvider {
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
    
    static var potato: HotPotatoSession {
        var s = HotPotatoSession()
        
        s.play = [1: "kyle", 2: "sarah", 3: "murphy", 4: "pablo"]
        s.multiplier = [1: 2, 2: 3, 3: 2, 4: 3]

        return s
    }
    
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.hotPotato.rawValue,
            holes: [1, 2, 3, 4],
            stroke: nil,
            match: nil,
            monkey: nil,
            bingo: nil,
            chaos: nil,
            survivor: nil,
            hotPotato: potato,
            hammer: nil,
            banker: nil,
            wolfHammer: nil
        )
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var previews: some View {
        PotatoResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
