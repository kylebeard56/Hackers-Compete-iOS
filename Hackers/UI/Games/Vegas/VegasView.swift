//
//  VegasView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/11/23.
//

import SwiftUI

struct VegasView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var bannerText: String = ""
    @State private var data: [GameScoreData] = []
    @State private var showTeamStructure: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            if viewModel.teams.isEmpty {
                BigButton(
                    title: "Set teams to play",
                    appleIcon: "plus.circle",
                    labelColor: Color.white,
                    buttonColor: Color.systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    showTeamStructure = true
                }
                .padding(.top, 10)
            } else {
                if !bannerText.isEmpty {
                    InfoBanner(
                        icon: viewModel.sideGame.icon,
                        text: bannerText,
                        foregroundColor: Color.systemHackersPurple,
                        backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                    )
                }
                teamTiles
                    .alignCenter()
            }
        }
        .onAppear() {
            withAnimation(.linear(duration: 0.2)) {
                compute()
            }
        }
        .onReceive(roundSession.$players, perform: { _ in
            withAnimation(.linear(duration: 0.2)) {
                compute()
            }
        })
        .onReceive(viewModel.$teams, perform: { _ in
            withAnimation(.linear(duration: 0.2)) {
                compute()
            }
        })
        .fullScreenCover(isPresented: $showTeamStructure) {
            TeamStructureView()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder private var teamTiles: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.teams, id: \.self) { team in
                let score = ScoreUtil.Vegas.computeScore(
                    for: roundSession.players,
                    on: team,
                    on: hole,
                    handicaps: roundSession.usingHandicaps
                )
                
                let everyoneScored = roundSession.everyoneScored(on: hole, team: team)
                
                if let d = data.first(where: { $0.key == team }) {
                    TeamScoreTile(
                        team: team,
                        score: "\(d.value)",
                        hole: hole,
                        subtitle: everyoneScored ? "\(score) this hole" : nil,
                        placeholder: !everyoneScored
                    )
                }
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
//        data = []
//        for team in viewModel.teams {
//            let value = ScoreUtil.Vegas.computeTotal(
//                for: roundSession.players,
//                for: team,
//                over: viewModel.sideGameSession.holes
//            )
//            data.append(GameScoreData(key: team, value: value))
//        }
        
        data = ScoreUtil.Vegas.computeTotal(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            upTo: hole,
            handicaps: roundSession.usingHandicaps
        )
        .sorted(by: { $0.value > $1.value })
        
        bannerText = ""
        if roundSession.everyoneScored(on: hole) {
            
            if let winner = ScoreUtil.Vegas.computePoints(
                for: roundSession.players,
                on: hole,
                handicaps: roundSession.usingHandicaps
            )
            .sorted(by: { $0.value > $1.value }).first {
                if winner.value == 0 {
                    bannerText = "Push! No points awarded."
                } else {
                    bannerText = "\(winner.key) wins \(winner.value) points!"
                }
            }
            
//            if let first = data.first, let last = data.last {
//                let diff = first.value - last.value
//                if diff == 0 {
//                    bannerText = "\(first.key) and \(last.key) are tied!"
//                } else {
//                    bannerText = "\(first.key) leads \(last.key) by \(abs(diff)) points!"
//                }
//            }
        }
    }
}

struct VegasView_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        rs.teams = ["Team one", "Team two"]
        
        rs.players[0].score = [1: "birdie", 2: "birdie"]
        rs.players[1].score = [1: "triple", 2: "bogey"]
        rs.players[0].team[1] = "Team one"
        rs.players[1].team[1] = "Team one"
        rs.players[0].team[2] = "Team one"
        rs.players[1].team[2] = "Team one"
        
        rs.players[2].score = [1: "birdie", 2: "double"]
        rs.players[3].score = [1: "birdie", 2: "triple"]
        rs.players[2].team[1] = "Team two"
        rs.players[3].team[1] = "Team two"
        rs.players[2].team[2] = "Team two"
        rs.players[3].team[2] = "Team two"
        
        return rs
    }
    
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2]
        vm.teams = ["Team one", "Team two"]
        vm.sideGame = .vegas
        return vm
    }
    
    static var previews: some View {
        VegasView(viewModel: viewModel, hole: 2)
            .environmentObject(roundSession)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
