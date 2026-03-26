//
//  SeriesView.swift
//  Hackers
//

import AlertToast
import SwiftUI

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

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
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
            SeriesLeagueSettingsView(
                viewModel: viewModel,
                onSetDefaultCourse: { showSetDefaultCourseSheet = true },
                onOpenHandicaps: { showHandicapSettings = true }
            )
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
        .sheet(isPresented: exportSheetPresented) {
            if let fileURL = viewModel.exportedCSVURL {
                SeriesCSVShareSheet(fileURL: fileURL)
            }
        }
        .toast(isPresenting: $viewModel.isLoading, alert: { AlertToast.loader() })
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
                    showEditNameSheet = true
                } label: {
                    Label("Edit name", systemImage: "pencil")
                }

                if viewModel.isCommissioner {
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

                if viewModel.isCommissioner && !viewModel.checklistComplete {
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

            checklistRow(title: "Add more players", done: viewModel.hasPlayers) {
                Haptics.fire(.light)
                showAddPlayersSheet = true
            }
            checklistRow(title: "Schedule first round", done: viewModel.hasScheduledRound) {
                Haptics.fire(.light)
                showNewRoundSheet = true
            }
            checklistRow(title: "Set league rules", done: viewModel.hasScoringRules) {
                Haptics.fire(.light)
                showLeagueSettings = true
            }
            optionalChecklistRow(title: "Set default course", done: viewModel.hasDefaultCourse) {
                Haptics.fire(.light)
                showSetDefaultCourseSheet = true
            }
        }
        .padding(16)
        .glassCardEffect()
        .padding(.horizontal, 16)
    }

    private func checklistRow(title: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(name: done ? "f058" : "f111", size: 20, weight: done ? .solid : .regular)
                    .foregroundStyle(done ? Color.accentGreen : Color.neutral)

                Text(title)
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(done ? Color.neutral : palette.foregroundColor)
                    .strikethrough(done, color: Color.neutral)

                Spacer(minLength: 0)

                if !done {
                    Icon(name: "f054", size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    private func optionalChecklistRow(title: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(name: done ? "f058" : "e3ac", size: 18, weight: .solid)
                    .foregroundStyle(done ? Color.accentGreen : Color.neutral)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)

                    Text(done ? "League default is ready" : "Optional, but it speeds up round launch")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private func rsvpButton(for round: SeriesRound) -> some View {
        let status = viewModel.currentAttendanceStatus(for: round.id)
        Menu {
            Button {
                Haptics.fire(.light)
                guard let memberID = viewModel.currentMemberID else { return }
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: round.id,
                        memberID: memberID,
                        status: .accepted,
                        declinedNote: nil
                    )
                }
            } label: {
                Label("Attending", systemImage: "checkmark")
            }
            Button {
                Haptics.fire(.light)
                roundDecliningFor = round
                declinedReasonInput = ""
                showDeclinedReasonAlert = true
            } label: {
                Label("Declined", systemImage: "xmark")
            }
            Button {
                Haptics.fire(.light)
                guard let memberID = viewModel.currentMemberID else { return }
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: round.id,
                        memberID: memberID,
                        status: .pending,
                        declinedNote: nil
                    )
                }
            } label: {
                Label("Pending", systemImage: "questionmark")
            }
        } label: {
            Group {
                switch status {
                case .accepted:
                    Text("Playing")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                case .no:
                    Text("Declined")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.systemError)
                default:
                    Text("RSVP")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCardEffect(cornerRadius: 10, tint: palette.whiteGlassButtonColor)
        }
        .buttonStyle(.plain)
        .alert("Why can't you make it?", isPresented: $showDeclinedReasonAlert) {
            TextField("Optional reason", text: $declinedReasonInput)
            Button("Save") {
                guard let round = roundDecliningFor, let memberID = viewModel.currentMemberID else { return }
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: round.id,
                        memberID: memberID,
                        status: .no,
                        declinedNote: declinedReasonInput.isEmpty ? nil : declinedReasonInput
                    )
                }
                roundDecliningFor = nil
            }
            Button("Skip", role: .cancel) {
                guard let round = roundDecliningFor, let memberID = viewModel.currentMemberID else { return }
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: round.id,
                        memberID: memberID,
                        status: .no,
                        declinedNote: nil
                    )
                }
                roundDecliningFor = nil
            }
        } message: {
            Text("Add an optional note explaining why you can't attend.")
        }
    }

    private func seriesRoundSection(title: String, rounds: [SeriesRound]) -> some View {
        VStack(spacing: 12) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()

            ForEach(rounds, id: \.id) { round in
                seriesRoundRow(round)
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    private func seriesRoundRow(_ round: SeriesRound) -> some View {
        let status = viewModel.effectiveStatus(for: round)
        let counts = viewModel.attendanceCounts(for: round.id)
        let teamPoints = viewModel.scoringProfiles.first { $0.id == round.teamScoringProfileID }?.name
            ?? viewModel.scoringProfiles.first { $0.id == viewModel.series.settings.defaultTeamScoringProfileID }?.name
        let individualPoints = viewModel.scoringProfiles.first { $0.id == round.individualScoringProfileID }?.name
            ?? viewModel.scoringProfiles.first { $0.id == viewModel.series.settings.defaultIndividualScoringProfileID }?.name

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(round.title.isEmpty ? "Round \(round.index + 1)" : round.title)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if let scheduledAt = round.scheduledAt {
                        Text(formattedSchedule(for: scheduledAt))
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    Text(round.resolvedCourse(using: viewModel.series)?.cachedName ?? "Course TBD")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.accentGreen)

                    Text(round.roundConfig.template.name)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)

                    Text(pointsSummary(teamPoints: teamPoints, individualPoints: individualPoints))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral2)
                }

                Spacer(minLength: 0)

                roundStatusChip(for: status)
            }

            if round.isAdjusted {
                Chip(
                    text: "Adjusted",
                    size: .xSmall,
                    foreground: .orange,
                    background: Color.orange.opacity(colorScheme.translucent)
                )
            }

            if status == .planned || status == .lobby || status == .live {
                HStack(spacing: 10) {
                    attendanceBadge(label: "Playing", count: counts.playing, color: .accentGreen)
                    attendanceBadge(label: "Declined", count: counts.declined, color: .systemError)
                    attendanceBadge(label: "Pending", count: counts.noResponse, color: .neutral)
                    Spacer(minLength: 0)
                    if viewModel.currentMemberID != nil {
                        rsvpButton(for: round)
                    }
                }
            }

            HStack(spacing: 10) {
                if viewModel.isCommissioner {
                    commissionerActionButton(for: round, status: status)
                } else if let roundID = round.roundID, status != .planned {
                    primaryCapsuleButton("Open round", fill: Color.accentGreen) {
                        Haptics.fire(.light)
                        appSession.activeRoundID = roundID
                        appSession.routeTo(.lobby)
                    }
                }

                if status == .planned || status == .lobby || status == .live {
                    primaryCapsuleButton("Attendance", fill: palette.whiteGlassButtonColor, foreground: palette.foregroundColor) {
                        Haptics.fire(.light)
                        roundToAttendance = round
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
                }
            }
        }
        .padding(14)
        .glassCardEffect(cornerRadius: 14, tint: palette.whiteGlassButtonColor)
        .contextMenu {
            if status == .planned || status == .lobby || status == .live {
                Button {
                    Haptics.fire(.light)
                    roundToAttendance = round
                } label: {
                    Label("Attendance", systemImage: "person.2")
                }
            }

            if let roundID = round.roundID {
                Button {
                    Haptics.fire(.light)
                    appSession.activeRoundID = roundID
                    appSession.routeTo(.lobby)
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
                if status == .planned && round.roundID == nil {
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

                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        Task { await viewModel.deleteScheduledRound(round) }
                    } label: {
                        Label("Delete round", systemImage: "trash")
                    }
                } else {
                    if round.roundID != nil, status != .complete, status != .canceled {
                        Button {
                            Haptics.fire(.light)
                            roundToEdit = round
                        } label: {
                            Label("Edit round settings", systemImage: "slider.horizontal.3")
                        }

                        Button(role: .destructive) {
                            Haptics.fire(.light)
                            Task { await viewModel.cancelRound(round) }
                        } label: {
                            Label("Cancel round", systemImage: "xmark.circle")
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
                }
            }
        }
    }

    @ViewBuilder
    private func commissionerActionButton(for round: SeriesRound, status: SeriesRoundStatus) -> some View {
        if status == .planned && round.roundID == nil {
            if viewModel.creatingRoundID == round.id {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Starting...")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentGreen)
                .clipShape(Capsule())
            } else {
                primaryCapsuleButton("Start round") {
                    Haptics.fire(.light)
                    startRound(round)
                }
            }
        } else if let roundID = round.roundID {
            primaryCapsuleButton("Open round") {
                Haptics.fire(.light)
                appSession.activeRoundID = roundID
                appSession.routeTo(.lobby)
            }
        }
    }

    private func roundStatusChip(for status: SeriesRoundStatus) -> some View {
        let tint: Color
        switch status {
        case .live, .lobby:
            tint = .accentGreen
        case .complete:
            tint = .systemBlue
        case .canceled:
            tint = .systemError
        case .planned:
            tint = .neutral
        }

        return Text(status.rawValue.capitalized)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCardEffect(cornerRadius: 10, tint: tint.opacity(0.12))
    }

    private func attendanceBadge(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .fontStyle(kFontName, size: 11, weight: .medium)
                .foregroundStyle(color)
        }
    }

    private func pointsSummary(teamPoints: String?, individualPoints: String?) -> String {
        switch (teamPoints, individualPoints) {
        case let (team?, individual?):
            return "Team: \(team)  •  Individual: \(individual)"
        case let (team?, nil):
            return "Team points: \(team)"
        case let (nil, individual?):
            return "Individual points: \(individual)"
        case (nil, nil):
            return "No point allocation configured"
        }
    }

    private func formattedSchedule(for time: Time) -> String {
        let date = Date(timeIntervalSince1970: time.unix)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func startRound(_ round: SeriesRound, forceCourseSelection: Bool = false) {
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
