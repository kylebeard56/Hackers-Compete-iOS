//
//  LandingView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Introspect
import SwiftUI

/// Homepage with Play button
struct LandingView: View {
    @EnvironmentObject var appSession: AppSession

    @State private var animate: Bool = false
    @State private var animateTiles: Bool = false
    
    @State private var navigateToPlayerEntry: Bool = false
    @State private var navigateToHole: Bool = false
    
    @State private var showSessionCodeEntry: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
            }
            .environmentObject(appSession)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $navigateToPlayerEntry, destination: { PlayerEntry() })
            .fullScreenCover(isPresented: $appSession.startRound) { HoleView() }
            .onChange(of: appSession.isReady, perform: { value in
                if value {
                    withAnimation(.easeIn(duration: 0.6)) {
                        animate = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                            withAnimation(.easeIn(duration: 0.6)) {
                                animateTiles = true
                            }
                        })
                    }
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
                Text("Please enter your party's code to join their round.")
            })
        }
    }
    
    private var background: some View {
        ZStack {
            Image(uiImage: Asset.Images.splash.image)
                .resizable()
                .scaledToFill()
                .frame(height: UIScreen.main.bounds.height + 24) // Note: Unsure why but adding 24 works here.
                .clipped()
            Color.black.opacity(animate ? 0.75 : 0.125)
        }
        .edgesIgnoringSafeArea(.vertical)
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            if animate {
                Text("Hackers Golf")
                    .font(.dmSans(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                PillDivider()
                
                Text("The interactive card game to enhance your next round.")
                    .font(.dmSans(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            LandingScroller()
                .padding(.horizontal, -kPadding)
                .padding(.vertical, kPadding * 2)
                .opacity(animateTiles ? 1 : 0)
            
            if animate {
                BigButton(
                    title: appSession.canContinueRound ? "New round" : "Play",
                    labelColor: .black,
                    buttonColor: .white,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: playTapped
                )
                .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
            }
            
            if appSession.canContinueRound {
                BigButton(
                    title: "Continue round",
                    labelColor: .black,
                    buttonColor: .white,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: continueTapped
                )
                .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
            }
            
            if animate {
                BigButton(
                    title: "Join round",
                    labelColor: .black,
                    buttonColor: .white,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: joinTapped
                )
                .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
            }
        }
        .padding(kPadding)
        .padding(.vertical, kPadding * 3)
    }
    
    private func playTapped() {
        print(#function)
        navigateToPlayerEntry = true
        if appSession.canContinueRound {
            appSession.endSession()
        }
    }
    
    private func continueTapped() {
        print(#function)
        Task { await appSession.continueSession() }
    }
    
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
    static var previews: some View {
        Group {
            LandingView()
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro")
            LandingView()
                .previewDevice("iPhone 8")
                .previewDisplayName("iPhone 8")
        }
        .environmentObject(AppSession())
    }
}
