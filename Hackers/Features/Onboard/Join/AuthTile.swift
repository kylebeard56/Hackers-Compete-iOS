//
//  AuthTile.swift
//  Hackers
//
//  Created by Kyle Beard on 1/12/26.
//

import AlertToast
import SwiftUI

struct AuthTile: View, Loggable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    var title: String = "Save player profile"
    var subtitle: String = "Sign in for free to link this round to your player and join future rounds faster."
    var allowGuests: Bool = true
    var onAuth: AsyncCallbackValue<Bool>? = nil
    var onContinueAsGuest: AsyncCallback? = nil
    
    @State private var showAuthErrorToast = false
    
    private var palette: DesignPalette { .init(theme: .secondary, scheme: colorScheme) }
    private var errorSubtitle: String {
        "Please \(allowGuests ? "try again or continue as guest" : "retry or wait a few minutes")."
    }
    var body: some View {
        VStack(spacing: 16) {
            NavButton(style: .glass, icon: "f00d", theme: palette.theme) {
                dismiss()
            }
            .alignTrailing()
            
            Spacer(minLength: 0)
            
            VStack(spacing: 8) {
                Text(title)
                    .fontStyle(size: 22, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()
                
                Text(subtitle)
                    .fontStyle(size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.center)
                    .alignCenter()
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
            
            signInWithGoogle
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
            
            signInWithApple
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
            
            if allowGuests {
                continueAsGuest
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
            }

            Spacer(minLength: 0)
            
            LegalFootnote(tint: .neutral)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(palette.backgroundColor)
        .toast(isPresenting: $showAuthErrorToast) {
            .errorBanner("Failed to authenticate", errorSubtitle)
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
                    onSuccess: { newlyCreated in await onAuth?(newlyCreated) },
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
                    onSuccess: { newlyCreated in await onAuth?(newlyCreated) },
                    onError: { showAuthErrorToast = true }
                )
            }
        )
    }
    
    private var continueAsGuest: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Continue as guest",
            labelColor: .foregroundPrimary,
            buttonColor: .clear,
            fillWidth: false,
            isDisabled: .false,
            isLoading: .false,
            onTapAsync: {
                await appSession.attemptLogin(
                    for: .anonymous,
                    onSuccess: { _ in await onContinueAsGuest?() },
                    onError: { showAuthErrorToast = true }
                )
            }
        )
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.edgesIgnoringSafeArea(.all).sheet(isPresented: .true) {
            AuthTile()
                .environmentObject(AppSession())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
}
