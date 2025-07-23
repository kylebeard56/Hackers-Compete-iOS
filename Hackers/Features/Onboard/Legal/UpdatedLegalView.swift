//
//  UpdatedLegalView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct UpdatedLegalView: View, Loggable {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @State private var showTerms = false
    @State private var showPolicy = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.hackersGray5, lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                Icon(name: "f24e", size: 32, maxSize: 32, weight: .regular)
                    .foregroundStyle(Color.hackersForeground)
            }
            .padding(.top, 16)
            
            Text("We've updated our terms.")
                .font(.system(size: 24, weight: .semibold, design: kFontDesign))
                .foregroundColor(Color.hackersForeground)
                .minimumScaleFactor(0.75)
            
            Text("By continuing to use Hackers Golf, you agree and acknowledge these updated documents.")
                .font(.system(size: 17, weight: .regular, design: kFontDesign))
                .foregroundColor(Color.hackersGray)
                .multilineTextAlignment(.center)
            
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Terms of Use",
                labelColor: Color.hackersForeground,
                buttonColor: Color.hackersGray6,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showTerms = true }
            )
            
            PrimaryButton(
                appearance: .fill,
                title: "Privacy Policy",
                labelColor: Color.hackersForeground,
                buttonColor: Color.hackersGray6,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showPolicy = true }
            )
            
            PrimaryButton(
                appearance: .fill,
                title: "Dismiss",
                labelColor: Color.hackersBackground,
                buttonColor: Color.hackersForeground,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    Task { await save() }
                }
            )
        }
        .padding(16)
        .sheet(isPresented: $showTerms) { TermsView() }
        .sheet(isPresented: $showPolicy) { PrivacyPolicy() }
    }
    
    private func save() async {
        defer { dismiss() }
        if var user = await AppData.shared.user {
            user.legal = UserLegal(
                terms: appSession.currentTermsVersion,
                privacyPolicy: appSession.currentPolicyVersion
            )
            do {
                user = try await user.put().get()
                await AppData.shared.setUser(user)
            } catch let error {
                addBreadcrumb(.error, .legal, "Failed to update user terms", error)
                // NOTE: We don't need a toast here since they'll just get hit next time
            }
        } else {
            addBreadcrumb(.warning, .legal, "Failed to update terms from missing user")
        }
    }
}

#Preview {
    VStack {
        Color.hackersGray6
    }
    .sheet(isPresented: .true) {
        UpdatedLegalView()
            .environmentObject(AppSession())
            .presentationDetents([.height(450)])
            .presentationDragIndicator(.visible)
    }
}
