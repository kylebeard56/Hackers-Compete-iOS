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
    @State private var showContinueRound: Bool = false
    
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
        }
        .sheet(isPresented: $showJoinWithCode) {
            JoinWithCodeView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showContinueRound) {
            ContinueRoundView()
                .presentationDetents([.height(appSession.continueRoundHeight), .large])
                .presentationDragIndicator(.visible)
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
        .onDisappear() {
            showJoinWithCode = false
            showContinueRound = false
        }
    }
    
    private var background: some View {
        ZStack {
            Color.systemHackersGreen.edgesIgnoringSafeArea(.vertical)
            
            VStack(spacing: 20) {
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
                .alignMiddle()
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
        self.showContinueRound = true
//        if let s = appSession.currentSessions.first, appSession.currentSessions.count == 1 {
//            appSession.startRound(for: s)
//        } else {
//            self.showContinueRound = true
//        }
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
