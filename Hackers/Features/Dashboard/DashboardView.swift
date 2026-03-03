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
        appSession.rounds.isEmpty ? MockDashboardData.rounds : appSession.rounds
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
            viewModel.checkForStalledCompletions(in: sortedRounds)
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
        case .home:
            DashboardHomeView(
                viewModel: viewModel,
                palette: palette,
                sortedRounds: sortedRounds,
                activeRounds: activeRounds,
                onSetHomeCourse: { showSetHomeCourse = true },
                onRoundTap: handleRoundTap,
                onRouteToLobby: { routeToLobby(for: $0) }
            )
        case .rounds:
            DashboardRoundHistoryView(
                viewModel: viewModel,
                palette: palette,
                sortedRounds: sortedRounds,
                onRoundTap: handleRoundTap
            )
        case .profile:
            DashboardProfileView(palette: palette)
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
        .environmentObject(AppSession.forPreview())
        .environmentObject(RoundSession())
}
