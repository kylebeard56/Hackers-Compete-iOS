//
//  DashboardView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import Flow
import SwiftUI

struct DashboardView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    @StateObject var viewModel = DashboardViewModel()
    @State private var pageCoordinator = PageCoordinator()
    @State private var scrollPageID: Int? = 0
    
    @State private var showNewRound = false
    @State private var showFindRound = false
    @State private var showSetHomeCourse = false
    
    private enum Tab: String, CaseIterable {
        case home
        case rounds
        case profile
        
        var icon: String {
            switch self {
            case .home: "e487" //"house.fill"
            case .rounds: "e0d5" //"flag.2.crossed.fill"
            case .profile: "f2bd" //"person.crop.circle.fill"
            }
        }
    }
    
    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
    private var displayRounds: Set<Round> {
        #if DEBUG
        if appSession.rounds.isEmpty { return MockDashboardData.rounds }
        #endif
        return appSession.rounds
    }
    private var sortedRounds: [Round] {
        Array(displayRounds).sorted(by: { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix })
    }
    
    private var activeRounds: [Round] {
        sortedRounds.filter { $0.status == .live || $0.status == .lobby }
    }
    
    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .green)
            
            pagedContent
            
            tabBar
                .padding(.horizontal, 16)
                .alignBottom()
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await appSession.loadRounds()
        }
        .fullScreenCover(isPresented: $showNewRound) {
            CourseSelectionView(
                viewModel: .init(),
                onCreation: { roundID in
                    showNewRound = false
                    routeToLobby(for: roundID)
                }
            )
            .environmentObject(appSession)
            .environmentObject(roundSession)
        }
        .sheet(isPresented: $showFindRound, onDismiss: { appSession.shareCode = nil }) {
            FindRoundView(onJoin: {
                showFindRound = false
                Task { await appSession.loadRounds() }
                appSession.routeTo(.lobby)
            })
            .environmentObject(appSession)
            .environmentObject(roundSession)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSetHomeCourse) {
            SetHomeCourseView(onSaved: {
                showSetHomeCourse = false
                viewModel.refreshHomeCourse()
            })
            .environmentObject(appSession)
            .environmentObject(roundSession)
            .presentationDragIndicator(.visible)
        }
        .onReceive(HackersNotification.joinRoundFromDeepLink.publisher()) { _ in
            showFindRound = true
        }
    }
    
    // MARK: - Paged Content
    
    private var pagedContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                        tabContent(for: tab)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPageID, anchor: .leading)
            .onScrollGeometryChange(for: CGFloat.self) { scrollGeo in
                let width = scrollGeo.containerSize.width
                guard width > 0 else { return 0 }
                return scrollGeo.contentOffset.x / width
            } action: { _, newFractional in
                pageCoordinator.fractionalIndex = newFractional
            }
            .onChange(of: pageCoordinator.programmaticTarget) { _, targetIndex in
                guard let targetIndex, targetIndex < Tab.allCases.count else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(targetIndex, anchor: .leading)
                }
                pageCoordinator.resetTarget()
            }
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .home: homeContent
        case .rounds: roundContent
        case .profile: profileContent
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            dashboardTabStrip
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .glassCardEffect(
                    shape: .capsule,
                    material: .bar,
                    interactive: true,
                    tint: nil
                )
            
            Spacer(minLength: 8)
            
            plusMenuButton
        }
    }
    
    @ViewBuilder
    private var dashboardTabStrip: some View {
        let tabWidth: CGFloat = 72
        let tabHeight: CGFloat = 48
        let tabCount = Tab.allCases.count
        let fractionalIndex = pageCoordinator.fractionalIndex
        let settledIndex = Int(fractionalIndex.rounded())
        let clampedFraction = min(max(0, fractionalIndex), CGFloat(tabCount - 1))
        let capsuleX = clampedFraction * tabWidth
        
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                    Button {
                        Haptics.fire(.light)
                        pageCoordinator.scrollTo(index: index, duration: 0.35)
                    } label: {
                        Icon(name: tab.icon, size: 24, weight: settledIndex == index ? .solid : .regular)
                            .foregroundStyle(settledIndex == index ? .accentGreen : Color.charcoal)
                            .frame(width: tabWidth, height: tabHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Capsule()
                .fill(Color.accentGreen.opacity(0.25))
                .frame(width: tabWidth, height: tabHeight)
                .offset(x: capsuleX)
        }
        .frame(width: tabWidth * CGFloat(tabCount), height: tabHeight)
    }
    
    private var plusMenuButton: some View {
        Menu {
            Button {
                Haptics.fire(.light)
                showFindRound = true
            } label: {
                Label("Join round or series", systemImage: "qrcode")
            }
            
            Divider()
            
            Button {
                Haptics.fire(.light)
                showNewRound = true
            } label: {
                Label("Start a new series", systemImage: "square.stack.3d.up")
                Text("Multi-round, trips, or leagues")
            }
            Button {
                Haptics.fire(.light)
                showNewRound = true
            } label: {
                Label("Play a new round", systemImage: "figure.golf")
                Text("Single session gameplay")
            }
        } label: {
            NavButton(style: .glass, icon: "2b", size: 24)
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    // MARK: - Home Content
    
    private var homeContent: some View {
        //ObservableScrollView(offset: $viewModel.scrollOffset, axes: .vertical, showsIndicators: false) {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    homeScrollContent
                    Padding(.vertical, 120)
                }
            }
            
            homeNavBar
                .alignTop()
        }
    }
    
    private var navBarSpacer: some View {
        homeNavBar
            .disabled(true)
            .opacity(0)
            .accessibilityHidden(true)
    }
    
    private var homeNavBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            
            Logo()
                .frame(height: 48)
            
            Spacer(minLength: 0)
            
