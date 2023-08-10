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
    
    @State private var teamData: [GameScoreData] = []
    @State private var playerData: [GameScoreData] = []
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
            if !teams.isEmpty {
                ForEach(teamData, id: \.self) { d in
                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            Text(d.key)
                                .font(.dmSans(size: 17, weight: .bold))
                                .foregroundColor(Color.systemBlack)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .alignLeading()
                            
                            Spacer(minLength: 0)
                            
                            Text("\(d.value)")
                                .font(.dmSans(size: 17, weight: .bold))
                                .foregroundColor(Color.systemBlack)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 40, alignment: .center)
                        }
                        
                        playerRows(for: d.key)
                    }
                }
            } else {
                ForEach(playerData, id: \.self) { d in
                    if let player = roundSession.players.first(where: { $0.id == d.key }) {
                        HStack(spacing: 0) {
                            Text(player.name)
                                .font(.dmSans(size: 17, weight: .bold))
                                .foregroundColor(player.color.value)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Spacer(minLength: 0)
                            
                            Text("\(d.value)")
                                .font(.dmSans(size: 17, weight: .bold))
                                .foregroundColor(player.color.value)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 40, alignment: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Player rows
    
    @ViewBuilder private func playerRows(for team: String) -> some View {
        VStack(spacing: 8) {
            if let hole = session.holes.last {
                ForEach(roundSession.players.filter({ $0.team[hole] == team }), id: \.self) { player in
                    if let score = playerData.first(where: { $0.key == player.id }) {
                        HStack {
                            Text(player.name)
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(player.color.value)
                            Spacer(minLength: 0)
                            Text("\(score.value)")
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(player.color.value)
                                .frame(width: 40, alignment: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
        teamData = []
        playerData = []
        
        playerData = ScoreUtil.Bingo.computeTotal(
            for: roundSession.players,
            playing: session.bingo,
            over: session.holes
        )
        .compactMap( { GameScoreData(key: $0.key, value: $0.value) })
        .sorted(by: { $0.value > $1.value })
        
        if !teams.isEmpty {
            for team in teams {
               let score = ScoreUtil.Bingo.computeTotal(
                    for: roundSession.players,
                    on: team,
                    playing: session.bingo,
                    over: session.holes
                )
                teamData.append(GameScoreData(key: team, value: score))
            }
            teamData = teamData.sorted(by: { $0.value > $1.value })
        }
        
        winner = "Scores"
        if teams.isEmpty {
            if ScoreUtil.didTie(for: .first, with: playerData.compactMap { ($0.key, $0.value) }) {
                winner = "Players tied"
            } else {
                if let pid = playerData.first?.key, let player = roundSession.players.first(where: { $0.id == pid }) {
                    winner = "\(player.name) won"
                }
            }
        } else {
            if ScoreUtil.didTie(for: .first, with: teamData.compactMap { ($0.key, $0.value) }) {
                winner = "Teams tied"
            } else if let team = teamData.first?.key {
                winner = "\(team) won"
            }
        }
    }
}

struct BingoResultsView_Previews: PreviewProvider {
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.bingoBangoBongo.rawValue,
            holes: [1, 2, 3, 4],
            stroke: StrokeSession(twoBall: true),
            match: nil,
            monkey: nil,
            bingo: BingoSession(
                play: [
                    1: BingoData(bingo: "kyle", bango: "sarah", bongo: "murphy"),
                    2: BingoData(bingo: "sarah", bango: "pablo", bongo: "murphy"),
                    3: BingoData(bingo: "kyle", bango: "sarah", bongo: "pablo"),
                    4: BingoData(bingo: "kyle", bango: "kyle", bongo: "pablo"),
                    5: BingoData(bingo: "", bango: "", bongo: ""),
                ]
            ),
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
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        return rs
    }
    
    static var previews: some View {
        BingoResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
