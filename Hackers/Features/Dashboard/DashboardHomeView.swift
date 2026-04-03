//
//  DashboardHomeView.swift
//  Hackers
//
//  Home tab content for Dashboard.
//

import Flow
import SkeletonUI
import SwiftUI

enum PlayersSegment: String, CaseIterable {
    case recent = "Recent"
    case top = "Top"
}

enum CoursesSegment: String, CaseIterable {
    case recent = "Recent"
    case top = "Top"
}

private let kMinSkeletonTime: TimeInterval = 1.2
private let kMaxSkeletonTime: TimeInterval = 12

struct DashboardHomeView: View {
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @EnvironmentObject var locationService: LocationService
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var homeViewModel: DashboardHomeViewModel

    let palette: DesignPalette
    let sortedRounds: [Round]
    let activeRounds: [Round]
    let isLoadingRounds: Bool
    let onRoundTap: (Round) -> Void
    let onRouteToLobby: (String) -> Void
    var onSeeMoreActiveRounds: (() -> Void)?
    var onPlayNewRound: (() -> Void)?
    var onCreateSeries: (() -> Void)?
    var onSeriesTap: ((Series) -> Void)?

    @State private var playersSegment: PlayersSegment = .recent
    @State private var coursesSegment: CoursesSegment = .recent
    @State private var showDashboardSkeleton = true
    @State private var dashboardSkeletonStart: Date?
    @State private var showRecentPlayers = false
    @State private var showRecentCourses = false
    @State private var showPlayAgainSheet = false
    @State private var playAgainCourse: Course?
    @State private var showCourseSelectionForPreQueue = false
    @State private var showPlayerProfile: PlayerHistoryEntry?
    @State private var roundToDelete: Round?

    private var displayedPlayers: [PlayerHistoryEntry] {
        switch playersSegment {
        case .recent: return homeViewModel.recentPlayers
        case .top: return homeViewModel.topPlayers
        }
    }

