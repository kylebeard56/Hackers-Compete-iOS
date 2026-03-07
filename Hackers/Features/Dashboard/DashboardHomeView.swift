//
//  DashboardHomeView.swift
//  Hackers
//
//  Home tab content for Dashboard.
//

import Flow
import SwiftUI

enum PlayersSegment: String, CaseIterable {
    case recent = "Recent"
    case top = "Top"
}

enum CoursesSegment: String, CaseIterable {
    case recent = "Recent"
    case top = "Top"
}

struct DashboardHomeView: View {
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @EnvironmentObject var locationService: LocationService
    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var homeViewModel = DashboardHomeViewModel()

    let palette: DesignPalette
    let sortedRounds: [Round]
    let activeRounds: [Round]
    let onRoundTap: (Round) -> Void
    let onRouteToLobby: (String) -> Void

    @State private var playersSegment: PlayersSegment = .recent
    @State private var coursesSegment: CoursesSegment = .recent
    @State private var showRecentPlayers = false
    @State private var showRecentCourses = false
    @State private var showPlayAgainSheet = false
    @State private var playAgainCourse: Course?
    @State private var showCourseSelectionForPreQueue = false

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

                    if activeRounds.isPopulated {
                        activeRoundSection
                    }

                    recentPlayersSection
                    recentCoursesSection

                    Padding(.vertical, 120)
                }
            }

            homeNavBar
                .alignTop()
        }
        .task(id: viewModel.currentPlayerID) {
            await homeViewModel.load(primaryPlayerID: viewModel.currentPlayerID)
        }
        .sheet(isPresented: $showRecentPlayers) {
            RecentPlayersView(
                homeViewModel: homeViewModel,
                palette: palette,
                onDismiss: { showRecentPlayers = false },
                onAddToRound: { ids in
                    appSession.preQueuedPlayerIDs = ids
                    showRecentPlayers = false
                    showCourseSelectionForPreQueue = true
                },
                onRouteToLobby: onRouteToLobby
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
            Text("Active rounds".uppercased())
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()

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
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var recentPlayersSection: some View {
        let players = Array(displayedPlayers.prefix(5))
        if players.isPopulated || homeViewModel.recentPlayers.isPopulated || homeViewModel.topPlayers.isPopulated {
        VStack(spacing: 12) {
            HStack {
                Text("Player History")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
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
                .glassCardEffect(shape: .capsule)
            }
            
            Picker("", selection: $playersSegment) {
                ForEach(PlayersSegment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .alignLeading()

            VStack(spacing: 8) {
                ForEach(players, id: \.playerID) { entry in
                    DashboardPlayerRow(entry: entry, palette: palette)
                }
            }
        }
        .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var recentCoursesSection: some View {
        let courses = Array(displayedCourses.prefix(5))
        if courses.isPopulated || homeViewModel.recentCourses.isPopulated || homeViewModel.topCourses.isPopulated {
        VStack(spacing: 12) {
            HStack {
                Text("Course History")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
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
                .glassCardEffect(shape: .capsule)
            }
            
            Picker("", selection: $coursesSegment) {
                ForEach(CoursesSegment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .alignLeading()

            VStack(spacing: 8) {
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
        .padding(.horizontal, 16)
        }
    }

    private func playAgain(for entry: CourseHistoryEntry) {
        Task {
            let course: Course?
            switch entry.courseIDType {
            case .courseAPI:
                if let id = Int(entry.courseID),
                   let apiCourse = try? await GolfCourseAPI.shared.getCourse(by: id) {
                    course = Course(from: apiCourse)
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
