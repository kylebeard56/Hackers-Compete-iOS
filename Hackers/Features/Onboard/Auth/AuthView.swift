//
//  AuthView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/25.
//

import Foundation
import SwiftUI

struct AuthView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    @State private var showLegalSheet = false
    @State private var showJoinSheet = false
    @State private var isLoading = false
    
    private let animation: Animation = .linear(duration: 0.2)
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            
            Text("Welcome to".uppercased())
                .fontStyle(size: 22, weight: .bold)
                .foregroundStyle(Color.systemBlack)
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
        .sheet(isPresented: $showJoinSheet) {
            JoinRoundView()
        }
    }
    
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
            onTap: {
                Task { await appSession.signInWithApple() }
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
            onTap: {
                Task { await appSession.signInWithGoogle() }
            }
        )
    }
    
    private var joinWithCode: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Join with code",
            labelColor: .systemBlack,
            buttonColor: .clear,
            isDisabled: .false,
            isLoading: .false,
            onTap: {
                showJoinSheet = true
            }
        )
    }
}

#Preview {
    AuthView()
        .environmentObject(AppSession())
}
