//
//  LiveRound.swift
//  Hackers
//
//  Created by Kyle Beard on 1/21/26.
//

import CoreLocation
import MapKit
import SwiftUI

enum IconType {
    case sanFrancisco, fontAwesome
    
    var normalWeight: FontModule.Weight {
        switch self {
        case .sanFrancisco:
            return .regular
        case .fontAwesome:
            return .regular
        }
    }
    
    var activeWeight: FontModule.Weight {
        switch self {
        case .sanFrancisco:
            return .semibold
        case .fontAwesome:
            return .solid
        }
    }
}

private enum Tab: String, CaseIterable {
    case scoring
    case matchups

    var icon: String {
        switch self {
        case .scoring: "menucard"
        case .matchups: "f71d"  // Font Awesome crossed swords
        }
    }
    
    func fontWeight(_ selection: Bool) -> FontModule.Weight {
        selection ? iconType.activeWeight : iconType.normalWeight
    }
    
    var iconType: IconType {
        switch self {
        case .scoring:
            return .sanFrancisco
        case .matchups:
            return .fontAwesome
        }
    }
}

/// Scroll animation duration: 0.28s base + 0.02s per additional hole beyond the first.
func holeScrollDuration(for distance: Int) -> Double {
    0.28 + Double(max(0, distance - 1)) * 0.02
}

fileprivate let kMinSkeletonTime: CGFloat = 0.6
fileprivate let kMaxSkeletonTime: CGFloat = 12

