//
//  HoleTab.swift
//  Hackers
//
//  Created by Kyle Beard on 7/19/23.
//

import SwiftUI

/// If the scroll view snaps to a certain depth.

struct HoleTab: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var showShadow: Bool = false
    
    @State private var proxyLock: Bool = true
    @State private var showHoleList: Bool = false
    private let colors: [Color] = [.clear, .clear, .systemViewBackground]
    
    private var iconHeight: CGFloat {
        roundSession.snapSideGames ? 22 : 0
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme.isLight ? Color.systemGray5 : Color.systemGray5)
                .frame(height: 1)
                .padding(.top, 26 + (roundSession.snapSideGames ? 28 : 0))
            
            HStack(spacing: 0) {
                ZStack {
                    content
                    Rectangle()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(height: 22 + (roundSession.snapSideGames ? 30 : 0))
                        .padding(.bottom, roundSession.snapSideGames ? 6 : 0)
                        .allowsHitTesting(false)
                }
                Button(action: {
                    showHoleList = true
                    Haptics.fire(.light)
                }) {
                    Text("Change")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 15, weight: .bold))
                        .padding(.bottom, 7)
                        .padding(.leading, 20)
                }
            }
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showHoleList) {
            HoleSelectionView()
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    @ViewBuilder private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 0) {
                    ForEach(roundSession.holeRange, id: \.self) { hole in
                        VStack(spacing: 4) {
                            if roundSession.snapSideGames {
                                Group {
                                    if let s = roundSession.sideGameSessions.first(where: { $0.holes.contains(hole) }),
                                       let g = SideGame(rawValue: s.game), !g.icon.isEmpty {
                                        AwesomeImage(
                                            rawIcon: g.icon.unicode,
                                            style: .regular,
                                            size: 17,
                                            color: .systemHackersPurple
                                        )
                                    } else {
                                        Circle()
                                            .stroke(Color.systemGray5, lineWidth: 1.5)
                                            .frame(width: 17, height: 17)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            
                            Button(action: {
                                roundSession.currentHole = hole
                                Haptics.fire(.light)
                            }) {
                                Text("Hole \(hole)")
                                    .font(.dmSans(size: 15, weight: roundSession.currentHole == hole ? .bold : .medium))
                                    .foregroundColor(
                                        roundSession.currentHole == hole ? Color.systemBlack : Color.systemGray
                                    )
                            }
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.systemHackersGreen)
                                .frame(height: 3)
                                .opacity(roundSession.currentHole == hole ? 1 : 0)
                        }
                        .padding(.leading, 20)
                        .tag(hole)
                    }
                    
                    Spacer(minLength: UIScreen.main.bounds.width - 164)
                }
                .onAppear() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                        self.proxyLock = false
                    })
                }
                .onReceive(roundSession.$currentHole, perform: { hole in
                    if proxyLock { return }
                    scroll(proxy: proxy, to: hole)
                })
            }
        }
        .environmentObject(roundSession)
    }
    
    private func scroll(proxy: ScrollViewProxy, to hole: Int) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(hole, anchor: .leading)
        }
    }
}

struct HoleTab_Preview: PreviewProvider {
    static var previews: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    HoleTab(showShadow: false)
                        .opacity(0)
                    Spacer(minLength: 20)
                    ForEach(0...100, id: \.self) { _ in
                        Text("lorem ipsum dolor fuck me in the butt right now")
                            .alignCenter()
                    }
                }
            }
            .background(Color.systemViewBackground)
            
            HoleTab(showShadow: true)
                .alignTop()
        }
        .environmentObject(RoundSession())
        .holisticPreview()
    }
}
