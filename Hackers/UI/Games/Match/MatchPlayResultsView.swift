//
//  MatchPlayResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/1/23.
//

import SwiftUI

struct MatchPlayResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var teamData: [GameScoreData] = []
    @State private var playerData: [GameScoreData] = []
    
    @State private var winner: String = ""
    @State private var skins: Bool = false
    
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
            if !teamData.isEmpty {
                ForEach(teamData, id: \.self) { d in
                    HStack(spacing: 0) {
                        Text(d.key)
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
            
            if !playerData.isEmpty {
                ForEach(playerData, id: \.self) { d in
                    if let player = roundSession.players.first(where: { $0.id == d.key }) {
                        HStack(spacing: 0) {
                            Text(player.name)
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
        }
    }
    
    // MARK: - Computation

    private func compute() {
        var teamsExist = false
        if let h = session.holes.last {
            teamsExist = roundSession.players.compactMap({ $0.team[h] }).uniques.count > 0
        }
        
        let scores = ScoreUtil.Match.computeTotal(
            for: roundSession.players,
            over: session.holes,
            teams: teamsExist,
            skins: session.match?.skins ?? false,
            handicaps: roundSession.usingHandicaps
        )
        .compactMap( { GameScoreData(key: $0.key, value: $0.value) })
        .sorted(by: { $0.value > $1.value })

        teamData = teamsExist ? scores : []
        playerData = teamsExist ? [] : scores
        
        winner = "Scores"
        
        let tuple = scores.compactMap { ($0.key, $0.value) }
        if ScoreUtil.didTie(for: .first, with: tuple) {
            winner = teamsExist ? "Teams tied" : "Players tied"
        } else if let winningKey = scores.first?.key {
            if teamsExist {
                winner = "\(winningKey) won"
            } else if let player = roundSession.players.first(where: { $0.id == winningKey }) {
                winner = "\(player.name) won"
            }
        }
    }
}

struct MatchPlayResultsView_Previews: PreviewProvider {
    static var previews: some View {
        MatchPlayResultsView(session: SideGameSession())
    }
}
