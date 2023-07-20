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
    
    private var kHeaderHeight: CGFloat = 64
    
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
        if headerLock { return }
        
        let h: CGFloat = 69
        
        if data.value < 0 {
            if data.value < -kHeaderHeight {
                withAnimation(.linear(duration: 0.2)) {
                    print("~animate out \(data.value)")
                    headerOpacity = 0
                    headerOffset = -kHeaderHeight
                }
            } else {
                print("~animate drag \(data.value)")
                headerOpacity = (1 - abs(data.value) * 1 / kHeaderHeight)
                headerOffset = min(data.value, kHeaderHeight)
            }
        } else {
            withAnimation(.linear(duration: 0.2)) {
                print("~animate in \(data.value)")
                headerOpacity = 1
                headerOffset = 0
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
