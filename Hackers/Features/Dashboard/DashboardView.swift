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
    @State private var showFindRound = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Logo()
                    .frame(height: 48)
                
                Spacer()
                
                NavButton(
                    icon: "f08b", //"e0ae",
                    size: 24,
                    weight: .solid,
                    //mirror: true,
                    onTap: {
                        try? AuthService.shared.logout()
                        print("todo: settings")
                    }
                )
            }
            
            PrimaryButton(
                appearance: .fill,
                title: "Play new round",
                icon: "f450",
                iconWeight: .regular,
                labelColor: .white,
                buttonColor: .hackersGreen,
//                height: 200,
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
//                height: 200,
                iconSize: 22,
                radius: 16,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    showFindRound = true
                }
            )
            
            Spacer(minLength: 0)
            
            if appSession.rounds.isPopulated {
                ForEach(appSession.rounds, id: \.self) { round in
                    Button(action: {
                        Haptics.fire(.light)
                        appSession.activeRoundID = round.id
                        appSession.routeTo(.lobby)
                    }) {
                        roundRow(for: round)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.hackersBackground)
        .navigationBarBackButtonHidden(true)
        .task {
            await appSession.loadRounds()
        }
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
        .sheet(isPresented: $showFindRound) {
            FindRoundView()
                .presentationDragIndicator(.visible)
        }
    }
    
    private func roundRow(for round: Round) -> some View {
        VStack(spacing: 4) {
            if let course = round.configuration.courses.first {
                Text(course.courseInfo.name)
                    .fontStyle(.poppins, size: 17, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()
                Text("Continue playing \(course.holeRange.count) holes")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.hackersGray)
                    .alignLeading()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.hackersGray6)
        .cornerRadius(radius: 16)
//        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
    }
}

extension DashboardView {
    fileprivate func checkForNewRound() {
        if let _ = appSession.activeRoundID {
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
