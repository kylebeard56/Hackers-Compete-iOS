//
//  RoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

class ScrollTimer: ObservableObject {
    
    @Published var showNextHoleButton: Bool = true
    var timer: Timer?
    
    func start(_ data: ScrollData) {
        timer?.invalidate()
        
        //withAnimation {
            showNextHoleButton = false
        //}
        
        timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(0.1),
            target: self,
            selector: #selector(stop),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc private func stop() {
        timer?.invalidate()
        //withAnimation {
            showNextHoleButton = true
        //}
    }
}

struct RoundView: View, WindowPresentable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    
    @StateObject var roundSession = RoundSession()
    
    @State private var headerOpacity: CGFloat = 1.0
    @State private var headerLock: Bool = true
    
    @State private var didReturnToZero: Bool = true
//    @State private var showFinishButton: Bool = false
    @State private var showGameRules: Bool = false
    
    @State private var tab: RoundTab = .games
    @StateObject private var timer = ScrollTimer()
    
    @ViewBuilder private func item(for tab: RoundTab) -> some View {
        let color: Color = roundSession.selectedTab == tab ? Color.systemBlack : Color.systemGray
        VStack(spacing: 6) {
            AwesomeImage(rawIcon: tab.icon, style: .regular, size: 20, color: color )
            Text(tab.rawValue)
                .font(.dmSans, size: 13, weight: .bold)
                .foregroundStyle(color)
        }
        .alignCenter()
    }
    
    private var kTabBarHeight: CGFloat {
        roundSession.pendingSideGame != .none && roundSession.selectedTab == .games ? 108 : 58
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HoleHeaderView()
                
                TabView(selection: $tab) {
                    HoleView(view: .games, hole: $roundSession.currentHole)
                        .onScroll { data in timer.start(data) }
                        .tag(RoundTab.games)
                    HoleView(view: .leaderboard, hole: $roundSession.currentHole)
                        .onScroll { data in timer.start(data) }
                        .tag(RoundTab.leaderboard)
                }
                .tag(roundSession.currentHole)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeIn, value: tab)
                
                Spacer(minLength: kTabBarHeight)
            }
            
