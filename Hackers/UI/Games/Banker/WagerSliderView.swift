//
//  WagerSliderView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/13/23.
//

import SwiftUI

struct WagerSliderView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    var hole: Int
    
    var bankerID: String = ""
    var playerID: String = ""
    
    @State private var tab: String = ""
    @State private var banker: Player = Player()
    @State private var player: Player = Player()
    
    @State private var value: CGFloat = 10
    @State private var isEditing: Bool = false
    
    var body: some View {
        TabView(selection: $tab) {
            ForEach(roundSession.players.filter({ $0.id != bankerID }), id: \.self) { p in
                sliderView(for: p)
                    .tag(p.id)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color.systemViewBackground)
        .onAppear() {
            /// 1. Set the default tab
            if let p = roundSession.players.first, playerID.isEmpty {
                tab = p.id
            } else {
                tab = playerID
            }
            
            /// 2. Set the default value
            if let w = viewModel.sideGameSession.banker?.wagers[hole] {
                value = CGFloat(w[tab] ?? 10)
            } else {
                value = 10
            }
            
            /// 3. Set the banker
            if let b = roundSession.players.first(where: { $0.id == bankerID }) { banker = b }
            
            /// 4. Page control stuff
            UIPageControl.appearance().pageIndicatorTintColor = colorScheme.pageIndicatorTintColor
            UIPageControl.appearance().currentPageIndicatorTintColor = colorScheme.currentPageIndicatorTintColor
        }
        .onChange(of: tab, perform: { t in
            Haptics.fire(.light)
            if let w = viewModel.sideGameSession.banker?.wagers[hole] {
                value = CGFloat(w[t] ?? 10)
            } else {
                value = 10
            }
        })
    }
    
    private func sliderView(for player: Player) -> some View {
        VStack(spacing: 20) {
            Text("\(player.name.possessive) wager against \(banker.name)")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemBlack)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .alignCenter()
            
            Text("\(Int(value))")
                .font(.dmSans(size: 80, weight: .medium))
                .foregroundColor(player.color.value)
                .alignCenter()
            
            Slider(
                value: $value,
                in: 10...100,
                step: 5
            ) {
                Text("Wager")
            } minimumValueLabel: {
                Text("10").font(.dmSans(size: 13, weight: .bold))
            } maximumValueLabel: {
                Text("100").font(.dmSans(size: 13, weight: .bold))
            } onEditingChanged: { editing in
                isEditing = editing
                setWager()
            }
            .tint(player.color.value)
            .onChange(of: value, perform: { _ in Haptics.fire(.light) })
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .environmentObject(roundSession)
    }
    
    private func setWager() {
        if let wagers = viewModel.sideGameSession.banker?.wagers[hole] {
            var w = wagers
            w.updateValue(Int(value), forKey: tab)
            viewModel.sideGameSession.banker?.wagers.updateValue(w, forKey: hole)
        } else {
            viewModel.sideGameSession.banker?.wagers.updateValue([tab: Int(value)], forKey: hole)
        }
    }
}

struct WagerSliderView_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        return rs
    }
    
    static var previews: some View {
        VStack { }
            .sheet(isPresented: .true) {
                WagerSliderView(viewModel: HoleViewModel(), hole: 1, bankerID: kPlayerPablo.id)
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
                    .environmentObject(roundSession)
            }
            .holisticPreview()
    }
}
