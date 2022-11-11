//
//  InfiniteScroller.swift
//  Hackers
//
//  Created by Kyle Beard on 11/8/22.
//

import SwiftUI

struct InfiniteScroller<Content: View>: View {
    var contentWidth: CGFloat
    var speed: CGFloat = 30
    var stagger: CGFloat = 0
    var content: (() -> Content)
    
    @State private var xOffset: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                content()
                content()
            }
            .offset(x: xOffset - stagger, y: 0)
        }
        .disabled(true)
        .onAppear {
            withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                xOffset = -contentWidth
            }
        }
    }
}

struct InfiniteScroller_Previews: PreviewProvider {
    static let tile = MarqueeTile(
        icon: .golfFlagHole,
        title: "Longest Yard",
        colors: (Color.systemPink.opacity(0.6), Color.systemYellow.opacity(0.6))
    )
    
    static var previews: some View {
        Group {
            VStack(spacing: 0) {
                InfiniteScroller(contentWidth: UIScreen.main.bounds.width) {
                    Group {
                        tile
                        tile
                        tile
                        tile
                    }
                }
                InfiniteScroller(contentWidth: UIScreen.main.bounds.width, stagger: 70) {
                    Group {
                        tile
                        tile
                        tile
                        tile
                    }
                }
            }
            .background(Color.secondarySystemBackground)
            .lightModePreview()
            
            VStack(spacing: 0) {
                InfiniteScroller(contentWidth: UIScreen.main.bounds.width) {
                    Group {
                        tile
                        tile
                        tile
                        tile
                    }
                }
                InfiniteScroller(contentWidth: UIScreen.main.bounds.width, stagger: 70) {
                    Group {
                        tile
                        tile
                        tile
                        tile
                    }
                }
            }
            .darkModePreview()
        }
    }
}
