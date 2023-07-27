//
//  BingoResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

private struct BingoDisplayData {
    var id: String = UUID().uuidString
    var player: Player
    var score: Int
}

struct BingoResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [BingoDisplayData] = []
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
            ForEach(data, id: \.id) { d in
                HStack(spacing: 0) {
                    Text(d.player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(d.score)")
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
        let results = ScoreUtil.Bingo.computeTotal(
            for: roundSession.players,
            playing: session.bingo,
            over: session.holes
        )
        
        data = results.compactMap({
            let id = $0.key
            guard let player = roundSession.players.first(where: { $0.id == id }) else { return nil }
            return BingoDisplayData(player: player, score: $0.value)
        }).sorted(by: { $0.score > $1.score })
        
        winner = "Scores"
        if data.count > 1, data[0].score == data[1].score {
            winner = "Tied"
        } else {
            winner = "\(data[0].player.name) won"
        }
    }
}

struct BingoResultsView_Previews: PreviewProvider {
    static var previews: some View {
        BingoResultsView(session: SideGameSession())
    }
}