//            NavButton(
//                style: .glass,
//                icon: "rectangle.portrait.and.arrow.right",
//                color: palette.foregroundColor,
//                onTap: { try? AuthService.shared.logout() }
//            )
        }
    }
    
    private var homeScrollContent: some View {
        VStack(spacing: 16) {
            navBarSpacer
            
            if activeRounds.isPopulated {
                activeRoundSection
            }
            
            homeCourseSection
            
            if sortedRounds.isPopulated {
                recentRoundsSection
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var activeRoundSection: some View {
        VStack(spacing: 12) {
            Text("Active round".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()
            
            ForEach(activeRounds, id: \.self) { round in
                Button {
                    Haptics.fire(.light)
                    appSession.activeRoundID = round.id
                    if round.status == .live {
                        appSession.routeTo(.liveRound)
                    } else if round.status == .lobby {
                        appSession.routeTo(.lobby)
                    }
                } label: {
                    activeRoundTile(for: round)
                }
            }
        }
    }
    
    private func activeRoundTile(for round: Round) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let course = round.configuration.courses.first {
                    Text(course.courseInfo.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                    Text("\(course.holeRange.count) holes \(kDot) \(round.players.count) players")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
            
            Spacer(minLength: 0)
            
            statusBadge(for: round.status)
            
            Icon(name: "chevron.right", size: 14, weight: .semibold)
                .foregroundStyle(Color.neutral3)
        }
        .padding(16)
        .glassCardEffect()
    }
    
    private func statusBadge(for status: RoundStatus) -> some View {
        Text(status.displayName)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(status == .live ? Color.accentGreen : Color.accentPurple)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status == .live ? Color.accentGreen.opacity(0.2) : Color.accentPurple.opacity(0.2))
            .cornerRadius(radius: 8)
    }
    
    @ViewBuilder
    private var homeCourseSection: some View {
        if let homeCourse = viewModel.homeCourseName {
            Button {
                Haptics.fire(.light)
                viewModel.playAtHomeCourse { roundID in
                    routeToLobby(for: roundID)
                }
            } label: {
                HStack(spacing: 16) {
                    Icon(name: "f3c5", size: 24, weight: .regular)
                        .foregroundStyle(Color.accentGreen)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play at \(homeCourse)")
                            .fontStyle(kFontName, size: 17, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                        Text("Quick start at your home course")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Icon(name: "chevron.right", size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral3)
                }
                .padding(16)
                .glassCardEffect()
            }
        } else {
            Button {
                Haptics.fire(.light)
                showSetHomeCourse = true
            } label: {
                HStack(spacing: 16) {
                    Icon(name: "star", size: 24, weight: .regular)
                        .foregroundStyle(Color.accentGreen)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set home course")
                            .fontStyle(kFontName, size: 17, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text("Quick start rounds at your favorite course")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Icon(name: "chevron.right", size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral3)
                }
                .padding(16)
                .glassCardEffect()
            }
        }
    }
    
    @ViewBuilder
    private var recentRoundsSection: some View {
        let recent = Array(sortedRounds.prefix(3))
        VStack(spacing: 12) {
            Text("Recent rounds".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()
            
            ForEach(recent, id: \.self) { round in
                Button {
                    Haptics.fire(.light)
                    handleRoundTap(round)
                } label: {
                    roundTile(for: round)
                }
            }
        }
    }
    
    // MARK: - Rounds Content
    
    private var roundContent: some View {
        VStack(spacing: 0) {
//            roundsNavBar
//                .padding(.horizontal, 16)
//                .padding(.top, 8)
            
            Text("Round history")
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .padding(.horizontal, 16)
                .alignLeading()
            
            SearchBar(
                placeholder: "Search rounds...",
                initialValue: viewModel.roundsSearchText,
                theme: .glass,
                onDebounce: { text in
                    viewModel.roundsSearchText = text
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredRounds(from: sortedRounds), id: \.self) { round in
                        Button {
                            Haptics.fire(.light)
                            handleRoundTap(round)
                        } label: {
                            roundTile(for: round)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 120)
                }
            }
        }
    }
    
//    private var roundsNavBar: some View {
//        HStack(spacing: 12) {
//            Logo()
//                .frame(height: 40)
//            
//            Spacer(minLength: 0)
//            
//            VStack(spacing: 2) {
//                Text("Rounds".uppercased())
//                    .fontStyle(kFontName, size: 15, weight: .semibold)
//                    .foregroundStyle(palette.foregroundColor)
//            }
//            .padding(.vertical, 3)
//            .padding(.horizontal, 24)
//            .glassCardEffect()
//            
//            Spacer(minLength: 0)
//            
//            Color.clear.frame(width: 44, height: 44)
//        }
//    }
    
    private func roundTile(for round: Round) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let course = round.configuration.courses.first {
                    Text(course.courseInfo.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                    Text("\(course.holeRange.count) holes \(kDot) \(round.players.count) players")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Text(round.lastUpdatedAt.formattedDate)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral3)
            }
            
            Spacer(minLength: 0)
            
            statusBadge(for: round.status)
            
            Icon(name: "chevron.right", size: 14, weight: .semibold)
                .foregroundStyle(Color.neutral3)
        }
        .padding(16)
        .glassCardEffect()
    }
    
    private func handleRoundTap(_ round: Round) {
        appSession.activeRoundID = round.id
        switch round.status {
        case .live:
            appSession.routeTo(.liveRound)
        case .lobby:
            appSession.routeTo(.lobby)
        case .complete, .paused:
            appSession.routeTo(.liveRound)
        case .archived:
            break
        }
    }
    
    // MARK: - Profile Content
    
    private var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
//                profileNavBar
//                    .padding(.horizontal, 16)
                
                Text("Profile")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 16)
                    .alignLeading()
                
                profileCard
                    .padding(.horizontal, 16)
                
                logoutButton
                    .padding(.horizontal, 16)
                
                Spacer(minLength: 80)
            }
        }
    }
    
    private var profileCard: some View {
        let profile = MockDashboardData.mockProfile
        return HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                PlayerAvatarView(
                    initials: profile.initials,
                    size: 56,
                    fillColor: .accentGreen.opacity(0.6),
                    glassTint: .neutral6,
                    badgeIcon: "e20e",
                    badgeIconColor: Color.charcoal,
                    badgeBackgroundColor: palette.whiteGlassButtonColor
                )
                .onTapGesture {
                    Haptics.fire(.light)
                    // Fake door: edit profile
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Text("Joined \(profile.joinedDateFormatted)  \(kDot)  \(profile.roundsPlayed) rounds")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCardEffect()
    }
    
    private var logoutButton: some View {
        Button {
            Haptics.fire(.light)
            try? AuthService.shared.logout()
        } label: {
            Text("Logout")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .glassCardEffect(
            cornerRadius: 24,
            tint: Color.systemError.opacity(0.9)
        )
    }
    
//    private var profileNavBar: some View {
//        HStack(spacing: 12) {
//            Logo()
//                .frame(height: 40)
//            
//            Spacer(minLength: 0)
//            
//            VStack(spacing: 2) {
//                Text("Profile".uppercased())
//                    .fontStyle(kFontName, size: 15, weight: .semibold)
//                    .foregroundStyle(palette.foregroundColor)
//            }
//            .padding(.vertical, 3)
//            .padding(.horizontal, 24)
//            .glassCardEffect()
//            
//            Spacer(minLength: 0)
//            
//            Color.clear.frame(width: 44, height: 44)
//        }
//    }
}

// MARK: - Routing

extension DashboardView {
    fileprivate func routeToLobby(for roundID: String) {
        appSession.activeRoundID = roundID
        appSession.routeTo(.lobby)
    }
}

// MARK: - RoundStatus Display

extension RoundStatus {
    var displayName: String {
        switch self {
        case .lobby: return "Lobby"
        case .live: return "Live"
        case .paused: return "Paused"
        case .complete: return "Complete"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Time Formatting

extension Time {
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: unix)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppSession())
        .environmentObject(RoundSession())
}
