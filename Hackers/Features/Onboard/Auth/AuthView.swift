//
//  AuthView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/25.
//

import Foundation
import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appSession: AppSession
    
    @State private var showJoinSheet = false
    @State private var isLoading = false
    
    private let animation: Animation = .linear(duration: 0.2)
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            
            Text("Welcome to".uppercased())
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.systemBlack)
                .opacity(isLoading ? 0 : 1)
            
            Logo()
                .frame(width: UIScreen.main.bounds.width * 0.69)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
            
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.systemBlack)
                .opacity(isLoading ? 1 : 0)
            
            Spacer(minLength: 0)
            
            if !isLoading {
                signInWithGoogle
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
                
                signInWithApple
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
                
                joinWithCode
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
            }
        }
        .padding(16)
        .background(GolfTopology())
        .navigationBarBackButtonHidden(true)
        .animation(animation, value: isLoading)
        .task {
            isLoading = appSession.isInitializing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                withAnimation(animation, {
                    isLoading = false
                })
            })
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinRoundView()
        }
    }
    
    private var signInWithApple: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Continue with Apple",
            icon: "f179",
            weight: .brand,
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
