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

fileprivate let kMinSkeletonTime: CGFloat = 0.8
fileprivate let kMaxSkeletonTime: CGFloat = 12

struct LiveRound: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    @StateObject var viewModel: LiveRoundViewModel = .init()
    
    @State private var tabBarScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    @State private var previousOffset: CGFloat = 0
    @State private var isShowingInitialScoringSkeleton = false
    @State private var hasHandledInitialScoringSkeleton = false
    
    @State var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapInit = false
    
    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
    var navPadding: some View { navigationTitleView.disabled(true).opacity(0) }
    
    var body: some View {
        ZStack {
            GolfTopology()
                .frame(width: UIScreen.main.bounds.width)
            
            if selectedTab == .scoring {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        navPadding
                        
                        scoringContent
                            .padding(.horizontal, 16)
                        
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
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                dismiss()
            }
            
            Spacer(minLength: 0)
            
            headerTitle
                .padding(.vertical, 3)
                .padding(.horizontal, 24)
                .glassCardEffect()
            
            Spacer(minLength: 0)
            
            NavButton(style: .glass, icon: "gear", weight: .regular, color: palette.foregroundColor) {
                print("todo: round configuration")
            }
        }
    }
    
    private var headerTitle: some View {
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
            
//            Text("\(snapshot.gameFormat.type.displayName)  •  \(snapshot.holeSegment.title)")
//                .fontStyle(.poppins, size: 12, weight: .regular)
//                .foregroundStyle(Color.neutral)
//                .lineLimit(1)
//                .minimumScaleFactor(0.7)
//                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Scroll Offset (tab bar scaling)

//extension LiveRound {
//    private var offsetReader: some View {
//        GeometryReader { geo in
//            Color.clear
//                .preference(
//                    key: ScrollOffsetKey.self,
//                    value: geo.frame(in: .named("liveround_scroll")).minY
//                )
//        }
//        .frame(height: 0)
//        .onPreferenceChange(ScrollOffsetKey.self) { value in
//            offset = value
//            updateTabBarScale()
//        }
//    }
//}

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
