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
    
    /// Slide logo from middle to top of view
    @State private var slide: Bool = false
    
    /// Animate CTA buttons into view
    @State private var animate: Bool = false
    
    var body: some View {
        ZStack {
            background
            content
                .alignBottom()
        }
        .ignoresSafeArea(.keyboard)
        .environmentObject(appSession)
        .onChange(of: appSession.isReady, perform: { value in
            if value {
                animateView()
            }
        })
        .sheet(isPresented: $appSession.showJoinWithCode) {
            JoinWithCodeView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appSession.showContinueRound) {
            ContinueRoundView()
                .presentationDetents([.height(CGFloat(appSession.currentSessions.count * 90) + 300.0), .large])
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
    }
    
    private var background: some View {
        ZStack {
            Group {
                if Date.now.isDawn {
                    Image(uiImage: Asset.Images.splashDawn.image)
                        .interpolation(.high)
                        .resizable()
                } else if Date.now.isDay {
                    Image(uiImage: Asset.Images.splashDay.image)
                        .interpolation(.high)
                        .resizable()
                } else if Date.now.isDusk {
                    Image(uiImage: Asset.Images.splashDusk.image)
                        .interpolation(.high)
                        .resizable()
                } else if Date.now.isNight {
                    Image(uiImage: Asset.Images.splashNight.image)
                        .interpolation(.high)
                        .resizable()
                } else {
                    Color.black.ignoresSafeArea(edges: .all)
                }
            }
            .ignoresSafeArea(edges: .all)
            .scaledToFill()
            .frame(maxWidth: UIScreen.main.bounds.width - 40)

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
            
            BigButton(
                title: "Join with code",
                labelColor: .white,
                buttonColor: .systemHackersGreen,
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
            .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 0)
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
        })
    }
    
    // MARK: - Button Actions
    
    private func playTapped() {
        print(#function)
        appSession.goToRoundSetup()
    }
    
    private func continueRoundTapped() {
        print(#function)
        appSession.showContinueRound = true
    }
    
    private func joinTapped() {
        print(#function)
        appSession.showJoinWithCode = true
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
