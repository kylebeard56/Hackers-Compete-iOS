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
/// [ ] Change or stop game (partition index)
/// [ ] Bingo Bango Bongo
/// [ ] Best Ball
/// [ ] Cards of Chaos
/// [ ] Monkey in the Middle
/// [ ] Banker
/// [ ] Wolf Hammer

enum HoleViewComponent {
    case hole, packs, scorecard, complete
}

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
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel = HoleViewModel()
    
    var hole: Int
    
    @State private var showLeaderboardMenu: Bool = false
    @State private var showSideGameMenu: Bool = false
    
    @State private var showPlayerScorecard: Bool = false
    @State private var scorecardIndex: Int = 0
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showNewSideGame: Bool = false
    
    @State private var scrollOffset: CGFloat = 0.0
    
    var onScroll: OnScrollCallback?
    private var coordinateSpace: String { "hole-\(hole)" }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                content(for: proxy)
                    .padding(.horizontal, 20)
                    .background(ScrollGeometry(name: coordinateSpace))
                    .onDisappear() { proxy.scrollTo("header") }
            }
        }
        .environmentObject(appSession)
        .environmentObject(roundSession)
        .onAppear() { load() }
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
        .sheet(isPresented: $showPlayerScorecard) {
            PlayerScorecardView(players: $roundSession.players, index: $scorecardIndex, hole: hole)
                .presentationDetents([.height(475), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLeaderboardMenu) {
            LeaderboardMenuView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSideGameMenu) {
            SideGameMenuView(hole: hole)
                .presentationDetents([.height(500), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNewSideGame) {
            SideGameSelectionView(action: .start, onSelection: { game in
                //roundSession.startSideGame(game, on: hole)
                roundSession.changeSideGame(to: game, on: hole)
            })
            .presentationDetents([.large])
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
        
        /// 4. Prompt callback for smooth header/footer animations
        callbackOnCommit(ScrollData(value: viewModel.lastScrollOffset, direction: .none))
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
            if let end = s.holes.last, hole > end, s.game != SideGame.none.rawValue {
                viewModel.results.append(s)
            }
        }
    }
    
    // MARK: - Content
    
    private func content(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            HoleHeaderView()
                .padding(.top, 10)
                .opacity(0.0)
                .disabled(true)
                .id("header")
            
            if viewModel.sideGame != .none {
                CurrentSideGameButton(viewModel: viewModel)
                    .onTap {
                        withAnimation(.linear(duration: 0.4)) {
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
                    print("scrollTo results")
                    proxy.scrollTo("results")
                }
            })
//            if let id = data.object as? String {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
//                    withAnimation(.linear(duration: 0.4)) {
//                        proxy.scrollTo("results")
//                    }
//                })
//
//            }
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
                
                Button(action: {
                    self.showLeaderboardMenu = true
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
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
                        roundSession.teamRowDisplay.toggle()
                        Haptics.fire(.light)
                    }) {
                        Text(roundSession.teamRowDisplay ? "teams" : "players")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 15, weight: .medium))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(colorScheme.superlightGray)
                            .cornerRadius(4)
                    }
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    // MARK: - Side game
    
    private var sideGameView: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(spacing: 2) {
                    Text("Side game")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    if viewModel.sideGame != .none {
                        HStack(spacing: 10) {
                            Text(viewModel.sideGame.name)
                                .foregroundColor(Color.systemHackersPurple)
                                .font(.dmSans(size: 15, weight: .medium))
                            
                            Circle()
                                .fill(Color.systemGray3)
                                .frame(width: 4, height: 4)
                            
                            Text("Thru \(viewModel.sideGameThru)")
                                .foregroundColor(Color.systemBlack)
                                .font(.dmSans(size: 15, weight: .medium))
                            
                            Spacer(minLength: 0)
                        }
                    }
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
            title: "Add a side game",
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
        case .none:         dashedButton
        case .medalPlay:    StrokePlayView(viewModel: viewModel, hole: hole, format: .medal)
        case .stableford:   StrokePlayView(viewModel: viewModel, hole: hole, format: .stableford)
        case .football:     StrokePlayView(viewModel: viewModel, hole: hole, format: .football)
        case .nines:        NinesView(viewModel: viewModel, hole: hole)
        case .vegas:        VegasView(viewModel: viewModel, hole: hole)
        default:            Text("Coming soon!!")
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
        switch SideGame(rawValue: session.game) ?? .none {
        case .none:         EmptyView()
        case .medalPlay:    StrokePlayResultsView(session: session)
        case .stableford:   StrokePlayResultsView(session: session)
        case .football:     StrokePlayResultsView(session: session)
        default:            Text("Coming soon!!")
        }
    }
}

struct HoleView_Previews: PreviewProvider {
    static var view: some View {
        HoleView(hole: 1)
            .environmentObject(AppSession())
            .environmentObject(RoundSession())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
