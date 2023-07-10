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
    
    @StateObject var viewModel = RoundViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HoleHeaderView(viewModel: viewModel)
                .padding(.top, 10)
            
            TabView(selection: $viewModel.currentHole) {
                ForEach(viewModel.holeRange, id: \.self) { i in
                    HoleView(roundViewModel: viewModel, hole: i)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            HoleFooterView(viewModel: viewModel)
//                .padding(.top, 10)
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        /// ON APPEAR
        .onAppear() {
            viewModel.players = appSession.players.filter({ $0.isPlaying })
            if let s = appSession.session {
                viewModel.loadSession(s)
            }
            deviceDefaults.roundsPlayedCount += 1
        }
        /// ON CHANGE OR RECEIVE
        .onChange(of: viewModel.currentHole, perform: { h in
            Haptics.fire(.light)
        })
        .onChange(of: viewModel.session, perform: { s in
            appSession.session = s
            appSession.sessionCode = s?.partyCode ?? viewModel.partyCode
        })
        .onReceive(HackersNotification.sessionUpdated.publisher(), perform: { data in
            if let session = data.object as? Session {
                /// Load session by data
                viewModel.loadSession(session)
            } else {
                /// Load session by cached ID since the publisher didn't provide right data.
                Task(operation: viewModel.fetchSession)
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
