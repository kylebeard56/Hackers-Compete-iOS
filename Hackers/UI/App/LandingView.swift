//
//  LandingView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import AlertToast
import Introspect
import SwiftUI

/// Homepage with Play button
struct LandingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    @State private var slide: Bool = false
    @State private var animate: Bool = false
    @State private var animateTiles: Bool = false
    
    @State private var showJoinWithCode: Bool = false
    
//    @State private var showNewRoundWarning: Bool = false
//    @State private var showJoinRoundWarning: Bool = false
    
//    @State private var navigateToPlayerEntry: Bool = false
//    @State private var navigateToHole: Bool = false
//
//    @State private var showSessionCodeEntry: Bool = false
    
    var body: some View {
        NavigationStack(path: $appSession.path) {
            ZStack {
                background
                content
            }
            .ignoresSafeArea(.keyboard)
            .environmentObject(appSession)
            .onChange(of: appSession.isReady, perform: { value in
                if value {
                    animateView()
                }
            })
            // TODO: We're going to allow user to save multiple rounds
//            .alert("Join round", isPresented: $showSessionCodeEntry, actions: {
//                TextField("Enter party code", text: $appSession.sessionCode)
//                    .font(.dmSans(size: 20, weight: .regular))
//                    .keyboardType(.alphabet)
//                    .disableAutocorrection(true)
//                    .textInputAutocapitalization(.none)
//                    .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
//                Button("Join", action: checkPartyCode)
//                Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
//            }, message: {
//                Text("Sync up with your party from your own device.")
//            })
//            .alert("End current round?", isPresented: $showNewRoundWarning, actions: {
//                Button("Continue", action: {
//                    proceedToNewRound()
//                })
//                Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
//            }, message: {
//                Text("To play a new round, your current round will marked as ended. Would you like to continue?")
//            })
//            .alert("End current round?", isPresented: $showJoinRoundWarning, actions: {
//                Button("Continue", action: {
//                    Task { await appSession.fetchSessionFromPartyCode() }
//                })
//                Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
//            }, message: {
//                Text("To join another round, your current round will marked as ended. Would you like to continue?")
//            })
        }
//        .toast(isPresenting: $appSession.showSessionCodeToast, offsetY: 0) {
//            AlertToast.messageHUD("Party code not found")
//        }
        .fullScreenCover(isPresented: $showJoinWithCode) {
            JoinWithCodeView()
//                .presentationDetents([.large])
//                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appSession.showTerms) {
            TermsView(onAccept: {
                deviceDefaults.acceptedTerms = true
                appSession.showTerms = false
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
    }
    
    private var background: some View {
        ZStack {
            Color.systemHackersGreen
                .edgesIgnoringSafeArea(.vertical)
            
            VStack {
                if !slide {
                    Spacer(minLength: 0)
                }
                
                logo
                
                if !appSession.isReady {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                
                Spacer(minLength: 0)
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            logo
                .opacity(0)

            IconScroller()
                .padding(.vertical, UIScreen.isSmall ? 0 : 40)
                .opacity(animate ? 1 : 0)
            
            BigButton(
                title: "Join with code",
                labelColor: .white,
                buttonColor: .black,
                isDisabled: .false,
                isLoading: .false,
                onTap: joinTapped
            )
            .opacity(animate ? 1 : 0)
            .padding(.horizontal, 20)
            
            if !appSession.currentSessions.isEmpty {
                BigButton(
                    title: "Continue round",
                    subtitle: "",
                    labelColor: .black,
                    subtitleColor: .black,
                    buttonColor: .systemYellow,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: continueRoundTapped
                )
                .opacity(animate ? 1 : 0)
                .padding(.horizontal, 20)
            }
            
            BigButton(
                title: "Play now",
                labelColor: .black,
                buttonColor: .white,
                isDisabled: .false,
                isLoading: .false,
                onTap: playTapped
            )
            .opacity(animate ? 1 : 0)
            .padding(.horizontal, 20)
        }
    }
    
    private var logo: some View {
        Image(uiImage: Asset.Images.logoWhite.image)
            .interpolation(.high)
            .resizable()
            .scaledToFit()
            .clipped()
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }
    
    private func animateView() {
        Haptics.fire(.success)
        withAnimation(.linear(duration: 0.2)) {
            slide = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
            withAnimation(.easeIn(duration: 0.6)) {
                animate = true
            }
            withAnimation(.easeIn(duration: 1.0)) {
                animateTiles = true
            }
        })
    }
    
    // MARK: - Button Actions
    
    private func playTapped() {
        print(#function)
        appSession.goToRoundSetup()
    }
    
    private func continueRoundTapped() {
        print(#function)
        if let s = appSession.currentSessions.first, appSession.currentSessions.count == 1 {
            appSession.startRound(for: s)
        } else {
            print("todo: show half sheet for various current sessions")
        }
    }
    
    private func joinTapped() {
        print(#function)
        self.showJoinWithCode = true
    }
}

struct LandingView_Previews: PreviewProvider {
    static var view: some View {
        LandingView()
            .environmentObject(AppSession())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
