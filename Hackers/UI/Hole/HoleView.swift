//
//  HoleView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/23/23.
//

import SwiftUI

/// NEXT GAMES:
/// [X] Nines
/// [X] Vegas
/// [X] Change or stop game (partition index)
/// [X] Subscription for side games (w/ grandfathered peeps getting 3 months free and showing popup if deviceRound > 1 on launch of new update) 3 days
/// [X] Bingo Bango Bongo Teams
/// [X] Handicaps 4 days
/// [X] Full scorecard (similar to handicap view but showing scores per hole) 1 day
/// [X] Match play w/ Skins 2 days
/// [X] Vegas and Bingo commentary banners 1 day
/// [X] Monkey in the Middle 1 day
/// [X] Cards of Chaos 2 days
/// [ ] Banker 3 days
/// [ ] Wolf Hammer 3 days
/// [ ] Football 1 day
/// [ ] Test / Clean up 7 days
/// [ ] Website and screenshots 2 days
/// ---
/// As of Aug 6th, current trajectory is Aug 28th release.
/// As of Aug 11th, current trajectory is Aug 29th release.
/// ---
///
/// [ ] RELEASE v2.0 by end of August!
/// [ ] OCR for scorecard to get par/yardage per tee or manually enter course and scorecard (all par 4 but you pad 3 or 5 on which holes).
/// [ ] Tips, helper text, small aesthetic tweaks,  etc...
/// [ ] Push notification opt-in

enum ScrollDirection { case up, down, none }

struct ScrollData {
    var value: CGFloat
    var direction: ScrollDirection
}

typealias OnScrollCallback = (ScrollData) -> Void

extension HoleView {
    fileprivate func callbackOnCommit(_ v: ScrollData) {
        if let onScroll { onScroll(v) }
    }
    
    func onScroll(_ action: @escaping OnScrollCallback) -> Self {
        var c = self
        c.onScroll = action
        return c
    }
}

struct HoleView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel = HoleViewModel()
    
    var hole: Int
    
    @State private var showLeaderboardMenu: Bool = false
    @State private var showSideGameMenu: Bool = false
    @State private var showIAP: Bool = false
    
    @State private var showScorecard: Bool = false
    @State private var showPlayerScorecard: Bool = false
    @State private var scorecardIndex: Int = 0
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showNewSideGame: Bool = false
    
    @State private var loadLock: Bool = false
    
    var onScroll: OnScrollCallback?
    private var coordinateSpace: String { "hole-\(hole)" }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                content(for: proxy)
                    .padding(.horizontal, 20)
                    .background(ScrollGeometry(name: coordinateSpace))
                    .onDisappear() { proxy.scrollTo("header", anchor: .top) }
