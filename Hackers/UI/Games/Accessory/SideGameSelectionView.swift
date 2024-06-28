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

struct SideGameSelectionView: View, OnSelectable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    
    var action: SideGameAction
    var hole: Int
    
    @State private var selected: SideGame = .none
    @State private var showHow: Bool = false
    @State private var showIAP: Bool = false
    @State private var showHackersProInfo: Bool = false
    
    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    ScrollViewReader { proxy in
                        SideGameDashboard()
                            .onSelection { game in
                                selected = game
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(game.name, anchor: .top)
                                }
                            }
                    }
                }
                
                if selected != .none {
                    VStack(spacing: 20) {
                        Divider()
                    
                        SmallButton(title: "How to play", isDisabled: .false, isLoading: .false)
                            .onTap { showHow = true }
                            .padding(.horizontal, 20)
                        
                        buttons
                    }
                }
            }
            //.padding(.top, 20)
            .navigationTitle("Change game")
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
        .environmentObject(purchaseStore)
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .sheet(isPresented: $showHow) {
            SideGameHowToView(game: selected)
        }
        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
            if value {
                showIAP = false
            }
        })
        .sheet(isPresented: $showIAP) {
            PurchaseView()
        }
    }
    
//    var bodyx: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                bodyView
//                    .padding(.horizontal, 20)
//                    .alignTop()
//            }
//            
//            if selected != .none {
//                VStack(spacing: 20) {
//                    Divider()
//                
//                    SmallButton(title: "How to play", isDisabled: .false, isLoading: .false)
//                        .onTap { showHow = true }
//                        .padding(.horizontal, 20)
//                    
//                    buttons
//                }
//            }
//        }
//        .environmentObject(purchaseStore)
//        .environmentObject(roundSession)
//        .padding(.top, 20)
//        .background(Color.systemViewBackground)
//        .sheet(isPresented: $showHow) {
//            SideGameHowToView(game: selected)
//        }
//        .sheet(isPresented: $showHackersProInfo) {
//            InfoCard(
//                title: "How does Hackers Pro work?",
//                subtitle: "**One players in your party needs Hackers Pro to start the first side game.** Afterwards, anyone in your party can manage side games.",
//                buttonText: "Learn more",
//                color: Color.systemHackersPurple
//            )
//            .onTap {
//                showHackersProInfo = false
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
//                    self.showIAP = true
//                })
//            }
//            .presentationDetents([.height(220)])
//            .presentationDragIndicator(.visible)
//        }
//        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
//            if value {
//                showIAP = false
//            }
//        })
//        .fullScreenCover(isPresented: $showIAP) {
//            PurchaseView()
//        }
//    }
    
    private var bodyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Change game")
                    .font(.dmSans, size: 28, weight: .bold)
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
                Group {
                    Text("Aside from the leaderboard, pick a ")
                        .foregroundColor(Color.systemBlack)
                        //.font(.dmSans, size: 17, weight: .regular)
                    + Text("**starting side game**")
                        .foregroundColor(Color.systemHackersPurple)
                        //.font(.dmSans, size: 17, weight: .bold)
                    + Text(" to boost your round.")
                        .foregroundColor(Color.systemBlack)
                        //.font(.dmSans, size: 17, weight: .regular)
                }
                .font(.dmSans, size: 17)
                .alignLeading()
                
                if roundSession.session?.unlockedPro ?? false {
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
            }
            
            if action == .change {
                Text("This will end your current game and start a new game **on this hole**.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 17, weight: .regular)
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
                    .font(.dmSans, size: 17, weight: .bold)
                    .alignLeading()
                
                tile(for: .medalPlay)
                tile(for: .stableford)
                tile(for: .bestBall)
                tile(for: .nines)
                tile(for: .bingo)
            }
            
            Group {
                Text("High Stakes")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 17, weight: .bold)
                    .alignLeading()

                tile(for: .vegas)
                tile(for: .banker)
                //tile(for: .hammer)
                tile(for: .wolfHammer)
            }
            
            Group {
                Text("Made by Hackers")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 17, weight: .bold)
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
            if roundSession.isGameSampled(selected) {
                
                BigButton(
                    title: "Requires Hackers Pro",
                    //logo: .purplePro,
                    labelColor: Color.systemHackersPurple,
                    buttonColor: Color.systemHackersPurple.opacity(colorScheme.translucent),
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    showIAP = true
                }
                
            } else if selected.underConstruction {

                BigButton(
                    title: "Under construction",
                    awesomeIconRaw: "f82c",
                    labelColor: Color.systemHackersYellow,
                    buttonColor: Color.systemHackersYellow.opacity(colorScheme.translucent),
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    Haptics.fire(.error)
                }
                
            } else if !selected.players.contains(roundSession.players.filter({ $0.isPlaying }).count) {
                
                BigButton(
                    title: "Requires \(selected.players.first ?? 0) players",
                    appleIcon: "figure.golf",
                    labelColor: Color.systemError,
                    buttonColor: Color.systemError.opacity(colorScheme.translucent),
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    Haptics.fire(.error)
                }
                
            } else {
                BigButton(
                    title: "Play \(selected.name)", //action == .start ? "Start" : "Change",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    changeGame()
//                    if purchaseStore.hasUnlockedPro || (roundSession.session?.unlockedPro ?? false) {
//                        changeGame()
//                    } else {
//                        showIAP = true
//                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func tile(for game: SideGame) -> some View {
        SideGameTile(
            game: game,
            isSelected: selected == game,
            canPlay: game.players.contains(roundSession.players.filter({ $0.isPlaying }).count)//,
            //isAlreadySampled: roundSession.isGameSampled(game)
        )
        .onTap {
            selected = selected == game ? .none : game
        }
    }
    
    private func changeGame() {
        roundSession.changeSideGame(to: selected, on: hole)
        triggerOnTap()
        dismiss()
    }
}

struct SideGameSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SideGameSelectionView(action: .start, hole: 1)
            .environmentObject(RoundSession())
            .environmentObject(PurchaseStore())
            .holisticPreview()
    }
}
