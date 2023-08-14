//
//  SliderTile.swift
//  Hackers
//
//  Created by Kyle Beard on 8/14/23.
//

import SwiftUI

struct SliderTile: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    var player: Player

    @State private var value: CGFloat = 10
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(player.name)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(player.color.value)
                
                Spacer(minLength: 0)
                
                Text("\(Int(value))")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(player.color.value)
                    .frame(width: 48, height: 40)
                    .background(player.color.value.opacity(colorScheme.translucent))
                    .cornerRadius(8)
            }
            
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
                Haptics.fire(.light)
                isEditing = editing
                setWager()
            }
            .tint(player.color.value)
            .onChange(of: value, perform: { _ in Haptics.fire(.light) })
        }
        .onAppear() {
            if let w = viewModel.sideGameSession.banker?.wagers[hole] {
                value = CGFloat(w[player.id] ?? 10)
            } else {
                value = 10
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func setWager() {
        if let wagers = viewModel.sideGameSession.banker?.wagers[hole] {
            var w = wagers
            w.updateValue(Int(value), forKey: player.id)
            viewModel.sideGameSession.banker?.wagers.updateValue(w, forKey: hole)
        } else {
            viewModel.sideGameSession.banker?.wagers.updateValue([player.id: Int(value)], forKey: hole)
        }
    }
}
