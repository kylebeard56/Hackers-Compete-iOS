//
//  LegalFootnote.swift
//  Hackers
//
//  Created by Kyle Beard on 7/29/25.
//

import SwiftUI

struct LegalFootnote: View {
    
    @State private var showActionSheet = false
    @State private var showTerms = false
    @State private var showPolicy = false
    
    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            showActionSheet = true
        }) {
            Text("By continuing, you agree to our Terms of Use and Privacy Policy.")
                .fontStyle(size: 13, weight: .medium)
                .foregroundStyle(Color.hackersCharcoal)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .confirmationDialog("", isPresented: $showActionSheet) {
            Button("Terms of Use") {
                Haptics.fire(.light)
                showTerms = true
            }

            Button("Privacy Policy") {
                Haptics.fire(.light)
                showPolicy = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
        }
        .sheet(isPresented: $showPolicy) {
            PrivacyPolicyView()
        }
    }
}

#Preview {
    LegalFootnote()
}
