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
    @EnvironmentObject var purchaseStore: PurchaseStore
    
    @State private var showIAP: Bool = false
    @State private var showHowToPlay: Bool = false
    @State private var showHackersProInfo: Bool = false
    
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
                
                buttons
            }
        }
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .environmentObject(purchaseStore)
        .navigationTitle("Pick a side game")
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
            SideGameHowToView(game: appSession.sideGame)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHackersProInfo) {
            InfoCard(
                title: "How does Hackers Pro work?",
                subtitle: "**One players in your party needs Hackers Pro to start the first side game.** Afterwards, anyone in your party can manage side games.",
                buttonText: "Learn more",
                color: Color.systemHackersPurple
            )
            .onTap {
                showHackersProInfo = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                    self.showIAP = true
                })
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
            if value {
                showIAP = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                    if appSession.sideGame != .none {
                        appSession.goToPartyCode()
                    }
                })
            }
        })
        .fullScreenCover(isPresented: $showIAP) {
            PurchaseView()
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Group {
                Text("Aside from the leaderboard, pick a ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("starting side game")
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" to boost your round.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .alignLeading()
            
            if purchaseStore.hasUnlockedPro {
                InfoBanner(
                    text: "You can change or stop side games at any time.",
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            } else {
                Button(action: {
                    showHackersProInfo = true
                    Haptics.fire(.light)
                }) {
                    InfoBanner(
                        text: "Someone in your party with **Hackers Pro** is needed to start the first side game.",
                        foregroundColor: Color.systemHackersPurple,
                        backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                    )
                    .disabled(true)
                }
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
                tile(for: .bingoBangoBongo)
            }
            
            Group {
                Text("High Stakes")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()

                tile(for: .vegas)
                tile(for: .banker)
                //tile(for: .hammer)
                tile(for: .wolfHammer)
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
            
            Spacer(minLength: 60)
        }
    }
    
    @ViewBuilder private var buttons: some View {
        Group {
            if appSession.sideGame == .none {

                BigButton(
                    title: "Skip",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    appSession.goToPartyCode()
                }
                
            } else if appSession.sideGame != .none && appSession.sideGame.underConstruction {

                BigButton(
                    title: "Under construction",
                    awesomeIconRaw: "f82c",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersYellow,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    Haptics.fire(.error)
                }
                
            } else if !appSession.sideGame.players.contains(appSession.players.filter({ $0.isPlaying }).count) {
                
                BigButton(
                    title: "Requires \(appSession.sideGame.players.first ?? 0) players",
                    appleIcon: "figure.golf",
                    labelColor: .systemWhite,
                    buttonColor: .systemError,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    Haptics.fire(.error)
                }
                
            } else {
                
                BigButton(
                    title: "Next",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    if !purchaseStore.hasUnlockedPro {
                        showIAP = true
                    } else {
                        appSession.goToPartyCode()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func tile(for game: SideGame) -> some View {
        SideGameTile(
            game: game,
            isSelected: appSession.sideGame == game,
            canPlay: game.players.contains(appSession.players.filter({ $0.isPlaying }).count)
        )
        .onTap {
            appSession.sideGame = appSession.sideGame == game ? .none : game
        }
    }
}

struct PickSideGameView_Previews: PreviewProvider {
    static var previews: some View {
        PickSideGameView()
            .environmentObject(AppSession())
    }
}
