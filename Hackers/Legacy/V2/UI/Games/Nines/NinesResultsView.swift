//
//  NinesResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import SwiftUI

struct NinesResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [GameScoreData] = []
    @State private var winner: String = ""
    
    var body: some View {
        SideGameResultsView(session: session, winnerLabel: winner, content: { content } )
            .onAppear() { compute() }
            .onReceive(roundSession.$players, perform: { _ in compute() })
    }
    
    // MARK: - Views
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 10) {
            ForEach(data, id: \.self) { d in
                if let player = roundSession.players.first(where: { $0.id == d.key }) {
                    HStack(spacing: 0) {
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
    
    // TODO: This needs to check player.count > 1, player[0] == player[1] then tied.
    
    private func compute() {
        data = ScoreUtil.Nines.computeResults(
            for: roundSession.players,
            over: session.holes
        ).sorted(by: { $0.value > $1.value })
        
        winner = "Scores"
        if data.count > 1, data[0].value == data[1].value {
            winner = "Tied"
        } else if let p = roundSession.players.first(where: { $0.id == data[0].key }){
            winner = "\(p.name) won"
        }
    }
}

struct NinesReultsView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "triple", 2: "triple", 3: "triple", 4: "triple"]
        m.score = [1: "bogey", 2: "par", 3: "par", 4: "par"]
        
        return [k, s, m]
    }
    
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.nines.rawValue,
            holes: [1, 2, 3, 4],
            stroke: nil,
            match: nil,
            monkey: nil,
            bingo: nil,
            chaos: nil,
            survivor: nil,
            hotPotato: nil,
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
        NinesResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
