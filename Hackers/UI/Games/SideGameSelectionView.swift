//
//  SideGameSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/11/23.
//

import SwiftUI

enum SideGameAction {
    case start, change
}

struct SideGameSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    var action: SideGameAction
    var onSelection: ((SideGame) -> Void)?
    
    @State private var selected: SideGame = .none
    @State private var showHow: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                bodyView
                    .padding(.horizontal, 20)
                    .alignTop()
            }
            
            VStack(spacing: 20) {
                Divider()
                
                if selected != .none {
                    SmallButton(title: "How to play", isDisabled: .false, isLoading: .false)
                        .onTap { showHow = true }
                        .padding(.horizontal, 20)
                }
                
                BigButton(
                    title: action == .start ? "Start" : "Change",
                    labelColor: .systemWhite,
                    buttonColor: selected == .none ? .systemHackersGreen : .systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    if let a = onSelection {
                        a(selected)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .sheet(isPresented: $showHow) {
            SideGameHowToView(game: selected)
        }
    }
    
    private var bodyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Side games")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.bottom, 10)
            
            content
            
            Spacer(minLength: 0)
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            if action == .start {
                Text("Start a new side game for your round.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                    .alignLeading()
                
                InfoBanner(
                    text: "You can change or quit side games during your round at any time.",
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            if action == .change {
                Text("Stop playing \(roundSession.sideGame.name) and start another.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                    .alignLeading()
                
                InfoBanner(
                    text: "\(roundSession.sideGame.name) results will be reveal on home page.",
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            Group {
                Text("Fun & Noteworthy")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
                
                tile(for: .medalPlay)
                tile(for: .stableford)
                tile(for: .bestBall)
                tile(for: .nines)
                tile(for: .vegas)
                tile(for: .bingoBangoBongo)
            }
            Group {
                Text("Made by Hackers")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
                
                tile(for: .cardsOfChaos)
                tile(for: .monkeyInTheMiddle)
                tile(for: .fibonacci)
                tile(for: .football)
                tile(for: .survivor)
                tile(for: .hotPotato)
            }
            Group {
                Text("High Stakes")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
                
                tile(for: .banker)
                tile(for: .hammer)
                tile(for: .wolfHammer)
            }
            
            Spacer(minLength: 20)
        }
    }
    
    private func tile(for game: SideGame) -> some View {
        SideGameTile(
            game: game,
            isSelected: selected == game,
            canPlay: game.players.contains(roundSession.players.filter({ $0.isPlaying }).count)
        )
        .onTap {
            selected = selected == game ? .none : game
        }
    }
}

struct SideGameSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SideGameSelectionView(action: .start)
    }
}
