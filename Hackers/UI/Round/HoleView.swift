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
    
    @State private var showPlayerScoring: Bool = false
    @State private var showTeamStructure: Bool = false
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showGamePicker: Bool = false
    
    @State private var scrollOffset: CGFloat = 0.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                leaderboard
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showTeamStructure) {
            TeamStructureView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var leaderboard: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Leaderboard")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                
                Button(action: {
                    self.showTeamStructure = true
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
                }
            }

            if viewModel.teams.isEmpty {
                VStack(spacing: 10) {
                    ForEach($viewModel.players, id: \.self) { p in
                        LeaderboardPlayerRow(viewModel: viewModel, player: p)
                            .onAppear() {
                                print("ForEach onAppear")
                                printPretty(viewModel.players)
                            }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { t in
                        LeaderboardTeamRow(viewModel: viewModel, team: t)
                    }
                }
            }
            
            /// (2) Side games
            /// Below are aligned to bottom with geometry reader if scroll view doesn't fill screen height
            /// (3) Party code
            /// (4) Manage round button
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
