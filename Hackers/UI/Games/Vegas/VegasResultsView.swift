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
    
    @State private var data: [GameScoreData] = []
    @State private var winner: String = ""
    
    var body: some View {
        SideGameResultsView(session: session, winnerLabel: winner, content: { content } )
            .onAppear() { compute() }
            .onReceive(roundSession.$players, perform: { _ in compute() })
    }
    
    // MARK: - Views
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 20) {
            ForEach(data, id: \.key) { d in
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text(d.key)
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundColor(Color.systemBlack)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                        
                        Text("\(d.value)")
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundColor(Color.systemBlack)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 40, alignment: .center)
                    }
                    
                    playerLabel(for: d.key)
                        .alignLeading()
                }
            }
        }
    }
    
    // MARK: - Player rows

    /// NOTE: Don't remove this, as it could be used elsewhere...
    
//    @ViewBuilder private func playerLabel(for team: String) -> some View {
//        HStack(spacing: 0) {
//            if let hole = session.holes.last {
//                let players = roundSession.players.filter({ $0.team[hole] == team })
//                ForEach(Array(players.enumerated()), id: \.element) { index, player in
//                    let useAnd = index == players.count - 2
//                    let useComma = index < players.count - 2
//                    Group {
//                        Text(player.name)
//                            .font(.dmSans, size: 15, weight: .bold)
//                            .foregroundColor(player.color.value)
//                        + Text(useComma ? ", " : useAnd ? "  &  " : "")
//                            .font(.dmSans, size: 13, weight: .medium)
//                            .foregroundColor(Color.systemBlack)
//                    }
//                }
//            }
//        }
//    }
    
    @ViewBuilder private func playerLabel(for team: String) -> some View {
        HStack(spacing: 8) {
            if let hole = session.holes.last {
                let players = roundSession.players.filter({ $0.team[hole] == team })
                ForEach(Array(players.enumerated()), id: \.element) { index, player in
                    Text(player.name)
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(player.color.value)
                    if index != players.count - 1 {
                        Circle()
                            .fill(Color.systemGray3)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
//        data = [:]
//        let teams = roundSession.players.compactMap({ $0.team[session.holes.first ?? 0] }).uniques
        
//        for team in teams {
//            let score = ScoreUtil.Vegas.computeTotal(for: roundSession.players, for: team, over: session.holes)
//            data.updateValue(score, forKey: team)
//        }
        
        data = ScoreUtil.Vegas.computeTotal(
            for: roundSession.players,
            over: session.holes,
            handicaps: roundSession.usingHandicaps
        )
        .sorted(by: { $0.value > $1.value })
        
        winner = "Scores"
        if ScoreUtil.didTie(for: .first, with: data.compactMap({ ($0.key, $0.value) })) {
            winner = "Teams tied"
        } else if let first = data.first {
            winner = "\(first.key) won"
        }
        
//        if let min = data.values.min(),
//           let max = data.values.max(),
//           let w = data.first(where: { $0.value == min }) {
//            winner = min == max ? "Teams tied" : "\(w.key) won"
//        }
    }
}

struct VegasResultsView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        s.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        m.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        p.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "triple", 2: "triple", 3: "triple", 4: "triple"]
        m.score = [1: "bogey", 2: "par", 3: "par", 4: "par"]
        p.score = [1: "bogey", 2: "par", 3: "par", 4: "par"]
        
        return [k, s, m, p]
    }
    
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.vegas.rawValue,
            holes: [1, 2, 3, 4],
            stroke: nil,
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
        rs.teams = ["Team one", "Team two"]
        return rs
    }
    
    static var previews: some View {
        VegasResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
