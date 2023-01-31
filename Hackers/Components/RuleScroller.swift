//
//  RuleScroller.swift
//  Hackers
//
//  Created by Kyle Beard on 1/30/23.
//

import SwiftUI

struct RuleTile: Hashable {
    var id: String = UUID().uuidString
    var name: String
    var icon: String
    var pColor: Color
    var sColor: Color
    
    static func == (lhs: RuleTile, rhs: RuleTile) -> Bool {
        lhs.id == rhs.id
    }
}

struct RuleScroller: View {
    @EnvironmentObject var appSession: AppSession
    
    @StateObject var viewModel: GameplayViewModel
    
    var width: CGFloat = 225
    var slowness: CGFloat = 0.5
    
    @State private var tiles: [RuleTile] = []
    @State private var offset: CGFloat = 0
    @State private var reversedOffset: CGFloat = 0
    @State private var animating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            row(for: tiles, reversed: true)
            row(for: tiles)
        }
        .onChange(of: viewModel.teamRules, perform: { _ in animate() })
        .onChange(of: viewModel.playerRules, perform: { _ in animate() })
        .onAppear { animate() }
    }
    
    private func row(for data: [RuleTile], reversed: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tiles(data)
            }
            .offset(x: reversed ? reversedOffset : offset, y: 0)
        }
        .disabled(true)
        .padding(.vertical, -64)
    }
    
    private func tiles(_ data: [RuleTile]) -> some View {
        ForEach(data, id: \.self) { tile in
            RuleHintTile(tile: tile)
        }
        .padding(.vertical, 64)
    }
    
    private func animate() {
        print(#function)
        tiles = []

        if let rule = viewModel.getTeamRule() {
            let style = appSession.gameplayPack.style
            let t = RuleTile(name: "Team", icon: rule.icon, pColor: style.primaryColor, sColor: style.secondaryColor)
            tiles.append(t)
        }

        viewModel.players.forEach { p in
            if let rule = viewModel.getPlayerRule(for: p.id) {
                let t = RuleTile(name: p.name, icon: rule.icon, pColor: p.color, sColor: p.color)
                tiles.append(t)
            }
        }
        
        if animating { return }
        animating = true
        
        resetAnimation()
    }
    
    private func resetAnimation() {
        let count: CGFloat = CGFloat(tiles.count)
        let w = -1.0 * count * (width + 16) + UIScreen.main.bounds.width
        reversedOffset = w
        
        withAnimation(.linear(duration: count * 5).repeatForever(autoreverses: true)) {
            offset = w
        }
        
        withAnimation(.linear(duration: count * 5).repeatForever(autoreverses: true)) {
            reversedOffset = 0
        }
    }
}
struct RuleScroller_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RuleScroller(viewModel: GameplayViewModel())
                .environmentObject(AppSession())
                .lightModePreview()
            
            RuleScroller(viewModel: GameplayViewModel())
                .environmentObject(AppSession())
                .darkModePreview()
        }
    }
}
