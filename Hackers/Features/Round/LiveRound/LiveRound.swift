//
//  LiveRound.swift
//  Hackers
//
//  Created by Kyle Beard on 1/21/26.
//

import MapKit
import SwiftUI

private enum Tab: String, CaseIterable {
    case scoring, games, map, chat
    
    var icon: String {
        switch self {
        case .scoring: "menucard"
        case .games: "figure.golf"
        case .map: "map"
        case .chat: "bubble"
        }
    }
}

fileprivate let kMinSkeletonTime: CGFloat = 0.6
fileprivate let kMaxSkeletonTime: CGFloat = 12

struct HoleWindowSelector: View {
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    
    let holes: [Int]
    let selectedHole: Int
    let visibleSlotCount: Int
    let activeColor: Color
    let inactiveColor: Color
    let fontSize: CGFloat
    let slotSpacing: CGFloat
    let itemSpacing: CGFloat
    let indicatorHeight: CGFloat
    let rowPadding: EdgeInsets
    let onSelect: (Int) -> Void
    
    @State private var viewportWidth: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: slotSpacing) {
                    ForEach(holes, id: \.self) { hole in
                        let isCurrent = hole == selectedHole
                        
                        Button {
                            onSelect(hole)
                        } label: {
                            VStack(spacing: itemSpacing) {
                                Text("Hole \(hole)")
                                    .fontStyle(.poppins, size: fontSize, weight: isCurrent ? .semibold : .regular)
                                    .foregroundStyle(isCurrent ? activeColor : inactiveColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Capsule()
                                    .fill(isCurrent ? activeColor : Color.clear)
                                    .frame(height: indicatorHeight)
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
                let duration = min(0.55, 0.16 + (Double(max(0, holeDistance - 1)) * 0.045))
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
            withAnimation(.easeInOut(duration: duration)) {
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
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    @StateObject var viewModel: LiveRoundViewModel = .init()
    
    @State private var scoringScrollOffset: CGFloat = 0
    @State private var heroStartMinY: CGFloat = 0
    @State private var navTitleMinY: CGFloat = 0
    @State private var hasCapturedCollapseStart = false
    @State private var measuredHeroHeight: CGFloat = 0
    
    @State private var isShowingInitialScoringSkeleton = false
    @State private var hasHandledInitialScoringSkeleton = false
    @State var scoringPageHole: Int?
    @State var pendingProgrammaticScoringPageHole: Int?
    
    @State var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapInit = false
    
    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
    var navPadding: some View {
        navigationTitlePlaceholder
            .disabled(true)
            .opacity(0)
            .accessibilityHidden(true)
    }
    
    var body: some View {
        ZStack {
            GolfTopology()
                .frame(width: UIScreen.main.bounds.width)
            
            if selectedTab == .scoring {
                ObservableScrollView(offset: $scoringScrollOffset, axes: .vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        navPadding
                        
                        scoringContent
                        
                        Padding(.vertical, 120)
                    }
                }
            } else if selectedTab == .games {
                gameContent
                    .padding(.horizontal, 16)
            } else if selectedTab == .map {
                mapContent
            } else if selectedTab == .chat {
                chatContent
                    .padding(.horizontal, 16)
            }

            navigationTitleView
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
            if let id = appSession.activeRoundID, !roundSession.isRunning {
                await roundSession.start(for: id)
            }
            viewModel.bind(appSession: appSession, roundSession: roundSession)
            await runInitialScoringSkeletonIfNeeded()
            
            print("LIVE ROUND:")
            printPretty(roundSession.snapshot)
        }
        .onReceive(roundSession.$snapshot, perform: { _ in
            if mapInit { return }

            if let courseLocation = snapshot.course?.location {
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
        .onPreferenceChange(LiveRoundHeaderFramePreferenceKey.self) { frames in
            updateHeaderCollapseFrames(from: frames)
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .scoring {
                scoringScrollOffset = 0
                hasCapturedCollapseStart = false
            }
        }
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
                            tint: selectedTab == tab
                                ? Color.accentGreen.opacity(colorScheme.ultraTranslucent)
                                : Color.clear,
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
    private var navigationTitleView: some View {
        navigationTitleScaffold {
            headerTitleCard
        }
    }
    
    private var navigationTitlePlaceholder: some View {
        navigationTitleScaffold {
            courseHeaderTitle
                .padding(.vertical, 3)
                .padding(.horizontal, 24)
                .glassCardEffect()
        }
    }
    
    private func navigationTitleScaffold<CenterContent: View>(
        @ViewBuilder centerContent: () -> CenterContent
    ) -> some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                dismiss()
            }
            
            Spacer(minLength: 0)
            
            centerContent()
            
            Spacer(minLength: 0)
            
            NavButton(style: .glass, icon: "gear", weight: .regular, color: palette.foregroundColor) {
                print("todo: round configuration")
            }
        }
    }
    
    private var headerTitleCard: some View {
        ZStack {
            courseHeaderTitle
                .opacity(1 - headerTransitionProgress)
                .offset(y: accessibilityReduceMotion ? 0 : -8 * headerTransitionProgress)
                .scaleEffect(accessibilityReduceMotion ? 1 : (1 - (0.06 * headerTransitionProgress)))
                .accessibilityHidden(headerTransitionProgress > 0.5)
            
            compactHoleHeaderTitle
                .opacity(headerTransitionProgress)
                .offset(y: accessibilityReduceMotion ? 0 : 8 * (1 - headerTransitionProgress))
                .scaleEffect(accessibilityReduceMotion ? 1 : (0.94 + (0.06 * headerTransitionProgress)))
                .accessibilityHidden(headerTransitionProgress <= 0.5)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 24)
        .glassCardEffect()
        .liveRoundHeaderFrame(.navigationTitle)
    }
    
    private var courseHeaderTitle: some View {
        VStack(spacing: 2) {
            Text((snapshot.courseInfo?.name ?? "Live round").uppercased())
                .fontStyle(.poppins, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 6) {
                Text(snapshot.gameFormat.type.displayName)
                    .fontStyle(.poppins, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                
                Dot()
                
                Text(snapshot.holeSegment.title)
                    .fontStyle(.poppins, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            .fontStyle(.poppins, size: 12, weight: .regular)
            .foregroundStyle(Color.neutral)
        }
    }
    
    private var compactHoleHeaderTitle: some View {
        let labels = compactHoleMetricLabels
        
        return VStack(spacing: 2) {
            compactHoleSelector
            
            if labels.isPopulated {
                ViewThatFits(in: .horizontal) {
                    compactMetricLine(labels)
                }
            }
        }
    }

    private var compactHoleSelector: some View {
        HoleWindowSelector(
            holes: viewModel.holeNumbers,
            selectedHole: viewModel.currentHoleNumber,
            visibleSlotCount: 3,
            activeColor: palette.foregroundColor,
            inactiveColor: .neutral2,
            fontSize: 12,
            slotSpacing: 10,
            itemSpacing: 4,
            indicatorHeight: 2,
            rowPadding: EdgeInsets(top: 2, leading: 8, bottom: 0, trailing: 8)
        ) { hole in
            viewModel.selectHole(hole)
        }
    }
    
    private var compactHoleMetricLabels: [String] {
        let hole = viewModel.hole(for: viewModel.currentHoleNumber, teeID: viewModel.selectedTeeID)
        var labels: [String] = []
        
        if let hole {
            labels.append("Par \(hole.par)")
            labels.append("\(hole.yardage) yds")
            if let handicap = hole.handicap {
                labels.append("HCP \(handicap)")
            }
        }
        
        return labels
    }
    
    @ViewBuilder
    private func compactMetricLine(_ labels: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, value in
                if index > 0 {
                    Dot()
                }
                
                Text(value)
                    .fontStyle(.poppins, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Header Collapse

extension LiveRound {
    var headerCollapseProgress: CGFloat {
        guard selectedTab == .scoring, hasCapturedCollapseStart else { return 0 }
        let traveled = max(0, -scoringScrollOffset)
        let progress = traveled / heroCollapseDistance
        return min(max(progress, 0), 1)
    }
    
    var headerTransitionProgress: CGFloat {
        guard !accessibilityReduceMotion else {
            return headerCollapseProgress >= 0.55 ? 1 : 0
        }
        return headerCollapseProgress
    }
    
    var heroHeaderScale: CGFloat {
        guard !accessibilityReduceMotion else { return 1 }
        return 1 - (0.08 * headerTransitionProgress)
    }
    
    var heroHeaderOpacity: CGFloat {
        guard !accessibilityReduceMotion else {
            return headerTransitionProgress >= 1 ? 0 : 1
        }
        return max(0, 1 - (1.15 * headerTransitionProgress))
    }
    
    var heroHeaderVerticalOffset: CGFloat {
        guard !accessibilityReduceMotion else { return 0 }
        return -(measuredHeroHeight * 0.10 * headerTransitionProgress)
    }
    
    private var heroCollapseDistance: CGFloat {
        max(1, heroStartMinY - navTitleMinY)
    }
    
    private func updateHeaderCollapseFrames(from frames: [LiveRoundHeaderFrameID: CGRect]) {
        if let navFrame = frames[.navigationTitle], navFrame.height > 0 {
            if !hasCapturedCollapseStart || scoringScrollOffset >= -1 {
                navTitleMinY = navFrame.minY
            }
        }
        
        if let heroFrame = frames[.heroCard], heroFrame.height > 0 {
            measuredHeroHeight = heroFrame.height
            if !hasCapturedCollapseStart || scoringScrollOffset >= -1 {
                heroStartMinY = heroFrame.minY
            }
        }
        
        if heroStartMinY > 0, navTitleMinY > 0 {
            hasCapturedCollapseStart = true
        }
    }
}

extension LiveRound {
    var shouldShowScoringSkeleton: Bool {
        selectedTab == .scoring && isShowingInitialScoringSkeleton
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

enum LiveRoundHeaderFrameID: Hashable {
    case heroCard
    case navigationTitle
}

struct LiveRoundHeaderFramePreferenceKey: PreferenceKey {
    static var defaultValue: [LiveRoundHeaderFrameID: CGRect] = [:]
    
    static func reduce(
        value: inout [LiveRoundHeaderFrameID: CGRect],
        nextValue: () -> [LiveRoundHeaderFrameID: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func liveRoundHeaderFrame(_ id: LiveRoundHeaderFrameID) -> some View {
        background {
            GeometryReader { geom in
                Color.clear.preference(
                    key: LiveRoundHeaderFramePreferenceKey.self,
                    value: [id: geom.frame(in: .global)]
                )
            }
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
