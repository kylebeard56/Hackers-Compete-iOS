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
    @StateObject var viewModel: RoundViewModel
    
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
        .onReceive(HackersNotification.displayPlayerScorecard.publisher(), perform: { data in
            showPlayerScorecard = false
            if let index = data.object as? Int {
                scorecardIndex = index
                showPlayerScorecard = true
            }
        })
        .sheet(isPresented: $showPlayerScorecard) {
            PlayerScorecardView(players: $viewModel.players, index: $scorecardIndex, hole: viewModel.currentHole)
                .presentationDetents([.height(475), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLeaderboardMenu) {
            LeaderboardMenuView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSideGameMenu) {
            SideGameMenuView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Content
    
    private func content(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 40) {
            leaderboardView
                .id("leaderboard")
            
            sideGameView
                .id("sidegame")
            
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
                    Text("Thru \(viewModel.netHoleNumber)")
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
            
            if viewModel.teams.isEmpty || !viewModel.teamRowDisplay {
                VStack(spacing: 10) {
                    ForEach($viewModel.players, id: \.self) { p in
                        LeaderboardPlayerRow(viewModel: viewModel, player: p)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { t in
                        LeaderboardTeamRow(viewModel: viewModel, team: t)
                    }
                }
            }
            
            if !viewModel.teams.isEmpty {
                HStack(spacing: 4) {
                    Text("Display rows as")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemGray)
                    
                    Button(action: {
                        viewModel.teamRowDisplay.toggle()
                        Haptics.fire(.light)
                    }) {
                        Text(viewModel.teamRowDisplay ? "teams" : "players")
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
                            
                            Text("Thru \(viewModel.netHoleNumber)")
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
        case .medalPlay:    AnyView(StrokePlayView(viewModel: viewModel, format: .medal))
        case .stableford:   StrokePlayView(viewModel: viewModel, format: .stableford)
        case .football:     StrokePlayView(viewModel: viewModel, format: .football)
        default:            Text("Coming soon!!")
        }
    }
}

struct HoleView_Previews: PreviewProvider {
    static var view: some View {
        HoleView(viewModel: RoundViewModel(), hole: 1)
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
