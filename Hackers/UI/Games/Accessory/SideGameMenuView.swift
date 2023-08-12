//
//  SideGameMenuView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

struct SideGameMenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    var hole: Int
    
    @State private var showOverview: Bool = false
    @State private var showChangeSideGames: Bool = false
    @State private var showRules: Bool = false
    @State private var showEndGameConfirmation: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                    .alignTop()
            }
            .padding(.vertical, 10)
            .navigationTitle("Side games")
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
        .sheet(isPresented: $showOverview) {
            SideGameOverview()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showChangeSideGames) {
            SideGameSelectionView(action: .change, hole: hole)
                .onTap { dismissWithDelay() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRules) {
            SideGameHowToView(game: roundSession.sideGame)
        }
        .confirmationDialog(
            "Are you sure?",
            isPresented: $showEndGameConfirmation,
            actions: {
                Button("End and keep past holes") {
                    roundSession.quitCurrentSideGame(on: hole, keep: true)
                    dismiss()
                }
                Button("End and discard", role: .destructive) {
                    roundSession.quitCurrentSideGame(on: hole, keep: false)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { dismiss() }
        }, message: {
            Text("Stop playing \(roundSession.sideGame.name)?")
        })
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Group {
                Text("You're currently playing ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text(roundSession.sideGame.name)
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(".")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 20)
            .alignLeading()
            
            ScrollView {
                VStack(spacing: 20) {
                    changeGameTile
                    rulesTile
                    quitTile
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Overview
    
    @ViewBuilder private var overviewTile: some View {
        Button(action: {
            showOverview = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersPurple.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "e475".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersPurple
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Overview")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        Text("See all games over your round")
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
    
    // MARK: - Change
    
    @ViewBuilder private var changeGameTile: some View {
        Button(action: {
            showChangeSideGames = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersPurple.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f0cb".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersPurple
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Change")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        Text("Play again or pick a new side game")
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
    
    // MARK: - Rules
    
    @ViewBuilder private var rulesTile: some View {
        Button(action: {
            showRules = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersPurple.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f02d".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersPurple
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Rules")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        Text("View instructions on how to play")
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
    
    // MARK: - End
    
    @ViewBuilder private var quitTile: some View {
        Button(action: {
            showEndGameConfirmation = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersPurple.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: "f1f8".unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersPurple
                    )
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Quit")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        Text("Stop playing side games (for now)")
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
    
    private func dismissWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
            dismiss()
        })
    }
}

struct SideGameMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SideGameMenuView(hole: 1)
            .environmentObject(RoundSession())
            .holisticPreview()
    }
}
