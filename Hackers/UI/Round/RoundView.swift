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
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TabView(selection: $roundSession.currentHole) {
                    ForEach(roundSession.holeRange, id: \.self) { i in
                        HoleView(hole: i)
                            .onScroll { value in
                                if value < 0 {
                                    headerOpacity = (1.0 - abs(value) * 1 / 44)
                                    headerOffset = value
                                } else {
                                    withAnimation(.linear(duration: 0.2)) {
                                        headerOpacity = 1.0
                                        headerOffset = 0.0
                                    }
                                }
                            }
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                HoleHeaderView()
                    .padding(.top, 10)
                    .offset(y: headerOffset)
                    .opacity(headerOpacity)
                    .alignTop()
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
        .onChange(of: roundSession.currentHole, perform: { _ in
            Haptics.fire(.light)
            withAnimation(.linear(duration: 0.2)) {
                headerOpacity = 1.0
                headerOffset = 0.0
            }
            // TODO: Scroll proxy to top here?
        })
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