//                    .padding(.top, roundSession.scrollBiasApplied ? roundSession.bias : 0)
//                    .offset(y: roundSession.scrollBiasApplied ? roundSession.bias : 0)
            }
        }
        .environmentObject(appSession)
        .environmentObject(purchaseStore)
        .environmentObject(roundSession)
        .onAppear() {
            /// Only load if the view is retained for more than 100ms
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
        /// Observe scrolling behavior to make round header behave fancy.
        .coordinateSpace(name: coordinateSpace)
        .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in
            if v == viewModel.lastScrollOffset { return }
            callbackOnCommit(ScrollData(value: v, direction: v - viewModel.lastScrollOffset >= 0 ? .down : .up))
            viewModel.lastScrollOffset = v
        })
        /// Capture round session changes for current hole view model
        .onReceive(roundSession.$players, perform: { _ in buildTeams() })
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
        .sheet(isPresented: $showLeaderboardMenu) {
            LeaderboardMenuView()
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSideGameMenu) {
            SideGameMenuView(hole: hole)
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
    }
    
    // MARK: - Load
    
    private func load() {
        /// 1. Build teams for this hole
        buildTeams()
        
        /// 1. Get the session corresponding to the hole
        buildSideGame()
        
        /// 2. Build results for any past side games
        buildResults()
        
        /// 3. Determine the # of holes thru the round
        var count: Int = 0
        for h in roundSession.holeRange {
            count += 1
            if h == hole { break }
        }
        viewModel.roundThru = count
        
        /// 4. Prompt callback for smooth header/footer animations resetting
        callbackOnCommit(ScrollData(value: 0, direction: .none))
    }
    
    private func buildTeams() {
        viewModel.teams = roundSession.players.compactMap({ $0.team[hole] }).uniques.filter({ !$0.isEmpty })
    }
    
    private func buildSideGame() {
        if let s = roundSession.sideGameSessions.first(where: { $0.holes.contains(hole) }) {
            viewModel.sideGame = SideGame(rawValue: s.game) ?? .none
            viewModel.sideGameSession = s
            calculateSideGameHolesThru(for: s)
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

    private var headerPadding: CGFloat {
        let h: CGFloat = roundSession.snapSideGames ? 86 : 56
        return h + kHeaderHeight
    }
    
    private func content(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            Color.systemViewBackground
                .frame(height: headerPadding)
                .id("header")
            
            if viewModel.sideGame != .none {
                CurrentSideGameButton(viewModel: viewModel)
                    .onTap {
                        withAnimation(.linear(duration: 0.4)) {
                            print("scrollTo sidegame")
                            proxy.scrollTo("sidegame")
                        }
                    }
                    .padding(.bottom, 20)
            }
            
            leaderboardView
                .id("leaderboard")
                .padding(.bottom, 20)
            
            sideGameView
                .id("sidegame")
                .padding(.bottom, 20)
            
            if !viewModel.results.isEmpty {
                resultsView
                    .id("results")
                    .padding(.bottom, 20)
            }
            
            Spacer(minLength: 40)
        }
        .onReceive(HackersNotification.sideGameResultsTapped.publisher(), perform: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                withAnimation(.linear(duration: 0.4)) {
                    proxy.scrollTo("results")
                }
            })
        })
    }
    
    // MARK: - Leaderboard
    
    @ViewBuilder private var leaderboardView: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(spacing: 2) {
                    Text("Leaderboard")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    Text("Thru \(viewModel.roundThru)")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 32) {
                    Button(action: {
                        self.showScorecard = true
                        Haptics.fire(.light)
                    }) {
                        AwesomeImage(rawIcon: "f00a".unicode, style: .regular, size: 20, color: .systemBlack)
                    }
                    
                    Button(action: {
                        self.showLeaderboardMenu = true
                        Haptics.fire(.light)
                    }) {
                        AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
                    }
                }
            }
            
            if viewModel.teams.isEmpty || !roundSession.teamRowDisplay {
                VStack(spacing: 10) {
                    ForEach($roundSession.players, id: \.self) { player in
                        LeaderboardPlayerRow(player: player, hole: hole)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { team in
                        LeaderboardTeamRow(team: team, hole: hole)
                    }
                }
            }
            
            if !viewModel.teams.isEmpty {
                HStack(spacing: 4) {
                    Text("Display rows as")
                        .font(.dmSans(size: 15, weight: .medium))
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
        }
    }
    
    // MARK: - Side game
    
    @ViewBuilder private var sideGameView: some View {
        //var games = SideGame.allCases
        //games = games.removeAll(where: { $0 == .none })

        VStack(spacing: 10) {
            HStack {
                VStack(spacing: 2) {
                    Text("Side game")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    if viewModel.sideGame != .none {
                        Text("Thru \(viewModel.sideGameThru)")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 15, weight: .medium))
                            .alignLeading()
                    }
//                    else {
//                        /// This should show game titles based on # of players in party.
//                        Text("Play games on the side like **Banker**, **Vegas**, or **Wolf Hammer** to get the most out of your round.")
//                            .foregroundColor(Color.systemGray)
//                            .font(.dmSans(size: 15, weight: .medium))
//                            .multilineTextAlignment(.leading)
//                            .alignLeading()
//                    }
                }
                
                Spacer(minLength: 0)
                
                if viewModel.sideGame != .none {
                    Button(action: {
                        self.showSideGameMenu = true
                        Haptics.fire(.light)
                    }) {
                        AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
                    }
                }
            }
            
            AnyView(sideGameDisplayView)
        }
    }
    
    private var dashedButton: some View {
        DashedButton(
            title: "Start on Hole \(hole)", //"Add a side game",
            appleIcon: "plus.circle",
            labelColor: .systemHackersPurple,
            buttonColor: .systemHackersPurple,
            isDisabled: .false,
            isLoading: .false
        )
        .onTap {
            showNewSideGame = true
        }
    }
    
    @ViewBuilder private var sideGameDisplayView: any View {
        switch viewModel.sideGame {
        case .none:                 dashedButton
        case .medalPlay:            StrokePlayView(viewModel: viewModel, hole: hole, format: .medal)
        case .stableford:           StrokePlayView(viewModel: viewModel, hole: hole, format: .stableford)
        case .fibonacci:            StrokePlayView(viewModel: viewModel, hole: hole, format: .fibonacci)
        case .nines:                NinesView(viewModel: viewModel, hole: hole)
        case .vegas:                VegasView(viewModel: viewModel, hole: hole)
        case .bingoBangoBongo:      BingoView(viewModel: viewModel, hole: hole)
        case .bestBall:             MatchPlayView(viewModel: viewModel, hole: hole)
        case .monkeyInTheMiddle:    MonkeyView(viewModel: viewModel, hole: hole)
        case .cardsOfChaos:         ChaosView(viewModel: viewModel, hole: hole)
        case .banker:               BankerView(viewModel: viewModel, hole: hole)
        default:                    comingSoon(viewModel.sideGame.name)
        }
    }
    
    // MARK: - Results
    
    private var resultsView: some View {
        VStack(spacing: 10) {
            Text("Results")
                .font(.dmSans(size: 20, weight: .bold))
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
        case .bingoBangoBongo:      BingoResultsView(session: session)
        case .bestBall:             MatchPlayResultsView(session: session)
        case .monkeyInTheMiddle:    MonkeyResultsView(session: session)
        case .cardsOfChaos:         ChaosResultsView(session: session)
        default:                    comingSoon(game.name)
        }
    }
    
    @ViewBuilder private func comingSoon(_ text: String? = nil) -> some View {
        HStack {
            AwesomeImage(rawIcon: "f82c".unicode, style: .regular, size: 20, color: .systemHackersPurple)
            if let text {
                Text("\(text) is under construction")
                    .font(.dmSans(size: 17, weight: .medium))
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

struct HoleView_Previews: PreviewProvider {
    static var previews: some View {
        HoleView(hole: 1)
            .environmentObject(AppSession())
            .environmentObject(RoundSession())
            .holisticPreview()
    }
}
