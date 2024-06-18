//
//  MonkeyResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct MonkeyResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [GameScoreData] = []
    
    @State private var winner: String = ""
    @State private var skins: Bool = false
    @State private var skinsLeft: Int = 0
    
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
                if let player = roundSession.players.first(where: { $0.id == d.key }) {
                    HStack(spacing: 0) {
                        Text(player.name)
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundColor(player.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                        
                        Text("\(d.value)")
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundColor(player.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 40, alignment: .center)
                    }
                }
            }
            
            if skins {
                HStack(spacing: 0) {
                    Text("Skins leftover")
                        .font(.dmSans, size: 17, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(skinsLeft)")
                        .font(.dmSans, size: 17, weight: .bold)
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

    private func compute() {
        skins = session.monkey?.skins ?? false
        let monkeys = session.monkey?.play ?? [:]
        
        data = ScoreUtil.Monkey.computeTotal(
            for: roundSession.players,
            over: session.holes,
            monkeys: monkeys,
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )
        .compactMap( { GameScoreData(key: $0.key, value: $0.value) })
        .sorted(by: { $0.value > $1.value })
        
        if skins {
            skinsLeft = ScoreUtil.Monkey.skinsRollover(
                for: roundSession.players,
                over: session.holes,
                monkeys: monkeys
            )
        }
        
        winner = "Scores"
        if teams.isEmpty {
            if ScoreUtil.didTie(for: .first, with: data.compactMap { ($0.key, $0.value) }) {
                winner = "Players tied"
            } else {
                if let pid = data.first?.key, let player = roundSession.players.first(where: { $0.id == pid }) {
                    winner = "\(player.name) won"
                }
            }
        }
    }
}

struct MonkeyResultsView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        
        k.team = [:]
        s.team = [:]
        m.team = [:]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "birdie"]
        s.score = [1: "par", 2: "par", 3: "bogey", 4: "par"]
        m.score = [1: "par", 2: "birdie", 3: "double", 4: "par"]
        
        /// 1. K  is monkey -> Push
        /// 2. S is monkey and loses -> K = 2, M = 2, S = 0
        /// 3. M is monkey and loses -> K = 3, M = 2, S = 1
        /// 4. M is monkey and loses -> K = 4, M = 2, S = 2
        
        return [k, s, m]
    }
    
    static var previewSession: SideGameSession {
        return SideGameSession(
            id: "preview",
            game: SideGame.monkeyInTheMiddle.rawValue,
            holes: [1, 2, 3, 4],
            stroke: nil,
            match: nil,
            monkey: MonkeySession(play: [1: "kyle", 2: "sarah", 3: "murphy", 4: "murphy"], skins: true),
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
        return rs
    }
    
    static var previews: some View {
        MonkeyResultsView(session: previewSession)
            .environmentObject(roundSession)
            .alignTop()
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
