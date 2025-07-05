//
//  FootballResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct FootballResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [GameScoreData] = []
    
    @State private var winner: String = ""
    
    private var teams: [String] {
        if let h = session.holes.last {
            return roundSession.players.compactMap({ $0.team[h] }).filter({ !$0.isEmpty }).uniques
        }
        return []
    }
    
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
                TeamScoreRow(name: d.key, score: "\(d.value)")
            }
        }
    }
    
    // MARK: - Computation

    private func compute() {
        data = ScoreUtil.Football.computeTotal(
            for: roundSession.players,
            playing: session.football,
            over: session.holes,
            handicaps: roundSession.usingHandicaps
        )
        .sorted(by: { $0.value > $1.value })
        
        winner = "Scores"
        if ScoreUtil.didTie(for: .first, with: data.compactMap { ($0.key, $0.value) }) {
            winner = "Teams tied"
        } else if let team = data.first?.key {
            winner = "\(team) won"
        }
    }
}

struct FootballResultsView_Previews: PreviewProvider {
    static var previews: some View {
        FootballResultsView(session: SideGameSession())
    }
}
