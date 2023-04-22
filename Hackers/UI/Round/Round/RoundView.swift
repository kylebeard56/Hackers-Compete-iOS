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
    @State private var roundEndedShown: Bool = false
    
    @State private var showMenu: Bool = false
    @State private var showHoleDetails: Bool = false
    @State private var showHoleList: Bool = false
    @State private var showWelcome: Bool = false
    @State private var showMenuButton: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(uiImage: Asset.Images.logoGreen.image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                
                Spacer(minLength: 0)
                
                Button(action: {
                    showHoleList = true
                    FirebaseEvent.menuTapped.log()
                    Haptics.fire(.light)
                }) {
                    Text("Hole \(viewModel.currentHole)")
                        .font(.dmSans(size: 20, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showMenu = true
                    FirebaseEvent.menuTapped.log()
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(rawIcon: "f0c9".unicode, style: .regular, size: 20, color: .systemBlack)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            
            VTabView(selection: $viewModel.currentHole) {
                ForEach(1..<19) { i in
                    HoleView(viewModel: viewModel, hole: i)
                        .onScroll { v in
                            showMenuButton = v >= 0.0
                        }
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
            appSession.activePack = 0
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
        /// SHEETS
        .sheet(isPresented: $showMenu) {
            MenuView(onPartyCode: {
                code in viewModel.sessionCode = code
            }, onEnd: {
                showMenu = false
                Task(operation: appSession.endRound)
            })
            .presentationDetents([.height(adminMode ? 500 : 410)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHoleList) {
            HoleListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHoleDetails) {
            HoleDetailView(
                details: appSession.holes[holeNumber - 1].details,
                hole: holeNumber,
                onSave: { d in appSession.holes[holeNumber - 1].details = d }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWelcome, onDismiss: {
            deviceDefaults.welcomeTourTaken = true
        }) {
            GuidedTourView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }
    
    private var menuGradientOverlay: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.systemViewBackground],
                        startPoint: .leading,
                        endPoint: .trailing)
                )
                .frame(width: 64, height: 16 + 36)
            
            Button(action: {
                showMenu = true
                FirebaseEvent.menuTapped.log()
                Haptics.fire(.light)
            }) {
                AwesomeImage(icon: .menuBars, style: .solid, size: 24, color: Color.systemBlack)
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.systemViewBackground)
        }
        .alignTop()
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
