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
                banner
                teamTiles
            }
        }
        .onAppear() { compute() }
        .onReceive(roundSession.$players, perform: { _ in compute() })
        .onReceive(viewModel.$teams, perform: { _ in compute() })
        .fullScreenCover(isPresented: $showTeamStructure) {
            TeamStructureView()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder private var teamTiles: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.teams, id: \.self) { team in
                if let d = data.first(where: { $0.key == team }) {
                    TeamScoreTile(team: team, score: "\(d.value)", hole: hole)
                }
            }
        }
    }
    
    @ViewBuilder private var banner: some View {
        if roundSession.everyoneScored(on: hole) {
            if let first = data.first, let last = data.last {
                let diff = first.value - last.value
                if diff == 0 {
                    InfoBanner(
                        icon: viewModel.sideGame.icon,
                        text: "\(first.key) and \(last.key) are tied!",
                        foregroundColor: Color.systemHackersPurple,
                        backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                    )
                } else {
                    InfoBanner(
                        icon: viewModel.sideGame.icon,
                        text: "\(first.key) leads \(last.key) by \(abs(diff)) points!",
                        foregroundColor: Color.systemHackersPurple,
                        backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                    )
                }
            }
        }
    }
    
    private func compute() {
        data = []
        for team in viewModel.teams {
            let value = ScoreUtil.Vegas.computeTotal(
                for: roundSession.players,
                for: team,
                over: viewModel.sideGameSession.holes
            )
            data.append(GameScoreData(key: team, value: value))
        }
        
        data = data.sorted(by: { $0.value < $1.value })
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
