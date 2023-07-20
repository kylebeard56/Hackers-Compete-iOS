//
//  RoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct RoundView: View, WindowPresentable {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var roundSession = RoundSession()
    
    @State private var headerOpacity: CGFloat = 1.0
    @State private var headerOffset: CGFloat = 0.0
    @State private var headerLock: Bool = true
    
    private var kHeaderHeight: CGFloat = 80
    
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
                .animation(.default, value: roundSession.currentHole)
                
                VStack(spacing: 0) {
                    HoleHeaderView()
                        .background(Color.systemViewBackground)
                        .opacity(headerOpacity)
                    Rectangle()
                        .fill(Color.systemViewBackground)
                        .frame(height: 20)
                    HoleTab(showShadow: headerOpacity == 0)
                }
                .padding(.top, 10)
                .offset(y: headerOffset)
                .alignTop()
            }
        }
        .environmentObject(appSession)
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
        /// 1. If direction is none, it was a loading reset and we should then animate header in/out based on animation
        /// and not on the values from scroll (looks jerky otherwise).
        
        if headerLock { return }
        
//        if data.direction == .none {
//            headerLock = true
//        } else {
//            /// 1b. Start timer to show/hide the hole selection footer
////            if data.direction != .none && data.value == 0 { return }
////            roundSession.animateFooter(false)
////            roundSession.scrollChangeCounter += 1
//        }
        
        /// 1. Should the direction be up or down and it hits 0, it could cause a jerky reaction which we want to avoid.
//        if data.direction != .none && data.value == 0 { return }
        
        /// 2. User has scrolled up beyond header so hide it.
        if data.value < 0 {
            if data.value < -kHeaderHeight {
                /// 2a. Animate header out of view if not within window of fancy animation.
                withAnimation(.linear(duration: 0.2)) {
                    headerOpacity = 0
                    headerOffset = -kHeaderHeight
                }
            } else {
                headerOpacity = (1 - abs(data.value) * 1 / kHeaderHeight)
                headerOffset = min(data.value, kHeaderHeight)
            }
        } else {
            withAnimation(.linear(duration: 0.2)) {
                headerOpacity = 1
                headerOffset = 0
            }
        }
    }
}

struct RoundView_Previews: PreviewProvider {
    static var view: some View {
        RoundView()
            .environmentObject(AppSession())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
