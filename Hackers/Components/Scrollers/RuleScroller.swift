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
    
    @StateObject var viewModel: RoundViewModel
    
    var width: CGFloat = 225
    var slowness: CGFloat = 0.5
    
    @State private var tiles: [RuleTile] = []
    @State private var offset: CGFloat = 0
    @State private var reversedOffset: CGFloat = 0
    @State private var animating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                GeometryReader { geom in
                    HStack(spacing: 0) {
                        ForEach(tiles, id: \.self) { tile in
                            RuleHintTile(tile: tile)
                        }
                    }
                    .offset(x: reversedOffset, y: 0)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tiles, id: \.self) { tile in
                        RuleHintTile(tile: tile)
                    }
                }
                .offset(x: offset, y: 0)
            }
        }
        .disabled(true)
        .onChange(of: viewModel.currentHole, perform: { _ in
            print("current hole updated")
            animating = false
            animate()
        })
        .onChange(of: viewModel.teamRules, perform: { _ in
            print("team rule updated")
            animating = false
            animate()
        })
        .onChange(of: viewModel.playerRules, perform: { _ in
            print("player rules updated")
            animating = false
            animate()
        })
        .onAppear {
            print("onAppear")
            animate()
        }
    }
    
    private func animate() {
        print(#function)
        updateTiles()
        
        if animating { return }
        animating = true
        
        startAnimation()
    }
    
    private func updateTiles() {
        tiles = []
       
        if let rule = viewModel.getTeamRule() {
            let style = appSession.gameplayPack.style
            let t = RuleTile(name: "Team", icon: rule.icon, pColor: style.primaryColor, sColor: style.secondaryColor)
            tiles.append(t)
        }

        viewModel.players.forEach { p in
            if let rule = viewModel.getPlayerRule(for: p.id) {
                let t = RuleTile(name: p.name, icon: rule.icon, pColor: p.color.value, sColor: p.color.value)
                tiles.append(t)
            }
        }
    }
    
    private func startAnimation() {
        print(#function)
        let count: CGFloat = CGFloat(tiles.count)
        let scrollDistance = -1.0 * count * (width + 16) + UIScreen.main.bounds.width
        let animation: Animation = .linear(duration: count * 5).repeatForever(autoreverses: true)
        
        print("offset: \(offset), reversed: \(reversedOffset), distance: \(scrollDistance))")
        
        offset = 0
        withAnimation(animation) {
            offset = scrollDistance
        }
        
        reversedOffset = scrollDistance
        withAnimation(animation) {
            reversedOffset = 0
        }
    }
}
struct RuleScroller_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RuleScroller(viewModel: RoundViewModel())
                .environmentObject(AppSession())
                .lightModePreview()
            
            RuleScroller(viewModel: RoundViewModel())
                .environmentObject(AppSession())
                .darkModePreview()
        }
    }
}
