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
    
    @State private var showNewRoundWarning: Bool = false
    
    @State private var navigateToPlayerEntry: Bool = false
    @State private var navigateToHole: Bool = false
    
    @State private var showSessionCodeEntry: Bool = false
    
    var body: some View {
        NavigationStack(path: $appSession.path) {
            ZStack {
                background
                content
            }
            .environmentObject(appSession)
            .onChange(of: appSession.isReady, perform: { value in
                if value {
                    animateView()
                }
            })
            .alert("Join round", isPresented: $showSessionCodeEntry, actions: {
                TextField("Enter party code", text: $appSession.sessionCode)
                    .font(.dmSans(size: 20, weight: .regular))
                    .keyboardType(.alphabet)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.none)
                    .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                Button("Join", action: checkPartyCode)
                Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
            }, message: {
                Text("Sync up with your party from your own device.")
            })
            .alert("End current round?", isPresented: $showNewRoundWarning, actions: {
                Button("Continue", action: {
                    FirebaseEvent.existingRoundedEndedForNewRound.log()
                    proceedToNewRound()
                })
                Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
            }, message: {
                Text("To play a new round, your current round will marked as ended. Would you like to continue?")
            })
        }
        .toast(isPresenting: $appSession.showSessionCodeToast, offsetY: 0) {
            AlertToast.messageHUD("Party code not found")
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
            Color.hackersGreen
                .edgesIgnoringSafeArea(.vertical)

            VStack {
                if !slide {
                    Spacer()
                }
                
                Image(uiImage: Asset.Images.logoWhite.image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: slide ? 72 : 108)
                    .clipped()
                    .padding(16)
                
                if !animate {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }

                Spacer()
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            Spacer()
                .frame(height: 72)
            
            VStack(spacing: 2) {
                Text("The amusing card game designed to")
                Text("enhance your party's next round.").bold()
            }
            .font(.dmSans(size: 20, weight: .regular))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .opacity(animate ? 1 : 0)
            
            LandingScroller(invert: true)
                .padding(.horizontal, -kPadding)
                .opacity(animateTiles ? 1 : 0)
            
            if appSession.canContinueRound {
                BigButton(
                    title: "Continue round\(appSession.continueSubtitle)",
                    labelColor: .black,
                    buttonColor: .systemYellow,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: continueTapped
                )
                .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
                .opacity(animate ? 1 : 0)
            }
            
            BigButton(
                title: "Join round",
                labelColor: .white,
                buttonColor: .black,
                isDisabled: .false,
                isLoading: .false,
                onTap: joinTapped
            )
            .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
            .opacity(animate ? 1 : 0)
            
            BigButton(
                title: appSession.canContinueRound ? "New round" : "Play",
                labelColor: .black,
                buttonColor: .white,
                isDisabled: .false,
                isLoading: .false,
                onTap: playTapped
            )
            .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
            .opacity(animate ? 1 : 0)
        }
        .padding(kPadding)
//        .padding(.vertical, kPadding * 3)
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
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
//            withAnimation(.easeIn(duration: 0.6)) {
//                animateTiles = true
//            }
//        })
    }
    
    // MARK: - Play New Round
    
    private func playTapped() {
        print(#function)
        if appSession.canContinueRound {
            Haptics.fire(.light)
            showNewRoundWarning = true
        } else {
            proceedToNewRound()
        }
    }
    
    private func proceedToNewRound() {
        print(#function)
        appSession.goToPlayers()
        if appSession.canContinueRound {
            appSession.endSession()
        }
    }
    
    // MARK: - Continue
    
    private func continueTapped() {
        print(#function)
        Task { await appSession.continueSession() }
    }
    
    // MARK: - Join Party
    
    private func joinTapped() {
        print(#function)
        showSessionCodeEntry = true
    }
    
    private func checkPartyCode() {
        print(#function)
        Haptics.fire(.light)
        Task { await appSession.fetchSessionFromPartyCode() }
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
