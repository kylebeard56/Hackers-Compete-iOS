//
//  ScoringLeaderboard.swift
//  Hackers
//
//  Created by Kyle Beard on 5/2/23.
//

import SwiftUI

enum LeaderboardScoringType: String {
    case traditional, stableford, vegas
}

struct ScoringLeaderboard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var hole: Int
    var type: LeaderboardScoringType
    
    @State private var showTeamStructure: Bool = false
    
    @State private var showPlayerScoring: Bool = false
    @State private var playerIndex: Int = 0
    @State private var rankedPlayers: [Player] = []
    
    @State private var teamOnePlayers: [Player] = []
    @State private var teamTwoPlayers: [Player] = []
    
    @State private var teamOneScore: Int = 0
    @State private var teamTwoScore: Int = 0
    
    private var teamOneScoreLabel: String {
        type == .traditional ? teamOneScore.toGolfScore : "\(teamOneScore) points"
    }
    
    private var teamTwoScoreLabel: String {
        type == .traditional ? teamTwoScore.toGolfScore : "\(teamTwoScore) points"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                Text("Leaderboard")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text("Thru \(viewModel.holesScored())")
                    .font(.dmSans(size: 13, weight: .bold))
                    .foregroundColor(Color.systemGray)
            }
            
            Spacer(minLength: 0)
            
            if UIScreen.isSmall {
                if viewModel.teams.isEmpty {
                    individualScoringBoxSmall
                } else {
                    teamScoringBoxSmall
                }
            } else {
                if viewModel.teams.isEmpty {
                    individualScoringBox
                } else {
                    teamScoringBox
                }
            }
            
            Spacer(minLength: 0)
            
            if viewModel.players.count == 4 {
                Button(action: {
                    showTeamStructure = true
                    FirebaseEvent.chaosRulesTapped.log()
                    Haptics.fire(.light)
                }) {
                    Text("\(viewModel.teams.isEmpty ? "Set" : "Edit") teams")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .alignCenter()
                        .background(Color.systemGray5)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .onAppear() { self.refreshData() }
        .onReceive(viewModel.$players, perform: { _ in self.refreshData() })
        .sheet(isPresented: $showPlayerScoring) {
            PlayerScoringView(players: $viewModel.players, index: $playerIndex, hole: hole)
                .presentationDetents([.height(436)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTeamStructure) {
            TeamStructureView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Normal
    
    private var individualScoringBox: some View {
        VStack(spacing: 12) {
            Text("Rankings")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .alignLeading()
            
            ForEach(rankedPlayers, id: \.self) { player in
                row(for: player)
            }
        }
        .padding(12)
        .background(Color.systemCard)
        .border(Color.systemGray5, width: 2, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private var teamScoringBox: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                HStack {
                    Text(TeamName.one.rawValue)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Circle()
                        .fill(Color.systemGray)
                        .frame(width: 3, height: 3)
                    
                    Text(teamOneScoreLabel)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer(minLength: 0)
                }
                
                ForEach(teamOnePlayers, id: \.self) { player in
                    row(for: player)
                }
            }
            .padding(12)
            .background(Color.systemCard)
            .border(Color.systemGray5, width: 2, cornerRadius: 12)
            .cornerRadius(12)

            VStack(spacing: 12) {
                HStack {
                    Text(TeamName.two.rawValue)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Circle()
                        .fill(Color.systemGray)
                        .frame(width: 3, height: 3)
                    
                    Text(teamTwoScoreLabel)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer(minLength: 0)
                }
                
                ForEach(teamTwoPlayers, id: \.self) { player in
                    row(for: player)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.systemCard)
            .border(Color.systemGray5, width: 2, cornerRadius: 12)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Small
    
    private var individualScoringBoxSmall: some View {
        VStack(spacing: 12) {
            Text("Rankings")
                .font(.dmSans(size: 13, weight: .medium))
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            HStack(spacing: 16) {
                if let player = rankedPlayers[safe: 0] {
                    row(for: player)
                }
                if let player = rankedPlayers[safe: 1] {
                    row(for: player)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 16) {
                if let player = rankedPlayers[safe: 2] {
                    row(for: player)
                }
                if let player = rankedPlayers[safe: 3] {
                    row(for: player)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.systemCard)
        .border(Color.systemGray5, width: 2, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private var teamScoringBoxSmall: some View {
        HStack(spacing: 12) {
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(TeamName.one.rawValue)
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .alignLeading()
                    
                    Text(teamOneScoreLabel)
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .alignLeading()
                }
                
                ForEach(teamOnePlayers, id: \.self) { player in
                    row(for: player)
                }
            }
            .padding(12)
            .background(Color.systemCard)
            .border(Color.systemGray5, width: 2, cornerRadius: 12)
            .cornerRadius(12)

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(TeamName.two.rawValue)
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .alignLeading()
                    
                    Text(teamTwoScoreLabel)
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .alignLeading()
                }
                
                ForEach(teamTwoPlayers, id: \.self) { player in
                    row(for: player)
                }
            }
            .padding(12)
            .background(Color.systemCard)
            .border(Color.systemGray5, width: 2, cornerRadius: 12)
            .cornerRadius(12)
        }
    }
    
    // MARK: - ViewBuilder
    
    @ViewBuilder
    private func row(for player: Player) -> some View {
        Button(action: {
            self.playerIndex = viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0
            self.showPlayerScoring = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 4) {
                Text(player.name)
                    .font(.dmSans(size: UIScreen.isSmall ? 15 : 17, weight: .bold))
                    .foregroundColor(player.color.value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Spacer(minLength: 0)
                
                Text(player.totalScore(for: type))
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 42, height: 28)
                    .background(Color.systemGray6)
                    .cornerRadius(6)
            }
        }
    }
    
    private func refreshData() {
        teamOnePlayers = []
        teamTwoPlayers = []
        teamOneScore = 0
        teamTwoScore = 0
        
        if type == .traditional {
            self.rankedPlayers = viewModel.players.sorted(by: { $1.totalRawScore() > $0.totalRawScore() })
        } else if type == .stableford {
            self.rankedPlayers = viewModel.players.sorted(by: { $0.totalStablefordScore() > $1.totalStablefordScore() })
        } else if type == .vegas {
            self.rankedPlayers = viewModel.players.sorted(by: { $1.totalRawScore() > $0.totalRawScore() })
        } else {
            print("wtf happened")
        }
        
        
        // TODO: Scoring format based on type here
        
        for p in viewModel.players {
            if p.team == TeamName.one.rawValue {
                teamOnePlayers.append(p)
                
                if type == .traditional {
                    teamOneScore += p.rawScoringSum(for: 1...18)
                } else if type == .stableford {
                    teamOneScore += p.stablefordScoringSum(for: 1...18)
                } else if type == .vegas {
                    teamOneScore += p.rawScoringSum(for: 1...18)
                } else {
                    print("wtf happened")
                }
            }
            
            if p.team == TeamName.two.rawValue {
                teamTwoPlayers.append(p)
                if type == .traditional {
                    teamTwoScore += p.rawScoringSum(for: 1...18)
                } else if type == .stableford {
                    teamTwoScore += p.stablefordScoringSum(for: 1...18)
                } else if type == .vegas {
                    teamTwoScore += p.rawScoringSum(for: 1...18)
                } else {
                    print("wtf happened")
                }
            }
        }
    }
}

struct ScoringLeaderboard_Previews: PreviewProvider {
    static var view: some View {
        ScoringLeaderboard(viewModel: RoundViewModel(), hole: 1, type: .traditional)
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
