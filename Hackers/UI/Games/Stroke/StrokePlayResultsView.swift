//
//  StrokePlayResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/16/23.
//

import SwiftUI

struct StrokePlayResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    private var format: StrokeScoringFormat {
        switch session.game {
        case SideGame.stableford.rawValue:
            return .stableford
        case SideGame.fibonacci.rawValue:
            return .fibonacci
        default:
            return .medal
        }
    }
    
    @State private var teamData: [GameScoreData] = []
    @State private var playerData: [GameScoreData] = []
    @State private var winner: String = ""
    
    @State private var isTwoBall: Bool = false
    @State private var twoBallScore: String = ""
    
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
                            
                            Text(format == .medal ? "\(d.value.toGolfScore)" : "\(d.value)")
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
                            
                            Text(format == .medal ? "\(d.value.toGolfScore)" : "\(d.value)")
                                .font(.dmSans(size: 17, weight: .bold))
                                .foregroundColor(player.color.value)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 40, alignment: .center)
                        }
                    }
                }
            }
            
            if isTwoBall {
                HStack(spacing: 0) {
                    Text("Two ball total")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text(twoBallScore)
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.systemGray6)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Computation
    
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
                            Text(format == .medal ? "\(score.value.toGolfScore)" : "\(score.value)")
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(player.color.value)
                                .frame(width: 40, alignment: .center)
                        }
                    }
                }
            }
        }
    }
    
    private func compute() {
        teamData = []
        playerData = []
        
        /// 1. Compute scores for players (need with or without teams)
        for p in roundSession.players {
            let score = ScoreUtil.Stroke.computeTotal(
                for: p,
                over: session.holes,
                using: format,
                handicaps: roundSession.usingHandicaps
            )
            playerData.append(GameScoreData(key: p.id, value: score))
        }
        playerData = playerData.sorted(by: { format == .medal ? $0.value < $1.value : $0.value > $1.value })
        
        if !teams.isEmpty {
            for team in teams {
                let score = ScoreUtil.Stroke.computeTotal(
                    for: roundSession.players,
                    on: team,
                    over: session.holes,
                    using: format,
                    handicaps: roundSession.usingHandicaps
                )
                teamData.append(GameScoreData(key: team, value: score))
            }
            teamData = teamData.sorted(by: { format == .medal ? $0.value < $1.value : $0.value > $1.value })
        }
        
        winner = "View scores"
        isTwoBall = session.stroke?.twoBall ?? false
        if isTwoBall {
            twoBallScore = ScoreUtil.Stroke.bestBallTotal(
                for: roundSession.players,
                over: session.holes,
                using: format
            ) ?? "Two ball"
        }

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

struct StrokePlayResultsView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [:]//[1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        s.team = [:]//[1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        m.team = [:]//[1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        p.team = [:]//[1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "triple", 2: "triple", 3: "triple", 4: "triple"]
        m.score = [1: "bogey", 2: "par", 3: "par", 4: "par"]
        p.score = [1: "bogey", 2: "par", 3: "par", 4: "par"]
        
        return [k, s, m, p]
    }
    
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.medalPlay.rawValue,
            holes: [1, 2, 3, 4],
            stroke: StrokeSession(twoBall: true),
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
        //rs.teams = ["Team one", "Team two"]
        return rs
    }
    
    static var previews: some View {
        StrokePlayResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