struct LiveRound: View {
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @CappedScaledMetric(relativeTo: .body) var leaderboardHeaderScoreWidth: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body) var leaderboardHeaderThruWidth: CGFloat = 54
    @CappedScaledMetric(relativeTo: .body) var leaderboardHeaderStarWidth: CGFloat = 24
    @CappedScaledMetric(relativeTo: .body) var skeletonAvatarSize: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var skeletonNameHeight: CGFloat = 17
    @CappedScaledMetric(relativeTo: .caption) var skeletonSubtitleHeight: CGFloat = 12
    @CappedScaledMetric(relativeTo: .body) var skeletonButtonWidth: CGFloat = 120
    @CappedScaledMetric(relativeTo: .body) var skeletonButtonHeight: CGFloat = 32
    @CappedScaledMetric(relativeTo: .body) var skeletonCellSize: CGFloat = 30
    @CappedScaledMetric(relativeTo: .caption) var skeletonCellHeight: CGFloat = 15
    @CappedScaledMetric(relativeTo: .body) var leaderboardScrollMaxHeight: CGFloat = 360
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    @StateObject var viewModel: LiveRoundViewModel = .init()
    
    @State private var isShowingInitialScoringSkeleton = false
    @State private var hasHandledInitialScoringSkeleton = false
    @State var pageCoordinator = PageCoordinator()
    @State var scoringPageHole: Int?
    
    @State var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapInit = false
    @StateObject var weatherService = WeatherService()

    @State private var showEditRoundSheet = false
    @State private var showShareRoundSheet = false
    @State private var showCompleteRoundSheet = false
    @State var showSwipeHint = true

    /// Checkmark appears when user can complete; CompleteRoundSheet warns about unscored holes and offers "Mark as max score".
    /// Only shown when viewing the final hole in the range.
    private var allHolesScored: Bool {
        !viewModel.isSpectator
        && viewModel.holeNumbers.isPopulated
        && (scoringPageHole ?? viewModel.currentHoleNumber) == (viewModel.holeNumbers.last ?? 0)
    }
    
    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    /// Invisible placeholder matching the nav header layout so content below aligns.
    /// Disabled and 0 opacity so it only reserves space.
    var navPadding: some View {
        scoringNavHeader
            .disabled(true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
    
    private var backgroundTheme: some View {
        ZStack {
            palette.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            LinearGradient(
                colors: [viewModel.theme.color.opacity(colorScheme.isLight ? 0.25 : 0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
//            viewModel.theme.color
//                .edgesIgnoringSafeArea(.all)
//                .opacity(0.2)
            
            GolfTopology(theme: viewModel.theme)
                .frame(width: UIScreen.main.bounds.width)
                .opacity(colorScheme.isLight ? 0.35 : 0.7)
        }
    }
    
    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: viewModel.theme)
            
            if selectedTab == .scoring {
                scoringContent
                    .edgesIgnoringSafeArea(.vertical)
            } else if selectedTab == .matchups {
                matchupsContent
                    .padding(.horizontal, 16)
            }

            scoringNavHeader
                .padding(.horizontal, 16)
                .alignTop()
            
            if visibleTabs.count > 1 {
                HStack(spacing: 8) {
                    liveTabStrip
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                }
                .glassCardEffect(
                    shape: .capsule,
                    material: .bar,
                    interactive: true,
                    tint: nil
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.jumpedToHoleNumber)
                .scaleEffect(viewModel.jumpedToHoleNumber != nil ? 1.1 : 1)
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: visibleTabs.count)
                .alignBottom()
            }

            if allHolesScored {
                HStack {
                    Spacer(minLength: 0)
                    NavButton(style: .glass, icon: "f00c", size: 24) {
                        Haptics.fire(.light)
                        showCompleteRoundSheet = true
                    }
                }
                .padding(.horizontal, 16)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: allHolesScored)
                .alignBottom()
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            if let id = appSession.activeRoundID {
                if roundSession.roundID != id || !roundSession.isRunning {
                    await roundSession.start(for: id)
                }
            }
            print(roundSession.snapshot.round.id)
            viewModel.bind(appSession: appSession, roundSession: roundSession)
            await runInitialScoringSkeletonIfNeeded()
            await viewModel.ensureParticipantResolved()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
//                viewModel.navigateToNextUnscoredHole()
//            })
            //await fetchWeatherIfNeeded()
        }
        // ── ViewModel intent → UI scroll state (single display source: scoringPageHole) ────
        .onChange(of: viewModel.currentHoleNumber) { old, new in
            guard scoringPageHole != new else { return }
            withAnimation(.spring(duration: holeScrollDuration(for: abs(new - old)))) {
                scoringPageHole = new
            }
        }
        .onChange(of: visibleTabs) { _, tabs in
            if !tabs.contains(selectedTab) {
                selectedTab = .scoring
            }
        }
        .fullScreenCover(isPresented: $showEditRoundSheet) {
            GameLobby(isEditMode: true)
                .environmentObject(appSession)
                .environmentObject(roundSession)
        }
        .sheet(isPresented: $showShareRoundSheet) {
            ShareRoundView(snapshot: roundSession.snapshot)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCompleteRoundSheet) {
            CompleteRoundSheet(viewModel: viewModel)
                .environmentObject(appSession)
                .environmentObject(roundSession)
        }
        .onReceive(roundSession.$snapshot, perform: { _ in
            if mapInit { return }

            if let courseLocation = roundSession.snapshot.course?.location {
                mapCameraPosition = .region(
                    .init(
                        center: .init(latitude: courseLocation.latitude, longitude: courseLocation.longitude),
                        latitudinalMeters: 1200,
                        longitudinalMeters: 1200
                    )
                )
                mapInit = true
            } else if let userLocation = locationService.location {
                mapCameraPosition = .region(
                    .init(
                        center: userLocation.coordinate,
                        latitudinalMeters: 300,
                        longitudinalMeters: 300
                    )
                )
                mapInit = true
            }
        })
    }
    
    /// Tabs to show: Scoring always; Matchups when scope is matchup and valid matchups exist for the current mode.
    private var visibleTabs: [Tab] {
        let matchups = snapshot.roundSegment?.matchups ?? []
        let expectedMode: MatchupMode = snapshot.requiresTeams ? .team : .individual
        let matchupsForMode = matchups.filter { ($0.mode ?? .team) == expectedMode }
        let validMatchupsForMode = matchupsForMode.filter { $0.isValid }
        let showMatchups = snapshot.configuration.resolvedCompetitionScope == .matchup && !validMatchupsForMode.isEmpty
        return showMatchups ? [.scoring, .matchups] : [.scoring]
    }

    @ViewBuilder
    private var liveTabStrip: some View {
        let tabWidth: CGFloat = 72
        let tabHeight: CGFloat = 48
        let tabs = visibleTabs
        let selectedIndex = tabs.firstIndex(of: selectedTab) ?? 0

        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        Haptics.fire(.light)
                        selectedTab = tab
                    } label: {
                        Icon(name: tab.icon, size: 20, weight: tab.fontWeight(selectedTab == tab))
                            .foregroundStyle(selectedTab == tab ? palette.foregroundColor : Color.charcoal)
                            .frame(width: tabWidth, height: tabHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Capsule()
                .fill(viewModel.theme.color.opacity(0.125))
                .frame(width: tabWidth, height: tabHeight)
                .offset(x: CGFloat(selectedIndex) * tabWidth)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
        }
        .frame(width: tabWidth * CGFloat(tabs.count), height: tabHeight)
    }
    
//    func updateTabBarScale(
//        shrinkSpeed: CGFloat = 0.015,
//        expandSpeed: CGFloat = 0.02,
//        minScale: CGFloat = 0.7,
//        maxScale: CGFloat = 1.0
//    ) {
//        let delta = offset - previousOffset
//        previousOffset = offset
//        
//        // Scrolling down → content moves up → shrink
//        if delta < 0 {
//            tabBarScale = max(minScale, tabBarScale + delta * shrinkSpeed)
//        }
//        
//        // Scrolling up → expand
//        else if delta > 0 {
//            tabBarScale = min(maxScale, tabBarScale + delta * expandSpeed)
//        }
//    }
}

