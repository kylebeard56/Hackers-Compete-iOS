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
    
    var hole: Int
    
    @State private var skins: Bool = false
    @State private var bannerText: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            if !bannerText.isEmpty {
                HStack(spacing: 10) {
                    AwesomeImage(rawIcon: "f091".unicode, style: .regular, size: 15, color: Color.systemHackersPurple)
                    Text(LocalizedStringKey(bannerText))
                        .foregroundColor(Color.systemHackersPurple)
                        .font(.dmSans(size: 13, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                .cornerRadius(12)
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
            computeBanner()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            withAnimation(.easeOut(duration: 0.2)) {
                skins = viewModel.sideGameSession.match?.skins ?? false
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            computeBanner()
        })
        /// Publish local changes back to current hole view model
        .onChange(of: skins, perform: { value in
            viewModel.sideGameSession.match = MatchSession(skins: value)
            computeBanner()
        })
    }
    
    // MARK: - Player
    
    @ViewBuilder private var playerDisplay: some View {
        VStack(spacing: 8) {
            Text("Points")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            ForEach(roundSession.players, id: \.self) { player in
                HStack {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text(accruedScore(for: player.id))
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Team
    
    private var teamDisplay: some View {
        HStack(spacing: 10) {
            ForEach(roundSession.teams, id: \.self) { team in
                teamTile(for: team)
            }
        }
    }
    
    @ViewBuilder private func teamTile(for name: String) -> some View {
        VStack(spacing: 8) {
            TeamScoreRow(name: name, score: accruedScore(for: name, isTeam: true))

            ForEach(roundSession.players, id: \.self) { player in
                if player.team[hole] == name {
                    PlayerScoreRow(player: player, score: accruedScore(for: player.id))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Skins
    
    @ViewBuilder private var skinsToggle: some View {
        Toggle(isOn: $skins, label: {
            VStack(spacing: 4) {
                Text("Skins")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text("Ties roll points over to the next hole.")
                    .font(.dmSans(size: 13, weight: .regular))
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
    
    // MARK: - Algorithm
    
    private func accruedScore(for value: String, isTeam: Bool = false) -> String {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        let scores = ScoreUtil.Match.computeTotal(
            for: roundSession.players,
            over: Array(range),
            teams: isTeam,
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )
        
        return "\(scores.first(where: { $0.key == value })?.value ?? 0)"
    }
    
    private func computeBanner() {
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
        MatchPlayView(viewModel: viewModel, hole: 3)
            .environmentObject(rs)
            .onAppear() {
                viewModel.sideGameSession.holes = [1, 2, 3, 4]
                viewModel.sideGameSession.match = MatchSession(skins: true)
                viewModel.teams = ["Team one", "Team two"]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
