//
//  BingoResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

struct BingoResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [String: Int] = [:]
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
        VStack(spacing: 10) {
            ForEach(roundSession.players, id: \.self) { player in
                HStack(spacing: 0) {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(data[player.id] ?? 0)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
        data = ScoreUtil.Bingo.computeTotal(
            for: roundSession.players,
            playing: session.bingo,
            over: session.holes
        )
        
        winner = "Scores"
        
        let scores = Array(data.values).sorted(by: { $0 > $1 })
        let max = scores.max() ?? 0
        
        let uniques = scores.uniques
        if scores.count > uniques.count {
            winner = "Tied"
        } else if let p = roundSession.players.first(where: {
            $0.id == data.first(where: { $0.value == max })?.key ?? ""
        }) {
            winner = "\(p.name) won"
        }
    }
}

struct BingoResultsView_Previews: PreviewProvider {
    static var previews: some View {
        BingoResultsView(session: SideGameSession())
    }
}
