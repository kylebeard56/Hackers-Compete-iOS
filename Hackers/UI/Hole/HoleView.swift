//
//  HoleView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/7/24.
//

import Charts
import SwiftUI

struct HoleView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel = HoleViewModel()
    
    var view: RoundTab
    @Binding var hole: Int
    
    @State private var showLeaderboardMenu: Bool = false
    @State private var showSideGameMenu: Bool = false
    @State private var showIAP: Bool = false
    @State private var showStatsTrends: Bool = false
    @State private var showSuggestionBox: Bool = false
    
    @State private var showScorecard: Bool = false
    @State private var showPlayerScorecard: Bool = false
    @State private var scorecardIndex: Int = 0
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showNewSideGame: Bool = false
    
    @State private var loadLock: Bool = false
    
    var onScroll: OnScrollCallback?
    private var coordinateSpace: String { "hole-\(hole)" }
    
    private let kSampleHoles: Int = 3
    
    private var sampleHolesLeft: Int {
        if let session = roundSession.sideGameSessions.first(where: { $0.holes.contains(roundSession.currentHole) }),
           let holeIndex = session.holes.firstIndex(of: roundSession.currentHole) {
            return max(kSampleHoles - holeIndex, 0)
        } else {
            return 0
        }
    }
    
    private var userCanPlayGame: Bool {
        roundSession.hasUnlockedPro || !showGamePaywallBanner
    }
    
    private var showGamePaywallBanner: Bool {
        sampleHolesLeft == 0 && viewModel.sideGame != .none
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                content(for: proxy)
                    .padding(.horizontal, 20)
                    .background(ScrollGeometry(name: coordinateSpace))
                    .padding(.top, 20)
            }
        }
        .environmentObject(appSession)
        .environmentObject(purchaseStore)
        .environmentObject(roundSession)
        .onAppear() {
            print("HoleView onAppear for hole \(hole) with \(viewModel.sideGameSession)")
            /// Only load if the view is retained for more than 125ms
            loadLock = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.125, execute: {
                if !loadLock {
                    load()
                }
            })
        }
        .onDisappear() {
            loadLock = true
        }
        .onReceive(roundSession.$currentHole, perform: { _ in load() })
        .coordinateSpace(name: coordinateSpace)
        .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in
            if v == viewModel.lastScrollOffset { return }
            callbackOnScroll(ScrollData(value: v, direction: v - viewModel.lastScrollOffset >= 0 ? .down : .up))
            viewModel.lastScrollOffset = v
        })
        /// Capture round session changes for current hole view model
        .onReceive(roundSession.$players, perform: { _ in buildTeams() })
        .onReceive(viewModel.$sideGame, perform: { _ in buildResults() })
        .onReceive(roundSession.$sideGameSessions, perform: { data in
            if let s = data.first(where: { $0.holes.contains(hole) }), let g = SideGame(rawValue: s.game) {
                /// Only set these values if they differ to prevent an endless loop.
                if viewModel.sideGame != g {
                    viewModel.sideGame = g
                }
                if viewModel.sideGameSession != s {
                    viewModel.sideGameSession = s
                    calculateSideGameHolesThru(for: s)
                }
            } else {
                viewModel.sideGame = .none
                viewModel.sideGameSession = SideGameSession()
            }
        })
        /// Publish current hole view model changes back to the round session
        .onReceive(viewModel.$sideGameSession, perform: { data in
            if let i = roundSession.sideGameSessions.firstIndex(where: { $0.id == data.id }) {
                if roundSession.sideGameSessions[i] != data {
                    roundSession.sideGameSessions[i] = data
                }
            }
        })
        .onReceive(HackersNotification.displayPlayerScorecard.publisher(), perform: { data in
            showPlayerScorecard = false
            if let index = data.object as? Int {
                scorecardIndex = index
                showPlayerScorecard = true
            }
        })
        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
            if value {
                print("[PURCHASE STORE] onReceive $didCompletePurchase")
                showIAP = false
                roundSession.session?.unlockedPro = true
                roundSession.hasUnlockedPro = true
            }
        })
        .fullScreenCover(isPresented: $showIAP) {
            PurchaseView(allowSkip: false)
        }
        .sheet(isPresented: $showLeaderboardMenu) {
            LeaderboardMenuView()
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSideGameMenu) {
            SideGameMenuView(viewModel: viewModel, hole: hole)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNewSideGame) {
            SideGameSelectionView(action: .start, hole: hole)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showScorecard) {
            ScorecardView()
                .presentationDetents([.height(roundSession.scorecardHeight)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStatsTrends) {
            LeaderboardStatsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSuggestionBox) {
            SuggestionBoxView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Load
    
    private func load() {
        /// 1. Build teams for this hole
        buildTeams()
        
        /// 2. Get the session corresponding to the hole
        buildSideGame()
        
        /// 3. Build results for any past side games
        buildResults()
        
        /// 4. Determine the # of holes thru the round
        var count: Int = 0
        for h in roundSession.holeRange {
            count += 1
            if h == hole { break }
        }
        viewModel.roundThru = count
        
        /// 5. Prompt callback for smooth header/footer animations resetting
        callbackOnScroll(ScrollData(value: 0, direction: .none))
    }
    
    private func buildTeams() {
        let t = roundSession.players.compactMap({ $0.team[hole] }).filter({ !$0.isEmpty }).uniques
        viewModel.teams = t
        roundSession.teams = t
    }
    
    private func buildSideGame() {
        if let s = roundSession.sideGameSessions.first(where: { $0.holes.contains(hole) }) {
            viewModel.sideGame = SideGame(rawValue: s.game) ?? .none
            viewModel.sideGameSession = s
            calculateSideGameHolesThru(for: s)
            
            /// Reset the index for the detail display in Cards of Chaos
            if let a = viewModel.sideGameSession.chaos?.arrangement, viewModel.sideGame == .cardsOfChaos {
                if a == ChaosCardsArrangement.player.rawValue {
                    roundSession.chaosTab = roundSession.players.first?.id ?? ""
                } else {
                    roundSession.chaosTab = "team"
                }
            }
        } else {
            viewModel.sideGame = .none
            viewModel.sideGameSession = SideGameSession()
        }
    }
    
    private func calculateSideGameHolesThru(for s: SideGameSession) {
        let current = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let start = roundSession.holeRange.firstIndex(of: s.holes.first ?? 0) ?? 0
        viewModel.sideGameThru = current - start + 1
    }
    
    private func buildResults() {
        viewModel.results = []
        for s in roundSession.sideGameSessions {
            if s.game == SideGame.none.rawValue { continue }
            let now = roundSession.holeRange.firstIndex(of: hole) ?? 0
            let last = roundSession.holeRange.firstIndex(of: s.holes.last ?? 0) ?? 0
            if now > last {
                viewModel.results.append(s)
            }
        }
    }
    
    // MARK: - Content
    
    private func content(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            if view == .games {
                sideGameView(for: proxy)
                    .id("sidegame")
                    .padding(.bottom, 20)
            }
            
            if view == .leaderboard {
                leaderboardView
                    .id("leaderboard")
                    .padding(.bottom, 20)
            }
            
            Spacer(minLength: 80)
        }
        .id("content")
        .onChange(of: viewModel.sideGame, perform: { _ in
            proxy.scrollTo("content", anchor: .top)
        })
//        .onReceive(HackersNotification.sideGameResultsTapped.publisher(), perform: { _ in
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
//                withAnimation(.linear(duration: 0.4)) {
//                    proxy.scrollTo("results")
//                }
//            })
//        })
    }
    
    // MARK: - Leaderboard
    
    @ViewBuilder private var leaderboardView: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                Text("Leaderboard")
                    .font(.dmSans, size: 32, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text("Hole \(hole) ⋅ Thru \(roundSession.netHoleNumber)")
                    .font(.dmSans, size: 15, weight: .medium)
                    .foregroundColor(Color.systemGray)
                    .alignLeading()
            }
            .alignLeading()
            
            if viewModel.teams.isEmpty || !roundSession.teamRowDisplay {
                VStack(spacing: 10) {
                    ForEach($roundSession.players, id: \.self) { player in
                        LeaderboardPlayerRow(player: player, hole: $hole)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { team in
                        LeaderboardTeamRow(team: team, hole: $hole)
                    }
                }
            }
            
            if !viewModel.teams.isEmpty {
                HStack(spacing: 4) {
                    Text("Display rows as")
                        .font(.dmSans, size: 15, weight: .medium)
                        .foregroundColor(Color.systemGray)
                    
                    Button(action: {
                        Haptics.fire(.light)
                        withAnimation(.easeOut(duration: 0.2)) {
                            roundSession.teamRowDisplay.toggle()
                        }
                    }) {
                        ChipButton(
                            text: roundSession.teamRowDisplay ? "teams" : "players",
                            backgroundColor: colorScheme.superlightGray
                        )
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            VStack(spacing: 10) {
                PillDivider()
                    .padding(.vertical, 10)
                
                HStack(spacing: 10) {
                    TileButton(
                        icon: "f00a",
                        label: "Scorecard",
                        backgroundColor: colorScheme.superlightGray,
                        onTap: { showScorecard = true }
                    )
                    TileButton(
                        icon: "f643",
                        label: "Charts and trends",
                        backgroundColor: colorScheme.superlightGray,
                        onTap: { showStatsTrends = true }
                    )
                }
                
                HStack(spacing: 10) {
                    TileButton(
                        icon: "f044",
                        label: "Edit leaderboard",
                        backgroundColor: colorScheme.superlightGray,
                        onTap: { showLeaderboardMenu = true }
                    )
                    TileButton(
                        icon: "f735",
                        label: "Suggestion box",
                        backgroundColor: colorScheme.superlightGray,
                        onTap: { showSuggestionBox = true }
                    )
                }
            }
        }
    }
    
    // MARK: - Side game
    
    @ViewBuilder private func sideGameView(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            if viewModel.sideGame != .none {
                VStack(spacing: 0) {
                    Text(viewModel.sideGame.name)
                        .font(.dmSans, size: 32, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .minimumScaleFactor(0.85)
                        .alignLeading()
                    
                    let thru = viewModel.sideGameSession.holes.firstIndex(of: hole) ?? 0
                    
                    Text("Hole \(hole) ⋅ Thru \(thru + 1)")
                        .font(.dmSans, size: 15, weight: .medium)
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }
                .alignLeading()
                
                if !roundSession.hasUnlockedPro {
                    unlimitedPlayBanner
                }
                
//                if userCanPlayGame {
//                    let h = roundSession.currentHole
//                    if viewModel.sideGame.computedFromScoring && !roundSession.everyoneScored(on: h) {
//                        InfoBanner(
//                            icon: "f303",
//                            text: "Add scores for **Hole \(h)** on Leaderboard.",
//                            foregroundColor: Color.systemHackersPurple,
//                            backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent),
//                            onTap: { roundSession.selectedTab = .leaderboard }
//                        )
//                    }
//                }
            }
            
            if userCanPlayGame {
                sideGameDisplayView(for: proxy)
            }
            
            if viewModel.sideGame != .none {
                PillDivider()
                    .padding(.vertical, 10)
                
                HStack(spacing: 10) {
                    TileButton(
                        icon: "f044",
                        label: "Manage game",
                        backgroundColor: colorScheme.superlightGray,
                        onTap: { showSideGameMenu = true }
                    )
                    TileButton(
                        icon: "f735",
                        label: "Suggestion box",
                        backgroundColor: colorScheme.superlightGray,
                        onTap: { showSuggestionBox = true }
                    )
                }
            }
        }
    }
    
    private func dashboardGameView(for proxy: ScrollViewProxy) -> some View {
        VStack {
            SideGameDashboard()
                .onSelection { game in
                    withAnimation {
                        if game != .none {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(game.name, anchor: .top)
                            }
                        }
                        roundSession.pendingSideGame = game
                    }
                }
                .onFocusChange { value in roundSession.isGameSearchFocused = value }
                .padding(.horizontal, -20)
        }
    }
    
    @ViewBuilder private var unlimitedPlayBanner: some View {
        Button(action: {
            showIAP = true
            Haptics.fire(.light)
        }) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Image(uiImage: Asset.Images.logoProWhite.image)
                        .interpolation(.high)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                    
                    VStack(spacing: 2) {
                        Text("Play unlimited with Hackers Pro")
                            .font(.dmSans, size: 13, weight: .bold)
                            .foregroundStyle(.white)
                            .alignLeading()
                        
                        Group {
                            if showGamePaywallBanner {
                                Text("You're out of sample holes left for this game. Please subscribe to continue playing.")
                            } else if sampleHolesLeft == 1 {
                                Text("This is your final hole to sample this game before you'll need to subscribe.")
                            } else {
                                Text("You have \(sampleHolesLeft) holes left to sample this game before you’ll need to subscribe.")
                            }
                        }
                        .font(.dmSans, size: 13, weight: .regular)
                        .foregroundStyle(.white)
                        .alignLeading()
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    }
                }
                
                if showGamePaywallBanner {
                    SmallButton(
                        title: "Trial or purchase to continue",
                        foregroundColor: Color.systemHackersPurple,
                        backgroundColor: Color.white,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showIAP = true }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemHackersPurple)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 0)
        }
    }
    
    @ViewBuilder private func sideGameDisplayView(for proxy: ScrollViewProxy) -> some View {
        switch viewModel.sideGame {
        case .none:                 
            dashboardGameView(for: proxy)
        case .medalPlay:
            AnyView(
                StrokePlayView(viewModel: viewModel, hole: $hole, format: .medal)
            )
        case .stableford:
            AnyView(
                StrokePlayView(viewModel: viewModel, hole: $hole, format: .stableford)
            )
        case .fibonacci:
            AnyView(
                StrokePlayView(viewModel: viewModel, hole: $hole, format: .fibonacci)
            )
        case .nines:
            AnyView(
                NinesView(viewModel: viewModel, hole: $hole)
            )
        case .vegas:
            AnyView(
                VegasView(viewModel: viewModel, hole: $hole)
            )
        case .bingo:
            AnyView(
                BingoView(viewModel: viewModel, hole: $hole)
            )
        case .bestBall:
            AnyView(
                MatchPlayView(viewModel: viewModel, hole: $hole)
            )
        case .monkeyInTheMiddle:
            AnyView(
                MonkeyView(viewModel: viewModel, hole: $hole)
            )
        case .cardsOfChaos:
            AnyView(
                ChaosView(viewModel: viewModel, hole: $hole)
            )
        case .banker:
            AnyView(
                BankerView(viewModel: viewModel, hole: $hole)
            )
        case .football:
            AnyView(
                FootballView(viewModel: viewModel, hole: $hole)
            )
        default:
            comingSoon(viewModel.sideGame.name)
        }
    }
    
    // MARK: - Results
    
    private var resultsView: some View {
        VStack(spacing: 10) {
            Text("Results")
                .font(.dmSans, size: 20, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            ForEach(viewModel.results, id: \.self) { result in
                AnyView(sideGameResultView(for: result))
            }
        }
    }
    
    @ViewBuilder private func sideGameResultView(for session: SideGameSession) -> any View {
        let game = SideGame(rawValue: session.game) ?? .none
        switch game {
        case .none:                 EmptyView()
        case .medalPlay:            StrokePlayResultsView(session: session)
        case .stableford:           StrokePlayResultsView(session: session)
        case .fibonacci:            StrokePlayResultsView(session: session)
        case .nines:                NinesResultsView(session: session)
        case .vegas:                VegasResultsView(session: session)
        case .bingo:      BingoResultsView(session: session)
        case .bestBall:             MatchPlayResultsView(session: session)
        case .monkeyInTheMiddle:    MonkeyResultsView(session: session)
        case .cardsOfChaos:         ChaosResultsView(session: session)
        case .banker:               BankerResultsView(session: session)
        case .football:             FootballResultsView(session: session)
        default:                    comingSoon(game.name)
        }
    }
    
    @ViewBuilder private func comingSoon(_ text: String? = nil) -> some View {
        HStack {
            AwesomeImage(rawIcon: "f82c".unicode, style: .regular, size: 20, color: .systemHackersPurple)
            if let text {
                Text("\(text) is under construction")
                    .font(.dmSans, size: 17, weight: .medium)
                    .foregroundColor(Color.systemHackersPurple)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .alignCenter()
        .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
        .cornerRadius(12)
    }
}

typealias OnScrollCallback = (ScrollData) -> Void
enum ScrollDirection { case up, down, none }

struct ScrollData {
    var value: CGFloat
    var direction: ScrollDirection
    
    var isNeutral: Bool {
        value == 0 && direction == .none
    }
}

extension HoleView {
    fileprivate func callbackOnScroll(_ v: ScrollData) {
        if let onScroll { onScroll(v) }
    }
    
    func onScroll(_ action: @escaping OnScrollCallback) -> Self {
        var c = self
        c.onScroll = action
        return c
    }
}

struct HoleView2_Previews: PreviewProvider {
    static var app = AppSession()
    static var purchase = PurchaseStore()
    static var round = RoundSession()
    
    static var previews: some View {
        HoleView(view: .leaderboard, hole: .constant(1))
            .environmentObject(app)
            .environmentObject(purchase)
            .environmentObject(round)
            .holisticPreview()
    }
}
