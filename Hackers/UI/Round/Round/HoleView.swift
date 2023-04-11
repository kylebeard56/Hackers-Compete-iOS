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
    
    @State private var showHoleList: Bool = false
    @State private var showHoleScoring: Bool = false
    @State private var showPlayerScoring: Bool = false
    @State private var showCurrentRoundSummary: Bool = false
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var scrollOffset: CGFloat = 0.0
    
    var body: some View {
//        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                holeButton
                // TODO: [UX] Chip here for gray "Details" or green "Par #"
                scorecardTile
                gamepackCards
            }
            .background(ScrollGeometry(name: "hole"))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
//        }
        .coordinateSpace(name: "hole")
        .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in
            scrollOffset = v
            callbackOnCommit(v)
        })
        .onChange(of: viewModel.currentHole, perform: { h in
            // Changing the hole will reset the selected tab within the card reveal.
            viewModel.revealTab = "team"
            
            // If the current hole matches, we want to passback scroll offset for the menu button animation.
            if h == hole {
                callbackOnCommit(scrollOffset)
            }
        })
        .sheet(isPresented: $showHoleList) {
            HoleListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHoleScoring) {
            HoleScoringView(players: $viewModel.players, hole: hole)
                .presentationDetents([.height(viewModel.holeScoringHeight)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlayerScoring) {
            PlayerScoringView(players: $viewModel.players, index: $selectedIndex, hole: hole)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCurrentRoundSummary) {
            RoundSummaryView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var holeButton: some View {
        Button(action: {
            showHoleList = true
            Haptics.fire(.light)
        }) {
            Text("Hole \(hole)")
                .font(.dmSans(size: 36, weight: .medium))
                .foregroundColor(Color.systemBlack)
        }
        .alignLeading()
    }
    
    private var scorecardTile: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                Text("Scorecard")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                if viewModel.metricsAvailable() {
                    Button(action: {
                        Haptics.fire(.light)
                        showCurrentRoundSummary = true
                        FirebaseEvent.scoreSummaryTapped.log()
                    }) {
                        AwesomeImage(rawIcon: "e473".unicode, style: .regular, size: 20, color: .systemBlack)
                    }
                }
                
                Button(action: {
                    Haptics.fire(.light)
                    showHoleScoring = true
                    FirebaseEvent.addScoreTapped.log()
                }) {
                    AwesomeImage(
                        icon: viewModel.scoringExists(for: hole) ? .penSquare : .squarePlus,
                        style: .regular,
                        size: 20,
                        color: .systemBlack
                    )
                }
            }
            
            if viewModel.scoringExists(for: hole) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Spacer().frame(width: 8)
                        ForEach(viewModel.players, id: \.self) { player in
                            Button(action: {
                                selectedPlayer = player
                                selectedIndex = viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0
                                showPlayerScoring = true
                                Haptics.fire(.light)
                            }) {
                                scoringTile(for: player)
                            }
                        }
                        Spacer().frame(width: 8)
                    }
                    .frame(minWidth: UIScreen.main.bounds.width - 32)
                }
                .padding(.horizontal, -16)
            }
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .border(Color.systemGray5, width: 1, cornerRadius: 8)
    }
    
    private func scoringTile(for p: Player) -> some View {
        VStack(spacing: 6) {
            Text(p.name)
                .font(.dmSans(size: 13, weight: .medium))
                .foregroundColor(p.color.value)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .alignLeading()
            
            HStack(spacing: 4) {
                Text(p.textualScore(for: hole))
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    
                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .background(Color.systemCard)
        .border(Color.systemGray5, width: 2, cornerRadius: 6)
        .cornerRadius(6)
    }
    
    private var gamepackCards: some View {
        VStack(spacing: 16) {
            Picker("", selection: $appSession.activePack) {
                Text("Strategy").padding(.top, 8).tag(0)
                Text("Future").padding(.top, 8).tag(1)
            }
            .pickerStyle(.segmented)
            .tint(Color.systemGray5)
            
            if appSession.activePack == 0 {
                GameplayView(viewModel: viewModel, hole: hole)
                    .padding(.horizontal, -16)
            }
            
            if appSession.activePack == 1 {
                DrinkingView(viewModel: viewModel)
                    .padding(.horizontal, -16)
            }
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .border(Color.systemGray5, width: 1, cornerRadius: 8)
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
