//
//  SeriesView.swift
//  Hackers
//

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

/// Matches former `primaryCapsuleButton` on round tiles (~8pt vertical padding + 14pt label).
private enum SeriesRoundTileButtonMetrics {
    static let height: CGFloat = 36
    static let fontSize: CGFloat = 14
    static let iconSize: CGFloat = 14
}

/// Nav spacer, bottom scroll inset (`Padding(.vertical, 120)`), and margin so empty-state spacers can center in the viewport.
private enum SeriesTabScrollLayout {
    static let emptyRoundsChromeVertical: CGFloat = 195
}

private struct LeagueDescriptionCollapsedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct LeagueDescriptionFullHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SeriesCSVExportSheetContext: Identifiable {
    var id: String
    var preselectedRoundID: String?

    static var series: SeriesCSVExportSheetContext {
        SeriesCSVExportSheetContext(id: "series", preselectedRoundID: nil)
    }

    static func round(_ round: SeriesRound) -> SeriesCSVExportSheetContext {
        SeriesCSVExportSheetContext(id: "round_\(round.id)", preselectedRoundID: round.id)
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
    @State private var tabScrollViewportHeight: CGFloat = 0

    @State private var showLeagueSettings = false
    @State private var showHandicapSettings = false
    @State private var showNewRoundSheet = false
    @State private var showAddPlayersSheet = false
    @State private var showSetDefaultCourseSheet = false
    @State private var roundToStart: SeriesRound?
    @State private var roundToEdit: SeriesRound?
    @State private var roundToPreviewTeeSheet: SeriesRound?
    @State private var roundToAttendance: SeriesRound?
    @State private var roundForAwards: SeriesRound?
    @State private var roundToCorrectScores: SeriesRound?
    @State private var roundToSyncFromLeague: SeriesRound?
    @State private var roundDecliningFor: SeriesRound?
    @State private var showDeclinedReasonAlert = false
    @State private var declinedReasonInput = ""
    @State private var showLeaveLeagueConfirmation = false
    @State private var roundForCompletionReview: SeriesRound?
    @State private var showAnnouncementsSheet = false
    @State private var showShareSeries = false
    @State private var csvExportSheetContext: SeriesCSVExportSheetContext?
    @State private var announcementEditorContext: SeriesAnnouncementEditorContext?
    @State private var isLeagueDescriptionExpanded = false
    @State private var leagueDescriptionCollapsedHeight: CGFloat = 0
    @State private var leagueDescriptionFullHeight: CGFloat = 0

    @Namespace private var seriesShareTransition

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
        .alert(
            "Cannot start round",
            isPresented: Binding(
                get: { viewModel.roundCreationErrorMessage != nil },
                set: { if !$0 { viewModel.roundCreationErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.roundCreationErrorMessage = nil
            }
        } message: {
            if let message = viewModel.roundCreationErrorMessage {
                Text(message)
            }
        }
        .task {
            appSession.activeSeriesID = seriesID
            TelemetryService.shared.setContext(seriesID: seriesID)
            await viewModel.load(seriesID: seriesID)
        }
        .onDisappear {
            guard appSession.activeSeriesID == seriesID else { return }
            appSession.activeSeriesID = nil
        }
        .sheet(isPresented: $showLeagueSettings) {
            SeriesLeagueSettingsView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAnnouncementsSheet) {
            SeriesAnnouncementsView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSeries) {
            ShareSeriesView(viewModel: viewModel)
                .navigationTransition(.zoom(sourceID: "qr", in: seriesShareTransition))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $announcementEditorContext) { ctx in
            SeriesAnnouncementEditorSheet(viewModel: viewModel, context: ctx) {
                announcementEditorContext = nil
            }
            .presentationDetents([.medium, .large])
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
        .sheet(item: $roundToPreviewTeeSheet) { round in
            SeriesRoundTeeSheetPreviewSheet(viewModel: viewModel, seriesRound: round)
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
        .sheet(item: $roundToSyncFromLeague) { round in
            SeriesRoundSyncSheet(viewModel: viewModel, seriesRound: round) {
                roundToSyncFromLeague = nil
            }
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
        .sheet(item: $csvExportSheetContext) { context in
            SeriesCSVExportOptionsSheet(
                viewModel: viewModel,
                preselectedRoundID: context.preselectedRoundID
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: exportSheetPresented) {
            if let fileURL = viewModel.exportedCSVURL {
                SeriesCSVShareSheet(
                    fileURL: fileURL,
                    experiencePreset: viewModel.series.experiencePreset,
                    skippedRoundTitles: viewModel.skippedCSVExportRoundTitles
                )
            }
        }
        .alert(viewModel.series.experiencePreset.leaveAlertTitle, isPresented: $showLeaveLeagueConfirmation) {
            Button("Leave", role: .destructive) {
                Task {
                    await viewModel.leaveLeague()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.series.experiencePreset.leaveAlertMessage)
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
                Button {
                    Haptics.fire(.light)
                    showShareSeries = true
                } label: {
                    Label(viewModel.series.experiencePreset.shareSheetTitle, systemImage: "qrcode")
                }
                
                Divider()

                if viewModel.isCommissioner {
                    Button {
                        Haptics.fire(.light)
                        showAnnouncementsSheet = true
                    } label: {
                        Label("Announcements", systemImage: "megaphone.fill")
                    }
                    
                    Button {
                        Haptics.fire(.light)
                        showLeagueSettings = true
                    } label: {
                        Label(viewModel.series.experiencePreset.gearMenuSettingsLabel, systemImage: "slider.horizontal.3")
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

                    Button {
                        Haptics.fire(.light)
                        csvExportSheetContext = .series
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                } else {
                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        showLeaveLeagueConfirmation = true
                    } label: {
                        Label(viewModel.series.experiencePreset.leaveMenuLabel, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                NavButton(style: .glass, icon: "f013", color: palette.foregroundColor)
                    .matchedTransitionSource(id: "qr", in: seriesShareTransition)
            }
            .onTapGesture { Haptics.fire(.light) }
        }
    }

    private var glassTitleCard: some View {
        VStack(spacing: 2) {
            Text(viewModel.series.name.isEmpty ? viewModel.series.experiencePreset.unnamedExperienceNavTitle : viewModel.series.name.uppercased())
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

                if tab == .rounds, viewModel.activeAnnouncements.isPopulated {
                    SeriesActiveAnnouncementsSection(
                        announcements: viewModel.activeAnnouncements,
                        palette: palette
                    )
                }

                if tab == .rounds, viewModel.isCommissioner, !viewModel.isLoading, !viewModel.checklistComplete {
                    commissionerChecklist
                }

                if tab == .rounds, !viewModel.isLoading {
                    leagueInfoCard
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
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { _, newHeight in
            tabScrollViewportHeight = newHeight
        })
        .refreshable {
            await viewModel.refreshLinkedRoundState()
        }
    }

    // MARK: - Tab Bar

    private var glassWrappedTabStrip: some View {
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            if viewModel.isCommissioner {
                glassWrappedTabStrip
                Spacer(minLength: 8)
                seriesPlusMenuButton
            } else {
                Spacer(minLength: 0)
                glassWrappedTabStrip
                Spacer(minLength: 0)
            }
        }
    }

    private var seriesPlusMenuButton: some View {
        Menu {
            Button {
                Haptics.fire(.light)
                showNewRoundSheet = true
            } label: {
                Label("New round", systemImage: "calendar.badge.plus")
            }

            Button {
                Haptics.fire(.light)
                showAddPlayersSheet = true
            } label: {
                Label("Add players", systemImage: "person.badge.plus")
            }

            Button {
                Haptics.fire(.light)
                announcementEditorContext = .newAnnouncement()
            } label: {
                Label("New announcement", systemImage: "megaphone.fill")
            }
        } label: {
            NavButton(style: .glass, icon: "2b", size: 24)
        }
        .onTapGesture {
            Haptics.fire(.light)
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
                title: viewModel.series.experiencePreset.checklistSetRulesRowTitle,
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
                    ? viewModel.series.experiencePreset.checklistDefaultCourseReadySubtitle
                    : "Optional, but it speeds up round launch",
                done: viewModel.hasDefaultCourse
            ) {
                Haptics.fire(.light)
                showSetDefaultCourseSheet = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
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

    private var leagueInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(leagueInfoTitle)
                        .fontStyle(kFontName, size: 22, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if let description = trimmedLeagueDescription {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(description)
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .lineLimit(isLeagueDescriptionExpanded ? nil : 3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .topLeading) {
                                    leagueDescriptionMeasuringText(description, lineLimit: 3)
                                        .background {
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: LeagueDescriptionCollapsedHeightKey.self,
                                                    value: proxy.size.height
                                                )
                                            }
                                        }
                                }
                                .overlay(alignment: .topLeading) {
                                    leagueDescriptionMeasuringText(description, lineLimit: nil)
                                        .background {
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: LeagueDescriptionFullHeightKey.self,
                                                    value: proxy.size.height
                                                )
                                            }
                                        }
                                }

                            if shouldShowLeagueDescriptionToggle {
                                Button {
                                    Haptics.fire(.light)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isLeagueDescriptionExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(isLeagueDescriptionExpanded ? "Show less" : "See more")
                                            .fontStyle(kFontName, size: 13, weight: .semibold)

                                        Icon(
                                            name: isLeagueDescriptionExpanded ? "chevron.up" : "chevron.down",
                                            size: 12,
                                            weight: .semibold
                                        )
                                    }
                                    .foregroundStyle(Color.accentGreen)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isCommissioner {
                    NavButton(
                        style: .glass,
                        icon: "f044",
                        size: 16,
                        weight: .regular,
                        color: palette.foregroundColor,
                        theme: palette.theme
                    ) {
                        showLeagueSettings = true
                    }
                    .accessibilityLabel("Edit league details")
                }
            }

            HStack(spacing: 8) {
                ForEach(Array(leagueInfoStats.enumerated()), id: \.offset) { _, stat in
                    leagueInfoStatTile(value: stat.value, label: stat.label)
                }
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
        .padding(.horizontal, 16)
        .onPreferenceChange(LeagueDescriptionCollapsedHeightKey.self) { height in
            leagueDescriptionCollapsedHeight = height
        }
        .onPreferenceChange(LeagueDescriptionFullHeightKey.self) { height in
            leagueDescriptionFullHeight = height
        }
        .accessibilityElement(children: .contain)
    }

    private var leagueInfoTitle: String {
        viewModel.series.name.isEmpty ? viewModel.series.experiencePreset.unnamedExperienceNavTitle : viewModel.series.name
    }

    private var trimmedLeagueDescription: String? {
        let trimmed = (viewModel.series.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isPopulated ? trimmed : nil
    }

    private var shouldShowLeagueDescriptionToggle: Bool {
        leagueDescriptionFullHeight > leagueDescriptionCollapsedHeight + 1
    }

    private func leagueDescriptionMeasuringText(_ description: String, lineLimit: Int?) -> some View {
        Text(description)
            .fontStyle(kFontName, size: 14, weight: .regular)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hidden()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var leagueInfoStats: [(value: String, label: String)] {
        let players = String(viewModel.eligibleMembers.count)
        let rounds = String(viewModel.rounds.count)
        if viewModel.series.settings.useTeams || viewModel.teams.isPopulated {
            return [
                (players, "Players"),
                (rounds, "Rounds"),
                (String(viewModel.teams.count), "Teams")
            ]
        }
        let completed = viewModel.rounds.filter { viewModel.effectiveStatus(for: $0) == .complete }.count
        return [
            (players, "Players"),
            (rounds, "Rounds"),
            (String(completed), "Complete")
        ]
    }

    private func leagueInfoStatTile(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label.uppercased())
                .fontStyle(kFontName, size: 10, weight: .semibold)
                .foregroundStyle(palette.foregroundColor.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(leagueInfoStatTileFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(leagueInfoStatTileStroke, lineWidth: 1)
        }
        .shadow(color: palette.shadowColor.opacity(colorScheme.isLight ? 0.55 : 0.2), radius: 8, y: 4)
        .accessibilityLabel("\(value) \(label)")
    }

    private var leagueInfoStatTileFill: Color {
        colorScheme.isLight ? palette.backgroundColor : palette.cardColor
    }

    private var leagueInfoStatTileStroke: Color {
        colorScheme.isLight ? Color.neutral4.opacity(0.55) : Color.white.opacity(0.12)
    }

    // MARK: - Rounds Tab

    private var roundsTabContent: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    seriesRoundSkeletonRow()
                }
            } else if viewModel.rounds.isEmpty {
                EmptyStateView(
                    imageName: "LeaderboardIsometric",
                    title: "No rounds scheduled",
                    subtitle: viewModel.series.experiencePreset.roundsEmptyStateSubtitle
                )
                .alignMiddle()
            } else {
                if viewModel.inProgressRounds.isPopulated {
                    seriesRoundSection(title: "Active", rounds: viewModel.inProgressRounds)
                }
                if viewModel.plannedRounds.isPopulated {
                    seriesRoundSection(title: "Upcoming", rounds: viewModel.plannedRounds)
                }
                if viewModel.completedRounds.isPopulated {
                    seriesRoundSection(title: "Completed", rounds: viewModel.completedRounds)
                }
                if viewModel.canceledRounds.isPopulated {
                    seriesRoundSection(title: "Canceled", rounds: viewModel.canceledRounds)
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

            ForEach(rounds, id: \.id) { round in
                seriesRoundRow(round)
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
                    .frame(height: SeriesRoundTileButtonMetrics.height)
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(22))
                    )
                    .frame(height: SeriesRoundTileButtonMetrics.height)
            }
        }
        .padding(14)
        .glassCardEffect(cornerRadius: 14, forceMaterial: true, tint: palette.cardColor)
    }

    private func formattedScheduleCompact(for time: Time) -> String {
        let date = Date(timeIntervalSince1970: time.unix)
        let calendar = Calendar.current
        if calendar.isDateInToday(date)    { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE MMM d"
        let dayString = dayFormatter.string(from: date)

        let startOfToday  = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        if let days = components.day, days > 0 {
            return "\(dayString) \(kDot) \(days) days away"
        }
        return dayString
    }

    private func roundSubtitle(for round: SeriesRound,
                                status: SeriesRoundStatus,
                                courseName: String,
                                isScored: Bool) -> String {
        let datePart: String
        if isScored || status == .complete {
            let time = round.completedAt ?? round.scheduledAt
            if let time {
                let date = Date(timeIntervalSince1970: time.unix)
                let f = DateFormatter(); f.dateFormat = "EEE MMM d"
                datePart = "Completed \(f.string(from: date))"
            } else {
                datePart = "Completed"
            }
        } else if let scheduledAt = round.scheduledAt {
            datePart = formattedScheduleCompact(for: scheduledAt)
        } else {
            datePart = "Unscheduled"
        }
        return "\(courseName) \(kDot) \(datePart)"
    }

    @ViewBuilder
    private func roundScoreSquare(for round: SeriesRound, status: SeriesRoundStatus) -> some View {
        let isComplete   = status == .complete
        let isScored     = status == .live && viewModel.allScoresComplete(for: round)
        let scoreContext = viewModel.currentUserScoreContext(for: round)
        let showScore    = (isComplete || isScored) && scoreContext?.scoreLabel != nil

        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.neutral.opacity(colorScheme.translucent))
                .frame(width: 52, height: 52)

            if showScore, let label = scoreContext?.scoreLabel {
                let scoreColor: Color = label.hasPrefix("-") ? .accentGreen
                                      : label == "E"        ? .neutral
                                                            : .systemError
                Text(label)
                    .fontStyle(kFontName, size: 15, weight: .bold)
                    .foregroundStyle(scoreColor)
            } else {
                Icon(name: "f450", size: 22, weight: .solid)
                    .foregroundStyle(Color.neutral.opacity(0.5))
            }
        }
    }

    private func seriesRoundRow(_ round: SeriesRound) -> some View {
        let status     = viewModel.effectiveStatus(for: round)
        let counts     = viewModel.attendanceCounts(for: round.id)
        let isScored   = status == .live && viewModel.allScoresComplete(for: round)
        let courseName = round.resolvedCourse(using: viewModel.series)?.cachedName ?? "Course TBD"
        let roundTitle = round.title.isEmpty ? "Round \(round.index + 1)" : round.title

        return VStack(alignment: .leading, spacing: 10) {

            // TOP: Status chip + Menu
            HStack(alignment: .center, spacing: 0) {
                roundStatusChip(for: status, isScored: isScored)
                Spacer(minLength: 0)
                seriesRoundOverflowMenuButton(round: round, status: status)
            }

            // TITLE
            Text(roundTitle)
                .fontStyle(kFontName, size: 17, weight: .bold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .alignLeading()

            // SUBTITLE: Course • Date
            Text(roundSubtitle(for: round, status: status, courseName: courseName, isScored: isScored))
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
                .alignLeading()

            Divider().padding(.vertical, 2)

            // BODY: Score square + format/opponent/tee context
            HStack(alignment: .top, spacing: 12) {
                roundScoreSquare(for: round, status: status)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.roundTileFormatCaption(for: round))
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)

                    if let opp = viewModel.roundTileOpponentSummary(for: round) {
                        Text("vs. \(opp.primaryLine)")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(1)
                        if let secondary = opp.secondaryLine {
                            Text(secondary)
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .lineLimit(1)
                        }
                    } else if let teeCtx = viewModel.roundTileTeeGroupContext(for: round) {
                        Text(teeCtx)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().padding(.vertical, 2)

            if round.isAdjusted || viewModel.linkedConfigurationDivergence(for: round) != nil {
                HStack(spacing: 8) {
                    if round.isAdjusted {
                        Chip(
                            text: "Adjusted",
                            size: .xSmall,
                            foreground: .orange,
                            background: Color.orange.opacity(colorScheme.translucent)
                        )
                    }
                    if viewModel.linkedConfigurationDivergence(for: round) != nil {
                        Chip(
                            text: "Setup differs",
                            size: .xSmall,
                            foreground: .orange,
                            background: Color.orange.opacity(colorScheme.translucent)
                        )
                    }
                }
            }

            // Attendance / player counts
            if (isScored || status == .complete), round.roundID != nil {
                let playerCount = viewModel.linkedRound(for: round)?.players.count ?? counts.playing
                HStack(spacing: 10) {
                    Text("\(playerCount) of \(viewModel.eligibleMembers.count)")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)
                    userParticipationBadge(for: round)
                    Spacer(minLength: 0)
                }
            } else if attendanceEnabled && status == .planned {
                HStack(spacing: 16) {
                    verticalAttendanceCount(count: counts.playing,    label: "Playing",  color: .accentGreen)
                    verticalAttendanceCount(count: counts.declined,   label: "Declined", color: .systemError)
                    verticalAttendanceCount(count: counts.noResponse, label: "Pending",  color: .neutral)
                    Spacer(minLength: 0)
                }
            }

            // ACTION BUTTONSUX Re
            if status == .planned {
                HStack(alignment: .center, spacing: 10) {
                    if viewModel.isRSVPEligible(for: round) {
                        let rsvp = viewModel.currentAttendanceStatus(for: round.id)
                        PrimaryButton(
                            appearance: .fill,
                            title: rsvp.buttonLabel,
                            icon: rsvp.buttonIcon,
                            iconWeight: .solid,
                            labelColor: rsvp.labelColor(palette: palette),
                            buttonColor: rsvp.buttonColor(palette: palette),
                            theme: palette.theme,
                            height: SeriesRoundTileButtonMetrics.height,
                            fillWidth: false,
                            iconSize: SeriesRoundTileButtonMetrics.iconSize,
                            fontSize: SeriesRoundTileButtonMetrics.fontSize,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { roundToAttendance = round }
                        )
                    }
                    if viewModel.isCommissioner {
                        commissionerActionButton(for: round, status: status)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Preview tee sheet",
                            labelColor: palette.foregroundColor,
                            buttonColor: palette.whiteGlassButtonColor,
                            theme: palette.theme,
                            height: SeriesRoundTileButtonMetrics.height,
                            fillWidth: true,
                            fontSize: SeriesRoundTileButtonMetrics.fontSize,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { roundToPreviewTeeSheet = round }
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else if status == .lobby {
                HStack(alignment: .center, spacing: 10) {
                    if viewModel.isRSVPEligible(for: round) {
                        let rsvp = viewModel.currentAttendanceStatus(for: round.id)
                        PrimaryButton(
                            appearance: .fill,
                            title: rsvp.buttonLabel,
                            icon: rsvp.buttonIcon,
                            iconWeight: .solid,
                            labelColor: rsvp.labelColor(palette: palette),
                            buttonColor: rsvp.buttonColor(palette: palette),
                            theme: palette.theme,
                            height: SeriesRoundTileButtonMetrics.height,
                            fillWidth: false,
                            iconSize: SeriesRoundTileButtonMetrics.iconSize,
                            fontSize: SeriesRoundTileButtonMetrics.fontSize,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { roundToAttendance = round }
                        )
                    }
                    if round.roundID != nil {
                        PrimaryButton(
                            appearance: .fill,
                            title: viewModel.openLinkedRoundButtonTitle(for: round),
                            labelColor: .white,
                            buttonColor: viewModel.openLinkedRoundButtonColor(for: round),
                            theme: palette.theme,
                            height: SeriesRoundTileButtonMetrics.height,
                            fontSize: SeriesRoundTileButtonMetrics.fontSize,
                            isDisabled: .constant(false),
                            isLoading: .constant(false),
                            onTap: { openRound(round) }
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } else if viewModel.isCommissioner {
                        commissionerActionButton(for: round, status: status)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else if status == .live {
                HStack(alignment: .center, spacing: 10) {
                    if viewModel.isCommissioner, viewModel.canReviewScores(for: round) {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Review scores",
                            labelColor: palette.foregroundColor,
                            buttonColor: palette.whiteGlassButtonColor,
                            theme: palette.theme,
                            height: SeriesRoundTileButtonMetrics.height,
                            fillWidth: false,
                            fontSize: SeriesRoundTileButtonMetrics.fontSize,
                            isDisabled: .constant(false),
                            isLoading: .constant(false),
                            onTap: { roundForCompletionReview = round }
                        )
                    }
                    if round.roundID != nil {
                        PrimaryButton(
                            appearance: .fill,
                            title: viewModel.openLinkedRoundButtonTitle(for: round),
                            labelColor: .white,
                            buttonColor: viewModel.openLinkedRoundButtonColor(for: round),
                            theme: palette.theme,
                            height: SeriesRoundTileButtonMetrics.height,
                            fontSize: SeriesRoundTileButtonMetrics.fontSize,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { openRound(round) }
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else if status == .complete, round.roundID != nil {
                HStack(alignment: .center, spacing: 10) {
                    PrimaryButton(
                        appearance: .fill,
                        title: "View awards",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        height: SeriesRoundTileButtonMetrics.height,
                        fillWidth: false,
                        fontSize: SeriesRoundTileButtonMetrics.fontSize,
                        isDisabled: .constant(false),
                        isLoading: .constant(false),
                        onTap: { roundForAwards = round }
                    )
                    PrimaryButton(
                        appearance: .fill,
                        title: viewModel.openLinkedRoundButtonTitle(for: round),
                        labelColor: .white,
                        buttonColor: viewModel.openLinkedRoundButtonColor(for: round),
                        theme: palette.theme,
                        height: SeriesRoundTileButtonMetrics.height,
                        fontSize: SeriesRoundTileButtonMetrics.fontSize,
                        isDisabled: .constant(false),
                        isLoading: .constant(false),
                        onTap: { openRound(round) }
                    )
                }
            } else if !viewModel.isCommissioner, round.roundID != nil,
                      status != .planned, status != .lobby,
                      status != .live,   status != .complete {
                PrimaryButton(
                    appearance: .fill,
                    title: viewModel.openLinkedRoundButtonTitle(for: round),
                    labelColor: .white,
                    buttonColor: viewModel.openLinkedRoundButtonColor(for: round),
                    theme: palette.theme,
                    height: SeriesRoundTileButtonMetrics.height,
                    fillWidth: false,
                    fontSize: SeriesRoundTileButtonMetrics.fontSize,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: { openRound(round) }
                )
            }
        }
        .padding(14)
        .glassCardEffect(cornerRadius: 14, forceMaterial: true, tint: palette.cardColor)
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
                height: SeriesRoundTileButtonMetrics.height,
                fontSize: SeriesRoundTileButtonMetrics.fontSize,
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
                title: viewModel.openLinkedRoundButtonTitle(for: round),
                labelColor: .white,
                buttonColor: viewModel.openLinkedRoundButtonColor(for: round),
                theme: palette.theme,
                height: SeriesRoundTileButtonMetrics.height,
                fontSize: SeriesRoundTileButtonMetrics.fontSize,
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
            tint = isScored ? .accentYellow : .accentGreen
            label = isScored ? "Scored" : status.rawValue.capitalized
        case .complete:
            tint = .accentYellow
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

    private func syncFromLeagueMenuEnabled(for round: SeriesRound) -> Bool {
        guard let rid = round.roundID, let linked = viewModel.linkedRounds[rid] else { return false }
        return linked.status != .complete && linked.status != .archived
    }

    private func canPreviewMatchups(for round: SeriesRound) -> Bool {
        let plannedStructure = SeriesRoundPlanningService.resolvedPlannedStructure(
            series: viewModel.series,
            seriesRound: round,
            members: viewModel.eligibleMembers,
            teams: viewModel.sortedTeams,
            pods: viewModel.sortedPods,
            courseSelection: round.resolvedCourse(using: viewModel.series)
        )
        return plannedStructure.matchups.isPopulated
    }

    private func seriesRoundOverflowMenuButton(round: SeriesRound, status: SeriesRoundStatus) -> some View {
        Menu {
            seriesRoundOverflowMenuContent(round: round, status: status)
        } label: {
            Icon(name: "f141", size: 16, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .padding(8)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
        }
    }

    @ViewBuilder
    private func seriesRoundOverflowMenuContent(round: SeriesRound, status: SeriesRoundStatus) -> some View {
        if attendanceEnabled && status == .planned {
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
                Label(viewModel.openLinkedRoundButtonTitle(for: round), systemImage: "arrow.right.circle")
            }
        }

        if viewModel.isCommissioner,
           round.roundID != nil,
           syncFromLeagueMenuEnabled(for: round) {
            Button {
                Haptics.fire(.light)
                roundToSyncFromLeague = round
            } label: {
                Label(viewModel.series.experiencePreset.syncFromShellMenuLabel, systemImage: "arrow.triangle.2.circlepath")
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
                if canPreviewMatchups(for: round) {
                    Button {
                        Haptics.fire(.light)
                        roundToPreviewTeeSheet = round
                    } label: {
                        Label("Preview matchups", systemImage: "tablecells.badge.ellipsis")
                    }
                }

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
                if round.roundID != nil {
                    Button {
                        Haptics.fire(.light)
                        csvExportSheetContext = .round(round)
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

                if status == .complete, round.roundID != nil {
                    Button {
                        Haptics.fire(.light)
                        roundToEdit = round
                    } label: {
                        Label("Edit format & awards", systemImage: "slider.horizontal.3")
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
        let target = viewModel.linkedRoundNavigationTarget(for: round)
        Task {
            if target == .lobby {
                await viewModel.repairLinkedLobbyRosterIfNeeded(seriesRoundID: round.id)
            }
            appSession.activeRoundID = roundID
            switch target {
            case .lobby:
                appSession.routeTo(.lobby)
            case .liveRound:
                appSession.routeTo(.liveRound)
            case .roundOutcome:
                appSession.roundOutcomeAllowsEditing = viewModel.isCommissioner
                appSession.routeTo(.roundOutcome)
            }
        }
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
            },
            onManageLeagueSettings: viewModel.isCommissioner
                ? {
                    Haptics.fire(.light)
                    showLeagueSettings = true
                }
                : nil
        )
            .padding(.horizontal, 16)
    }
}

private struct SeriesCSVExportOptionsSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    @State private var options: SeriesCSVExportOptions
    @State private var isExporting = false
    @State private var warning: String?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var linkedRounds: [SeriesRound] {
        viewModel.rounds
            .filter { $0.roundID != nil }
            .sorted { $0.index < $1.index }
    }
    private var exportMembers: [SeriesMember] {
        viewModel.members
            .filter { $0.isActive && $0.role != .spectator }
            .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
    }
    private var exportTeams: [SeriesTeam] {
        viewModel.teams.sorted { lhs, rhs in
            if lhs.index != rhs.index { return lhs.index < rhs.index }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    private var selectedRoundCount: Int { options.selectedRoundIDs.count }
    private var selectedSectionCount: Int { options.selectedSections.count }
    private var selectedTeamCount: Int { options.selectedTeamIDs.isEmpty ? exportTeams.count : options.selectedTeamIDs.count }
    private var selectedPlayerCount: Int { options.selectedMemberIDs.isEmpty ? exportMembers.count : options.selectedMemberIDs.count }
    private var canExport: Bool {
        options.selectedRoundIDs.isPopulated && options.selectedSections.isPopulated && !isExporting
    }

    init(viewModel: SeriesViewModel, preselectedRoundID: String?) {
        self.viewModel = viewModel
        let defaults: SeriesCSVExportOptions
        if let preselectedRoundID {
            defaults = SeriesCSVExportOptions(
                selectedRoundIDs: [preselectedRoundID],
                selectedTeamIDs: [],
                selectedMemberIDs: [],
                selectedSections: Set(SeriesCSVExportSection.allCases)
            )
        } else {
            defaults = SeriesCSVExportOptions.defaults(for: viewModel.rounds)
        }
        _options = State(initialValue: defaults)
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "CSV Export",
                subtitle: "Choose the rounds, sections, teams, and players to include.",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    summaryStrip
                    if let warning {
                        warningBanner(warning)
                    }
                    roundsSection
                    sectionsSection
                    teamsSection
                    playersSection
                    exportButton
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private var summaryStrip: some View {
        HStack(spacing: 8) {
            summaryPill("\(selectedRoundCount) rounds")
            summaryPill("\(selectedSectionCount) sections")
            summaryPill(options.selectedTeamIDs.isEmpty ? "All teams" : "\(selectedTeamCount) teams")
            summaryPill(options.selectedMemberIDs.isEmpty ? "All players" : "\(selectedPlayerCount) players")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func summaryPill(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .glassCardEffect(cornerRadius: 10, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
    }

    private var roundsSection: some View {
        checklistSection(title: "Rounds") {
            if linkedRounds.isEmpty {
                emptyLine("No linked rounds yet.")
            } else {
                ForEach(linkedRounds) { round in
                    checklistRow(
                        title: round.title.isPopulated ? round.title : "Round \(round.index + 1)",
                        subtitle: round.status.rawValue.capitalized,
                        isSelected: options.selectedRoundIDs.contains(round.id)
                    ) {
                        toggle(round.id, in: &options.selectedRoundIDs)
                    }
                }
            }
        }
    }

    private var sectionsSection: some View {
        checklistSection(title: "Sections") {
            ForEach(SeriesCSVExportSection.allCases) { section in
                checklistRow(
                    title: section.displayName,
                    subtitle: section.rawValue,
                    isSelected: options.selectedSections.contains(section)
                ) {
                    toggle(section, in: &options.selectedSections)
                }
            }
        }
    }

    private var teamsSection: some View {
        checklistSection(title: "Teams") {
            checklistRow(
                title: "All teams",
                subtitle: "Includes unassigned players",
                isSelected: options.selectedTeamIDs.isEmpty
            ) {
                options.selectedTeamIDs.removeAll()
            }

            ForEach(exportTeams) { team in
                checklistRow(
                    title: team.name,
                    subtitle: "Team filter",
                    isSelected: options.selectedTeamIDs.contains(team.id)
                ) {
                    if options.selectedTeamIDs.isEmpty {
                        options.selectedTeamIDs = [team.id]
                    } else {
                        toggle(team.id, in: &options.selectedTeamIDs)
                    }
                }
            }
        }
    }

    private var playersSection: some View {
        checklistSection(title: "Players") {
            checklistRow(
                title: "All players",
                subtitle: "Includes every selected-round participant",
                isSelected: options.selectedMemberIDs.isEmpty
            ) {
                options.selectedMemberIDs.removeAll()
            }

            ForEach(exportMembers) { member in
                checklistRow(
                    title: member.name.fullName,
                    subtitle: member.teamID.flatMap(teamName) ?? "Unassigned",
                    isSelected: options.selectedMemberIDs.contains(member.id)
                ) {
                    if options.selectedMemberIDs.isEmpty {
                        options.selectedMemberIDs = [member.id]
                    } else {
                        toggle(member.id, in: &options.selectedMemberIDs)
                    }
                }
            }
        }
    }

    private var exportButton: some View {
        Button {
            Task { await export() }
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(isExporting ? "Building CSV..." : "Export CSV")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canExport ? Color.accentGreen : Color.neutral.opacity(0.35))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canExport)
        .padding(.top, 4)
    }

    private func checklistSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
        }
    }

    private func checklistRow(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.fire(.light)
            action()
            warning = nil
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentGreen : Color.neutral)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                    if let subtitle, subtitle.isPopulated {
                        Text(subtitle)
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func warningBanner(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(Color.systemOrange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardEffect(cornerRadius: 12, tint: Color.systemOrange.opacity(0.14), shadowOpacity: 0)
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 13, weight: .regular)
            .foregroundStyle(Color.neutral)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func export() async {
        guard canExport else { return }
        isExporting = true
        warning = nil
        let fileURL = await viewModel.exportCSV(options: options)
        isExporting = false
        if fileURL == nil {
            warning = viewModel.skippedCSVExportRoundTitles.isPopulated
                ? "No CSV was created. The selected rounds could not be loaded."
                : "No CSV rows matched the current selection."
            return
        }
        dismiss()
    }

    private func teamName(for teamID: String) -> String? {
        exportTeams.first { $0.id == teamID }?.name
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

private struct SeriesCSVShareSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let fileURL: URL
    let experiencePreset: SeriesExperiencePreset
    let skippedRoundTitles: [String]

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "CSV Export",
                subtitle: experiencePreset.csvExportSheetSubtitle,
                onClose: { dismiss() }
            )

            VStack(spacing: 20) {
                Image(systemName: "tablecells.badge.ellipsis")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)

                Text(experiencePreset.csvExportReadyLine)
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

                if skippedRoundTitles.isPopulated {
                    Text("Skipped: \(skippedRoundTitles.joined(separator: ", "))")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.systemOrange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }
}
