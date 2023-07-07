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
    var isOnboard: Bool = false
    var component: HoleViewComponent = .hole
    
    var onScroll: OnFloatCallback?
    
    @State private var showLeaderboardMenu: Bool = false
    @State private var showPartyCodeView: Bool = false
    @State private var showManageRoundView: Bool = false
    
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
        .sheet(isPresented: $showLeaderboardMenu) {
            LeaderboardMenuView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showPartyCodeView) {
            PartyCodeView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showManageRoundView) {
            ManageRoundView()
        }
    }
    
    // MARK: - Content
    
    private func content(for proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 20) {
            if viewModel.sideGame != .none {
                Button(action: {
                    Haptics.fire(.light)
                    withAnimation(.easeOut(duration: 0.6)) { proxy.scrollTo("side-game", anchor: .top) }
                }) {
                    sideGameHeader
                }
            }
            
            leaderboardView
                .id("leaderboard")
            
            sideGameView
                .id("side-game")
            
            RoundedRectangle(cornerRadius: 2)
                .fill(colorScheme == .light ? Color.systemGray5: Color.systemGray3)
                .frame(height: 2, alignment: .center)
                .padding(.vertical, 10)
            
            Button(action: {
                showPartyCodeView = true
                Haptics.fire(.light)
            }) {
                partyCode
            }
            .id("party-code")
            
            BigButton(title: "Manage round", isDisabled: .false, isLoading: .false)
                .onTap {
                    showManageRoundView = true
                }
                .id("manage-round")
            
            Spacer(minLength: 120)
        }
    }
    
    // MARK: - Leaderboard
    
    private var leaderboardView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Leaderboard")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                
                Button(action: {
                    self.showLeaderboardMenu = true
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
                }
            }

            if viewModel.teams.isEmpty {
                VStack(spacing: 10) {
                    ForEach($viewModel.players, id: \.self) { p in
//                        Text(p.name.wrappedValue)
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
        }
    }
    
    // MARK: - Side game
    
    private var sideGameHeader: some View {
        HStack(spacing: 0 ) {
            VStack(spacing: 4) {
                Text("Currently playing")
                    .font(.dmSans(size: 11, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text(viewModel.sideGame.name)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemHackersPurple)
                    .alignLeading()
            }
            
            Spacer(minLength: 0)
            
            AwesomeImage(rawIcon: "f175".unicode, style: .solid, size: 20, color: .systemHackersPurple)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(Color.systemHackersPurple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var sideGameView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Side game")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                
                Button(action: {
                    print("todo")
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
                }
            }

            if viewModel.sideGame == .none {
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

            } else {
                Text(viewModel.sideGame.name)
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemHackersPurple)
                    .alignCenter()
                    .padding(.vertical, 12)
                    .background(Color.systemHackersPurple.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Party code
    
    private var partyCode: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("Party code")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                if viewModel.partyCode.isEmpty {
                    Text("Set party code")
                        .foregroundColor(Color.systemGray)
                        .font(.dmSans(size: 13, weight: .bold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(4)
                } else {
                    Text(viewModel.partyCode)
                        .foregroundColor(Color.systemHackersGreen)
                        .font(.dmSans(size: 13, weight: .bold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.systemHackersGreen.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Text("Share this code with anyone else to have them join and enjoy the fun with live scoring and gameplay updates.")
                .foregroundColor(Color.systemGray)
                .font(.dmSans(size: 13, weight: .regular))
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
}

// MARK: - Callbacks

extension HoleView {
    fileprivate func callbackOnCommit(_ v: CGFloat) {
        if let onScroll { onScroll(v) }
    }
    
    func onScroll(_ action: @escaping OnFloatCallback) -> Self {
        var c = self
        c.onScroll = action
        return c
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
