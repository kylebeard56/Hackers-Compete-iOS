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
    var incrementer: Int = 0
    
    func start(_ data: ScrollData) {
        if data.isNeutral || incrementer == 0 {
            incrementer += 1
            return
        }
        
        timer?.invalidate()
        
        showNextHoleButton = false
        
        timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(0.1),
            target: self,
            selector: #selector(stop),
            userInfo: nil,
            repeats: false
        )
        
        incrementer += 1
    }
    
    @objc private func stop() {
        timer?.invalidate()
        showNextHoleButton = true
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
    @State private var showGameRules: Bool = false
    @State private var showIAP: Bool = false
    
    @State private var tab: RoundTab = .games
    @StateObject private var timer = ScrollTimer()
    
    @State private var nextHoleHoverButtonEligible: Bool = false
    @State private var loadLock: Bool = true
    @State private var tipLock: Bool = true
    
    private var kTabBarHeight: CGFloat {
        if roundSession.selectedTab != .games || roundSession.pendingSideGame == .none {
            return 60
        } else {
            switch (roundSession.isGameSearchFocused, roundSession.pendingSideGame == .none) {
            case (true, true):      return 60
            case (true, false):     return 108
            case (false, true):     return 60
            case (false, false):    return 108
            }
        }
//        if roundSession.selectedTab == .games {
//            if roundSession.isGameSearchFocused && roundSession.pendingSideGame == .none {
//                return 0
//            } else {
//                if roundSession.pendingSideGame != .none {
//                    return 108
//                }
//                return 60
//            }
//        } else {
//            return 60
//        }
    }
    
    var isFinalHole: Bool {
        roundSession.holeRange.last == roundSession.currentHole
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
                    HoleSelectionView()
                        .tag(RoundTab.nextHole)
                }
                .tag(roundSession.currentHole)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeIn, value: tab)
                
                Spacer(minLength: kTabBarHeight)
            }
            
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
                            .observePosition(onChange: { p in
                                print("POSITION: \(p)")
                                switch tab {
                                case .games: roundSession.tips[0].position = p
                                case .leaderboard: roundSession.tips[1].position = p
                                case .nextHole: roundSession.tips[2].position = p
                                }
                            })
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .background(Color.systemViewBackground)
            .frame(height: kTabBarHeight)
            .alignBottom()
            
            if timer.showNextHoleButton
                && !roundSession.isGameSearchFocused
                && roundSession.pendingSideGame == .none 
                && nextHoleHoverButtonEligible
                && roundSession.everyoneScored(on: roundSession.currentHole) 
                && roundSession.selectedTab != .nextHole 
            {
                CurrentHoleButton()
                    .padding(.horizontal, 20)
                    .alignBottom()
                    .padding(.bottom, kTabBarHeight + 12)
            }
            
            if roundSession.isGameSearchFocused {
                KeyboardDismissalButton()
                    .padding(.bottom, kTabBarHeight + 20)
                    .padding(.horizontal, 20)
                    .alignBottom()
                    .alignTrailing()
            }
            
            if roundSession.showHoleAnimation {
                HoleAnimationOverlay(
                    isShown: $roundSession.showHoleAnimation,
                    hole: $roundSession.currentHole
                )
            }
            
            if let tip = roundSession.activeTip {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.05)

                    TipCard(
                        tip: tip,
                        showClose: roundSession.tips.last?.data.id == tip.data.id,
                        showNext: roundSession.tips.last?.data.id != tip.data.id,
                        onClose: roundSession.onTipClose,
                        onNext: roundSession.onTipNext
                    )
                }
                .ignoresSafeArea(edges: .all)
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
                print("Create session -> unlocked pro? \(purchaseStore.hasUnlockedPro)")
                roundSession.loadSession(s, isPro: purchaseStore.hasUnlockedPro)
            }
            deviceDefaults.roundsPlayedCount += 1
            
            /// User came to this hole and not everyone has scored so flip boolean to show the hover if everyone does score.
            if !roundSession.everyoneScored(on: roundSession.currentHole) {
                nextHoleHoverButtonEligible = true
            }
            
            /// Prevent any animation triggers from occurring on initial showing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                loadLock = false
            })
            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
//                roundSession.showNextTipIfAvailable()
//                tipLock = false
//            })
        }
        .task {
            await purchaseStore.updatePurchasedProducts()
        }
        .onChange(of: tab, perform: { t in
            if roundSession.selectedTab == t { return }
            withAnimation {
                roundSession.selectedTab = t
            }
        })
        .onReceive(roundSession.$selectedTab, perform: { t in
            if tab == t { return }
            withAnimation {
                tab = t
            }
        })
