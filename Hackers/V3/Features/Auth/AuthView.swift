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
    
    var body: some View {
        ZStack {

            
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                
                Text("Welcome to")
    //                .font(.system(size: 28, weight: .bold))
                    .font(.fugaz, size: 28)
                    .foregroundStyle(Color.systemBlack)
                
                Logo()
                    .frame(width: UIScreen.main.bounds.width * 0.69)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
                
                Spacer(minLength: 0)
                
                joinWithCode
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 8)
                
                signInWithApple
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 8)
                
                signInWithGoogle
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 8)
                
//                Button(action: {
//                    Haptics.fire(.light)
//                    print("join with code")
//                }) {
//                    Text("Join with code")
//                        .font(.system(size: 17, weight: .semibold))
//                        .foregroundStyle(Color.systemBlack)
//                }
            }
        }
        .padding(16)
        .background(background)
        .navigationBarBackButtonHidden(true)
    }
    
    private var background: some View {
        Image("GolfTopology")
            .interpolation(.high)
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
    }
    
    private var signInWithApple: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Sign in with Apple",
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
            title: "Sign in with Google",
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
            appearance: .outline,
            title: "Join with code",
            icon: "f145",
            weight: .regular,
            labelColor: .hackersGreen,
            borderColor: .hackersGreen,
            iconSize: 22,
            borderSize: 5,
            isDisabled: .false,
            isLoading: .false,
            onTap: {
                print("todo: join with code")
            }
        )
    }
}

#Preview {
    AuthView()
        .environmentObject(AppSession())
}
