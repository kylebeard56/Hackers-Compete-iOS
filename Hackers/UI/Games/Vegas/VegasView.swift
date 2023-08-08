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
    
    @State private var showTeamStructure: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            if viewModel.teams.isEmpty {
                DashedButton(
                    title: "Set teams to play",
                    appleIcon: "plus.circle",
                    labelColor: Color.systemHackersPurple,
                    buttonColor: Color.systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    showTeamStructure = true
                }
                .padding(.top, 10)
            } else {
                HStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { team in
                        teamTile(for: team)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showTeamStructure) {
            TeamStructureView()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder private func teamTile(for name: String) -> some View {
        let scored = roundSession.players
            .filter({ $0.team[hole] == name })
            .filter({ $0.hasScore(in: hole...hole) }).count == 2
        
        let total = ScoreUtil.Vegas.computeTotal(
            for: roundSession.players,
            for: name,
            over: viewModel.sideGameSession.holes
        )
        
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                Text("\(total)")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            ForEach(roundSession.players, id: \.self) { player in
                if player.team[hole] == name {
                    Button(action: {
                        HackersNotification.displayPlayerScorecard.send(
                            with: roundSession.players.firstIndex(where: { $0.id == player.id }) ?? 0
                        )
                        Haptics.fire(.light)
                    }) {
                        HStack {
                            Group {
                                if let s = PlayerScore(rawValue: player.score[hole] ?? ""), s != .none {
                                    Text(s.numericalValue.toGolfScore)
                                } else {
                                    Text("-")
                                }
                            }
                            .font(.dmSans(size: 13, weight: .bold))
                            .foregroundColor(player.color.value)
                            .frame(width: 24, height: 24)
                            .background(player.color.value.opacity(colorScheme.translucent))
                            .cornerRadius(8)
                            
                            Text(player.name)
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(player.color.value)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            
            if scored {
                Text("\(ScoreUtil.Vegas.computeScore(for: roundSession.players, on: name, on: hole)) points")
                    .font(.dmSans(size: 13, weight: .bold))
                    .foregroundColor(Color.systemHackersPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .alignCenter()
                    .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                    .cornerRadius(8)
    //                .lineLimit(1)
    //                .minimumScaleFactor(0.75)
            } else {
                Text("Scores needed")
                    .font(.dmSans(size: 13, weight: .bold))
                    .foregroundColor(Color.systemGray3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .alignCenter()
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
}

struct VegasView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    
    static var previews: some View {
        VegasView(viewModel: viewModel, hole: 2)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGameSession.holes = [1, 2]
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                roundSession.teams = ["Team one", "Team two"]
                
                roundSession.players[0].score = [1: "birdie", 2: "birdie"]
                roundSession.players[1].score = [1: "triple", 2: "bogey"]
                roundSession.players[0].team[1] = "Team one"
                roundSession.players[1].team[1] = "Team one"
                roundSession.players[0].team[2] = "Team one"
                roundSession.players[1].team[2] = "Team one"
                
                roundSession.players[2].score = [1: "birdie", 2: "double"]
                roundSession.players[3].score = [1: "birdie", 2: "triple"]
                roundSession.players[2].team[1] = "Team two"
                roundSession.players[3].team[1] = "Team two"
                roundSession.players[2].team[2] = "Team two"
                roundSession.players[3].team[2] = "Team two"
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
