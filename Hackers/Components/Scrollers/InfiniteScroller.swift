//
//  InfiniteScroller.swift
//  Hackers
//
//  Created by Kyle Beard on 11/8/22.
//

import SwiftUI

struct InfiniteScroller: View {
    @EnvironmentObject var appSession: AppSession
    
    var width: CGFloat = 162 // <- This was calculated from the geometry reader commented out under the tile.
    var slowness: CGFloat = 15 // <- This is the time that a tile is on screen from edge to edge.
    var stagger: CGFloat = 0
    
    @State private var topTiles: [Rule] = []
    @State private var bottomTiles: [Rule] = []
    @State private var offset: CGFloat = 0
    @State private var a: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !UIScreen.isSmall {
                row(for: topTiles, stagger: 20)
            }
            row(for: bottomTiles, stagger: UIScreen.isSmall ? 75 : 110)
        }
//        .onChange(of: appSession.rules, perform: { _ in buildTiles() })
        .onAppear { buildTiles() }
//        .onTapGesture { buildTiles() }
    }
    
   private func row(for data: [Rule], stagger: CGFloat = 0) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tiles(data)
                tiles(data)
            }
            .offset(x: offset - stagger)
            //.offset(x: a ? -1.0 * CGFloat(topTiles.count) * width - stagger : 0)
            //.animation(Animation.linear(duration: CGFloat(topTiles.count) * slowness).repeat(while: a), value: a)
            //.animation()
            //.offset(x: offset - stagger, y: 0)
        }
        .disabled(true)
        .padding(.vertical, -64)
    }
    
    private func tiles(_ data: [Rule]) -> some View {
        ForEach(data, id: \.self) { rule in
            MarqueeTile(icon: rule.icon, title: rule.name, style: appSession.gameplayPack.style)
        }
        .padding(.vertical, 64)
    }
    
    private func buildTiles() {
        var x = appSession.rules
            .filter({ $0.name.count < 18 && $0.packID == PackName.gameplay.rawValue })
            .reduce(into: [String: Rule]()) { $0[$1.name] = $1 }
            .compactMap({ $0.value })
        
        // Remove last element if odd so we have even split
        if x.count % 2 == 1 {
            x.removeLast()
        }
        
        let tiles = x.partition(into: 2)
        
        topTiles = tiles.first ?? []
        bottomTiles = tiles.last ?? []
//
//        let duration = CGFloat(topTiles.count) * slowness
//        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
//            offset = -1.0 * CGFloat(topTiles.count) * width
//        }
    }
}

extension Animation {
    func `repeat`(while expression: Bool, autoreverses: Bool = true) -> Animation {
        if expression {
            return self.repeatForever(autoreverses: autoreverses)
        } else {
            return self
        }
    }
}
