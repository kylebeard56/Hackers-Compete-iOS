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
    
    @State private var showTeamStructure: Bool = false
    
    @State private var showPlayerScoring: Bool = false
    @State private var playerIndex: Int = 0
    
    @State private var teamOnePlayers: [Player] = []
    @State private var teamTwoPlayers: [Player] = []
    
    @State private var teamOneScore: Int = 0
    @State private var teamTwoScore: Int = 0
    
    var body: some View {
        VStack(spacing: 8) {
            GameCardHeader(game: .traditional, condense: viewModel.showTraditionalLeaderboard)
            
            Spacer(minLength: 0)
            
            if viewModel.showTraditionalLeaderboard {
                ScoringLeaderboard(viewModel: viewModel, hole: hole, type: .traditional)
            } else {
                gameSummaryBox
                
                Spacer(minLength: 0)
                
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
        .environmentObject(appSession)
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
