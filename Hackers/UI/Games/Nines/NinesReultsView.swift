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
    
    @State private var data: [NinesData] = []
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
                let name = roundSession.players.first(where: { $0.id == d.player })?.name ?? ""
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
    
    private func compute() {
        data = ScoreUtil.Nines.computeResults(for: roundSession.players, over: session.holes)
        data = data.sorted(by: { $0.value > $1.value })
        let scores = data.compactMap({ $0.value })
        let uniques = data.uniques
        if uniques.count < scores.count {
            winner = "Players tied"
        } else if let max = scores.max(),
                  let w = data.first(where: { $0.value == max }),
                  let name = roundSession.players.first(where: { $0.id == w.player }) {
            winner = "\(name) won"
        } else {
            winner = "Scores"
        }
    }
}

struct NinesReultsView_Previews: PreviewProvider {
    static var previews: some View {
        NinesReultsView(session: SideGameSession())
    }
}
