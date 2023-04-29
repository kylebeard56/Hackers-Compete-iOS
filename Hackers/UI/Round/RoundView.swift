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
    
    @State private var holeNumber: Int = 1
    @State private var scrollOffset: CGFloat = 0
    
    @State private var showWelcome: Bool = false
    @State private var roundEndedShown: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            HoleHeaderView(viewModel: viewModel)
            
            TabView(selection: $viewModel.currentHole) {
                ForEach(1..<19) { i in
                    HoleView(viewModel: viewModel, hole: i)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        /// ON APPEAR
        .onAppear() {
            appSession.gameTab = 0
            viewModel.players = appSession.players.filter({ $0.isPlaying })
            viewModel.reload(for: appSession.rules.filter({ $0.packID == PackName.gameplay.rawValue }))
            if let s = appSession.session {
                viewModel.loadSession(s)
            }
            showWelcome = !deviceDefaults.welcomeTourTaken
        }
        /// ON CHANGE OR RECEIVE
        .onChange(of: viewModel.currentHole, perform: { h in
            Haptics.fire(.light)
            self.holeNumber = h
        })
        .onChange(of: viewModel.session, perform: { s in
            appSession.session = s
            appSession.sessionCode = s?.code ?? viewModel.sessionCode
        })
        .onReceive(appSession.$rules, perform: { rules in
            viewModel.reload(for: rules.filter({ $0.packID == PackName.gameplay.rawValue }))
        })
        .onReceive(HackersNotification.sessionUpdated.publisher(), perform: { data in
            if let session = data.object as? Session {
                print("session update received in round, ended: \(session.ended)")
                if session.ended && !roundEndedShown {
                    print("presenting round ended for ID: [\(session.id)]")
                    roundEndedShown = true
                    Haptics.fire(.warning)
                    FirebaseEvent.roundCompleteShown.log()
                    presentOnWindow {
                        RoundCompleteView().environmentObject(appSession)
                    }
                }
                viewModel.loadSession(session)
            } else {
                print("session update detected")
                Task(operation: viewModel.fetchSession)
            }
        })
        .sheet(isPresented: $showWelcome, onDismiss: {
            deviceDefaults.welcomeTourTaken = true
        }) {
            GuidedTourView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
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
