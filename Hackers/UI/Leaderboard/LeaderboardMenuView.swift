//
//  LeaderboardMenuView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/30/23.
//

import SwiftUI

struct LeaderboardMenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: RoundViewModel
    
    @State private var showPlayerEditor: Bool = false
    @State private var showTeamStructure: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                    .alignTop()
            }
            .padding(.vertical, 10)
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
        }
        .background(Color.systemViewBackground)
        .padding(.top, 10)
        .sheet(isPresented: $showPlayerEditor) {
            EditPlayersView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTeamStructure) {
            TeamStructureView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Text("Manage overall scoring for your round.")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans(size: 17, weight: .regular))
                .alignLeading()
                .padding(.horizontal, 20)
            
//            InfoBanner(
//                text: "Rounds are only active for 24 hours before they become archived.",
//                foregroundColor: Color.systemHackersGreen,
//                backgroundColor: Color.systemHackersGreen.opacity(0.1)
//            )
//            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 20) {
                    playerTile
                    teamsTile
                    handicapTile
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder private var playerTile: some View {
        Button(action: {
            showPlayerEditor = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGreen.opacity(0.1))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f450".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersGreen
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Players")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        Text("Edit names or colors")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans(size: 13, weight: .medium))
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
    
    // TODO: If the side game drives teams, show different text here.
    @ViewBuilder private var teamsTile: some View {
        let isDisabled = viewModel.players.count < 3
        Button(action: {
            showTeamStructure = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((isDisabled ? Color.systemError : Color.systemHackersGreen).opacity(0.1))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f500".unicode,
                        style: .regular,
                        size: 24,
                        color: isDisabled ? Color.systemError : Color.systemHackersGreen
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Teams")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                        
                        if isDisabled {
                            HStack(spacing: 4) {
                                Text("3 or 4")
                                Image(systemName: "figure.golf")
                                    .font(.dmSans(size: 10, weight: .bold))
                            }
                            .foregroundColor(Color.systemError)
                            .font(.dmSans(size: 13, weight: .bold))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.systemError.opacity(0.125))
                            .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 10) {
                        Text("Set or remove pairings")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans(size: 13, weight: .medium))
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
    
    /**
     HANDICAPS ARE UNDER CONSTRUCTION
     
     Let us know how important this feature would be for you so we can try to build it faster <strong arm emoji>
     1, Very - I want this now
     2, Somewhat - I want this eventually
     3. Neutral - Focus on other features
     */
    @ViewBuilder private var handicapTile: some View {
        Button(action: {
            print("todo show handicaps accelerator popup")
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersYellow.opacity(0.1))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f303".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersYellow
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Handicaps")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                        
                        Text("Coming soon")
                            .foregroundColor(Color.systemHackersYellow)
                            .font(.dmSans(size: 13, weight: .bold))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.systemHackersYellow.opacity(0.125))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 10) {
                        Text("Set player stroke adjustments")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans(size: 13, weight: .medium))
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
}

struct LeaderboardMenuView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardMenuView(viewModel: RoundViewModel())
            .holisticPreview()
    }
}
