//
//  LeaderboardTeamRow.swift
//  Hackers
//
//  Created by Kyle Beard on 6/23/23.
//

import SwiftUI

struct LeaderboardTeamRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var viewModel: RoundViewModel
    var team: String
    
    @State private var currentScore: String = ""
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
            .cornerRadius(12)
    }
    
    private var content: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text(team)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text(currentScore)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
            }
            
            ForEach($viewModel.players, id: \.self) { p in
                if p.team.wrappedValue == team {
                    LeaderboardPlayerRow(viewModel: viewModel, player: p, teamStyle: true)
                }
            }
        }
        .onAppear() {  updateScoring() }
        .onReceive(viewModel.$netHoleNumber, perform: { _ in updateScoring() })
    }

    private func updateScoring() {
        currentScore = "0"
        if viewModel.netHoleNumber < 1 { return }
        
        var score: Int = 0
        
        for p in viewModel.players {
            for i in 0..<viewModel.netHoleNumber {
                let hole = viewModel.holeRange[i]
                let s = PlayerScore(rawValue: p.score[hole] ?? "") ?? .par
                score += s.numericalValue
            }
        }

        currentScore = "\(score > 0 ? "+" : "")\(score)"
    }
}

struct LeaderboardTeamRow_Previews: PreviewProvider {
    static var vm = RoundViewModel()
    static var previews: some View {
        LeaderboardTeamRow(viewModel: vm, team: "Team one")
            .onAppear() {
                vm.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                vm.teams = ["Team one", "Team two"]
            }
            .background(Color.systemViewBackground)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
