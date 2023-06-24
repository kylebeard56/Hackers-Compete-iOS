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
    
    @State private var players: [Player] = []
    @State private var playerLock: Bool = false
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
            
            ForEach($players, id: \.self) { player in
                LeaderboardPlayerRow(viewModel: viewModel, player: player, teamStyle: true)
            }
        }
        .onAppear() {  buildPlayers() }
        .onReceive(viewModel.$teams, perform: { _ in buildPlayers() })
        .onChange(of: players, perform: { _ in updatePlayers() })
        .onReceive(viewModel.$netHoleNumber, perform: { _ in updateScoring() })
    }
    
    private func buildPlayers() {
        if team.isEmpty { return }
        playerLock = true
        players = viewModel.players.filter({ $0.team == self.team })
    }
    
    private func updatePlayers() {
        if team.isEmpty { return }
        
        /// 1. If the players are empty, don't update. If a lock exists, it prevents infinite loop.
        if players.count == 0 || playerLock {
            playerLock = false
            return
        }
        
        /// 2. Back-propagate changes to the view model to persist to session.
        for p in players {
            if let i = viewModel.players.firstIndex(where: { $0.id == p.id }) {
                viewModel.players[i] = p
            }
        }
        
        /// 3. Update teams to recalculate scoring.
        updateScoring()
    }

    private func updateScoring() {
        if team.isEmpty { return }
        
        currentScore = "0"
        if viewModel.netHoleNumber < 1 { return }
        
        var score: Int = 0
        
        for p in players {
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