//        .onReceive(roundSession.$tips, perform: { t in
//            if roundSession.activeTip == nil && !tipLock {
//                withAnimation {
//                    roundSession.showNextTipIfAvailable()
//                }
//            }
//        })
        .onChange(of: roundSession.currentHole, perform: { hole in
            Haptics.fire(.light)
            if tab == .nextHole {
                withAnimation {
                    tab = roundSession.sideGame == .none ? .leaderboard : .games
                }
            }
            roundSession.showHoleAnimation = !loadLock
            
            /// User came to this hole and not everyone has scored so flip boolean to show the hover if everyone does score.
            if !roundSession.everyoneScored(on: hole) {
                nextHoleHoverButtonEligible = true
            }
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
        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
            if value {
                showIAP = false
            }
        })
        .sheet(isPresented: $showIAP) {
            PurchaseView()
        }
    }
    
    // MARK: - Tab Item
    
    @ViewBuilder private func item(for tab: RoundTab) -> some View {
        let color: Color = roundSession.selectedTab == tab ? Color.systemBlack : Color.systemGray
        let label = tab == .nextHole ? isFinalHole ? "Finish round" : "Hole \(roundSession.currentHole)" : tab.rawValue
        let icon = tab == .nextHole && isFinalHole ? "f00c".unicode : tab.icon
        
        VStack(spacing: 6) {
            AwesomeImage(rawIcon: icon, style: .regular, size: 20, color: color )
            Text(label)
                .font(.dmSans, size: 13, weight: .bold)
                .foregroundStyle(color)
        }
        .alignCenter()
    }
    
    // MARK: - Scroll Offset
    
//    private func setScrollOffset(for data: ScrollData) {
//        /// 1. This lock is timed by 600ms when view first loads to prevent weird bouncing as components appear.
//        if headerLock { return }
//
//        /// 2. If the value is 0, reset with animation
//        if data.value == 0 {
//            withAnimation(.linear(duration: 0.2)) {
//                headerOpacity = 1
//                roundSession.headerOffset = 0
//            }
//            return
//        }
//
//        /// 2. Used to track snap action for showing side game icon above hole number.
//        if data.value <= 30 {
//            didReturnToZero = true
//        }
//        
//        /// 3. Value is negative, user is scrolling up.
//        if data.value <= 0 {
//            /// 3a. Value is beyond the header height -> guardrail
//            if data.value < -kHeaderHeight {
//                withAnimation(.linear(duration: 0.2)) {
//                    headerOpacity = 0
//                    roundSession.headerOffset = -kHeaderHeight
//                }
//            /// 3b. User is scrolling up but header is still visible -> apply transient translucent offset/opacity effect.
//            } else {
//                headerOpacity = (1 - abs(data.value) * 1 / kHeaderHeight)
//                roundSession.headerOffset = min(data.value, kHeaderHeight)
//            }
//        /// 4. Value is either zero or positive -> animate header back into view
//        } else {
//            headerOpacity = 1
//            roundSession.headerOffset = 0
//            
//            /// 4a. User pulled down almost to pull-to-refresh -> toggle hole scroller snap to show/hide side game icons.
//            if data.value > 90 && didReturnToZero {
//                didReturnToZero = false
//                withAnimation(.linear(duration: 0.2)) {
//                    roundSession.snapSideGames.toggle()
//                }
//                Haptics.fire(.medium)
//            }
//        }
//    }
    
    // MARK: - Game Buttons
    
    @ViewBuilder private var gameButtons: some View {
        VStack(spacing: 10) {
            SmallButton(
                title: "How to play",
                //awesomeIconRaw: "f02d",
                //foregroundColor: Color.systemWhite,
                //backgroundColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showGameRules = true }
            )
            
            if roundSession.isGameSampled(roundSession.pendingSideGame) {
                
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
            } else if !roundSession.pendingSideGame.players.contains(roundSession.players.count) {
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
            }  else {
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
    static var app: AppSession {
        let app = AppSession()
        
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
            sideGames: [
//                SideGameSession(
//                    id: "",
//                    game: SideGame.banker.rawValue,
//                    holes: Array(1...18)
//                )
            ],
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
        
        return app
    }
    static var purchase = PurchaseStore()
    
    static var previews: some View {
        RoundView()
            .environmentObject(app)
            .environmentObject(purchase)
            .holisticPreview()
    }
}