// MARK: - Header

extension LiveRound {
    /// Nav header for scoring tab: X, hole selector, gear. Shown only when scoring tab is active.
    private var scoringNavHeader: some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                dismiss()
            }
            .highPriorityGesture(
                TapGesture().onEnded { _ in
                    Haptics.fire(.light)
                    dismiss()
                }
            )
            
            Spacer(minLength: 0)
            
            if selectedTab == .scoring {
                navHoleSelector
            } else if selectedTab == .matchups {
                Text("Matchups".uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Live round".uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer(minLength: 0)
            
            Menu {
                if !viewModel.isSpectator {
                    Button {
                        Haptics.fire(.light)
                        showEditRoundSheet = true
                    } label: {
                        Label("Edit round", systemImage: "pencil")
                    }
                }
                Button {
                    Haptics.fire(.light)
                    showShareRoundSheet = true
                } label: {
                    Label("Share round", systemImage: "qrcode")
                }
                
                Divider()
                
                Menu {
                    ForEach(GolfTheme.colorOptions, id: \.self) { t in
                        Button {
                            viewModel.theme = t
                        } label: {
                            HStack {
                                Text(t.displayName)
                                if viewModel.theme == t {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Theme", systemImage: "paintpalette")
                }
                .menuActionDismissBehavior(.disabled)
                .onTapGesture {
                    Haptics.fire(.light)
                }
                
                Menu {
                    Button {
                        Haptics.fire(.light)
                        viewModel.nameDisplayFormat = .firstInitialLastName
                    } label: {
                        HStack {
                            Text("J. Smith")
                            if viewModel.nameDisplayFormat == .firstInitialLastName {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button {
                        Haptics.fire(.light)
                        viewModel.nameDisplayFormat = .firstNameLastInitial
                    } label: {
                        HStack {
                            Text("John S.")
                            if viewModel.nameDisplayFormat == .firstNameLastInitial {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Label("Name display", systemImage: "person.text.rectangle")
                }
                .menuActionDismissBehavior(.disabled)
                .onTapGesture {
                    Haptics.fire(.light)
                }
                
                Button {
                    Haptics.fire(.light)
                    viewModel.autoAdvanceWhenHoleComplete.toggle()
                } label: {
                    Label(
                        "Auto-swipe",
                        systemImage: viewModel.autoAdvanceWhenHoleComplete
                        ? "checkmark.circle.fill"
                        : "circle"
                    )
                }
                .accessibilityHint("Jump to the next hole when scores are entered by you or others for the current hole")
                .menuActionDismissBehavior(.disabled)
                
                if !viewModel.isSpectator {
                    Divider()
                    Button(role: .destructive) {
                        Haptics.fire(.error)
                        showCompleteRoundSheet = true
                    } label: {
                        Label("Finish round", systemImage: "flag.checkered")
                    }
                }
            } label: {
                NavButton(style: .glass, icon: "gear", color: palette.foregroundColor)
            }
            .onTapGesture {
                Haptics.fire(.light)
            }
        }
    }
    
    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }

    private var navHoleSelector: some View {
        HoleWindowSelector(
            coordinator: pageCoordinator,
            holes: viewModel.holeNumbers,
            visibleSlotCount: 3,
            accentColor: effectiveAccent,
            activeColor: palette.foregroundColor,
            inactiveColor: .neutral2,
            fontSize: 14,
            slotSpacing: 10,
            itemSpacing: 4,
            indicatorHeight: 4,
            rowPadding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
            holeState: { hole in
                if shouldShowScoringSkeleton {
                    let current = scoringPageHole ?? viewModel.currentHoleNumber
                    return hole == current ? .current : .unscored
                }
                return viewModel.holeState(for: hole, currentHoleOverride: scoringPageHole)
            }
        ) { hole in
            print("hole tap change")
            Haptics.fire(.light)
            guard scoringPageHole != hole else { return }
            guard let targetIndex = viewModel.holeNumbers.firstIndex(of: hole) else { return }
            let currentIndex = viewModel.holeNumbers.firstIndex(of: scoringPageHole ?? viewModel.currentHoleNumber)
                ?? Int(pageCoordinator.fractionalIndex.rounded())
            let distance = abs(targetIndex - currentIndex)
            withAnimation(.spring(duration: holeScrollDuration(for: distance))) {
                scoringPageHole = hole
            }
        }
        .clipped()
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .glassCardEffect()
    }
}

extension LiveRound {
    var shouldShowScoringSkeleton: Bool {
        selectedTab == .scoring && isShowingInitialScoringSkeleton
    }

    private func fetchWeatherIfNeeded() async {
        await weatherService.fetchWeather(
            for: snapshot.course?.location?.toCLLocation() ?? locationService.location,
            mock: true
        )
    }

    private func runInitialScoringSkeletonIfNeeded() async {
        guard !hasHandledInitialScoringSkeleton else { return }
        hasHandledInitialScoringSkeleton = true

        let minimumDuration = TimeInterval(max(0, kMinSkeletonTime))
        let needsLoadingSkeleton = viewModel.snapshot.participants.isEmpty
        
        guard needsLoadingSkeleton else {
            isShowingInitialScoringSkeleton = false
            return
        }

        isShowingInitialScoringSkeleton = true
        let startedAt = Date()

        while true {
            let elapsed = Date().timeIntervalSince(startedAt)
            let metMinimumDuration = elapsed >= minimumDuration
            let isDataReady = !viewModel.snapshot.participants.isEmpty
            
            if metMinimumDuration && isDataReady {
                break
            }
            
            // Safety exit: avoid an indefinite skeleton if listeners fail.
            if elapsed >= kMaxSkeletonTime {
                break
            }

            try? await Task.sleep(for: .milliseconds(50))
        }

        withAnimation(.easeOut(duration: 0.18)) {
            isShowingInitialScoringSkeleton = false
        }
    }
}

//@MainActor
//private enum Mock {
//    static func appSesssion(
//        participantID: String? = nil,
//        playerID: String? = nil,
//        snapshot: RoundSnapshot? = nil
//    ) -> AppSession {
//        let session = AppSession()
//        
//        if let participantID {
//            session.ephemeralParticipantID = participantID
//        } else if let playerID, let snapshot,
//                  let participant = snapshot.participants.first(where: { $0.playerID == playerID }) {
//            session.ephemeralParticipantID = participant.id
//        }
//        
//        return session
//    }
//    
//    static func roundSession(using snapshot: RoundSnapshot) -> RoundSession {
//        let session = RoundSession()
//        session.snapshot = snapshot
//        return session
//    }
//}

#Preview("2v2 Red vs Blue") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRound2v2.snapshot)
}

#Preview("Ryder Cup (16, Mixed Groups)") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRoundRyderCup.snapshot)
}

#Preview("Four Teams (4x4)") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRoundFourTeams.snapshot)
}

#Preview("Matchups (Red vs Blue, Green vs Purple)") {
    LiveRound.ImmediatePreview(snapshot: MockLobbyMatchups.liveSnapshot)
}

#Preview("Best 2 of 4 Matchup (integrated groups)") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRoundBest2of4Matchup.snapshot)
}

//@MainActor
//private struct LiveRoundDelayedHydrationPreview: View {
//    @StateObject private var appSession: AppSession
//    @StateObject private var locationService: LocationService = .init()
//    @StateObject private var roundSession: RoundSession = .init()
//    
//    private let hydratedSnapshot: RoundSnapshot
//    private let simulatedLoadDelay: TimeInterval
//    
//    init(hydratedSnapshot: RoundSnapshot, simulatedLoadDelay: TimeInterval) {
//        _appSession = StateObject(
//            wrappedValue: Mock.appSesssion(
//                participantID: hydratedSnapshot.participants.first?.id,
//                snapshot: hydratedSnapshot
//            )
//        )
//        self.hydratedSnapshot = hydratedSnapshot
//        self.simulatedLoadDelay = simulatedLoadDelay
//    }
//    
//    var body: some View {
//        LiveRound()
//            .environmentObject(appSession)
//            .environmentObject(locationService)
//            .environmentObject(roundSession)
//            .task {
//                guard roundSession.snapshot.participants.isEmpty else { return }
//                try? await Task.sleep(for: .milliseconds(Int(simulatedLoadDelay * 1_000)))
//                roundSession.snapshot = hydratedSnapshot
//            }
//    }
//}