//            Group {
//                if roundSession.pendingSideGame != .none {
//                    VStack(spacing: 12) {
//                        Divider()
//                        
//                        gameButton
//                    }
//                    .background(Color.systemViewBackground)
//                    .frame(height: kTabBarHeight)
//                    .alignBottom()
//                } else if timer.showNextHoleButton && roundSession.pendingSideGame != .none && !roundSession.isGameSearchFocused {
//                    CurrentHoleButton()
//                }
//            }
            
            if timer.showNextHoleButton && !roundSession.isGameSearchFocused {
                CurrentHoleButton()
                    .padding(.horizontal, 20)
                    .alignBottom()
                    .padding(.bottom, kTabBarHeight + 12)
            }
            
            if !roundSession.isGameSearchFocused {
                VStack(spacing: 12) {
                    Divider()
                    
                    if roundSession.pendingSideGame != .none && roundSession.selectedTab == .games {
                        gameButtons
                    } else {
                        HStack {
                            ForEach(RoundTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    Haptics.fire(.light)
                                    self.tab = tab
                                }) {
                                    item(for: tab)
                                }
                            }
                        }
                    }
                }
                .background(Color.systemViewBackground)
                .frame(height: kTabBarHeight)
                .alignBottom()
            }
            
            if roundSession.showHoleAnimation {
                HoleAnimationOverlay(
                    isShown: $roundSession.showHoleAnimation,
                    hole: $roundSession.currentHole
                )
            }
        }
        .environmentObject(appSession)
        .environmentObject(purchaseStore)
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear() {
            roundSession.players = appSession.players.filter({ $0.isPlaying })
            
            if let s = appSession.session {
                roundSession.loadSession(s, isPro: purchaseStore.hasUnlockedPro)
            }
            deviceDefaults.roundsPlayedCount += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                self.headerLock = false
            })
        }
        .onChange(of: tab, perform: { t in
            withAnimation {
                roundSession.selectedTab = t
            }
        })
        .onChange(of: roundSession.currentHole, perform: { hole in
            Haptics.fire(.light)
//            withAnimation(.linear(duration: 0.4)) {
//                showFinishButton = hole == roundSession.holeRange.last
//            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                if !roundSession.scoringExists(for: hole) {
                    roundSession.showHoleAnimation = true
                }
            })
        })
        .onChange(of: roundSession.session, perform: { s in
            appSession.session = s
            appSession.sessionCode = s?.partyCode ?? roundSession.partyCode
        })
        .onReceive(HackersNotification.sessionUpdated.publisher(), perform: { data in
            if let session = data.object as? Session {
                /// Load session by data
                roundSession.loadSession(session, isPro: purchaseStore.hasUnlockedPro)
            } else {
                /// Load session by cached ID since the publisher didn't provide right data.
                Task(operation: roundSession.fetchSession)
            }
        })
        .sheet(isPresented: $showGameRules) {
            SideGameHowToView(game: roundSession.pendingSideGame)
        }
    }
    
    // MARK: - Scroll Offset
    
    private func setScrollOffset(for data: ScrollData) {
        /// 1. This lock is timed by 600ms when view first loads to prevent weird bouncing as components appear.
        if headerLock { return }

        /// 2. If the value is 0, reset with animation
        if data.value == 0 {
            withAnimation(.linear(duration: 0.2)) {
                headerOpacity = 1
                roundSession.headerOffset = 0
            }
            return
        }

        /// 2. Used to track snap action for showing side game icon above hole number.
        if data.value <= 30 {
            didReturnToZero = true
        }
        
        /// 3. Value is negative, user is scrolling up.
        if data.value <= 0 {
            /// 3a. Value is beyond the header height -> guardrail
            if data.value < -kHeaderHeight {
                withAnimation(.linear(duration: 0.2)) {
                    headerOpacity = 0
                    roundSession.headerOffset = -kHeaderHeight
                }
            /// 3b. User is scrolling up but header is still visible -> apply transient translucent offset/opacity effect.
            } else {
                headerOpacity = (1 - abs(data.value) * 1 / kHeaderHeight)
                roundSession.headerOffset = min(data.value, kHeaderHeight)
            }
        /// 4. Value is either zero or positive -> animate header back into view
        } else {
            headerOpacity = 1
            roundSession.headerOffset = 0
            
            /// 4a. User pulled down almost to pull-to-refresh -> toggle hole scroller snap to show/hide side game icons.
            if data.value > 90 && didReturnToZero {
                didReturnToZero = false
                withAnimation(.linear(duration: 0.2)) {
                    roundSession.snapSideGames.toggle()
                }
                Haptics.fire(.medium)
            }
        }
    }
    
    // MARK: - Game Buttons
    
    @ViewBuilder private var gameButtons: some View {
        VStack(spacing: 10) {
            SmallButton(
                title: "View rules",
                awesomeIconRaw: "f02d",
                isDisabled: .false, 
                isLoading: .false,
                onTap: { showGameRules = true }
            )
            
            if !roundSession.pendingSideGame.players.contains(roundSession.players.count) {
                BigButton(
                    title: "Requires \(roundSession.pendingSideGame.playerLabel)",
                    appleIcon: "figure.golf",
                    labelColor: Color.systemError,
                    buttonColor: Color.systemError.opacity(colorScheme.translucent),
                    fillContainer: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { Haptics.fire(.error) }
                )
            } else if roundSession.pendingSideGame.underConstruction {
                BigButton(
                    title: "Under construction",
                    awesomeIconRaw: "f82c",
                    labelColor: Color.systemHackersYellow,
                    buttonColor: Color.systemHackersYellow.opacity(colorScheme.translucent),
                    fillContainer: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { Haptics.fire(.error) }
                )
            } else {
                BigButton(
                    title: "Play \(roundSession.pendingSideGame.name)",
                    labelColor: Color.white,
                    buttonColor: Color.systemHackersPurple,
                    fillContainer: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        roundSession.changeSideGame(to: roundSession.pendingSideGame, on: roundSession.currentHole)
                        roundSession.pendingSideGame = .none
                    }
                )
            }

        }
        .padding(.horizontal, 20)
    }
    
//    @ViewBuilder private var finishRoundButton: some View {
//        VStack(spacing: 20) {
//            Divider()
//
//            BigButton(title: "Finish round", isDisabled: .false, isLoading: .false)
//                .onTapAsync {
//                    await appSession.leaveRound()
//                }
//                .padding(.horizontal, 20)
//        }
//        .padding(.bottom, UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 40)
//        .background(
//            Color.systemViewBackground
//                .shadow(
//                    color: Color.systemBlack.opacity(colorScheme.isLight ? 0.08 : 0.04),
//                    radius: 8,
//                    x: 0,
//                    y: -4
//                )
//        )
//    }
}

struct RoundView_Previews: PreviewProvider {
    static var app = AppSession()
    static var purchase = PurchaseStore()
    
    static var previews: some View {
        RoundView()
            .environmentObject(app)
            .environmentObject(purchase)
            .onAppear() {
                app.session = Session(
                    id: "",
                    partyCode: "",
                    players: [
                        PlayerSession(player: kPlayerKyle),
                        PlayerSession(player: kPlayerSarah),
                        PlayerSession(player: kPlayerMurphy),
                        PlayerSession(player: kPlayerPablo)
                    ],
                    unlockedPro: false,
                    numberOfHoles: 18,
                    staringHole: 1,
                    sideGames: [SideGameSession()],
                    createdAt: Time(),
                    lastUpdatedAt: Time()
                )
            }
            .holisticPreview()
    }
}
