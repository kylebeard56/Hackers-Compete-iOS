//
//  SeriesView.swift
//  Hackers
//

import AlertToast
import SkeletonUI
import SwiftUI

private enum CommissionerChecklistRowKind {
    case required
    case optional
}

private enum SeriesTab: String, CaseIterable {
    case rounds
    case roster
    case standings

    var icon: String {
        switch self {
        case .rounds: return "e0d5"
        case .roster: return "f0c0"
        case .standings: return "f091"
        }
    }
}

struct SeriesView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession

    let seriesID: String

    @StateObject private var viewModel = SeriesViewModel()
    @State private var pageCoordinator = PageCoordinator()
    @State private var scrollPageID: Int? = 0

    @State private var showEditNameSheet = false
    @State private var showLeagueSettings = false
    @State private var showHandicapSettings = false
    @State private var showNewRoundSheet = false
    @State private var showAddPlayersSheet = false
    @State private var showSetDefaultCourseSheet = false
    @State private var roundToStart: SeriesRound?
    @State private var roundToEdit: SeriesRound?
    @State private var roundToAttendance: SeriesRound?
    @State private var roundForAwards: SeriesRound?
    @State private var roundToCorrectScores: SeriesRound?
    @State private var roundDecliningFor: SeriesRound?
    @State private var showDeclinedReasonAlert = false
    @State private var declinedReasonInput = ""
    @State private var showLeaveLeagueConfirmation = false
    @State private var roundForCompletionReview: SeriesRound?

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
    private var attendanceEnabled: Bool { viewModel.series.settings.isAttendanceEnabled }
    private var exportSheetPresented: Binding<Bool> {
        .init(
            get: { viewModel.exportedCSVURL != nil },
            set: { if !$0 { viewModel.exportedCSVURL = nil } }
        )
    }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .green)

            pagedContent

            navigationBar
                .padding(.horizontal, 16)
                .alignTop()

            tabBar
                .padding(.horizontal, 16)
                .alignBottom()
        }
        .navigationBarBackButtonHidden()
        .captureScreen("series")
        .task {
            appSession.activeSeriesID = seriesID
            TelemetryService.shared.setContext(seriesID: seriesID)
            await viewModel.load(seriesID: seriesID)
            await viewModel.createBuiltInScoringProfilesIfNeeded()
        }
        .onDisappear {
            guard appSession.activeSeriesID == seriesID else { return }
            appSession.activeSeriesID = nil
        }
        .sheet(isPresented: $showEditNameSheet) {
            EditSeriesNameView(currentName: viewModel.series.name) { newName in
                showEditNameSheet = false
                Task { await viewModel.updateName(newName) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLeagueSettings) {
            SeriesLeagueSettingsView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHandicapSettings) {
            SeriesHandicapSettingsView(viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPlayersSheet) {
            AddSeriesPlayersView(viewModel: viewModel) {
                showAddPlayersSheet = false
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNewRoundSheet) {
            NewSeriesRoundSheet(viewModel: viewModel) {
                showNewRoundSheet = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSetDefaultCourseSheet) {
            SetSeriesDefaultCourseSheet(viewModel: viewModel) {
                showSetDefaultCourseSheet = false
            }
            .environmentObject(appSession)
            .environmentObject(locationService)
            .environmentObject(roundSession)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundToEdit) { round in
            EditSeriesRoundSheet(viewModel: viewModel, seriesRound: round) {
                roundToEdit = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundToAttendance) { round in
            SeriesRoundAttendanceView(viewModel: viewModel, seriesRound: round) {
                roundToAttendance = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundForAwards) { round in
            SeriesRoundAwardsDetailSheet(viewModel: viewModel, seriesRound: round)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundToCorrectScores) { round in
            SeriesRoundScoreCorrectionSheet(viewModel: viewModel, seriesRound: round)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundToStart) { round in
            CourseSelectionForSeriesRoundSheet(viewModel: viewModel, seriesRound: round) { roundID in
                roundToStart = nil
                appSession.activeRoundID = roundID
                appSession.routeTo(.lobby)
            }
            .environmentObject(appSession)
            .environmentObject(locationService)
            .environmentObject(roundSession)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundForCompletionReview) { round in
            SeriesCompletionReviewSheet(viewModel: viewModel, seriesRound: round)
                .background(palette.backgroundColor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: exportSheetPresented) {
            if let fileURL = viewModel.exportedCSVURL {
                SeriesCSVShareSheet(fileURL: fileURL)
            }
        }
        .toast(isPresenting: $viewModel.isLoading, alert: { AlertToast.loader() })
        .alert("Leave League", isPresented: $showLeaveLeagueConfirmation) {
            Button("Leave", role: .destructive) {
                Task {
                    await viewModel.leaveLeague()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your membership will be removed. Your historical scores and round data will be preserved, but you will lose access to this series.")
        }
    }

    // MARK: - Navigation Bar

    private var navBarSpacer: some View {
        navigationBar
            .disabled(true)
            .opacity(0)
            .accessibilityHidden(true)
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor, onTap: {
                dismiss()
            })

            Spacer(minLength: 0)

            glassTitleCard

            Spacer(minLength: 0)

            Menu {
                if viewModel.isCommissioner {
                    Button {
                        Haptics.fire(.light)
                        showEditNameSheet = true
                    } label: {
                        Label("Edit name", systemImage: "pencil")
                    }

                    Button {
                        Haptics.fire(.light)
                        showLeagueSettings = true
                    } label: {
                        Label("League settings", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        Haptics.fire(.light)
                        showSetDefaultCourseSheet = true
                    } label: {
                        Label("Default course", systemImage: "flag")
                    }

                    Button {
                        Haptics.fire(.light)
                        showHandicapSettings = true
                    } label: {
                        Label("Handicap settings", systemImage: "figure.golf")
                    }
                } else {
                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        showLeaveLeagueConfirmation = true
                    } label: {
                        Label("Leave league", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                NavButton(style: .glass, icon: "f013", color: palette.foregroundColor)
            }
            .onTapGesture { Haptics.fire(.light) }
        }
    }

    private var glassTitleCard: some View {
        VStack(spacing: 2) {
            Text(viewModel.series.name.isEmpty ? "Series" : viewModel.series.name.uppercased())
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(viewModel.isCommissioner ? "Commissioner" : viewModel.series.status.rawValue.capitalized)
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 24)
        .glassCardEffect()
    }

    // MARK: - Paged Content

    private var pagedContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(SeriesTab.allCases.enumerated()), id: \.element) { index, tab in
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
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                let width = geo.containerSize.width
                guard width > 0 else { return 0 }
                return geo.contentOffset.x / width
            } action: { _, newFractional in
                pageCoordinator.fractionalIndex = newFractional
            }
            .onChange(of: pageCoordinator.programmaticTarget) { _, targetIndex in
                guard let targetIndex, targetIndex < SeriesTab.allCases.count else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(targetIndex, anchor: .leading)
                }
                pageCoordinator.resetTarget()
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: SeriesTab) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                navBarSpacer

                if viewModel.isCommissioner && !viewModel.isLoading && !viewModel.checklistComplete {
                    commissionerChecklist
                }

                switch tab {
                case .rounds:
                    roundsTabContent
                case .roster:
                    rosterTabContent
                case .standings:
                    standingsTabContent
                }

                Padding(.vertical, 120)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            seriesTabStrip
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .glassCardEffect(
                    shape: .capsule,
                    material: .bar,
                    interactive: true,
                    tint: nil
                )
        }
    }

    @ViewBuilder
    private var seriesTabStrip: some View {
        let tabWidth: CGFloat = 72
        let tabHeight: CGFloat = 48
        let tabs = SeriesTab.allCases
        let fractionalIndex = pageCoordinator.fractionalIndex
        let settledIndex = Int(fractionalIndex.rounded())
        let clampedFraction = min(max(0, fractionalIndex), CGFloat(tabs.count - 1))
        let capsuleX = clampedFraction * tabWidth

        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
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
        .frame(width: tabWidth * CGFloat(tabs.count), height: tabHeight)
    }

    // MARK: - Commissioner Checklist

    private var commissionerChecklist: some View {
        VStack(spacing: 12) {
            Text("Get started".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            checklistRow(
                kind: .required,
                title: "Add more players",
                subtitle: nil,
                done: viewModel.hasPlayers
            ) {
                Haptics.fire(.light)
                showAddPlayersSheet = true
            }
            checklistRow(
                kind: .required,
                title: "Schedule first round",
                subtitle: nil,
                done: viewModel.hasScheduledRound
            ) {
                Haptics.fire(.light)
                showNewRoundSheet = true
            }
            checklistRow(
                kind: .required,
                title: "Set league rules",
                subtitle: nil,
                done: viewModel.hasScoringRules
            ) {
                Haptics.fire(.light)
                showLeagueSettings = true
            }
            checklistRow(
                kind: .optional,
                title: "Set default course",
                subtitle: viewModel.hasDefaultCourse
                    ? "League default is ready"
                    : "Optional, but it speeds up round launch",
                done: viewModel.hasDefaultCourse
            ) {
                Haptics.fire(.light)
                showSetDefaultCourseSheet = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCardEffect()
        .padding(.horizontal, 16)
    }

    private func checklistRow(
        kind: CommissionerChecklistRowKind,
        title: String,
        subtitle: String?,
        done: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                checklistLeadingIndicator(kind: kind, done: done)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .multilineTextAlignment(.leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Icon(name: "f054", size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .opacity(done ? 0.35 : 1)
                    .padding(.top, 2)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func checklistLeadingIndicator(kind: CommissionerChecklistRowKind, done: Bool) -> some View {
        Group {
            if done {
                Icon(name: "f058", size: 20, weight: .solid)
                    .foregroundStyle(Color.accentGreen)
            } else if kind == .required {
                Icon(name: "f111", size: 20, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                Circle()
                    .strokeBorder(
                        Color.neutral,
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .frame(width: 18, height: 18)
            }
        }
        .frame(width: 20, height: 20)
    }

    // MARK: - Rounds Tab

    private var roundsTabContent: some View {
        VStack(spacing: 16) {
            if viewModel.rounds.isEmpty {
                EmptyStateView(
                    imageName: "LeaderboardIsometric",
                    title: "No rounds scheduled",
                    subtitle: "Schedule your first round to get the league calendar moving."
                )
                .frame(minHeight: 280)

                if viewModel.isCommissioner {
                    primaryCapsuleButton("Schedule round") {
                        Haptics.fire(.light)
                        showNewRoundSheet = true
                    }
                }
            } else {
                if viewModel.upcomingRounds.isPopulated {
                    seriesRoundSection(title: "Upcoming", rounds: viewModel.upcomingRounds)
                }
                if viewModel.completedRounds.isPopulated {
                    seriesRoundSection(title: "Completed", rounds: viewModel.completedRounds)
                }
                if viewModel.canceledRounds.isPopulated {
                    seriesRoundSection(title: "Canceled", rounds: viewModel.canceledRounds)
                }

                if viewModel.isCommissioner {
                    primaryCapsuleButton("Schedule round") {
                        Haptics.fire(.light)
                        showNewRoundSheet = true
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

//    @ViewBuilder
//    private func rsvpButton(for round: SeriesRound) -> some View {
//        let status = viewModel.currentAttendanceStatus(for: round.id)
//        Menu {
//            Button {
//                Haptics.fire(.light)
//                guard let memberID = viewModel.currentMemberID else { return }
//                Task {
//                    await viewModel.updateAttendance(
//                        seriesRoundID: round.id,
//                        memberID: memberID,
//                        status: .accepted,
//                        declinedNote: nil
//                    )
//                }
//            } label: {
//                Label("Attending", systemImage: "checkmark")
//            }
//            Button {
//                Haptics.fire(.light)
//                roundDecliningFor = round
//                declinedReasonInput = ""
//                showDeclinedReasonAlert = true
//            } label: {
//                Label("Declined", systemImage: "xmark")
//            }
//            Button {
//                Haptics.fire(.light)
//                guard let memberID = viewModel.currentMemberID else { return }
//                Task {
//                    await viewModel.updateAttendance(
//                        seriesRoundID: round.id,
//                        memberID: memberID,
//                        status: .pending,
//                        declinedNote: nil
//                    )
//                }
//            } label: {
//                Label("Pending", systemImage: "questionmark")
//            }
//        } label: {
//            Group {
//                switch status {
//                case .accepted:
//                    Text("attending")
//                        .fontStyle(kFontName, size: 13, weight: .semibold)
//                        .foregroundStyle(Color.accentGreen)
//                case .no:
//                    Text("declined")
//                        .fontStyle(kFontName, size: 13, weight: .semibold)
//                        .foregroundStyle(Color.systemError)
//                default:
//                    Text("RSVP")
//                        .fontStyle(kFontName, size: 13, weight: .semibold)
//                        .foregroundStyle(palette.foregroundColor)
//                }
//            }
//            .lineLimit(1)
//            .padding(.horizontal, 14)
//            .padding(.vertical, 8)
//            .frame(minHeight: 36)
//            .fixedSize(horizontal: true, vertical: false)
//            .background(Color.neutral6)
//            .clipShape(Capsule())
//        }
//        .buttonStyle(.plain)
//        .alert("Why can't you make it?", isPresented: $showDeclinedReasonAlert) {
//            TextField("Optional reason", text: $declinedReasonInput)
//            Button("Save") {
//                guard let round = roundDecliningFor, let memberID = viewModel.currentMemberID else { return }
//                Task {
//                    await viewModel.updateAttendance(
//                        seriesRoundID: round.id,
//                        memberID: memberID,
//                        status: .no,
//                        declinedNote: declinedReasonInput.isEmpty ? nil : declinedReasonInput
//                    )
//                }
//                roundDecliningFor = nil
//            }
//            Button("Skip", role: .cancel) {
//                guard let round = roundDecliningFor, let memberID = viewModel.currentMemberID else { return }
//                Task {
//                    await viewModel.updateAttendance(
//                        seriesRoundID: round.id,
//                        memberID: memberID,
//                        status: .no,
//                        declinedNote: nil
//                    )
//                }
//                roundDecliningFor = nil
//            }
//        } message: {
//            Text("Add an optional note explaining why you can't attend.")
//        }
//    }

    private func seriesRoundSection(title: String, rounds: [SeriesRound]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .padding(.leading, 4)

            if viewModel.isLoading {
                let skeletonCount = rounds.isEmpty ? 2 : rounds.count
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    seriesRoundSkeletonRow()
                }
            } else {
                ForEach(rounds, id: \.id) { round in
                    seriesRoundRow(round)
                }
            }
        }
    }

    private func seriesRoundSkeletonRow() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(6))
                    )
                    .frame(width: 120, height: 15)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(10))
                    )
                    .frame(width: 44, height: 18)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(4))
                    )
                    .frame(width: 160, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(4))
                    )
                    .frame(width: 110, height: 12)
            }

            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .skeleton(
                                with: true,
                                animation: .linear(duration: 1.6),
                                appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                                shape: .rounded(.radius(4))
                            )
                            .frame(width: 24, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .skeleton(
                                with: true,
                                animation: .linear(duration: 1.6),
                                appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                                shape: .rounded(.radius(4))
                            )
                            .frame(width: 40, height: 10)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(22))
                    )
                    .frame(height: 44)
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(22))
                    )
                    .frame(height: 44)
            }
        }
        .padding(14)
        .glassCardEffect(cornerRadius: 14)
    }

    private func seriesRoundRow(_ round: SeriesRound) -> some View {
        let status = viewModel.effectiveStatus(for: round)
        let counts = viewModel.attendanceCounts(for: round.id)
        let isScored = status == .live && viewModel.allScoresComplete(for: round)
        let resolvedCourse = round.resolvedCourse(using: viewModel.series)
        let courseName = resolvedCourse?.cachedName ?? "Course TBD"
        let segmentName = resolvedCourse?.holeSegment.title ?? "Full 18"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(round.title.isEmpty ? "Round \(round.index + 1)" : round.title)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)

                roundStatusChip(for: status, isScored: isScored)

                Spacer(minLength: 0)

                seriesRoundOverflowMenuButton(round: round, status: status)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isScored || status == .complete {
                    let completedTime = round.completedAt ?? round.scheduledAt
                    if let time = completedTime {
                        Text(formattedCompletionDate(for: time))
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                } else if let scheduledAt = round.scheduledAt {
                    Text(formattedSchedule(for: scheduledAt))
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Text("\(courseName) \(kDot) \(segmentName)")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.accentGreen)

                Text(round.roundConfig.template.name)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            if round.isAdjusted {
                Chip(
                    text: "Adjusted",
                    size: .xSmall,
                    foreground: .orange,
                    background: Color.orange.opacity(colorScheme.translucent)
                )
            }

            if (isScored || status == .complete), round.roundID != nil {
                let playerCount = viewModel.linkedRound(for: round)?.players.count ?? counts.playing
                HStack(spacing: 10) {
                    Text("\(playerCount) of \(viewModel.eligibleMembers.count)")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)

                    userParticipationBadge(for: round)

                    Spacer(minLength: 0)
                }
            } else if attendanceEnabled && (status == .planned || status == .lobby || status == .live) {
                HStack(spacing: 16) {
                    verticalAttendanceCount(count: counts.playing, label: "Playing", color: .accentGreen)
                    verticalAttendanceCount(count: counts.declined, label: "Declined", color: .systemError)
                    verticalAttendanceCount(count: counts.noResponse, label: "Pending", color: .neutral)
                    Spacer(minLength: 0)
                }
            }

            if status == .planned || status == .lobby || status == .live {
                HStack(alignment: .center, spacing: 10) {
//                    if viewModel.currentMemberID != nil {
//                        rsvpButton(for: round)
//                    }

                    if attendanceEnabled {
                        let rsvp = viewModel.currentAttendanceStatus(for: round.id)

                        PrimaryButton(
                            appearance: .fill,
                            title: rsvp.buttonLabel,
                            icon: rsvp.buttonIcon,
                            iconWeight: .solid,
                            labelColor: rsvp.labelColor(palette: palette),
                            buttonColor: rsvp.buttonColor(palette: palette),
                            theme: palette.theme,
                            height: 44,
                            fontSize: 14,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { roundToAttendance = round }
                        )
                    }

                    if viewModel.isCommissioner {
                        commissionerActionButton(for: round, status: status)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else if let roundID = round.roundID, status != .planned {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Open round",
                            labelColor: .white,
                            buttonColor: Color.accentGreen,
                            theme: palette.theme,
                            height: 44,
                            fontSize: 14,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { openRound(round) }
                        )
                    }
                }
            } else if status == .complete, round.roundID != nil {
                HStack(spacing: 10) {
                    primaryCapsuleButton("Awards", fill: palette.whiteGlassButtonColor, foreground: palette.foregroundColor) {
                        Haptics.fire(.light)
                        roundForAwards = round
                    }

                    if viewModel.isCommissioner {
                        primaryCapsuleButton("Correct", fill: Color.neutral5, foreground: palette.foregroundColor) {
                            Haptics.fire(.light)
                            roundToCorrectScores = round
                        }
                    }
                }
            } else if !viewModel.isCommissioner, round.roundID != nil, status != .planned {
                primaryCapsuleButton("Open round", fill: Color.accentGreen) {
                    openRound(round)
                }
            }
        }
        .padding(14)
        .glassCardEffect(cornerRadius: 14)
    }

    @ViewBuilder
    private func commissionerActionButton(for round: SeriesRound, status: SeriesRoundStatus) -> some View {
        if status == .planned && round.roundID == nil {
            PrimaryButton(
                appearance: .fill,
                title: viewModel.creatingRoundID == round.id ? "Starting..." : "Start round",
                labelColor: .white,
                buttonColor: Color.accentGreen,
                theme: palette.theme,
                height: 44,
                fontSize: 14,
                isDisabled: .constant(false),
                isLoading: Binding(
                    get: { viewModel.creatingRoundID == round.id },
                    set: { _ in }
                ),
                onTap: { startRound(round) }
            )
        } else if round.roundID != nil {
            PrimaryButton(
                appearance: .fill,
                title: "Open round",
                labelColor: .white,
                buttonColor: Color.accentGreen,
                theme: palette.theme,
                height: 44,
                fontSize: 14,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTap: { openRound(round) }
            )
        }
    }

    private func roundStatusChip(for status: SeriesRoundStatus, isScored: Bool = false) -> some View {
        let tint: Color
        let label: String
        switch status {
        case .live, .lobby:
            tint = isScored ? .systemBlue : .accentGreen
            label = isScored ? "Scored" : status.rawValue.capitalized
        case .complete:
            tint = .systemBlue
            label = "Scored"
        case .canceled:
            tint = .systemError
            label = status.rawValue.capitalized
        case .planned:
            tint = .neutral
            label = status.rawValue.capitalized
        }

        return Text(label)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCardEffect(cornerRadius: 10, tint: tint.opacity(0.12))
    }

    private func verticalAttendanceCount(count: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .fontStyle(kFontName, size: 18, weight: .bold)
                .foregroundStyle(color)
            Text(label)
                .fontStyle(kFontName, size: 11, weight: .medium)
                .foregroundStyle(color)
        }
    }

    private func formattedSchedule(for time: Time) -> String {
        let date = Date(timeIntervalSince1970: time.unix)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE MMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        let relativeStr = relative.localizedString(for: date, relativeTo: Date())
        return "\(dayFormatter.string(from: date)) at \(timeFormatter.string(from: date)) (\(relativeStr))"
    }

    private func formattedCompletionDate(for time: Time) -> String {
        let date = Date(timeIntervalSince1970: time.unix)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return "Completed \(formatter.string(from: date))"
    }

    @ViewBuilder
    private func userParticipationBadge(for round: SeriesRound) -> some View {
        if let context = viewModel.currentUserScoreContext(for: round) {
            if context.played {
                let scoreText = context.scoreLabel ?? "—"
                Text(scoreText)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentGreen.opacity(colorScheme.translucent))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("—")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.systemError)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.systemError.opacity(colorScheme.translucent))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func seriesRoundOverflowMenuButton(round: SeriesRound, status: SeriesRoundStatus) -> some View {
        Menu {
            seriesRoundOverflowMenuContent(round: round, status: status)
        } label: {
            Icon(name: "f141", size: 16, weight: .regular)
                .foregroundStyle(Color.neutral)
                .padding(8)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
        }
    }

    @ViewBuilder
    private func seriesRoundOverflowMenuContent(round: SeriesRound, status: SeriesRoundStatus) -> some View {
        if attendanceEnabled && (status == .planned || status == .lobby || status == .live) {
            Button {
                Haptics.fire(.light)
                roundToAttendance = round
            } label: {
                Label("Attendance", systemImage: "person.2")
            }
        }

        if round.roundID != nil {
            Button {
                openRound(round)
            } label: {
                Label("Open round", systemImage: "arrow.right.circle")
            }
        }

        if status == .complete {
            Button {
                Haptics.fire(.light)
                roundForAwards = round
            } label: {
                Label("View awards", systemImage: "rosette")
            }
        }

        if viewModel.isCommissioner {
            if status == .planned {
                if round.roundID == nil {
                    Button {
                        Haptics.fire(.light)
                        startRound(round)
                    } label: {
                        Label("Start round", systemImage: "play.fill")
                    }

                    Button {
                        Haptics.fire(.light)
                        startRound(round, forceCourseSelection: true)
                    } label: {
                        Label("Change course before start", systemImage: "flag")
                    }
                }

                Button {
                    Haptics.fire(.light)
                    roundToEdit = round
                } label: {
                    Label("Edit round", systemImage: "pencil")
                }

                Button {
                    Haptics.fire(.light)
                    Task { _ = await viewModel.duplicateRound(round) }
                } label: {
                    Label("Duplicate round", systemImage: "doc.on.doc")
                }

                Divider()
                
                if round.roundID == nil {
                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        Task { await viewModel.deleteScheduledRound(round) }
                    } label: {
                        Label("Delete round", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        Task { await viewModel.cancelRound(round) }
                    } label: {
                        Label("Cancel round", systemImage: "xmark.circle")
                    }
                }
            } else {
                if round.roundID != nil, status == .live {
                    Button {
                        Haptics.fire(.light)
                        roundForCompletionReview = round
                    } label: {
                        Label("Review scores", systemImage: "checkmark.shield")
                    }
                }

                if round.roundID != nil {
                    Button {
                        Haptics.fire(.light)
                        Task { _ = await viewModel.exportCSV(for: round) }
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                }

                if status == .complete, round.roundID != nil {
                    Button {
                        Haptics.fire(.light)
                        roundToCorrectScores = round
                    } label: {
                        Label("Correct scores", systemImage: "pencil.and.outline")
                    }
                }
                
                if round.roundID != nil, status != .complete, status != .canceled {
                    Button {
                        Haptics.fire(.light)
                        roundToEdit = round
                    } label: {
                        Label("Edit round settings", systemImage: "slider.horizontal.3")
                    }
                    
                    Divider()

                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        Task { await viewModel.cancelRound(round) }
                    } label: {
                        Label("Cancel round", systemImage: "xmark.circle")
                    }
                }
            }
        }
    }

    private func openRound(_ round: SeriesRound) {
        guard let roundID = round.roundID else { return }
        Haptics.fire(.light)
        appSession.activeRoundID = roundID
        let status = viewModel.effectiveStatus(for: round)
        appSession.routeTo(status == .live ? .liveRound : .lobby)
    }

    private func startRound(_ round: SeriesRound, forceCourseSelection: Bool = false) {
        guard viewModel.creatingRoundID != round.id else { return }
        guard forceCourseSelection || round.resolvedCourse(using: viewModel.series) == nil else {
            Task {
                if let roundID = await viewModel.createLiveRound(from: round) {
                    appSession.activeRoundID = roundID
                    appSession.routeTo(.lobby)
                }
            }
            return
        }

        roundToStart = round
    }

    private func primaryCapsuleButton(
        _ title: String,
        fill: Color = .accentGreen,
        foreground: Color = .white,
        fillWidth: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .background(fill)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Roster Tab

    private var rosterTabContent: some View {
        SeriesRosterView(viewModel: viewModel, palette: palette) {
            showAddPlayersSheet = true
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Standings Tab

    private var standingsTabContent: some View {
        SeriesLeaderboardView(
            viewModel: viewModel,
            palette: palette,
            onOpenRoundDetails: { round in
                roundForAwards = round
            }
        )
            .padding(.horizontal, 16)
    }
}

private struct SeriesCSVShareSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let fileURL: URL

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "CSV Export",
                subtitle: "Your league round export is ready to share.",
                onClose: { dismiss() }
            )

            VStack(spacing: 20) {
                Image(systemName: "tablecells.badge.ellipsis")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)

                Text("League round export is ready.")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                ShareLink(item: fileURL) {
                    Chip(
                        text: "Share CSV",
                        size: .small,
                        foreground: .white,
                        background: Color.accentGreen
                    )
                }

                Text(fileURL.lastPathComponent)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }
}
