//
//  PickSideGameView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import SwiftUI

struct PickSideGameView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @State private var showHowToPlay: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .alignTop()
            }
            
            VStack(spacing: 20) {
                Divider()
                
                if appSession.sideGame != .none {
                    SmallButton(title: "How to play", isDisabled: .false, isLoading: .false)
                        .onTap { showHowToPlay = true }
                        .padding(.horizontal, 20)
                }
                
                BigButton(
                    title: appSession.sideGame == .none ? "Skip" : "Next",
                    labelColor: .systemWhite,
                    buttonColor: appSession.sideGame == .none ? .systemHackersGreen : .systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap { appSession.goToPartyCode() }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationTitle("Pick your side game")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
        })
        .sheet(isPresented: $showHowToPlay) {
            VStack {
                Text("todo")
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            InfoBanner(
                text: "You can change or quit side games during your round at any time.",
                foregroundColor: Color.systemHackersPurple,
                backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
            )
            
            Group {
                Text("Fun & Noteworthy")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
                
                SideGameTile(game: .stableford)
                SideGameTile(game: .bestBall)
                SideGameTile(game: .vegas)
                SideGameTile(game: .bingoBangoBongo)
            }
            Group {
                Text("Made by Hackers")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
                
                SideGameTile(game: .cardsOfChaos)
                SideGameTile(game: .monkeyInTheMiddle)
                SideGameTile(game: .football)
                SideGameTile(game: .survivor)
                SideGameTile(game: .hotPotato)
            }
            Group {
                Text("High Stakes")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
                
                SideGameTile(game: .banker)
                SideGameTile(game: .hammer)
                SideGameTile(game: .wolfHammer)
            }
            
            Spacer(minLength: 20)
        }
    }
}

struct PickSideGameView_Previews: PreviewProvider {
    static var previews: some View {
        PickSideGameView()
    }
}
