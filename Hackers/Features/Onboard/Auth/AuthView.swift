//
//  AuthView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/25.
//

import AlertToast
import Foundation
import SwiftUI

struct AuthView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var showLegalSheet = false
    @State private var showFindRound = false
    @State private var isLoading = false
    @State private var didPreviouslyLoad = false
    @State private var showAuthErrorToast = false
    
    private let animation: Animation = .linear(duration: 0.2)
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            
            Text("Welcome to".uppercased())
                .fontStyle(size: 22, weight: .bold)
                .foregroundStyle(Color.foregroundPrimary)
                .opacity(appSession.isLoading ? 0 : 1)
            
            Logo()
                .frame(width: UIScreen.main.bounds.width * (appSession.isLoading ? 0.9 : 0.69))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
            
            Spacer(minLength: 0)
            
            if !appSession.isLoading {
                signInWithGoogle
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
                
                signInWithApple
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
        
                joinWithCode
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)

                Spacer(minLength: 0).frame(height: 32)
                
                LegalFootnote()
            }
        }
        .padding(16)
        .background(GolfTopology())
        .navigationBarBackButtonHidden(true)
        .animation(animation, value: appSession.isLoading)
        .sheet(isPresented: $showFindRound) {
            FindRoundView(onJoin: {
                showFindRound = false
                appSession.routeTo(.lobby)
            })
            .environmentObject(appSession)
            .environmentObject(roundSession)
            .presentationDragIndicator(.visible)
        }
        .onReceive(HackersNotification.joinRoundFromDeepLink.publisher()) { _ in
            showFindRound = true
        }
        .onReceive(appSession.$isLoading, perform: { value in
            if value {
                if !self.didPreviouslyLoad {
                    self.isLoading = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.isLoading = false
                    self.didPreviouslyLoad = true
                }
            }
        })
        .toast(isPresenting: $showAuthErrorToast) {
            .errorBanner("Failed to authenticate", "Please try again or contact support.")
        }
    }
    
    // MARK: - Auth Buttons
    
    private var signInWithApple: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Continue with Apple",
            icon: "f179",
            iconWeight: .brand,
            labelColor: .white,
            buttonColor: .black,
            iconSize: 24,
            isDisabled: .false,
            isLoading: $appSession.isSigningApple,
            onTapAsync: {
                await appSession.attemptLogin(
                    for: .apple,
                    onSuccess: { appSession.routeTo(.dashboard) },
                    onError: { showAuthErrorToast = true }
                )
            }
        )
    }
    
    private var signInWithGoogle: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Continue with Google",
            image: Image("Google"),
            labelColor: .black,
            buttonColor: .white,
            iconSize: 22,
            isDisabled: .false,
            isLoading: $appSession.isSigningGoogle,
            onTapAsync: {
                await appSession.attemptLogin(
                    for: .google,
                    onSuccess: { appSession.routeTo(.dashboard) },
                    onError: { showAuthErrorToast = true }
                )
            }
        )
    }
    
    private var joinWithCode: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Join with code",
            labelColor: .foregroundPrimary,
            buttonColor: .clear,
            fillWidth: false,
            isDisabled: .false,
            isLoading: $appSession.isSigningAnonymous,
            onTapAsync: {
                await appSession.attemptLogin(
                    for: .anonymous,
                    onSuccess: { showFindRound = true },
                    onError: { showAuthErrorToast = true }
                )
            }
        )
    }
}

#Preview {
    AuthView()
        .environmentObject(AppSession())
}
