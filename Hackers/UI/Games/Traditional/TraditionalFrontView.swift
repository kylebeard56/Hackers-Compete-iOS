//
//  TraditionalFrontView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/30/23.
//

import SwiftUI

struct TraditionalFrontView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var hole: Int
    
    @State private var showPlayerScoring: Bool = false
    @State private var playerIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            playView
        }
        .environmentObject(appSession)
        .sheet(isPresented: $showPlayerScoring) {
            PlayerScoringView(players: $viewModel.players, index: $playerIndex, hole: hole)
                .presentationDetents([.height(436)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Views
    
    // This needs a play now button that shows a box with each player's score ranked low to high with Thru X
    
    private var playView: some View {
        VStack(spacing: 8) {
            GameCardHeader(game: .traditional)
            
            Spacer(minLength: 0)
            
            if viewModel.showTraditionalLeaderboard {
                leaderboardBox
            } else {
                gameSummaryBox
            }
            
            Spacer(minLength: 0)
            
            if !viewModel.showTraditionalLeaderboard {
                Button(action: {
                    viewModel.showTraditionalLeaderboard = true
                    Haptics.fire(.light)
                }) {
                    Text("View leaderboard")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemWhite)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemBlack)
                        .cornerRadius(8)
                }
            }
        }
    }
    private var leaderboardBox: some View {
        VStack(spacing: UIScreen.isSmall ? 10 : 16) {
            HStack {
                Text("Leaderboard")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text("Thru \(viewModel.holesScored())")
                    .font(.dmSans(size: 13, weight: .bold))
                    .foregroundColor(Color.systemGray)
            }
            
            ForEach(viewModel.players, id: \.self) { player in
                Button(action: {
                    self.playerIndex = viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0
                    self.showPlayerScoring = true
                    Haptics.fire(.light)
                }) {
                    HStack {
                        Text(player.name)
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(player.color.value)
                        
                        Spacer(minLength: 0)
                        
                        Text(player.totalScore())
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                            .frame(width: 32, height: 32)
                            .background(Color.systemGray5)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
    }
    
    private var gameSummaryBox: some View {
        VStack(spacing: UIScreen.isSmall ? 10 : 16) {
            HStack {
                Text("Players")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                Text("1+")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemHackersGreen)
            }
            HStack(spacing: 6) {
                Text("Complexity")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                
                Circle()
                    .fill(Color.systemHackersGreen)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3)
                    .frame(width: 6, height: 6)
            }
            HStack {
                Text("True scoring")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                Text("Yes")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemHackersGreen)
            }
            HStack {
                Text("Pace of play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                Text("Normal")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemHackersGreen)
            }
        }
        .padding(16)
        .border(Color.systemGray6, width: 2, cornerRadius: 8)
    }
}

struct TraditionalFrontView_Previews: PreviewProvider {
    static var view: some View {
        TraditionalFrontView(viewModel: RoundViewModel(), hole: 1)
            .environmentObject(AppSession())
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
