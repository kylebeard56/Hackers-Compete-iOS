//
//  LandingScroller.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/23.
//

import SwiftUI

struct IconScroller: View {
    @State private var offset: CGFloat = 0
    @State private var reversedOffset: CGFloat = 0
    @State private var animating: Bool = false
    
    @State private var iconsA: [String] = []
    @State private var iconsB: [String] = []
    @State private var iconsC: [String] = []
    
    private let icons: [String] = ["f450" + "f451"] + SideGame.allCases.compactMap({ $0.icon })
    private let width: CGFloat = 150
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(iconsA, id: \.self) { icon in
                        tile(for: icon)
                    }
                }
                .offset(x: offset, y: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(iconsB, id: \.self) { icon in
                        tile(for: icon)
                    }
                }
                .offset(x: reversedOffset, y: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(iconsC, id: \.self) { icon in
                        tile(for: icon)
                    }
                }
                .offset(x: offset, y: 0)
            }
        }
        .onAppear() { animate() }
        .disabled(true)
    }
    
    private func animate() {
        print(#function)
        
        iconsA = icons.shuffled()
        iconsB = icons.shuffled()
        iconsC = icons.shuffled()
        
        if animating { return }
        animating = true
        
        let count: CGFloat = CGFloat(icons.count)
        let scrollDistance = -1.0 * count * width
        let animation: Animation = .linear(duration: count * 6).repeatForever(autoreverses: true)
        
        offset = 0.0
        reversedOffset = scrollDistance + UIScreen.main.bounds.width / 2
        
        withAnimation(animation) {
            offset = scrollDistance + UIScreen.main.bounds.width / 2
        }
        
        withAnimation(animation) {
            reversedOffset = 0
        }
    }
    
    @ViewBuilder private func tile(for icon: String) -> some View {
        AwesomeImage(
            rawIcon: icon.unicode ?? "\u{f451}",
            style: .regular,
            size: UIScreen.isSmall ? 32 : 40,
            color: .white
        )
        .alignCenter()
        .alignMiddle()
        .padding()
        .frame(width: width)
        .frame(maxHeight: width)
        .background(Color.white.opacity(0.125))
        .border(Color.white, width: 6, cornerRadius: 16)
        .cornerRadius(16)
        .padding(10)
    }
}

struct IconScroller_Previews: PreviewProvider {
    static var previews: some View {
        IconScroller()
    }
}
