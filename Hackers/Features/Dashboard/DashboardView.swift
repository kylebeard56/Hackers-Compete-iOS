//
//  DashboardView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct DashboardView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    @State private var showUpdatedTerms = false
    
    var body: some View {
        VStack(spacing: 16) {
            PrimaryButton(
                appearance: .fill,
                title: "Play new round",
                icon: "f450",
                labelColor: .white,
                buttonColor: .hackersGreen,
                iconSize: 22,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    print("todo: play new round")
                }
            )
            
            PrimaryButton(
                appearance: .fill,
                title: "Join round",
                icon: "f450",
                labelColor: .white,
                buttonColor: .hackersGreen,
                iconSize: 22,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    print("todo: play new round")
                }
            )
            
            Spacer(minLength: 0)
        }
        .background(Color.hackersBackground)
        .task {
            await checkLegal()
        }
        .sheet(isPresented: $showUpdatedTerms) {
            UpdatedLegalView()
                .presentationDetents([.height(450)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }
}

extension DashboardView {
    fileprivate func checkLegal() async {
        if let legal = await AppData.shared.user?.legal {
            let terms = appSession.currentTermsVersion
            let privacy = appSession.currentPolicyVersion
            showUpdatedTerms = !legal.isTermsUpToDate(for: terms) || !legal.isPolicyUpToDate(for: privacy)
        } else {
            self.addBreadcrumb(.error, .legal, "Failed to check legal from missing user")
        }
    }
}

#Preview {
    DashboardView()
}
