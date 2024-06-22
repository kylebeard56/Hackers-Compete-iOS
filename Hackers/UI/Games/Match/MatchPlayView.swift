//
//  MatchPlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/1/23.
//

import SwiftUI

struct MatchPlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    @Binding var hole: Int
    
    @State private var data: [GameScoreData] = []
    @State private var skins: Bool = false
    @State private var bannerText: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            if !bannerText.isEmpty {
                InfoBanner(
                    icon: viewModel.sideGame.icon,
                    text: bannerText,
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            if roundSession.teams.isEmpty {
                playerDisplay
            } else {
                teamDisplay
            }
            
            if roundSession.players.count > 1 {
                skinsToggle
            }
        }
        .onAppear() {
            skins = viewModel.sideGameSession.match?.skins ?? false
            compute()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            if roundSession.isInSync { return }
            withAnimation(.easeOut(duration: 0.2)) {
                skins = viewModel.sideGameSession.match?.skins ?? false
                compute()
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            compute()
        })
        /// Publish local changes back to current hole view model
        .onChange(of: skins, perform: { value in
            viewModel.sideGameSession.match = MatchSession(skins: value)
            compute()
        })
    }
    
    // MARK: - Player
    
    @ViewBuilder private var playerDisplay: some View {
        HStack(spacing: 10) {
            ForEach(data, id: \.self) { d in
                if let player = roundSession.players.first(where: { $0.id == d.key }) {
                    let score = player.score(for: hole, handicaps: roundSession.usingHandicaps)
                    if score == .none {
                        PlayerScoreTile(
                            player: player,
                            score: "\(d.value)",
                            subtitle: roundSession.scoringExists(for: hole) ? "" : nil,
                            placeholder: true
                        )
                    } else {
                        PlayerScoreTile(
                            player: player,
                            score: "\(d.value)",
                            subtitle: score.shortName
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Team
    
    private var teamDisplay: some View {
        HStack(spacing: 10) {
            ForEach(roundSession.teams, id: \.self) { team in
                if let score = data.first(where: { $0.key == team })?.value {
                    TeamScoreTile(
                        team: team,
                        score: "\(score)",
                        hole: hole,
                        placeholder: !roundSession.everyoneScored(on: hole, team: team),
                        scale: 2
                    )
                }
            }
        }
    }
    
    // MARK: - Skins
    
    @ViewBuilder private var skinsToggle: some View {
        Toggle(isOn: $skins, label: {
            VStack(spacing: 4) {
                Text("Skins")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text("Ties roll points over to the next hole.")
                    .font(.dmSans, size: 13, weight: .regular)
                    .foregroundColor(Color.systemGray)
                    .alignLeading()
            }
        })
        .tint(Color.systemHackersPurple)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Computation
    
    private func compute() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        self.data = ScoreUtil.Match.computeTotal(
            for: roundSession.players,
            over: Array(range),
            teams: !viewModel.teams.isEmpty,
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )
        .compactMap({ GameScoreData(key: $0.key, value: $0.value) })
        
        /// Sort data appropriately if only players (we want team order preserved).
        if viewModel.teams.isEmpty {
            data = data.sorted(by: {
                if $0.value == $1.value {
                    return index(of: $1.key) > index(of: $0.key)
                } else {
                    return $0.value > $1.value
                }
            })
        }
        
        func index(of id: String) -> Int {
            roundSession.players.firstIndex(where: { $0.id == id }) ?? 0
        }
        
        self.bannerText = ScoreUtil.Match.banner(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            for: hole,
            teams: !viewModel.teams.isEmpty,
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )
    }
}

struct MatchPlayView_Previews: PreviewProvider {

    static var viewModel = HoleViewModel()
    
    static var rs: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        rs.teams = ["Team one", "Team two"]
        return rs
    }
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        s.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        m.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        p.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
//        k.team = [:]
//        s.team = [:]
//        m.team = [:]
//        p.team = [:]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "birdie"]
        s.score = [1: "birdie", 2: "par", 3: "bogey", 4: "par"]
        m.score = [1: "par", 2: "birdie", 3: "double", 4: "par"]
        p.score = [1: "par", 2: "par", 3: "triple", 4: "par"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        MatchPlayView(viewModel: viewModel, hole: .constant(3))
            .environmentObject(rs)
            .onAppear() {
                viewModel.sideGame = .bestBall
                viewModel.sideGameSession.holes = [1, 2, 3, 4]
                viewModel.sideGameSession.match = MatchSession(skins: true)
                viewModel.teams = ["Team one", "Team two"]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