    private var displayedCourses: [CourseHistoryEntry] {
        switch coursesSegment {
        case .recent: return homeViewModel.recentCourses
        case .top: return homeViewModel.topCourses
        }
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    navBarSpacer

                    VStack(spacing: 16) {
                        activeRoundSection
                        seriesSection
                        recentPlayersSection
                        recentCoursesSection
                    }
                    .padding(.horizontal, 16)

                    Padding(.vertical, 120)
                }
            }

            homeNavBar
                .alignTop()
        }
        .sheet(isPresented: $showRecentPlayers) {
            RecentPlayersView(
                homeViewModel: homeViewModel,
                palette: palette,
                sortedRounds: sortedRounds,
                currentPlayerID: viewModel.currentPlayerID,
                onDismiss: { showRecentPlayers = false },
                onAddToRound: { ids in
                    appSession.preQueuedPlayerIDs = ids
                    showRecentPlayers = false
                    showCourseSelectionForPreQueue = true
                },
                onRouteToLobby: onRouteToLobby,
                onRoundTap: { round in
                    showRecentPlayers = false
                    onRoundTap(round)
                }
            )
            .environmentObject(appSession)
            .environmentObject(roundSession)
        }
        .fullScreenCover(isPresented: $showCourseSelectionForPreQueue) {
            CourseSelectionView(
                viewModel: .init(),
                onCreation: { roundID in
                    showCourseSelectionForPreQueue = false
                    onRouteToLobby(roundID)
                }
            )
            .environmentObject(appSession)
            .environmentObject(roundSession)
            .environmentObject(locationService)
        }
        .sheet(isPresented: $showRecentCourses) {
            RecentCoursesView(
                homeViewModel: homeViewModel,
                palette: palette,
                onDismiss: { showRecentCourses = false },
                onPlayAgain: { entry in
                    showRecentCourses = false
                    playAgain(for: entry)
                }
            )
        }
        .fullScreenCover(isPresented: $showPlayAgainSheet) {
            if let course = playAgainCourse {
                CourseSelectionView(
                    viewModel: .init(course: course, tee: nil),
                    onCreation: { roundID in
                        showPlayAgainSheet = false
                        playAgainCourse = nil
                        onRouteToLobby(roundID)
                    }
                )
                .environmentObject(appSession)
                .environmentObject(roundSession)
                .environmentObject(locationService)
            }
        }
        .sheet(item: $showPlayerProfile) { entry in
            PlayerProfileView(
                entry: entry,
                palette: palette,
                sortedRounds: sortedRounds,
                currentPlayerID: viewModel.currentPlayerID,
                onRoundTap: onRoundTap,
                onDismiss: { showPlayerProfile = nil }
            )
            .environmentObject(appSession)
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if dashboardSkeletonStart == nil {
                dashboardSkeletonStart = Date()
            }
            if isLoadingRounds || homeViewModel.isLoading {
                dashboardSkeletonStart = Date()
                showDashboardSkeleton = true
            }
            runDashboardSkeletonTimingIfNeeded()
        }
        .onChange(of: isLoadingRounds) { _, isNowLoading in
            if isNowLoading {
                dashboardSkeletonStart = Date()
                showDashboardSkeleton = true
            } else {
                runDashboardSkeletonTimingIfNeeded()
            }
        }
        .onChange(of: homeViewModel.isLoading) { _, isNowLoading in
            if isNowLoading {
                dashboardSkeletonStart = Date()
                showDashboardSkeleton = true
            } else {
                runDashboardSkeletonTimingIfNeeded()
            }
        }
        .confirmationDialog("Delete round?", isPresented: Binding(
            get: { roundToDelete != nil },
            set: { if !$0 { roundToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { roundToDelete = nil }
            Button("Delete", role: .destructive) {
                guard let round = roundToDelete else { return }
                roundToDelete = nil
                Task { await appSession.deleteRound(round) }
            }
        } message: {
            Text("This will permanently delete the round and cannot be undone.")
        }
    }

    private func runDashboardSkeletonTimingIfNeeded() {
        guard !isLoadingRounds, !homeViewModel.isLoading else { return }
        let start = dashboardSkeletonStart ?? Date()
        Task {
            while true {
                let elapsed = Date().timeIntervalSince(start)
                let canHide = viewModel.currentPlayerID != nil || elapsed >= kMaxSkeletonTime
                if elapsed >= kMinSkeletonTime && canHide { break }
                if elapsed >= kMaxSkeletonTime { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            await MainActor.run {
                dashboardSkeletonStart = nil
                showDashboardSkeleton = false
            }
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
        }
    }

    @ViewBuilder
    private var activeRoundSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active rounds")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                if !activeRounds.isEmpty, let onSeeMore = onSeeMoreActiveRounds {
                    Button("See more") {
                        Haptics.fire(.light)
                        onSeeMore()
                    }
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                    .whiteGlassCardShadow(color: palette.shadowColor)
                }
            }

            if showDashboardSkeleton {
                activeRoundsSkeleton
            } else if activeRounds.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView(preset: .activeRounds)
                    if let onPlayNewRound {
                        Button("Play a new round") {
                            Haptics.fire(.light)
                            onPlayNewRound()
                        }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .whiteGlassCardShadow(color: palette.shadowColor)
                    }
                }
            } else {
                ForEach(activeRounds, id: \.self) { round in
                    Button {
                        Haptics.fire(.light)
                        onRoundTap(round)
                    } label: {
                        DashboardRoundTile(
                            round: round,
                            palette: palette,
                            showDate: false,
                            currentPlayerID: viewModel.currentPlayerID
                        )
                    }
                    .contextMenu {
                        Button {
                            Haptics.fire(.light)
                            onRoundTap(round)
                        } label: {
                            Label("Enter round", systemImage: "figure.golf")
                        }
                        if round.createdBy == viewModel.currentUserID, round.status != .archived {
                            Button {
                                Haptics.fire(.light)
                                Task { await appSession.archiveRound(round) }
                            } label: {
                                Label("Archive round", systemImage: "archivebox")
                            }
                        }
                        Divider()
                        if round.createdBy == viewModel.currentUserID {
                            Button(role: .destructive) {
                                Haptics.fire(.light)
                                roundToDelete = round
                            } label: {
                                Label("Delete round", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    private var activeRoundsSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                roundTileSkeleton
            }
        }
    }

    private var roundTileSkeleton: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.accentGreen.opacity(0.4),
                            background: Color.accentGreen.opacity(0.2)
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.6]
                    )
                    .frame(width: 140, height: 16)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.accentGreen.opacity(0.4),
                            background: Color.accentGreen.opacity(0.2)
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.4]
                    )
                    .frame(width: 80, height: 12)
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: Color.accentGreen.opacity(0.4),
                        background: Color.accentGreen.opacity(0.2)
                    ),
                    shape: .rounded(.radius(8)),
                    lines: 1,
                    scales: [1: 0.6]
                )
                .frame(width: 60, height: 24)
        }
        .padding(.vertical, 10)
    }

    private func seriesTileRow(for series: Series) -> some View {
        let linked = SeriesDashboardTileChip.linkedRoundsMap(from: appSession.rounds)
        let seriesRounds = appSession.seriesRoundsBySeriesID[series.id] ?? []
        let chipMode = SeriesDashboardTileChip.chipMode(seriesRounds: seriesRounds, linkedRounds: linked)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if series.activeAnnouncementCount > 0 {
                    Chip(
                        text: "New announcement",
                        icon: "f0a1",
                        iconWeight: .solid,
                        size: .xSmall,
                        foreground: Color.accentPurple,
                        background: Color.accentPurple.opacity(0.14)
                    )
                }
                Text(series.name)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text("\(series.roundCount) round\(series.roundCount == 1 ? "" : "s")")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            Spacer(minLength: 0)
            SeriesDashboardTileStatusChip(mode: chipMode)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var seriesSection: some View {
        let userSeries = appSession.seriesList
        VStack(spacing: 12) {
            HStack {
                Text("My series")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

//                if let onCreateSeries {
//                    Button("New") {
//                        Haptics.fire(.light)
//                        onCreateSeries()
//                    }
//                    .fontStyle(kFontName, size: 14, weight: .semibold)
//                    .foregroundStyle(Color.accentGreen)
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 8)
//                    .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
//                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
//                }
            }

            if userSeries.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView(preset: .mySeries)
                    if let onCreateSeries {
                        Button("Create series") {
                            Haptics.fire(.light)
                            onCreateSeries()
                        }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .whiteGlassCardShadow(color: palette.shadowColor)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(userSeries, id: \.id) { series in
                        Button {
                            Haptics.fire(.light)
                            onSeriesTap?(series)
                        } label: {
                            seriesTileRow(for: series)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    @ViewBuilder
    private var recentPlayersSection: some View {
        let players = Array(displayedPlayers.prefix(5))
        VStack(spacing: 12) {
            HStack {
                Text("Player History")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Button("See all") {
                    Haptics.fire(.light)
                    showRecentPlayers = true
                }
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                .whiteGlassCardShadow(color: palette.shadowColor)
                .opacity(players.isPopulated ? 1 : 0)
            }

            if showDashboardSkeleton {
                playerHistorySkeleton
            } else if players.isEmpty {
                EmptyStateView(preset: .playerHistory)
            } else {
                Picker("", selection: $playersSegment) {
                    ForEach(PlayersSegment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .alignLeading()

                VStack(spacing: 12) {
                    ForEach(players, id: \.playerID) { entry in
                        Button {
                            Haptics.fire(.light)
                            showPlayerProfile = entry
                        } label: {
                            DashboardPlayerRow(entry: entry, palette: palette)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    private var playerHistorySkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                playerRowSkeleton
            }
        }
    }

    private var playerRowSkeleton: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: Color.accentGreen.opacity(0.4),
                        background: Color.accentGreen.opacity(0.2)
                    ),
                    shape: .rounded(.radius(24)),
                    lines: 1,
                    scales: [1: 0.8]
                )
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.accentGreen.opacity(0.4),
                            background: Color.accentGreen.opacity(0.2)
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.5]
                    )
                    .frame(width: 120, height: 15)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.accentGreen.opacity(0.4),
                            background: Color.accentGreen.opacity(0.2)
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.25]
                    )
                    .frame(width: 90, height: 13)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var recentCoursesSection: some View {
        let courses = Array(displayedCourses.prefix(5))
        VStack(spacing: 12) {
            HStack {
                Text("Course History")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Button("See all") {
                    Haptics.fire(.light)
                    showRecentCourses = true
                }
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                .whiteGlassCardShadow(color: palette.shadowColor)
                .opacity(courses.isPopulated ? 1 : 0)
            }

            if showDashboardSkeleton {
                courseHistorySkeleton
            } else if courses.isEmpty {
                EmptyStateView(preset: .courseHistory)
            } else {
                Picker("", selection: $coursesSegment) {
                    ForEach(CoursesSegment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .alignLeading()

                VStack(spacing: 12) {
                    ForEach(courses, id: \.compositeKey) { entry in
                        DashboardCourseRow(
                            entry: entry,
                            palette: palette,
                            rank: coursesSegment == .top ? (homeViewModel.topCourses.firstIndex(where: { $0.courseID == entry.courseID }).map { $0 + 1 }) : nil,
                            onPlayAgain: { playAgain(for: entry) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    private var courseHistorySkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                playerRowSkeleton
            }
        }
    }

    private func playAgain(for entry: CourseHistoryEntry) {
        Task {
            let course: Course?
            switch entry.courseIDType {
            case .courseAPI:
                if let id = Int(entry.courseID),
                   let apiCourse = try? await GolfCourseAPI.shared.getCourse(by: id) {
                    course = Course(from: apiCourse, with: String(id), useStableTeeIDs: true)
                } else {
                    course = nil
                }
            case .manual:
                switch await FirebaseService.shared.getCourseByID(entry.courseID) {
                case .success(let c): course = c
                case .failure: course = nil
                }
            }
            await MainActor.run {
                if let course {
                    playAgainCourse = course
                    showPlayAgainSheet = true
                }
            }
        }
    }
}
