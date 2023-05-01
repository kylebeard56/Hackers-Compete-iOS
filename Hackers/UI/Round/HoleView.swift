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
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    var isOnboard: Bool = false
    var component: HoleViewComponent = .hole
    
    var onScroll: OnFloatCallback?
    
//    @State private var showHoleList: Bool = false
    @State private var showHoleScoring: Bool = false
    @State private var showPlayerScoring: Bool = false
    @State private var showCurrentRoundSummary: Bool = false
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showGamePicker: Bool = false
    
    @State private var scrollOffset: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 12) {
            ScoringTileView(viewModel: viewModel, hole: hole)
            gamesView
        }
        .background(ScrollGeometry(name: "hole"))
        .padding(.horizontal, 12)
        .padding(.bottom, UIScreen.isSmall ? 16 : 0)
        .coordinateSpace(name: "hole")
        .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in
            scrollOffset = v
            callbackOnCommit(v)
        })
        .onChange(of: viewModel.currentHole, perform: { h in
            // Changing the hole will reset the selected tab within the card reveal.
            appSession.revealTab = "team"
            
            // If the current hole matches, we want to passback scroll offset for the menu button animation.
            if h == hole {
                callbackOnCommit(scrollOffset)
            }
        })
        .fullScreenCover(isPresented: $showGamePicker) {
            ChangeGameView(viewModel: viewModel, hole: hole)
        }
    }
    
    private var gamesView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Games")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)

                Button(action: {
                    showGamePicker = true
                    Haptics.fire(.light)
                }) {
                    Text("Change")
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemGray)
                }
            }
            
//            VTabView(selection: $appSession.gameTab) {
//                VStack {
//                    TraditionalView(viewModel: viewModel, hole: hole)
//                    Spacer(minLength: 0)
//                        .frame(height: 16)
//                }
//                .tag(0)
//
//                VStack {
//                    ChaosCardsView(viewModel: viewModel, hole: hole)
//                    Spacer(minLength: 0)
//                        .frame(height: 16)
//                }
//                .tag(1)
//
//                VStack {
//                    FootballView(viewModel: viewModel, hole: hole)
//                    Spacer(minLength: 0)
//                        .frame(height: 16)
//                }
//                .tag(2)
//
//                VStack {
//                    VegasView(viewModel: viewModel, hole: hole)
//                    Spacer(minLength: 0)
//                        .frame(height: 16)
//                }
//                .tag(3)
//
//                VStack {
//                    StablefordView(viewModel: viewModel, hole: hole)
//                    Spacer(minLength: 0)
//                        .frame(height: 16)
//                }
//                .tag(4)
//
//                VStack {
//                    WolfHammerView(viewModel: viewModel, hole: hole)
//                    Spacer(minLength: 0)
//                        .frame(height: 16)
//                }
//                .tag(5)
//            }
//            .tabViewStyle(.page(indexDisplayMode: .never))
//            .padding(.horizontal, -16)
//            .padding(.bottom, 16)
                
            activeGameCard()
                .padding(.horizontal, -16)
                .padding(.bottom, 16)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .border(Color.systemGray5, width: 1, cornerRadius: 8)
        .padding(.bottom, 2)
//        .onAppear() {
//            UIPageControl.appearance().currentPageIndicatorTintColor = .systemGray2
//            UIPageControl.appearance().pageIndicatorTintColor = .systemGray4
//        }
    }
    
    @ViewBuilder private func activeGameCard() -> some View {
        switch viewModel.activeGame {
        case .chaos:            AnyView(ChaosCardsView(viewModel: viewModel, hole: hole))
        case .football:         AnyView(FootballView(viewModel: viewModel, hole: hole))
        case .stableford:       AnyView(StablefordView(viewModel: viewModel, hole: hole))
        case .traditional:      AnyView(TraditionalView(viewModel: viewModel, hole: hole))
        case .vegas:            AnyView(VegasView(viewModel: viewModel, hole: hole))
        case .wolf:             AnyView(WolfHammerView(viewModel: viewModel, hole: hole))
        }
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
