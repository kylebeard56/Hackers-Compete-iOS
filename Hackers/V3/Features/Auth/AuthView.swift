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
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            
            Logo()
                .frame(width: 120)
                .cornerRadius(radius: 24)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
            
            VStack(spacing: 8) {
                Text("Box Fox")
                    .font(.system(.largeTitle, design: kFontDesign, weight: .bold))
                    .foregroundStyle(Color.hackersForeground)
                
                Text("Golf is hard. Make it fun")
                    .font(.system(.title3, design: kFontDesign, weight: .regular))
                    .foregroundStyle(Color.hackersGray)
            }
            
            Spacer(minLength: 0)
            
            signInWithApple
            signInWithGoogle
        }
        .padding(16)
        .background(Color.hackersBackground)
        .navigationBarBackButtonHidden(true)
    }
    
    private var signInWithApple: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Sign in with Apple",
            icon: "f179",
            weight: .brand,
            labelColor: .hackersBackground,
            buttonColor: .hackersForeground,
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
            appearance: .outline,
            title: "Sign in with Google",
            image: Image("Google"),
            labelColor: .hackersForeground,
            borderColor: .hackersGray4,
            iconSize: 22,
            isDisabled: .false,
            isLoading: $appSession.isSigningGoogle,
            onTap: {
                Task { await appSession.signInWithGoogle() }
            }
        )
    }
}

#Preview {
    AuthView()
        .environmentObject(AppSession())
}
