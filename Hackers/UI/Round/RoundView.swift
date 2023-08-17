//
//  RoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct RoundView: View, WindowPresentable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    
    @StateObject var roundSession = RoundSession()
    
    @State private var headerOpacity: CGFloat = 1.0
    @State private var headerLock: Bool = true
    
    @State private var didReturnToZero: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TabView(selection: $roundSession.currentHole) {
                    ForEach(roundSession.holeRange, id: \.self) { i in
                        HoleView(hole: i)
                            .onScroll { v in setScrollOffset(for: v) }
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeOut(duration: 0.2), value: roundSession.currentHole)
                
                VStack(spacing: 0) {
                    Color.systemViewBackground.frame(height: 10)
                    VStack(spacing: 20) {
                        HoleHeaderView()
                            .opacity(headerOpacity)
                        HoleTab()
                    }
                    .background(Color.systemViewBackground)
                    
                    LinearGradient(colors: [.systemBlack, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 8)
                        .opacity(headerOpacity == 0 && colorScheme.isLight ? 0.03 : 0.00)
                }
                .offset(y: roundSession.headerOffset)
                .alignTop()
            }
        }
        .environmentObject(appSession)
        .environmentObject(purchaseStore)
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear() {
            roundSession.players = appSession.players.filter({ $0.isPlaying })
            if let s = appSession.session {
                roundSession.loadSession(s)
            }
            deviceDefaults.roundsPlayedCount += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                self.headerLock = false
            })
        }
        .onChange(of: roundSession.currentHole, perform: { _ in Haptics.fire(.light) })
        .onChange(of: roundSession.session, perform: { s in
            appSession.session = s
            appSession.sessionCode = s?.partyCode ?? roundSession.partyCode
        })
        .onReceive(HackersNotification.sessionUpdated.publisher(), perform: { data in
            if let session = data.object as? Session {
                /// Load session by data
                roundSession.loadSession(session)
            } else {
                /// Load session by cached ID since the publisher didn't provide right data.
                Task(operation: roundSession.fetchSession)
            }
        })
    }
    
    private func setScrollOffset(for data: ScrollData) {
        /// 1. This lock is timed by 600ms when view first loads to prevent weird bouncing as components appear.
        if headerLock { return }
        
        var scroll = data.value

        /// 2. Scroll is 0, but offset isn't -> hole changed and we want to keep header hidden and hole scroller sticky up top.
//        if scroll == 0 && roundSession.headerOffset < 0 {
//            roundSession.scrollBiasApplied = true
//            return
//        }
//
//        /// 3a. Introduce header offset bias based on whether the user changed holes with the header transparent.
//        if roundSession.scrollBiasApplied {
//            scroll -= kHeaderHeight
//        }
//
//        /// 3b. We've scrolled beyond the biased value so remove.
//        if scroll >= 0 {
//            roundSession.scrollBiasApplied = false
//            roundSession.bias = 0
//        }
//
//        if roundSession.scrollBiasApplied && data.value < kHeaderHeight {
//            roundSession.bias = max(min(data.value, kHeaderHeight), 0)
//        }
        
        /// 4. Used to track snap action for showing side game icon above hole number.
        if scroll <= 30 {
            didReturnToZero = true
        }
        
        /// 5. Value is negative, user is scrolling up.
        if scroll <= 0 {
            /// 5a. Value is beyond the header height -> guardrail
            if scroll < -kHeaderHeight {
                withAnimation(.linear(duration: 0.2)) {
                    headerOpacity = 0
                    roundSession.headerOffset = -kHeaderHeight
                }
            /// 5b. User is scrolling up but header is still visible -> apply transient translucent offset/opacity effect.
            } else {
                headerOpacity = (1 - abs(scroll) * 1 / kHeaderHeight)
                roundSession.headerOffset = min(scroll, kHeaderHeight)
            }
        /// 6. Value is either zero or positive -> animate header back into view
        } else {
            withAnimation(.linear(duration: 0.4)) {
                headerOpacity = 1
                roundSession.headerOffset = 0
            }
            
            /// 6a. User pulled down almost to pull-to-refresh -> toggle hole scroller snap to show/hide side game icons.
            if scroll > 90 && didReturnToZero {
                didReturnToZero = false
                withAnimation(.linear(duration: 0.2)) {
                    roundSession.snapSideGames.toggle()
                }
                Haptics.fire(.medium)
            }
        }
    }
}

struct RoundView_Previews: PreviewProvider {
    static var previews: some View {
        RoundView()
            .environmentObject(AppSession())
            .holisticPreview()
    }
}
