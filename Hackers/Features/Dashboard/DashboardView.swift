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
    
    @StateObject var viewModel = DashboardViewModel()
    
    @State private var selectedTab: Tab = .home
    @State private var showUpdatedTerms = false
    @State private var showNewRound = false
    @State private var showFindRound = false
    
    private enum Tab: String { case home, rounds, add, search, profile }
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var sortedRounds: [Round] {
        Array(appSession.rounds).sorted(by: { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix })
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            homeContent
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            roundContent
                .tabItem {
                    Label("Rounds", systemImage: "flag.2.crossed.fill")
                }
                .tag(Tab.rounds)

            addContent
                .tabItem {
                    Label("", systemImage: "plus.circle.fill")
                }
                .tag(Tab.add)

            searchContent
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            profileContent
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(Color.accentGreen)
        .toolbarBackground(palette.backgroundColor, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .task {
            await appSession.loadRounds()
//            await addTemporaryPlayers()
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
        .fullScreenCover(isPresented: $showNewRound) {
            CourseSelectionView(
                viewModel: .init(),
                onCreation: { roundID in
                    showNewRound = false
                    routeToLobby(for: roundID)
                }
            )
        }
        .sheet(isPresented: $showFindRound) {
            FindRoundView()
                .presentationDragIndicator(.visible)
        }
    }
    
    private func addTemporaryPlayers() async {
        let names: [String] = [
            "Diane Beard",
            "Gary Beard",
            "Sarah Beard",
            "Banks Beard",
            "Murphy Beard",
            "Kim Sciullo",
            "Chip Sciullo",
            "Parker Sciullo",
            "Harper Sciullo"
        ]
        
        for (index, name) in names.enumerated() {
            let player = Player(id: "temp\(index + 1)", name: Name(name))
            _ = await player.post()
        }
    }
    
    var homeContent: some View {
        VStack(spacing: 16) {
            HStack {
                Logo()
                    .frame(height: 48)
                
                Spacer()
                
                Button(action: {
                    try? AuthService.shared.logout()
                }) {
                    Chip(text: "Logout", weight: .medium, size: .small, style: .fill)
                }
            }
            
            HackersCard(
                title: "Active rounds",
                headerStyle: .complimentary,
                callToAction: { EmptyView() },
                content: {
                    if appSession.rounds.isPopulated {
                        ForEach(sortedRounds, id: \.self) { round in
                            Button(action: {
                                Haptics.fire(.light)
                                appSession.activeRoundID = round.id
                                appSession.routeTo(.lobby)
                            }) {
                                roundRow(for: round)
                            }
                        }
                    } else {
                        Text("No active rounds found")
                            .fontStyle(.poppins, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignCenter()
                    }
                },
                isLoading: $appSession.isLoading
            )
            
            // TODO: Credits
            // TODO: Promos
            // TODO: Announcements
            // TODO: More ideas...
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.backgroundPrimary)
    }
    
    private var addContent: some View {
        // TODO: Redesign
        // Text field ready to enter join code
        // Big button to create new round
        // Play again option to duplicate a round? (would you check or uncheck players?)
        // Marketing opportunity to upsell new games and formats
        // Coins or tickets?
        // Do we display games here? (game value passes through to course selector)
        
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Play new round",
                icon: "f450",
                iconWeight: .regular,
                labelColor: .white,
                buttonColor: .accentGreen,
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
                buttonColor: .accentPurple,
                iconSize: 22,
                radius: 16,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    showFindRound = true
                }
            )
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.backgroundPrimary)
    }
    
    private var roundContent: some View {
        VStack {
            Text("TODO: Rounds history")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
        .background(Color.backgroundPrimary)
    }
    
    private var searchContent: some View {
        VStack {
            // TODO: Fake door test
            Text("TODO: Search anything in app")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
        .background(Color.backgroundPrimary)
    }
    
    private var profileContent: some View {
        VStack {
            Text("TODO: Profile view")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
        .background(Color.backgroundPrimary)
    }
    
    private func roundRow(for round: Round) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                if let course = round.configuration.courses.first {
                    Text(course.courseInfo.name)
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                        .alignLeading()
                    Text("\(course.holeRange.count) holes \(kDot) \(round.players.count) players")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            }
            
            NavButton(icon: "trash", onTap: {
                Task {
                    await appSession.archiveRound(round)
                }
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.backgroundPrimary)
        .cornerRadius(radius: 12)
    }
}

extension DashboardView {
    fileprivate func routeToLobby(for roundID: String) {
        appSession.activeRoundID = roundID
        appSession.routeTo(.lobby)
    }
    
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
