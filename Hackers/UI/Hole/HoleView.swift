//
//  HoleView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/23/23.
//

import SwiftUI

enum HoleViewComponent {
    case hole, packs, scorecard, complete
}

typealias OnFloatCallback = (CGFloat) -> Void

struct HoleView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var roundViewModel: RoundViewModel
    @StateObject var viewModel = HoleViewModel()
    
    var hole: Int
    
    @State private var showLeaderboardMenu: Bool = false
    @State private var showSideGameMenu: Bool = false
    
    @State private var showPlayerScorecard: Bool = false
    @State private var scorecardIndex: Int = 0
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showGamePicker: Bool = false
    
    @State private var scrollOffset: CGFloat = 0.0
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                content(for: proxy)
                    .padding(.horizontal, 20)
            }
        }
        .onAppear() {
            viewModel.players = roundViewModel.players
            viewModel.teams = roundViewModel.teams
            if let sideGameSession = roundViewModel.sideGameSessions.first(where: { $0.holes.contains(hole) }) {
                viewModel.sideGame = SideGame(rawValue: sideGameSession.game) ?? .none
                viewModel.sideGameSession = sideGameSession
            }
            
            var count: Int = 0
            for h in roundViewModel.holeRange {
                count += 1
                if h == hole { break }
            }
            viewModel.currentHole = hole
            viewModel.netHole = count
        }
        /// HOLE -> ROUND
        .onReceive(viewModel.$players, perform: { p in roundViewModel.players = p })
        /// ROUND -> HOLE
        .onReceive(roundViewModel.$teams, perform: { t in viewModel.teams = t })
        .onReceive(roundViewModel.$sideGameSessions, perform: { data in
            if let sideGameSession = data.first(where: { $0.holes.contains(hole) }) {
                viewModel.sideGame = SideGame(rawValue: sideGameSession.game) ?? .none
                viewModel.sideGameSession = sideGameSession
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
            PlayerScorecardView(players: $viewModel.players, index: $scorecardIndex, hole: hole)
                .presentationDetents([.height(475), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLeaderboardMenu) {
            LeaderboardMenuView(viewModel: roundViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSideGameMenu) {
            SideGameMenuView(viewModel: roundViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Content
    
    private func content(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            if viewModel.sideGame != .none {
                CurrentSideGameButton(viewModel: roundViewModel)
                    .onTap {
                        withAnimation(.linear(duration: 0.4)) {
                            proxy.scrollTo("sidegame", anchor: .bottom)
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
            
            // todo: results
            
            Spacer(minLength: 80)
        }
    }
    
    // MARK: - Leaderboard
    
    private var leaderboardView: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(spacing: 2) {
                    Text("Leaderboard")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    Text("Thru \(viewModel.netHole)")
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
            
            if viewModel.teams.isEmpty || !roundViewModel.teamRowDisplay {
                VStack(spacing: 10) {
                    ForEach($viewModel.players, id: \.self) { player in
                        LeaderboardPlayerRow(viewModel: roundViewModel, player: player, hole: hole)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { team in
                        LeaderboardTeamRow(viewModel: roundViewModel, team: team, hole: hole)
                    }
                }
            }
            
            if !viewModel.teams.isEmpty {
                HStack(spacing: 4) {
                    Text("Display rows as")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemGray)
                    
                    Button(action: {
                        roundViewModel.teamRowDisplay.toggle()
                        Haptics.fire(.light)
                    }) {
                        Text(roundViewModel.teamRowDisplay ? "teams" : "players")
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
        VStack(spacing: 20) {
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
                            
                            Text("Thru \(viewModel.netHole)")
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
            print("todo: show side game selection")
        }
    }
    
    @ViewBuilder private var sideGameDisplayView: any View {
        switch viewModel.sideGame {
        case .none:         dashedButton
        case .medalPlay:    AnyView(StrokePlayView(viewModel: roundViewModel, hole: hole, format: .medal))
        case .stableford:   StrokePlayView(viewModel: roundViewModel, hole: hole, format: .stableford)
        case .football:     StrokePlayView(viewModel: roundViewModel, hole: hole, format: .football)
        default:            Text("Coming soon!!")
        }
    }
}

struct HoleView_Previews: PreviewProvider {
    static var view: some View {
        HoleView(roundViewModel: RoundViewModel(), hole: 1)
            .environmentObject(AppSession())
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
