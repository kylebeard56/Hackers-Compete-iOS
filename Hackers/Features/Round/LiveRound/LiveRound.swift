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

struct HoleWindowSelector: View {
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    
    let holes: [Int]
    let selectedHole: Int
    let visibleSlotCount: Int
    let accentColor: Color
    let activeColor: Color
    let inactiveColor: Color
    let fontSize: CGFloat
    let slotSpacing: CGFloat
    let itemSpacing: CGFloat
    let indicatorHeight: CGFloat
    let rowPadding: EdgeInsets
    let holeState: (Int) -> LiveRoundViewModel.HoleDisplayState
    let onSelect: (Int) -> Void
    
    @State private var viewportWidth: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: slotSpacing) {
                    ForEach(holes, id: \.self) { hole in
                        let isCurrent = hole == selectedHole
                        let state = holeState(hole)
                        
                        Button {
                            onSelect(hole)
                        } label: {
                            VStack(spacing: 0) {
                                HStack(spacing: 3) {
                                    Text("Hole \(hole)")
                                        .fontStyle(kFontName, size: fontSize, weight: isCurrent ? .semibold : .medium)
                                        .foregroundStyle(holeForeground(isCurrent: isCurrent, state: state))

//                                    if !isCurrent {
//                                        holeStatusIcon(for: state)
//                                    }
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.vertical, itemSpacing)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())

                                if isCurrent {
                                    Capsule()
                                        .fill(accentColor)
                                        .padding(.horizontal, slotSpacing / 2)
                                        .frame(height: indicatorHeight)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Capsule()
                                        .fill(Color.clear)
                                        .frame(height: indicatorHeight)
                                }
                            }
                            .frame(width: slotWidth)
                        }
                        .buttonStyle(.plain)
                        .id(hole)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                alignStripIfNeeded(with: proxy, animated: false)
            }
            .onChange(of: selectedHole) { oldHole, newHole in
                guard oldHole != newHole else { return }
                let holeDistance = abs(newHole - oldHole)
                let shouldAnimate = !accessibilityReduceMotion && holeDistance > 0
                let duration = holeScrollDuration(for: holeDistance, totalHoles: holes.count)
                alignStripIfNeeded(with: proxy, animated: shouldAnimate, duration: duration)
            }
            .onChange(of: holes) { _, _ in
                alignStripIfNeeded(with: proxy, animated: false)
            }
            .onChange(of: viewportWidth) { _, _ in
                alignStripIfNeeded(with: proxy, animated: false)
            }
        }
        .padding(rowPadding)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        viewportWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, width in
                        viewportWidth = width
                    }
            }
        }
    }

    private func holeForeground(isCurrent: Bool, state: LiveRoundViewModel.HoleDisplayState) -> Color {
        if isCurrent { return accentColor }
        switch state {
        case .completed: return activeColor
        case .error: return .systemError
        case .unscored, .current: return inactiveColor
        }
    }

    @ViewBuilder
    private func holeStatusIcon(for state: LiveRoundViewModel.HoleDisplayState) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(activeColor)
        case .error:
//            Image(systemName: "exclamationmark.triangle")
            Image(systemName: "circle.dashed")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.systemError)
        case .unscored, .current:
            EmptyView()
        }
    }
    
    private var clampedSlotCount: Int {
        max(1, min(visibleSlotCount, max(holes.count, 1)))
    }
    
    private var slotWidth: CGFloat {
        let spacingWidth = CGFloat(max(0, clampedSlotCount - 1)) * slotSpacing
        let contentWidth = max(
            1,
            viewportWidth - rowPadding.leading - rowPadding.trailing - spacingWidth
        )
        return contentWidth / CGFloat(clampedSlotCount)
    }
    
    private func alignStripIfNeeded(
        with proxy: ScrollViewProxy,
        animated: Bool,
        duration: Double = 0.2
    ) {
        guard let startHole = alignedStartHole(for: selectedHole) else { return }
        
        let action = {
            proxy.scrollTo(startHole, anchor: .leading)
        }
        
        if animated {
            withAnimation(.snappy(duration: duration)) {
                action()
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                action()
            }
        }
    }
    
    private func alignedStartHole(for selectedHole: Int) -> Int? {
        guard !holes.isEmpty else { return nil }
        guard let selectedIndex = holes.firstIndex(of: selectedHole) else {
            return holes.first
        }
        
        let slotCount = max(1, min(visibleSlotCount, holes.count))
        let anchorIndex = slotCount / 2
        let maxStart = max(0, holes.count - slotCount)
        let startIndex = min(max(0, selectedIndex - anchorIndex), maxStart)
        return holes[startIndex]
    }
}

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
    @State var scoringPageHole: Int?
    @State var isProgrammaticHoleScroll = false
    
    @State var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapInit = false
    @StateObject var weatherService = WeatherService()

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
                        scoringContent
                        Padding(.vertical, 120)
                    }
                }
                .task {
                    //await fetchWeatherIfNeeded()
                }
//            } else if selectedTab == .games {
//                gameContent
//                    .padding(.horizontal, 16)
            } else if selectedTab == .map {
                mapContent
            } else if selectedTab == .chat {
                chatContent
                    .padding(.horizontal, 16)
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
//            .glassCardEffect(
//                cornerRadius: 100,
//                material: .ultraThinMaterial,
//                tint: Color.accentPurple.opacity(colorScheme.isDark ? 0.18 : 0.10),
//                strokeOpacity: colorScheme.isDark ? 0.20 : 0.30,
//                shadowOpacity: colorScheme.isDark ? 0.12 : 0.08
//            )
            .alignBottom()
        }
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
    
    private var navHoleSelector: some View {
        HoleWindowSelector(
            holes: viewModel.holeNumbers,
            selectedHole: viewModel.currentHoleNumber,
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
            viewModel.selectHole(hole)
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
