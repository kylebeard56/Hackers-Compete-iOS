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
    }
    
    private var gamesView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Games")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer()
                
                if !deviceDefaults.userViewedGameInstructions {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.point.down")
                            .font(.system(size: 13))
                        Text("Tap cards for instructions")
                            .font(.dmSans(size: 13, weight: .regular))
                    }
                    .foregroundColor(Color.systemGray2)
                }
            }
            
            TabView(selection: $appSession.activePack) {
                VStack {
                    ChaosCardsView(viewModel: viewModel, hole: hole)
                    Spacer(minLength: 0)
                        .frame(height: 42)
                }
                .tag(0)
                
                VStack {
                    DrinkingView(viewModel: viewModel)
                        .padding(16)
                        .background(Color.systemCard)
                        .border(Color.systemGray5, width: 2, cornerRadius: 16)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                        .frame(height: 42)
                }
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .padding(.horizontal, -16)
            .padding(.bottom, -16)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 12)
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .border(Color.systemGray5, width: 1, cornerRadius: 8)
        .onAppear() {
            UIPageControl.appearance().currentPageIndicatorTintColor = .systemGray2
            UIPageControl.appearance().pageIndicatorTintColor = .systemGray4
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
