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
            if roundSession.teams.isEmpty {
                DashedButton(
                    title: "Set teams to play Vegas",
                    appleIcon: "plus.circle",
                    labelColor: Color.systemHackersPurple,
                    buttonColor: Color.systemHackersPurple,
                    fontSize: 15,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    showTeamStructure = true
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(roundSession.teams, id: \.self) { team in
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
            .filter({ $0.team == name })
            .filter({ $0.hasScore(in: hole...hole) }).count == 2
        
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                Text("\(computeTotal(for: name))")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            ForEach(roundSession.players, id: \.self) { player in
                if player.team == name {
                    Button(action: {
                        HackersNotification.displayPlayerScorecard.send(
                            with: roundSession.players.firstIndex(where: { $0.id == player.id }) ?? 0
                        )
                        Haptics.fire(.light)
                    }) {
                        HStack {
                            Group {
                                if let s = PlayerScore(rawValue: player.score[hole] ?? "")?.numericalValue {
                                    Text(s.toGolfScore)
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
            
            if let points = computeScore(for: name, on: hole), scored {
                Group {
                    Text("\(points) points")
                        .font(.dmSans(size: 13, weight: .bold))
                    + Text(" this hole")
                        .font(.dmSans(size: 13, weight: .regular))
                }
                .foregroundColor(Color.systemHackersPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                .cornerRadius(8)
                .alignCenter()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            } else {
                Text("Scores needed")
                    .font(.dmSans(size: 13, weight: .bold))
                    .foregroundColor(Color.systemGray3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
                    .alignCenter()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Scoring
    
    private func computeScore(for team: String, on hole: Int) -> Int? {
        var scores: [Int] = []
        for p in roundSession.players {
            if p.team == team {
                let s = PlayerScore(rawValue: p.score[hole] ?? "") ?? .none
                scores.append(s.numericalValue)
            }
        }
        
        let min = scores.min() ?? 0
        let max = scores.max() ?? 0
        return min * 10 + max
    }
    
    private func computeTotal(for team: String) -> Int {
        var sum: Int = 0
        for h in viewModel.sideGameSession.holes {
            if h > hole { break }
            if let v = computeScore(for: team, on: h) {
                sum += v
            }
        }
        return sum
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
                roundSession.players[0].team = "Team one"
                roundSession.players[1].team = "Team one"
                
                roundSession.players[2].score = [1: "birdie", 2: "double"]
                roundSession.players[3].score = [1: "birdie", 2: "triple"]
                roundSession.players[2].team = "Team two"
                roundSession.players[3].team = "Team two"
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
