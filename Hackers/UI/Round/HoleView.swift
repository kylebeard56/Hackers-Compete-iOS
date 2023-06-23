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
    }
    
    private var leaderboard: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Leaderboard")
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
            
            VStack(spacing: 10) {
                ForEach($viewModel.players, id: \.self) { p in
                    LeaderboardPlayerRow(
                        viewModel: viewModel,
                        player: p//,
//                        currentHole: hole
                    )
                }
            }
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
