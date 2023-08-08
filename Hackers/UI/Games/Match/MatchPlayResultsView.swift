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
    
    @State private var teamData: [String: Int] = [:]
    @State private var playerData: [String: Int] = [:]
    
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
                ForEach(Array(teamData.keys), id: \.self) { key in
                    let value = teamData[key]
                    HStack(spacing: 0) {
                        Text(key)
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                        
                        Text("\(value ?? 0)")
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            
            if !playerData.isEmpty {
                ForEach(Array(playerData.keys), id: \.self) { key in
                    let value = playerData[key]
                    if let player = roundSession.players.first(where: { $0.id == key }) {
                        HStack(spacing: 0) {
                            Text(player.name)
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(Color.systemBlack)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Spacer(minLength: 0)
                            
                            Text("\(value ?? 0)")
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
    
    // TODO: This is broken for computation and needs help...
    
    
    private func compute() {
        teamData = [:]
        playerData = [:]
        
        var teamsExist = false
        if let h = session.holes.last {
            teamsExist = roundSession.players.compactMap({ $0.team[h] }).uniques.count > 0
        }
        
        let scores = ScoreUtil.Match.computeTotal(
            for: roundSession.players,
            over: session.holes,
            teams: teamsExist,
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )

        if teamsExist {
            teamData = scores
        } else {
            playerData = scores
        }
        
        winner = "Scores"
        
        let sorted = Array(scores.keys).sorted(by: { scores[$0] ?? 99 < scores[$1] ?? 99 })
        
        let tuple = scores.compactMap { ($0.key, $0.value) }
        if ScoreUtil.didTie(for: .first, with: tuple) {
            winner = teamsExist ? "Teams tied" : "Players tied"
        } else if let winningKey = sorted.first {
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
