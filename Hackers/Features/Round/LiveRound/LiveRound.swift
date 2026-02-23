//
//  LiveRound.swift
//  Hackers
//
//  Created by Kyle Beard on 1/21/26.
//

import CoreLocation
import MapKit
import SwiftUI

private enum Tab: String, CaseIterable {
    case scoring
    //case games
    case map
    case chat
    
    // TODO: Add a finish button with a line divider when holes are complete
    // Gear icon also has an optional end round which will complete for that user.
    
    var icon: String {
        switch self {
        case .scoring: "menucard"
        //case .games: "figure.golf"
        case .map: "map"
        case .chat: "bubble"
        }
    }
}

fileprivate let kMinScrollDuration: Double = 0.25
fileprivate let kMaxScrollDuration: Double = 0.5

/// Compute scroll animation duration that scales linearly from
/// `kMinScrollDuration` (1-hole jump) to `kMaxScrollDuration` (max-distance jump).
/// The per-hole step is derived from `totalHoles` so the full range is always used.
func holeScrollDuration(for distance: Int, totalHoles: Int) -> Double {
    let clamped = max(1, distance)
    let maxSteps = max(1, totalHoles - 1)
    let step = (kMaxScrollDuration - kMinScrollDuration) / Double(maxSteps)
    return min(kMaxScrollDuration, kMinScrollDuration + Double(clamped - 1) * step)
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
    @State private var pageCoordinator = PageCoordinator()

    private var coordinatorSettledIndex: Int { Int(pageCoordinator.fractionalIndex.rounded()) }
    
    @State var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapInit = false
    @StateObject var weatherService = WeatherService()

    @State private var popupDetent: PresentationDetent = .height(ScorecardPopupLayout.initialLowHeight)
    @State private var effectiveSheetHeightForPadding: CGFloat = ScorecardPopupLayout.initialLowHeight

    @State private var showEditRoundSheet = false
    @State private var showShareRoundSheet = false
    
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
            BackgroundTheme(palette: self.palette, theme: viewModel.theme)
            
            if selectedTab == .scoring {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        navPadding
                        scoringContent
                        Spacer().frame(height: leaderboardBottomPadding)
                            .animation(.easeInOut(duration: 0.3), value: leaderboardBottomPadding)
                    }
                    .padding(.horizontal, 16)
                }
            } else if selectedTab == .map {
                mapContent
            } else if selectedTab == .chat {
                chatContent
                    .padding(.horizontal, 16)
            }

            if popupDetent == .large {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            scoringNavHeader
                .padding(.horizontal, 16)
                .alignTop()
            
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabItem(for: tab)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .glassCardEffect(
                shape: .capsule,
                material: .bar
            )
            .alignBottom()
        }
        .animation(.easeInOut(duration: 0.25), value: popupDetent)
        .navigationBarBackButtonHidden(true)
        .task {
            if let id = appSession.activeRoundID {
                if roundSession.roundID != id || !roundSession.isRunning {
                    await roundSession.start(for: id)
                }
            }
            viewModel.bind(appSession: appSession, roundSession: roundSession)
            await runInitialScoringSkeletonIfNeeded()
            viewModel.navigateToNextUnscoredHole()
            
            print("LIVE ROUND:")
            printPretty(roundSession.snapshot)
        }
        .sheet(isPresented: viewModel.isSpectator ? .false : .true) {
            ScorecardPopupView(
                viewModel: viewModel,
                palette: palette,
                coordinator: pageCoordinator,
                roundSession: roundSession,
                currentDetent: $popupDetent,
                effectiveSheetHeightForPadding: $effectiveSheetHeightForPadding
            )
        }
        // ── Coordinator ↔ ViewModel bridge ───────────────────────────────────
        .onChange(of: coordinatorSettledIndex) { _, newIndex in
            guard newIndex >= 0, newIndex < viewModel.holeNumbers.count else { return }
            let holeNumber = viewModel.holeNumbers[newIndex]
            guard holeNumber != viewModel.currentHoleNumber else { return }
            viewModel.selectHole(holeNumber)
        }
        .onChange(of: viewModel.currentHoleNumber) { _, newHole in
            guard let index = viewModel.holeNumbers.firstIndex(of: newHole) else { return }
            guard coordinatorSettledIndex != index else { return }
            pageCoordinator.scrollTo(index: index)
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
    
    private func tabItem(for tab: Tab) -> some View {
        Button {
            Haptics.fire(.light)
            selectedTab = tab
        } label: {
            ZStack {
                if selectedTab == tab {
                    Capsule()
                        .fill(.clear)
                        .frame(width: 72, height: 48)
                        .glassCardEffect(
                            cornerRadius: 24,
                            material: .ultraThinMaterial,
                            tint: selectedTab == tab ? viewModel.theme.color.opacity(0.125) : Color.clear,
                            strokeOpacity: colorScheme.isDark ? 0.20 : 0.30,
                            shadowOpacity: colorScheme.isDark ? 0.12 : 0.08
                        )
                } else {
                    Capsule()
                        .fill(.clear)
                        .frame(width: 72, height: 48)
                }
                
                Icon(name: tab.icon, size: 20, weight: .semibold)
                    .foregroundStyle(selectedTab == tab ? palette.foregroundColor : Color.charcoal)
            }
        }
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
            
            Spacer(minLength: 0)
            
            if selectedTab == .scoring {
                navHoleSelector
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
                        showEditRoundSheet = true
                    } label: {
                        Label("Edit round", systemImage: "pencil")
                    }
                }
                Button {
                    showShareRoundSheet = true
                } label: {
                    Label("Share round", systemImage: "qrcode")
                }
                Menu {
                    ForEach(GolfTheme.allCases, id: \.self) { t in
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
                Menu {
                    Button {
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
                if !viewModel.isSpectator {
                    Divider()
                    Button(role: .destructive) {
                        // Fake door - no action
                    } label: {
                        Label("Finish round", systemImage: "flag.checkered")
                    }
                }
            } label: {
                NavButton(style: .glass, icon: "gear", color: palette.foregroundColor)
//                Icon(name: "gear", size: 18, weight: .regular)
//                    .foregroundStyle(palette.foregroundColor)
//                    .frame(width: 44, height: 44)
            }
        }
    }
    
    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }

    private var leaderboardBottomPadding: CGFloat {
        effectiveSheetHeightForPadding + ScorecardPopupLayout.leaderboardBottomInset
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
                    return hole == viewModel.currentHoleNumber ? .current : .unscored
                }
                return viewModel.holeState(for: hole)
            }
        ) { hole in
            Haptics.fire(.light)
            guard let index = viewModel.holeNumbers.firstIndex(of: hole) else { return }
            pageCoordinator.scrollTo(index: index)
        }
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
    LiveRound.DelayedHydrationPreview(
        hydratedSnapshot: MockLiveRound2v2.snapshot,
        simulatedLoadDelay: TimeInterval(kMinSkeletonTime)
    )
}

#Preview("Ryder Cup (16, Mixed Groups)") {
    LiveRound.DelayedHydrationPreview(
        hydratedSnapshot: MockLiveRoundRyderCup.snapshot,
        simulatedLoadDelay: TimeInterval(kMinSkeletonTime)
    )
}

#Preview("Four Teams (4x4)") {
    LiveRound.DelayedHydrationPreview(
        hydratedSnapshot: MockLiveRoundFourTeams.snapshot,
        simulatedLoadDelay: TimeInterval(kMinSkeletonTime)
    )
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
