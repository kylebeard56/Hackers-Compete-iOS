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
                    .padding(.bottom, 40)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .onAppear() {
            if let p = roundSession.players.first, playerID.isEmpty {
                tab = p.id
            } else {
                tab = playerID
            }
            
            if let b = roundSession.players.first(where: { $0.id == bankerID }) { banker = b }
            print("tab: \(tab)")
            setWager()
            
            UIPageControl.appearance().pageIndicatorTintColor = colorScheme.pageIndicatorTintColor
            UIPageControl.appearance().currentPageIndicatorTintColor = colorScheme.currentPageIndicatorTintColor
        }
        .onChange(of: tab, perform: { t in
            Haptics.fire(.light)
            print("tabChanged, \(viewModel.sideGameSession.banker?.wagers[hole] ?? [:])")
            if let w = viewModel.sideGameSession.banker?.wagers[hole] {
                print("set value to \(w[t] ?? 10) for \(t)")
                value = CGFloat(w[t] ?? 10)
            } else {
                value = 10
            }
        })
    }
    
    private func sliderView(for player: Player) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0).frame(height: 10)
            
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
        .background(Color.systemCard)
        .environmentObject(roundSession)
    }
    
    private func setWager() {
        if let wagers = viewModel.sideGameSession.banker?.wagers[hole] {
            var w = wagers
            w.updateValue(Int(value), forKey: tab)
            print("set wager \(Int(value)) for \(tab)")
            viewModel.sideGameSession.banker?.wagers.updateValue(w, forKey: hole)
        } else {
            print("set wager \(Int(value)) for \(tab)")
            viewModel.sideGameSession.banker?.wagers.updateValue([tab: Int(value)], forKey: hole)
            print("hole: \(hole), value: \([tab: Int(value)])")
            print(viewModel.sideGameSession.banker?.wagers[hole])
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
