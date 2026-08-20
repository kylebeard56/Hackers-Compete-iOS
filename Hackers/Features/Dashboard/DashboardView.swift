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
    @EnvironmentObject var liveRoundCompanion: LiveRoundCompanionCoordinator
    
    @StateObject var viewModel = DashboardViewModel()
    @StateObject private var homeViewModel = DashboardHomeViewModel()
    @State private var pageCoordinator = PageCoordinator()
    @State private var scrollPageID: Int? = 0
     
    @State private var showNewRound = false
    @State private var showNewSeries = false
    @State private var showFindRound = false
    
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
        appSession.rounds
//        appSession.rounds.isEmpty ? MockDashboardData.rounds : appSession.rounds
    }
    private var sortedRounds: [Round] {
        Array(displayRounds).sorted(by: { $0.displayDate.unix > $1.displayDate.unix })
    }
    
    private var activeRounds: [Round] {
        let base = sortedRounds.filter { $0.status == .live || $0.status == .lobby }
        guard let playerID = viewModel.currentPlayerID else { return base }
        return base.filter { round in
            !round.completedPlayers.contains { $0.playerID == playerID }
        }
    }

    private var companionEligibilityKey: String {
        ([viewModel.currentPlayerID ?? ""] + activeRounds.map(\.id).sorted())
            .joined(separator: "|")
    }
    
    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .course)
            
            pagedContent
            
            tabBar
                .padding(.horizontal, 16)
                .alignBottom()
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarBackButtonHidden(true)
        .captureScreen("dashboard")
        .task {
            TelemetryService.shared.clearContext()
        }
        .task {
            async let roundsLoad: Void = appSession.loadRounds()
            async let seriesLoad: Void = appSession.loadSeries()
            _ = await (roundsLoad, seriesLoad)
            viewModel.checkForStalledCompletions(in: sortedRounds)
        }
        .task(id: viewModel.currentPlayerID) {
            await homeViewModel.load(primaryPlayerID: viewModel.currentPlayerID)
        }
        .task(id: companionEligibilityKey) {
            liveRoundCompanion.reconcileEligibleRounds(
                activeRounds,
                currentPlayerID: viewModel.currentPlayerID
            )
        }
        .onChange(of: appSession.rounds) { _, _ in
            viewModel.checkForStalledCompletions(in: sortedRounds)
        }
        .sheet(item: $viewModel.stalledCompletionInfo) { info in
            RoundCompletionPrompt(
                info: info,
                currentPlayerID: viewModel.currentPlayerID,
                onRespond: {
                    viewModel.clearStalledCompletionInfo()
                    Task { await appSession.loadRounds() }
                }
            )
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
        .sheet(isPresented: $showNewSeries) {
            NewSeriesView { name, preset in
                showNewSeries = false
                Task {
                    if let seriesID = await appSession.createSeries(name: name, preset: preset) {
                        appSession.routeTo(.series(id: seriesID))
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFindRound, onDismiss: {
                appSession.shareCode = nil
                appSession.pendingJoinLink = nil
            }) {
            FindRoundView(onJoin: {
                showFindRound = false
                Task { await appSession.loadRounds() }
            })
            .environmentObject(appSession)
            .environmentObject(roundSession)
            .presentationDragIndicator(.visible)
        }
        .onReceive(HackersNotification.joinFromDeepLink.publisher()) { _ in
            showFindRound = true
        }
        .onAppear {
            if appSession.pendingJoinLink != nil {
                showFindRound = true
            }
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
            .ignoresSafeArea(.keyboard)
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
        case .home:
            DashboardHomeView(
                viewModel: viewModel,
                homeViewModel: homeViewModel,
                palette: palette,
                sortedRounds: sortedRounds,
                activeRounds: activeRounds,
                isLoadingRounds: appSession.isLoadingRounds,
                onRoundTap: handleRoundTap,
                onRouteToLobby: { routeToLobby(for: $0) },
                onSeeMoreActiveRounds: { pageCoordinator.scrollTo(index: 1, duration: 0.35) },
                onPlayNewRound: { showNewRound = true },
                onCreateSeries: { showNewSeries = true },
                onSeriesTap: { series in
                    appSession.activeSeriesID = series.id
                    appSession.routeTo(.series(id: series.id))
                }
            )
        case .rounds:
            DashboardRoundHistoryView(
                viewModel: viewModel,
                palette: palette,
                sortedRounds: sortedRounds,
                playerHistoryEntries: homeViewModel.recentPlayers,
                isLoadingRounds: appSession.isLoadingRounds,
                onRoundTap: handleRoundTap
            )
        case .profile:
            DashboardProfileView(palette: palette, currentPlayerID: viewModel.currentPlayerID)
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
            #if SANDBOX
            Button {
                Haptics.fire(.light)
                appSession.routeTo(.designStudio)
            } label: {
                Label("Open Design Studio", systemImage: "paintpalette.fill")
                Text("Local interactive prototypes")
            }

            Divider()
            #endif

            Button {
                Haptics.fire(.light)
                showFindRound = true
            } label: {
                Label("Join round or series", systemImage: "qrcode")
            }
            
            Divider()
            
            Button {
                Haptics.fire(.light)
                showNewSeries = true
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
    
    private func handleRoundTap(_ round: Round) {
        appSession.activeRoundID = round.id
        let hasSignedScorecard = viewModel.currentPlayerID.map { playerID in
            round.completedPlayers.contains { $0.playerID == playerID }
        } ?? false

        print(#function)
        
        switch round.status {
        case .live:
            if hasSignedScorecard {
                appSession.roundOutcomeAllowsEditing = true
                appSession.routeTo(.roundOutcome)
            } else {
                appSession.routeTo(.liveRound)
            }
        case .lobby:
            appSession.routeTo(.lobby)
        case .complete, .paused:
            appSession.roundOutcomeAllowsEditing = true
            appSession.routeTo(.roundOutcome)
        case .archived:
            break
        }
    }
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
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Format: "Wednesday, Mar 11" (weekday, short month, day)
    var weekdayShortMonthDay: String {
        let date = Date(timeIntervalSince1970: unix)
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppSession.forPreview())
        .environmentObject(RoundSession())
        .environmentObject(LiveRoundCompanionCoordinator())
}
