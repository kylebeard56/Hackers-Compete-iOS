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
    case table
    case matchups

    var title: String {
        switch self {
        case .scoring: "Scorecard"
        case .table: "Table"
        case .matchups: "Matchups"
        }
    }

    var icon: String {
        switch self {
        case .scoring: "menucard"
        case .table: "tablecells"
        case .matchups: "f71d"  // Font Awesome crossed swords
        }
    }

    var iconType: IconType {
        switch self {
        case .scoring, .table: .sanFrancisco
        case .matchups: .fontAwesome
        }
    }

    func fontWeight(isSelected: Bool) -> FontModule.Weight {
        isSelected ? iconType.activeWeight : iconType.normalWeight
    }
}

/// Scroll animation duration: 0.28s base + 0.02s per additional hole beyond the first.
func holeScrollDuration(for distance: Int) -> Double {
    0.28 + Double(max(0, distance - 1)) * 0.02
}

fileprivate let kMinSkeletonTime: CGFloat = 1.2
fileprivate let kMaxSkeletonTime: CGFloat = 12

struct LiveRound: View, Loggable {
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @CappedScaledMetric(relativeTo: .body) var leaderboardHeaderScoreWidth: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body) var leaderboardHeaderThruWidth: CGFloat = 54
    @CappedScaledMetric(relativeTo: .body) var skeletonAvatarSize: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var skeletonNameHeight: CGFloat = 17
    @CappedScaledMetric(relativeTo: .caption) var skeletonSubtitleHeight: CGFloat = 12
    @CappedScaledMetric(relativeTo: .body) var skeletonButtonWidth: CGFloat = 120
    @CappedScaledMetric(relativeTo: .body) var skeletonButtonHeight: CGFloat = 32
    @CappedScaledMetric(relativeTo: .body) var skeletonCellSize: CGFloat = 30
    @CappedScaledMetric(relativeTo: .caption) var skeletonCellHeight: CGFloat = 15
    @CappedScaledMetric(relativeTo: .body) var leaderboardScrollMaxHeight: CGFloat = 360
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var liveRoundCompanion: LiveRoundCompanionCoordinator
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    @StateObject var viewModel: LiveRoundViewModel
    @StateObject private var tablePresentationState: FullScorecardPresentationState
    
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
    @State private var didTrackLiveRoundView = false
    @State var showRevealConfirmation = false

    @MainActor
    init(viewModel: LiveRoundViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? LiveRoundViewModel())
        _tablePresentationState = StateObject(wrappedValue: FullScorecardPresentationState())
    }

    /// Complete-round FAB when the user may finish (any hole); CompleteRoundSheet warns about unscored holes and offers "Mark as max score".
    private var shouldShowCompleteRoundButton: Bool {
        viewModel.canCompleteActualGroup && viewModel.holeNumbers.isPopulated
    }

    private var showsLiveRoundChrome: Bool {
        selectedTab != .table || !tablePresentationState.isRotated
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
            } else if selectedTab == .table {
                tableContent
            } else if selectedTab == .matchups {
                matchupsContent
            }

            if showsLiveRoundChrome {
                scoringNavHeader
                    .padding(.horizontal, 16)
                    .alignTop()
            }

            if visibleTabs.count > 1 && showsLiveRoundChrome {
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

            if shouldShowCompleteRoundButton && showsLiveRoundChrome {
                HStack {
                    Spacer(minLength: 0)
                    NavButton(style: .glass, icon: "f00c", size: 24) {
                        Haptics.fire(.light)
                        showCompleteRoundSheet = true
                    }
                }
                .padding(.horizontal, 16)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: shouldShowCompleteRoundButton)
                .alignBottom()
            }
        }
        .navigationBarBackButtonHidden(true)
        .captureScreen("live_round")
        .task {
            TelemetryService.shared.setContext(roundID: appSession.activeRoundID, seriesID: appSession.activeSeriesID)
            if let id = appSession.activeRoundID {
                await roundSession.activate(roundID: id, profile: .liveRound)
            }
            activateCompanionsIfPossible()
            print(roundSession.snapshot.round.id)
            viewModel.bind(appSession: appSession, roundSession: roundSession)
            synchronizeCompanionMatchupBasis()
            viewModel.startMatchupProbabilityPrecomputation()
            restoreDurableRoundContextIfNeeded()
            trackLiveRoundViewedIfNeeded(snapshot: roundSession.snapshot)
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
        .onChange(of: scoringPageHole) { _, hole in
            persistDurableRoundContext(hole: hole)
        }
        .onChange(of: selectedTab) { oldTab, _ in
            if oldTab == .table {
                tablePresentationState.resetForTabExit()
            }
            persistDurableRoundContext(hole: scoringPageHole)
        }
        .onChange(of: viewModel.matchupScoreBasis) { _, _ in
            synchronizeCompanionMatchupBasis()
        }
        .onChange(of: viewModel.visibleGroupSwitchRequest?.revisionID) { _, _ in
            applyVisibleGroupSwitchIfNeeded()
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
        .sheet(item: $viewModel.presentedParticipant) { participant in
            PlayerInsightsView(
                viewModel: viewModel,
                participant: participant
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .onReceive(roundSession.$snapshot, perform: { _ in
            trackLiveRoundViewedIfNeeded(snapshot: roundSession.snapshot)
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
        .onReceive(HackersNotification.appSceneDidBecomeActive.publisher()) { _ in
            guard let id = appSession.activeRoundID else { return }
            Task { await roundSession.activate(roundID: id, profile: .liveRound) }
        }
        .onDisappear {
            tablePresentationState.resetForTabExit()
        }
    }

    private func restoreDurableRoundContextIfNeeded() {
        guard let state = appSession.roundResumeState,
              state.roundID == appSession.activeRoundID else {
            persistDurableRoundContext(hole: viewModel.currentHoleNumber)
            return
        }

        if let selectedHole = state.selectedHole, viewModel.holeNumbers.contains(selectedHole) {
            viewModel.selectHole(selectedHole)
            scoringPageHole = selectedHole
        }

        let restoredTab: Tab
        switch state.selectedTab {
        case .scoring: restoredTab = .scoring
        case .table: restoredTab = .table
        case .matchups: restoredTab = .matchups
        }
        selectedTab = visibleTabs.contains(restoredTab) ? restoredTab : .scoring
        persistDurableRoundContext(hole: scoringPageHole ?? viewModel.currentHoleNumber)
    }

    private func persistDurableRoundContext(hole: Int?) {
        appSession.updateLiveRoundResume(
            selectedHole: hole,
            selectedTab: {
                switch selectedTab {
                case .scoring: .scoring
                case .table: .table
                case .matchups: .matchups
                }
            }()
        )
    }
    
    /// Scorecard and Table are always available; Matchups appears for valid matchup rounds.
    private var visibleTabs: [Tab] {
        let matchups = snapshot.roundSegment?.matchups ?? []
        let expectedMode = viewModel.expectedMatchupMode
        let matchupsForMode = matchups.filter { $0.effectiveMode == expectedMode }
        let validMatchupsForMode = matchupsForMode.filter { $0.isValid }
        let showMatchups = snapshot.configuration.resolvedCompetitionScope == .matchup && !validMatchupsForMode.isEmpty
        return showMatchups ? [.scoring, .table, .matchups] : [.scoring, .table]
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
                        Icon(
                            name: tab.icon,
                            size: 20,
                            weight: tab.fontWeight(isSelected: selectedTab == tab)
                        )
                            .foregroundStyle(selectedTab == tab ? palette.foregroundColor : Color.charcoal)
                            .frame(width: tabWidth, height: tabHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
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

    @ViewBuilder
    private var tableContent: some View {
        if let participant = viewModel.currentParticipant ?? snapshot.participants.first {
            VStack(spacing: 8) {
                if !tablePresentationState.isRotated {
                    navPadding
                }

                FullScorecardView(
                    viewModel: viewModel,
                    participant: participant,
                    allowsScoreEditing: viewModel.canEditActualGroupScores,
                    initialSelectedScoringUnitID: participant.id,
                    presentation: .embeddedLiveTable,
                    presentationState: tablePresentationState
                )
            }
            .padding(.top, tablePresentationState.isRotated ? 0 : UIApplication.shared.topSafeAreaInset)
            .padding(.bottom, tablePresentationState.isRotated ? 0 : 88)
        } else {
            ContentUnavailableView(
                "Score table unavailable",
                systemImage: "tablecells",
                description: Text("Players will appear here when the round is ready.")
            )
            .padding(24)
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
                appSession.clearRoundResume()
                dismiss()
            }
            .highPriorityGesture(
                TapGesture().onEnded { _ in
                    Haptics.fire(.light)
                    appSession.clearRoundResume()
                    dismiss()
                }
            )
            
            Spacer(minLength: 0)
            
            if selectedTab == .scoring {
                navHoleSelector
            } else if selectedTab == .table {
                Text("Score table".uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                if selectedTab == .table {
                    Section(header: Text("Score table")) {
                        Button {
                            Haptics.fire(.light)
                            tablePresentationState.showPlayerVisibilitySheet = true
                        } label: {
                            Label("Visible players", systemImage: "person.2")
                        }

                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tablePresentationState.showPar.toggle()
                            }
                        } label: {
                            Label(
                                "Par",
                                systemImage: tablePresentationState.showPar ? "checkmark.circle.fill" : "circle"
                            )
                        }
                        .menuActionDismissBehavior(.disabled)

                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tablePresentationState.showYardage.toggle()
                            }
                        } label: {
                            Label(
                                "Yardage",
                                systemImage: tablePresentationState.showYardage ? "checkmark.circle.fill" : "circle"
                            )
                        }
                        .menuActionDismissBehavior(.disabled)

                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tablePresentationState.showHandicap.toggle()
                            }
                        } label: {
                            Label(
                                "Hole handicap",
                                systemImage: tablePresentationState.showHandicap ? "checkmark.circle.fill" : "circle"
                            )
                        }
                        .menuActionDismissBehavior(.disabled)

                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tablePresentationState.isRotated = true
                            }
                        } label: {
                            Label("Rotate table", systemImage: "rotate.right")
                        }
                    }

                    Divider()
                }

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

                if viewModel.canChangeVisibleGroup {
                    Menu {
                        ForEach(viewModel.orderedTeeGroups, id: \.id) { group in
                            changeGroupMenuButton(for: group)
                        }
                    } label: {
                        Label("Change group", systemImage: "arrow.left.arrow.right")
                    }
                }

                if viewModel.canChangeVisibleGroupStartingHole {
                    Menu {
                        ForEach(viewModel.startingHoleMenuNumbers, id: \.self) { hole in
                            startingHoleMenuButton(hole)
                        }
                    } label: {
                        Label("Starting hole", systemImage: "flag")
                    }
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

                    Button {
                        Haptics.fire(.light)
                        viewModel.showScorelessLeaderboardRows.toggle()
                    } label: {
                        Label(
                            "Show scoreless",
                            systemImage: viewModel.showScorelessLeaderboardRows
                            ? "checkmark.circle.fill"
                            : "circle"
                        )
                    }
                    .menuActionDismissBehavior(.disabled)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
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
                
                if viewModel.canManageRound
                    && snapshot.isSecretScoring
                    && !snapshot.areScoresRevealed {
                    Divider()
                    Button {
                        Haptics.fire(.light)
                        showRevealConfirmation = true
                    } label: {
                        Label("Reveal scores", systemImage: "eye")
                    }
                }

                if viewModel.canCompleteActualGroup {
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
        viewModel.theme.color
    }

    private func activateCompanionsIfPossible() {
        let roundID = snapshot.round.id
        guard roundID.isPopulated else { return }
        liveRoundCompanion.select(roundID: roundID)
    }

    private func synchronizeCompanionMatchupBasis() {
        let roundID = snapshot.round.id
        guard roundID.isPopulated else { return }
        liveRoundCompanion.synchronizeMatchupScoreBasis(
            viewModel.matchupScoreBasis,
            roundID: roundID
        )
    }

    @ViewBuilder
    private func changeGroupMenuButton(for group: TeeTimeGroup) -> some View {
        let subtitle = viewModel.groupMenuSubtitle(for: group)
        let isSelected = viewModel.visibleTeeGroupID == group.id

        Button {
            Haptics.fire(.light)
            viewModel.selectVisibleTeeGroup(group.id)
        } label: {
            if isSelected {
                Label(group.name, systemImage: "checkmark")
                if subtitle.isPopulated {
                    Text(subtitle)
                }
            } else {
                Text(group.name)
                if subtitle.isPopulated {
                    Text(subtitle)
                }
            }
        }
    }

    @ViewBuilder
    private func startingHoleMenuButton(_ hole: Int) -> some View {
        Button {
            Haptics.fire(.light)
            Task { await viewModel.changeVisibleTeeGroupStartingHole(to: hole) }
        } label: {
            if viewModel.visibleStartingHole == hole {
                Label("Hole \(hole)", systemImage: "checkmark")
            } else {
                Text("Hole \(hole)")
            }
        }
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
            dismissSwipeHintIfNeeded()
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

    private func applyVisibleGroupSwitchIfNeeded() {
        guard let request = viewModel.visibleGroupSwitchRequest else { return }
        dismissSwipeHintIfNeeded()
        viewModel.selectHole(request.targetHoleNumber)
        scoringPageHole = request.targetHoleNumber
        if let targetIndex = viewModel.holeNumbers.firstIndex(of: request.targetHoleNumber) {
            pageCoordinator.scrollTo(index: targetIndex, duration: holeScrollDuration(for: 1))
        }
    }
}

extension LiveRound {
    var shouldShowScoringSkeleton: Bool {
        selectedTab == .scoring && isShowingInitialScoringSkeleton
    }

    private func trackLiveRoundViewedIfNeeded(snapshot: RoundSnapshot) {
        guard !didTrackLiveRoundView else { return }
        guard snapshot.round.id.isPopulated else { return }
        didTrackLiveRoundView = true
        addEvent(
            "live_round.viewed",
            eventProps: telemetryRoundProperties(
                snapshot: snapshot,
                extra: [
                    "is_spectator": viewModel.isSpectator
                ]
            )
        )
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

#Preview("Series Commissioner Group Switch") {
    LiveRound.ImmediatePreview(
        snapshot: MockLiveRoundVisibilityPreview.snapshot,
        participantID: nil,
        useFirstParticipantIfMissing: false,
        seriesID: "series_preview",
        isCommissioner: true
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
