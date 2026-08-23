//
//  SpectatorHoleTab.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import SwiftUI

struct SpectatorHoleTab: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel: SpectateViewModel
    
    @State private var proxyLock: Bool = true
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.systemGray5)
                .frame(height: 1)
                .padding(.top, 22)
            
            content
        }
    }
    
    private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 0) {
                    ForEach(viewModel.holeRange, id: \.self) { hole in
                        VStack(spacing: 4) {
                            Button(action: {
                                viewModel.currentHole = hole
                                Haptics.fire(.light)
                            }) {
                                Text("Hole \(hole)")
                                    .font(.dmSans, size: 15, weight: viewModel.currentHole == hole ? .bold : .medium)
                                    .foregroundColor(
                                        viewModel.currentHole == hole ? Color.systemBlack : Color.systemGray3
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.systemHackersGreen)
                                .frame(height: 3)
                                .opacity(viewModel.currentHole == hole ? 1 : 0)
                        }
                        .padding(.leading, 20)
                        .tag(hole)
                    }
                    
                    Spacer(minLength: 20)
                }
                .onAppear() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                        self.proxyLock = false
                    })
                }
                .onReceive(viewModel.$currentHole, perform: { hole in
                    if proxyLock { return }
                    scroll(proxy: proxy, to: hole)
                })
            }
        }
    }
    
    private func scroll(proxy: ScrollViewProxy, to hole: Int) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(hole, anchor: .leading)
        }
    }
}
