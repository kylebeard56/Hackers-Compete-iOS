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
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var showPlayerEditor: Bool = false
    @State private var showTeamStructure: Bool = false
    @State private var showHandicaps: Bool = false
    
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
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .padding(.top, 10)
        .fullScreenCover(isPresented: $showPlayerEditor) {
            EditPlayersView()
        }
        .fullScreenCover(isPresented: $showTeamStructure) {
            TeamStructureView()
        }
        .fullScreenCover(isPresented: $showHandicaps) {
            HandicapView()
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Text("Manage overall scoring for your round.")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans(size: 17, weight: .regular))
                .alignLeading()
                .padding(.horizontal, 20)
            
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
                        .fill(Color.systemHackersGreen.opacity(colorScheme.translucent))
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
                colorScheme.lightGray,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
    
    // TODO: If the side game drives teams, show different text here.
    @ViewBuilder private var teamsTile: some View {
        Button(action: {
            showTeamStructure = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGreen.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f500".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersGreen
                    )
                }
                
                VStack(spacing: 4) {
                    Text("Teams")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 20, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()

                    Text("Set or remove pairings")
                        .foregroundColor(Color.systemGray)
                        .font(.dmSans(size: 13, weight: .medium))
                        .alignLeading()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                colorScheme.lightGray,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }

    @ViewBuilder private var handicapTile: some View {
        Button(action: {
            showHandicaps = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGreen.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f303".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersGreen
                    )
                }
                
                VStack(spacing: 4) {
                    Text("Handicaps")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 20, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()

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
                colorScheme.lightGray,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
}

struct LeaderboardMenuView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardMenuView()
            .environmentObject(RoundSession())
            .holisticPreview()
    }
}
