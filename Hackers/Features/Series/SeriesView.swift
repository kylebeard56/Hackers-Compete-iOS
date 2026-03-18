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
    @State private var showHandicapSettings = false
    @State private var showNewRoundSheet = false
    @State private var showAddPlayersSheet = false
    @State private var showScoringProfileSheet = false
    @State private var showSetDefaultCourseSheet = false
    @State private var roundToStart: SeriesRound?
    @State private var roundToEdit: SeriesRound?
    @State private var roundToAttendance: SeriesRound?
    @State private var roundDecliningFor: SeriesRound?
    @State private var showDeclinedReasonAlert = false
    @State private var declinedReasonInput = ""

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

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
        .task {
            await viewModel.load(seriesID: seriesID)
        }
        .sheet(isPresented: $showEditNameSheet) {
            EditSeriesNameView(currentName: viewModel.series.name) { newName in
                showEditNameSheet = false
                Task { await viewModel.updateName(newName) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHandicapSettings) {
            SeriesHandicapSettingsView(viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPlayersSheet) {
            AddPlayerView(roundSession: .init(), onConfirm: { players in
                Task {
                    for player in players {
                        await viewModel.addMember(player)
                    }
                    showAddPlayersSheet = false
                }
            })
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showNewRoundSheet) {
            NewSeriesRoundSheet(viewModel: viewModel) {
                showNewRoundSheet = false
            }
            .presentationDetents([.medium])
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
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roundToAttendance) { round in
            SeriesRoundAttendanceView(viewModel: viewModel, seriesRound: round) {
                roundToAttendance = nil
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
                        showHandicapSettings = true
                    } label: {
                        Label("Handicap settings", systemImage: "slider.horizontal.3")
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

            Text("Commissioner")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .opacity(viewModel.isCommissioner ? 1 : 0)
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

            checklistRow(title: "Add players", done: viewModel.hasPlayers) {
                Haptics.fire(.light)
                showAddPlayersSheet = true
            }
            checklistRow(title: "Schedule first round", done: viewModel.hasScheduledRound) {
                Haptics.fire(.light)
                showNewRoundSheet = true
            }
            checklistRow(title: "Set scoring rules", done: viewModel.hasScoringRules) {
                Haptics.fire(.light)
                Task { _ = await viewModel.createMatchupScoringProfile() }
            }
            defaultCourseChecklistRow
        }
        .padding(16)
        .glassCardEffect()
        .padding(.horizontal, 16)
    }

    private var defaultCourseChecklistRow: some View {
        let done = viewModel.hasDefaultCourse
        let title = viewModel.skippedDefaultCourse ? "Using course per round" : "Set default course"
        return Button(action: {
            guard !done else { return }
            Haptics.fire(.light)
            showSetDefaultCourseSheet = true
        }) {
            HStack(spacing: 12) {
                Icon(
                    name: done ? "f058" : "f111",
                    size: 20,
                    weight: done ? .solid : .regular
                )
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
        .contextMenu {
            if !done {
                Button {
                    Haptics.fire(.light)
                    Task { await viewModel.skipDefaultCourse() }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }
            }
        }
    }

    private func checklistRow(title: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(
                    name: done ? "f058" : "f111",
                    size: 20,
                    weight: done ? .solid : .regular
                )
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

    // MARK: - Rounds Tab

    private var roundsTabContent: some View {
        VStack(spacing: 16) {
            if viewModel.rounds.isEmpty {
                EmptyStateView(
                    imageName: "LeaderboardIsometric",
                    title: "No rounds scheduled",
                    subtitle: "Schedule your first round to get started."
                )
                .frame(minHeight: 280)

                if viewModel.isCommissioner {
                    Button("Schedule round") {
                        Haptics.fire(.light)
                        showNewRoundSheet = true
                    }
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                }
            } else {
                if !viewModel.upcomingRounds.isEmpty {
                    seriesRoundSection(title: "Upcoming", rounds: viewModel.upcomingRounds)
                }
                if !viewModel.completedRounds.isEmpty {
                    seriesRoundSection(title: "Completed", rounds: viewModel.completedRounds)
                }

                if viewModel.isCommissioner {
                    Button("Schedule round") {
                        Haptics.fire(.light)
                        showNewRoundSheet = true
                    }
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
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

    private func attendanceCountBadge(count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(count)")
                .foregroundStyle(color)
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private func isUpcomingRound(_ round: SeriesRound) -> Bool {
        let status = viewModel.effectiveStatus(for: round)
        return status == .planned || status == .lobby || status == .live
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
        HStack(spacing: 12) {
            Button {
                if isUpcomingRound(round) {
                    Haptics.fire(.light)
                    roundToAttendance = round
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.title.isEmpty ? "Round \(round.index + 1)" : round.title)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if let date = round.scheduledAt {
                        Text(date.formattedDate)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    if isUpcomingRound(round) {
                        let counts = viewModel.attendanceCounts(for: round.id)
                        HStack(spacing: 6) {
                            attendanceCountBadge(count: counts.playing, icon: "checkmark", color: Color.accentGreen)
                            Text("\u{00B7}")
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                            attendanceCountBadge(count: counts.declined, icon: "xmark", color: Color.systemError)
                            Text("\u{00B7}")
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                            attendanceCountBadge(count: counts.noResponse, icon: "questionmark", color: Color.neutral)
                        }
                        .fontStyle(kFontName, size: 12, weight: .regular)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isUpcomingRound(round))

            Spacer(minLength: 0)

            if isUpcomingRound(round), viewModel.currentMemberID != nil {
                rsvpButton(for: round)
            } else if isUpcomingRound(round) {
                Button {
                    Haptics.fire(.light)
                    roundToAttendance = round
                } label: {
                    Icon(name: "f2c2", size: 18, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                .buttonStyle(.plain)
            }

            if viewModel.effectiveStatus(for: round) == .planned && round.roundID == nil && viewModel.isCommissioner {
                Button {
                    Haptics.fire(.light)
                    roundToStart = round
                } label: {
                    Text("Start round")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                let status = viewModel.effectiveStatus(for: round)
                Text(status.rawValue.capitalized)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(status == .live ? Color.accentGreen : Color.neutral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassCardEffect(cornerRadius: 8, tint: status == .live ? Color.accentGreen.opacity(0.15) : nil)
            }
        }
        .contextMenu {
            if isUpcomingRound(round) {
                Button {
                    Haptics.fire(.light)
                    roundToAttendance = round
                } label: {
                    Label("Attendance", systemImage: "person.2")
                }
            }
            if viewModel.isCommissioner {
                if viewModel.effectiveStatus(for: round) == .planned && round.roundID == nil {
                    Button {
                        Haptics.fire(.light)
                        roundToStart = round
                    } label: {
                        Label("Start round in lobby", systemImage: "play.fill")
                    }
                    Button {
                        Haptics.fire(.light)
                        roundToEdit = round
                    } label: {
                        Label("Edit round", systemImage: "pencil")
                    }
                }
                Button {
                    Haptics.fire(.light)
                    Task { _ = await viewModel.duplicateRound(round) }
                } label: {
                    Label("Duplicate round", systemImage: "doc.on.doc")
                }
            }
            if let rid = round.roundID {
                Button {
                    Haptics.fire(.light)
                    appSession.activeRoundID = rid
                    appSession.routeTo(.lobby)
                } label: {
                    Label("Open round", systemImage: "arrow.right.circle")
                }
            }
        }
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
        SeriesLeaderboardView(viewModel: viewModel, palette: palette)
            .padding(.horizontal, 16)
    }
}
