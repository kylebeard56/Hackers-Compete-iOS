//
//  NinesReultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import SwiftUI

struct NinesReultsView: View {
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
                let name = roundSession.players.first(where: { $0.id == d.key })?.name ?? ""
                HStack(spacing: 0) {
                    Text(name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(d.value)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
    static var previews: some View {
        NinesReultsView(session: SideGameSession())
    }
}
