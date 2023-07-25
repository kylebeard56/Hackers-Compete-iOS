//
//  VegasResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import SwiftUI

struct VegasResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [String: Int] = [:]
    @State private var winner: String = ""
    
    var body: some View {
        SideGameResultsView(session: session, winnerLabel: winner, content: { content } )
            .onAppear() { compute() }
            .onReceive(roundSession.$players, perform: { _ in compute() })
    }
    
    // MARK: - Views
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 10) {
            ForEach(data.sorted(by: <), id: \.key) { (team, score) in
                HStack(spacing: 0) {
                    Text(team)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(score)")
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
        data = [:]
        let teams = roundSession.players.compactMap({ $0.team[session.holes.first ?? 0] }).uniques
        
        for team in teams {
            let score = ScoreUtil.Vegas.computeTotal(for: roundSession.players, for: team, over: session.holes)
            data.updateValue(score, forKey: team)
        }
        
        winner = "Scores"
        if let min = data.values.min(),
           let max = data.values.max(),
           let w = data.first(where: { $0.value == min }) {
            winner = min == max ? "Teams tied" : "\(w.key) won"
        }
    }
}

struct VegasResultsView_Previews: PreviewProvider {
    static var previews: some View {
        VegasResultsView(session: SideGameSession())
    }
}
