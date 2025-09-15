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
    @State private var showNewRound = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Logo()
                    .frame(height: 48)
                
                Spacer()
                
                NavButton(
                    icon: "e0ae",
                    size: 24,
                    weight: .solid,
                    mirror: true,
                    onTap: { print("todo: settings") }
                )
            }
            PrimaryButton(
                appearance: .fill,
                title: "Play new round",
                icon: "f450",
                iconWeight: .regular,
                labelColor: .white,
                buttonColor: .hackersGreen,
                height: 200,
                iconSize: 22,
                radius: 16,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    showNewRound = true
                }
            )
            
            PrimaryButton(
                appearance: .fill,
                title: "Join round",
                icon: "f029",
                iconWeight: .regular,
                labelColor: .white,
                buttonColor: .hackersPurple,
                height: 200,
                iconSize: 22,
                radius: 16,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    print("todo: join round")
                }
            )
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.hackersBackground)
        .navigationBarBackButtonHidden(true)
//        .task {
//            await checkLegal()
//        }
//        .sheet(isPresented: $showUpdatedTerms) {
//            LegalAcceptanceView()
//                .presentationDetents([.height(450)])
//                .presentationDragIndicator(.visible)
//                .interactiveDismissDisabled()
//        }
        .fullScreenCover(
            isPresented: $showNewRound,
            onDismiss: checkForNewRound
        ) {
            CourseSelectionView()
        }
    }
}

extension DashboardView {
    fileprivate func checkForNewRound() {
        if let id = appSession.activeRoundID {
            appSession.routeTo(.lobby)
        }
    }
}

extension DashboardView {
    fileprivate func checkLegal() async {
        // TODO: Clean this up and show popup if legal has been updated
//        let t = await Defaults.shared.getAcceptedTermsOfUse().last ?? ""
//        let p = await Defaults.shared.getAcceptedPrivacyPolicy().last ?? ""
        
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
