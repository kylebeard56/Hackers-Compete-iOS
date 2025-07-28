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
                
                Text("Welcome to".uppercased())
                    .font(.system(size: 24, weight: .bold))
//                    .font(.fugaz, size: 24)
                    .foregroundStyle(Color.systemBlack)
                
                Logo()
                    .frame(width: UIScreen.main.bounds.width * 0.69)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
                
                Spacer(minLength: 0)
                
//                joinWithCode
//                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 8)
                
                signInWithGoogle
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
                    .padding(.horizontal, 16)
                
                signInWithApple
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
                    .padding(.horizontal, 16)
                
                joinWithCode
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
                    .padding(.horizontal, 16)
                
                Spacer().frame(height: 0)
                
//                ZStack {
//                    Color.hackersGreen
//                    joinWithCode
//                }
//                .frame(height: 100)
//                .edgesIgnoringSafeArea(.bottom)
                
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
        .background(background)
        .navigationBarBackButtonHidden(true)
        .edgesIgnoringSafeArea(.all)
    }
    
    private var background: some View {
        Image("GolfTopology")
            .interpolation(.high)
            .resizable()
            .scaledToFill()
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
//            font: .fugaz,
//            weight: .regular,
            labelColor: .systemBlack,
            buttonColor: .clear,
//            fontSize: 20,
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
