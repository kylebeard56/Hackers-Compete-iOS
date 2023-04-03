//
//  LandingScroller.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/23.
//

import SwiftUI

struct LandingScroller: View {
    @EnvironmentObject var appSession: AppSession
    
    var invert: Bool = false
    var width: CGFloat = 150
    
    @State private var iconsA: [LandingTileData] = []
    @State private var iconsB: [LandingTileData] = []
    @State private var iconsC: [LandingTileData] = []
    @State private var offset: CGFloat = 0
    @State private var reversedOffset: CGFloat = 0
    @State private var animating: Bool = false
    
    let colors: [Color] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemIndigo//, .systemPink
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                GeometryReader { geom in
                    HStack(spacing: 0) {
                        ForEach(iconsA, id: \.self) { tile in
                            LandingTile(tile: tile, invert: invert)
                        }
                    }
                    .offset(x: reversedOffset, y: 0)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(iconsB, id: \.self) { tile in
                        LandingTile(tile: tile, invert: invert)
                    }
                }
                .offset(x: offset, y: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                GeometryReader { geom in
                    HStack(spacing: 0) {
                        ForEach(iconsC, id: \.self) { tile in
                            LandingTile(tile: tile, invert: invert)
                        }
                    }
                    .offset(x: reversedOffset, y: 0)
                }
            }
        }
        .disabled(true)
        .environmentObject(appSession)
        .onChange(of: appSession.rules, perform: { _ in
            animating = false
            animate()
        })
    }
    
    private func animate() {
        print(#function)
        
        let icons = appSession.rules.compactMap({
            LandingTileData(icon: $0.icon, color: colors.randomElement() ?? .systemGray)
        })
        
        iconsA = icons.shuffled()
        iconsB = icons.shuffled()
        iconsC = icons.shuffled()

        for i in 0..<icons.count {
            if i == 0 { continue } // First
            colorSwap(&iconsA, i: i)
            colorSwap(&iconsB, i: i)
            colorSwap(&iconsC, i: i)
        }
        
        if animating { return }
        animating = true
        
        let count: CGFloat = CGFloat(icons.count)
        let scrollDistance = -1.0 * count * width //-1.0 * count * (width + 16) + UIScreen.main.bounds.width
        let animation: Animation = .linear(duration: count * 4).repeatForever(autoreverses: true)
        
        offset = 0.0
        reversedOffset = scrollDistance
        
        withAnimation(animation) {
            offset = scrollDistance
        }
        
        withAnimation(animation) {
            reversedOffset = 0
        }
    }
    
    private func colorSwap(_ data: inout [LandingTileData], i: Int) {
        if data[i-1].color != data[i].color { return }
        data[i].color = colors.randomElement() ?? .systemGray
        if data[i-1].color == data[i].color {
            colorSwap(&data, i: i)
        }
    }
}

struct LandingScroller_Previews: PreviewProvider {
    static var previews: some View {
        LandingScroller()
    }
}
