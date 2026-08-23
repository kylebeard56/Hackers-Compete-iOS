//
//  LegalAcceptanceView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct LegalAcceptanceView: View, Loggable {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @State private var showTerms = false
    @State private var showPolicy = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.neutral5, lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                Icon(name: "f24e", size: 32, maxSize: 32, weight: .regular)
                    .foregroundStyle(Color.foregroundPrimary)
            }
            .padding(.top, 16)
            
            Text("We've updated our terms.")
                .fontStyle(size: 24, weight: .semibold)
                .foregroundColor(Color.foregroundPrimary)
                .minimumScaleFactor(0.75)
            
            Text("By continuing to use Hackers Golf, you agree and acknowledge these updated documents.")
                .fontStyle()
                .foregroundColor(Color.neutral)
                .multilineTextAlignment(.center)
            
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Terms of Use",
                labelColor: Color.foregroundPrimary,
                buttonColor: Color.neutral6,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showTerms = true }
            )
            
            PrimaryButton(
                appearance: .fill,
                title: "Privacy Policy",
                labelColor: Color.foregroundPrimary,
                buttonColor: Color.neutral6,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showPolicy = true }
            )
            
            PrimaryButton(
                appearance: .fill,
                title: "Dismiss",
                labelColor: Color.backgroundPrimary,
                buttonColor: Color.foregroundPrimary,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    Task { await save() }
                }
            )
        }
        .padding(16)
        .sheet(isPresented: $showTerms) { TermsView() }
        .sheet(isPresented: $showPolicy) { PrivacyPolicyView() }
    }
    
    private func save() async {
        defer { dismiss() }
        
        /// 1. Store local defaults since these matter for next presentation
        await Defaults.shared.acceptNewTermsOfUse(appSession.currentTermsVersion)
        await Defaults.shared.acceptNewPrivacyPolicy(appSession.currentPolicyVersion)
        
        /// 2. Save remote to user's profile
        if var user = await AppData.shared.user {
            user.legal = UserLegal(
                terms: appSession.currentTermsVersion,
                privacyPolicy: appSession.currentPolicyVersion
            )
            do {
                user = try await user.put().get()
                await AppData.shared.setUser(user)
            } catch let error {
                addBreadcrumb(level: .error, message: "Failed to update user terms", error: error)
                // NOTE: We don't need a toast here since they'll just get hit next time
            }
        } else {
            addBreadcrumb(level: .warning, message: "Failed to update terms from missing user")
        }
    }
}

#Preview {
    VStack {
        Color.neutral6
    }
    .sheet(isPresented: .true) {
        LegalAcceptanceView()
            .environmentObject(AppSession())
            .presentationDetents([.height(450)])
            .presentationDragIndicator(.visible)
    }
}
