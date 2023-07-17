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
    @State private var headerLock: Bool = false
    
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
                
                HoleHeaderView()
                    .padding(.top, 10)
                    .background(Color.systemViewBackground)
                    .offset(y: headerOffset)
                    .opacity(headerOpacity)
                    .alignTop()
                
//                HoleFooterView()
//                    .background(Color.systemViewBackground)
//                    .offset(y: roundSession.showFooter ? 0 : 120)
//                    .alignBottom()
            }
            
            HoleFooterView()
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
        if data.direction == .none {
            headerLock = true
        } else {
            /// 1b. Start timer to show/hide the hole selection footer
            if data.value == 0 { return }
//            roundSession.animateFooter(false)
//            roundSession.scrollChangeCounter += 1
        }
        
        /// 2. User has scrolled up beyond header so hide it.
        if data.value < 0 {
            if headerLock && data.value < -44 {
                /// 2a. Animate header out of view if not within window of fancy animation.
                withAnimation(.linear(duration: 0.2)) {
                    headerOpacity = 0
                    headerOffset = -44
                }
            } else {
                headerOpacity = (1 - abs(data.value) * 1 / 44)
                headerOffset = min(data.value, 44)
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
