//
//  SeriesLeagueSettingsView.swift
//  Hackers
//

import SwiftUI

struct SeriesLeagueSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    var onSetDefaultCourse: () -> Void
    var onOpenHandicaps: () -> Void

    @State private var draftSettings = SeriesSettings()
    @State private var hasLoaded = false

    @State private var announcementTitle = ""
    @State private var announcementMessage = ""
    @State private var announcementStartsAt = Date()
    @State private var announcementEndsAt = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var showInviteSheet = false
    @State private var profileEditorSeed: SeriesScoringProfileEditorSeed?

    // Collapsible section state
    @State private var courseLogisticsExpanded = true
    @State private var formatExpanded = true
    @State private var teamPointsExpanded = true
    @State private var individualPointsExpanded = true

    // Announcement editing
    @State private var editingAnnouncement: SeriesAnnouncement? = nil

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    /// Chips and inputs on grey cards: solid white in light; system grouped secondary in dark so `palette.foregroundColor` stays legible (avoid `Color.white` in dark).
    private var settingsElevatedSurfaceColor: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "League Settings",
                    subtitle: "Manage logistics, configuration, announcements, and commissioner tools.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    leagueBasicsSection
                    pointsAwardsSection
                    behaviorSection
                    rulesConfirmationSection
                    adminToolsSection
                    invitesSection.hidden()
                    announcementsSection
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                PrimaryButton(
                    appearance: .fill,
                    title: "Save",
                    labelColor: .white,
                    buttonColor: Color.accentGreen,
                    fillWidth: true,
                    isDisabled: .false,
                    isLoading: .false,
                    onTapAsync: {
                        await viewModel.saveLeagueSettings(draftSettings)
                        dismiss()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .task {
            guard !hasLoaded else { return }
            draftSettings = viewModel.series.settings
            normalizeSelectedTemplate()
            normalizeDraftProfilesForCompetition()
            normalizeDefaultCourseHoleSegmentForAlternateRotation()
            hasLoaded = true
        }
        .onChange(of: draftSettings.defaultCourseRotationMode) { _, newMode in
            if newMode == .alternateFrontBack {
                normalizeDefaultCourseHoleSegmentForAlternateRotation()
            }
        }
        .onChange(of: draftSettings.defaultRoundConfig.competitionScope) { _, _ in
            normalizeDraftProfilesForCompetition()
        }
        .onChange(of: draftSettings.useTeams) { _, useTeams in
            if !useTeams {
                draftSettings.defaultRoundConfig.teamAssignmentMode = .manual
                draftSettings.defaultRoundConfig.matchupMode = resolvedCompetitionScope == .matchup ? .individualVsIndividual : .field
                draftSettings.defaultRoundConfig.podGroupingStrategy = .disabled
            } else {
                draftSettings.defaultRoundConfig.teamAssignmentMode = .seriesTeams
                draftSettings.defaultRoundConfig.matchupMode = resolvedCompetitionScope == .matchup ? .teamVsTeam : .field
            }
            normalizeSelectedTemplate()
            normalizeDraftProfilesForCompetition()
        }
        .sheet(isPresented: $showInviteSheet) {
            SeriesInvitePlayerSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $profileEditorSeed) { seed in
            SeriesScoringProfileEditorSheet(viewModel: viewModel, seed: seed) { saved in
                if saved.competitorType == .team {
                    draftSettings.defaultTeamScoringProfileID = saved.id
                } else {
                    draftSettings.defaultIndividualScoringProfileID = saved.id
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var leagueBasicsSection: some View {
        settingsGroup(title: "League Basics") {
            collapsibleCard(title: "Course logistics", isExpanded: $courseLogisticsExpanded) {
                builderField(
                    title: "Default course",
                    subtitle: "New rounds will automatically happen here."
                ) {
                    HStack(spacing: 8) {
                        Button { openDefaultCourse() } label: {
                            HStack(spacing: 8) {
                                Text(draftSettings.defaultCourse?.cachedName ?? "Set course")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Icon(name: "f078", size: 12, weight: .solid)
                                    .foregroundStyle(Color.neutral)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(settingsElevatedSurfaceColor)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)

                        if draftSettings.defaultCourse != nil {
                            Button {
                                Haptics.fire(.light)
                                draftSettings.defaultCourse = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.systemError.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                builderField(
                    title: "Default tee time",
                    subtitle: "Used when commissioners turn on a scheduled date for a new round."
                ) {
                    DatePicker(
                        "",
                        selection: defaultTeeTimeBinding,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .blendMode(.destinationOver)
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                    .background(
                        Capsule()
                            .fill(settingsElevatedSurfaceColor)
                    )
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(settingsElevatedSurfaceColor)
//                    .clipShape(Capsule())
                }

                builderField(
                    title: "Play days",
                    subtitle: "Optional. Set date for a new round jumps to the next selected weekday at the default tee time. Leave all off to use tomorrow instead."
                ) {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            playDayCircle(weekday: weekday)
                        }
                    }
                }

                if draftSettings.defaultCourse != nil {
                    builderField(
                        title: "Course rotation",
                        subtitle: "Keep the same segment every week or alternate front and back nines automatically."
                    ) {
                        Menu {
                            Button {
                                draftSettings.defaultCourseRotationMode = .fixed
                            } label: {
                                HStack {
                                    Text("Fixed")
                                    if draftSettings.defaultCourseRotationMode == .fixed {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                draftSettings.defaultCourseRotationMode = .alternateFrontBack
                            } label: {
                                HStack {
                                    Text("Alternate front/back")
                                    if draftSettings.defaultCourseRotationMode == .alternateFrontBack {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            settingsMenuChip(draftSettings.defaultCourseRotationMode == .alternateFrontBack ? "Alternate front/back" : "Fixed")
                        }
                        .buttonStyle(.plain)
                    }

                    builderField(
                        title: draftSettings.defaultCourseRotationMode == .alternateFrontBack ? "Starts on" : "Default segment",
                        subtitle: draftSettings.defaultCourseRotationMode == .alternateFrontBack
                            ? "Choose which nine starts the alternating sequence."
                            : "Choose which segment new rounds should inherit by default."
                    ) {
                        Menu {
                            if draftSettings.defaultCourseRotationMode == .fixed {
                                Button {
                                    defaultCourseSegmentBinding.wrappedValue = .full18
                                } label: {
                                    HStack {
                                        Text("Full 18")
                                        if defaultCourseSegmentBinding.wrappedValue == .full18 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }

                            Button {
                                defaultCourseSegmentBinding.wrappedValue = .front9
                            } label: {
                                HStack {
                                    Text("Front 9")
                                    if defaultCourseSegmentBinding.wrappedValue == .front9 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                defaultCourseSegmentBinding.wrappedValue = .back9
                            } label: {
                                HStack {
                                    Text("Back 9")
                                    if defaultCourseSegmentBinding.wrappedValue == .back9 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            settingsMenuChip(defaultCourseSegmentTitle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            collapsibleCard(title: "Format", isExpanded: $formatExpanded) {
                builderField(
                    title: "Format template",
                    subtitle: "Choose how each individual player score is computed before team rollups or matchups."
                ) {
                    Menu {
                        ForEach(availableTemplates, id: \.id) { template in
                            Button {
                                draftSettings.defaultRoundConfig.formatTemplateID = template.id
                            } label: {
                                HStack {
                                    Text(template.name)
                                    if template.id == draftSettings.defaultRoundConfig.formatTemplateID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        settingsMenuChip(templateName)
                    }
                    .buttonStyle(.plain)
                }

                builderField(
                    title: "Competition",
                    subtitle: draftSettings.useTeams
                        ? "Field compares everyone together. Matchup compares scheduled head-to-head pairings."
                        : "Field compares everyone together. Matchup creates player-vs-player pairings for rounds that do not use teams."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            draftSettings.defaultRoundConfig.competitionScope = .field
                        } label: {
                            settingsChip("Field", selected: resolvedCompetitionScope == .field)
                        }
                        .buttonStyle(.plain)

                        Button {
                            draftSettings.defaultRoundConfig.competitionScope = .matchup
                        } label: {
                            settingsChip("Matchup", selected: resolvedCompetitionScope == .matchup)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if draftSettings.useTeams {
                    builderField(
                        title: "Count scores",
                        subtitle: "Choose whether every team score counts or only the best or worst scores."
                    ) {
                        HStack(spacing: 10) {
                            Menu {
                                Button {
                                    draftSettings.defaultRoundConfig.teamScoring.mode = .all
                                } label: {
                                    HStack {
                                        Text("All")
                                        if draftSettings.defaultRoundConfig.teamScoring.mode == .all {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    draftSettings.defaultRoundConfig.teamScoring.mode = .bestN
                                    let c = draftSettings.defaultRoundConfig.teamScoring.count
                                    if c < 1 || c > 4 { draftSettings.defaultRoundConfig.teamScoring.count = 2 }
                                } label: {
                                    HStack {
                                        Text("Best")
                                        if draftSettings.defaultRoundConfig.teamScoring.mode == .bestN {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    draftSettings.defaultRoundConfig.teamScoring.mode = .worstN
                                    let c = draftSettings.defaultRoundConfig.teamScoring.count
                                    if c < 1 || c > 4 { draftSettings.defaultRoundConfig.teamScoring.count = 2 }
                                } label: {
                                    HStack {
                                        Text("Worst")
                                        if draftSettings.defaultRoundConfig.teamScoring.mode == .worstN {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            } label: {
                                settingsMenuChip(teamScoringKindLabel)
                            }
                            .buttonStyle(.plain)

                            let mode = draftSettings.defaultRoundConfig.teamScoring.mode
                            if mode == .bestN || mode == .worstN {
                                Menu {
                                    ForEach(1...4, id: \.self) { n in
                                        Button {
                                            draftSettings.defaultRoundConfig.teamScoring.count = n
                                        } label: {
                                            HStack {
                                                Text("\(n)")
                                                if draftSettings.defaultRoundConfig.teamScoring.count == n {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    settingsMenuChip("\(draftSettings.defaultRoundConfig.teamScoring.count)")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    builderField(
                        title: "Count by",
                        subtitle: "Apply team counting on each hole or across the full round."
                    ) {
                        HStack(spacing: 8) {
                            Button {
                                draftSettings.defaultRoundConfig.teamScoring.scope = .perHole
                            } label: {
                                settingsChip("Hole", selected: draftSettings.defaultRoundConfig.teamScoring.scope == .perHole)
                            }
                            .buttonStyle(.plain)

                            Button {
                                draftSettings.defaultRoundConfig.teamScoring.scope = .perRound
                            } label: {
                                settingsChip("Round", selected: draftSettings.defaultRoundConfig.teamScoring.scope == .perRound)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                builderField(
                    title: "Shotgun start",
                    subtitle: "New tee groups pick up the next open tee box at the same tee time instead of always starting on hole 1."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            draftSettings.defaultRoundConfig.sequentialTeeStartsEnabled = false
                        } label: {
                            settingsChip("Off", selected: !(draftSettings.defaultRoundConfig.sequentialTeeStartsEnabled ?? false))
                        }
                        .buttonStyle(.plain)

                        Button {
                            draftSettings.defaultRoundConfig.sequentialTeeStartsEnabled = true
                        } label: {
                            settingsChip("On", selected: draftSettings.defaultRoundConfig.sequentialTeeStartsEnabled == true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var pointsAwardsSection: some View {
        settingsGroup(title: "Points & Awards") {
            Text(defaultAwardsDescription)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .padding(.leading, 4)

            if draftSettings.useTeams {
                collapsibleCard(title: "Team points", isExpanded: $teamPointsExpanded) {
                    SeriesScoringProfileSelectionCard(
                        viewModel: viewModel,
                        title: nil,
                        subtitle: "Choose the default team points profile for new league rounds.",
                        competitorType: .team,
                        competitionScope: resolvedCompetitionScope,
                        supportsWinTieLoss: resolvedCompetitionScope == .matchup,
                        selectedProfileID: $draftSettings.defaultTeamScoringProfileID
                    ) { seed in
                        profileEditorSeed = seed
                    }
                }
            }

            collapsibleCard(title: "Individual points", isExpanded: $individualPointsExpanded) {
                SeriesScoringProfileSelectionCard(
                    viewModel: viewModel,
                    title: nil,
                    subtitle: "Choose the default player points profile for new league rounds.",
                    competitorType: .member,
                    competitionScope: resolvedCompetitionScope,
                    supportsWinTieLoss: resolvedCompetitionScope == .matchup && !draftSettings.useTeams,
                    selectedProfileID: $draftSettings.defaultIndividualScoringProfileID
                ) { seed in
                    profileEditorSeed = seed
                }
            }

            Button {
                Haptics.fire(.light)
                Task { await viewModel.createBuiltInScoringProfilesIfNeeded() }
            } label: {
                Chip(
                    text: "Refresh built-ins",
                    size: .small,
                    foreground: .white,
                    background: Color.accentGreen
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var behaviorSection: some View {
        settingsGroup(title: "Behavior") {
            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.useTeams) {
                        settingsToggleLabel(title: "Use teams", subtitle: "Enable persistent teams and optional fixed pairs.")
                    }
                    .tint(.accentGreen)
                }
            }

            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.useTeamStandings) {
                        settingsToggleLabel(title: "Show team standings", subtitle: "Publish a separate team leaderboard.")
                    }
                    .tint(.accentGreen)
                }
            }

            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.useIndividualStandings) {
                        settingsToggleLabel(title: "Show individual standings", subtitle: "Publish an individual leaderboard too.")
                    }
                    .tint(.accentGreen)
                }
            }

            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.allowRoundEditsAfterLobbyCreation) {
                        settingsToggleLabel(title: "Allow editing after start", subtitle: "Keep round settings adjustable from the league.")
                    }
                    .tint(.accentGreen)
                }
            }

            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.autoFinalizeAwardsOnRoundCompletion) {
                        settingsToggleLabel(title: "Auto-finalize awards", subtitle: "Publish standings as soon as the linked round completes.")
                    }
                    .tint(.accentGreen)
                }
            }

            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.allowManualAwardOverrides) {
                        settingsToggleLabel(title: "Allow commissioner overrides", subtitle: "Keep manual control for edge cases and testing.")
                    }
                    .tint(.accentGreen)
                }
            }

            SeriesSheetCard(palette: palette) {
                SeriesSheetRow {
                    Toggle(isOn: $draftSettings.isAttendanceEnabled) {
                        settingsToggleLabel(
                            title: "Collect attendance",
                            subtitle: draftSettings.isAttendanceEnabled
                                ? "Only accepted and pending invites will be added to rounds."
                                : "All players in the series will be added to planned rounds."
                        )
                    }
                    .tint(.accentGreen)
                }

                if draftSettings.isAttendanceEnabled {
                    builderField(
                        title: "Default attendance",
                        subtitle: "Choose the initial response state when a new league round is scheduled."
                    ) {
                        Menu {
                            Button {
                                draftSettings.attendanceDefault = .pending
                            } label: {
                                HStack {
                                    Text("Pending")
                                    if draftSettings.attendanceDefault == .pending {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                draftSettings.attendanceDefault = .accepted
                            } label: {
                                HStack {
                                    Text("Accepted")
                                    if draftSettings.attendanceDefault == .accepted {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                draftSettings.attendanceDefault = .no
                            } label: {
                                HStack {
                                    Text("Declined")
                                    if draftSettings.attendanceDefault == .no {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            settingsMenuChip(attendanceDefaultTitle)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }

            SeriesSheetCard(palette: palette) {
                builderField(
                    title: "Default pair grouping",
                    subtitle: "Use fixed pairs as a shortcut for auto-grouping only when both matchup teams have valid pairs."
                ) {
                    Menu {
                        Button {
                            draftSettings.podGroupingDefault = .disabled
                        } label: {
                            HStack {
                                Text("Disabled")
                                if draftSettings.podGroupingDefault == .disabled {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button {
                            draftSettings.podGroupingDefault = .alignByIndex
                        } label: {
                            HStack {
                                Text("Align by pair")
                                if draftSettings.podGroupingDefault == .alignByIndex {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        settingsMenuChip(pairGroupingTitle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var adminToolsSection: some View {
        settingsGroup(title: "Admin Tools") {
            Button {
                Haptics.fire(.light)
                openDefaultCourse()
            } label: {
                toolRow(
                    title: "Default course",
                    subtitle: viewModel.series.defaultCourse?.cachedName ?? "Set the league-wide course and tee default"
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.fire(.light)
                openHandicaps()
            } label: {
                toolRow(
                    title: "Handicap settings",
                    subtitle: viewModel.series.handicapConfig.isEnabled ? "Handicaps are enabled" : "Configure series handicap rules"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var rulesConfirmationSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionTitle("League Rules")

            SeriesSheetRow {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: rulesConfirmationIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(rulesConfirmationColor)
                        .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rulesConfirmationTitle)
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        Text(rulesConfirmationSubtitle)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                }
            }

            Button {
                Haptics.fire(.light)
                Task {
                    await viewModel.confirmLeagueRules(draftSettings)
                    draftSettings = viewModel.series.settings
                }
            } label: {
                Chip(
                    text: hasUnsavedChanges ? "Save & confirm league rules" : "Confirm league rules",
                    size: .small,
                    foreground: .white,
                    background: Color.accentGreen
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var invitesSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionTitle("Invites")

            Button {
                Haptics.fire(.light)
                showInviteSheet = true
            } label: {
                Chip(
                    text: "Invite players",
                    size: .small,
                    foreground: .white,
                    background: Color.accentGreen
                )
            }
            .buttonStyle(.plain)

            if viewModel.invites.isEmpty {
                Text("No league invites yet.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                ForEach(viewModel.invites.sorted(by: { $0.invitedAt.unix > $1.invitedAt.unix }), id: \.id) { invite in
                    SeriesSheetRow {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invite.invitedName)
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)

                                Text(invite.status.rawValue.capitalized)
                                    .fontStyle(kFontName, size: 12, weight: .medium)
                                    .foregroundStyle(invite.status == .pending ? Color.accentGreen : Color.neutral)
                            }

                            Spacer(minLength: 0)

                            if invite.status == .pending {
                                Button {
                                    Task { await viewModel.resolveInvite(invite, status: .revoked) }
                                } label: {
                                    Chip(
                                        text: "Revoke",
                                        size: .xSmall,
                                        foreground: .systemError,
                                        background: Color.systemError.opacity(colorScheme.translucent)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var announcementsSection: some View {
        settingsGroup(title: "Commissioner Notes") {
            SeriesSheetCard(palette: palette) {
                TextField("Title", text: $announcementTitle)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(12)
                    .background(settingsElevatedSurfaceColor)
                    .cornerRadius(14)

                TextField("Message", text: $announcementMessage, axis: .vertical)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(settingsElevatedSurfaceColor)
                    .cornerRadius(14)

                SeriesSheetRow {
                    DatePicker("Starts", selection: $announcementStartsAt, displayedComponents: [.date, .hourAndMinute])
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                }

                SeriesSheetRow {
                    DatePicker("Expires", selection: $announcementEndsAt, in: announcementStartsAt..., displayedComponents: [.date, .hourAndMinute])
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                }

                HStack(spacing: 12) {
                    Button {
                        Haptics.fire(.light)
                        if let editing = editingAnnouncement {
                            Task {
                                await viewModel.updateAnnouncement(
                                    editing,
                                    title: announcementTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                    message: announcementMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                                    startsAt: announcementStartsAt,
                                    endsAt: announcementEndsAt
                                )
                                resetAnnouncementForm()
                            }
                        } else {
                            Task {
                                await viewModel.addAnnouncement(
                                    title: announcementTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                    message: announcementMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                                    startsAt: announcementStartsAt,
                                    endsAt: announcementEndsAt
                                )
                                resetAnnouncementForm()
                            }
                        }
                    } label: {
                        Chip(
                            text: editingAnnouncement != nil ? "Update" : "Post announcement",
                            size: .small,
                            foreground: .white,
                            background: announcementCanPost ? Color.accentGreen : Color.neutral3
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!announcementCanPost)

                    if editingAnnouncement != nil {
                        Button {
                            resetAnnouncementForm()
                        } label: {
                            Text("Cancel")
                                .fontStyle(kFontName, size: 13, weight: .medium)
                                .foregroundStyle(Color.neutral)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.announcements.isEmpty {
                    Text("No announcements yet")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                } else {
                    ForEach(viewModel.announcements.sorted(by: { $0.startsAt.unix > $1.startsAt.unix }), id: \.id) { announcement in
                        SeriesSheetRow {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(announcement.title.isEmpty ? "Note from commissioner" : announcement.title)
                                        .fontStyle(kFontName, size: 14, weight: .semibold)
                                        .foregroundStyle(palette.foregroundColor)

                                    Text(announcement.message)
                                        .fontStyle(kFontName, size: 13, weight: .regular)
                                        .foregroundStyle(Color.neutral)

                                    Text("\(announcement.startsAt.formattedDate) to \(announcement.endsAt.formattedDate)")
                                        .fontStyle(kFontName, size: 11, weight: .regular)
                                        .foregroundStyle(Color.neutral2)
                                }

                                Spacer(minLength: 0)

                                VStack(spacing: 6) {
                                    Button {
                                        editingAnnouncement = announcement
                                        announcementTitle = announcement.title
                                        announcementMessage = announcement.message
                                        announcementStartsAt = Date(timeIntervalSince1970: announcement.startsAt.unix)
                                        announcementEndsAt = Date(timeIntervalSince1970: announcement.endsAt.unix)
                                    } label: {
                                        Chip(
                                            text: "Edit",
                                            size: .xSmall,
                                            foreground: palette.foregroundColor,
                                            background: Color.neutral6
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        Task { await viewModel.deleteAnnouncement(announcement) }
                                    } label: {
                                        Chip(
                                            text: "Delete",
                                            size: .xSmall,
                                            foreground: .systemError,
                                            background: Color.systemError.opacity(colorScheme.translucent)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func resetAnnouncementForm() {
        editingAnnouncement = nil
        announcementTitle = ""
        announcementMessage = ""
        announcementStartsAt = Date()
        announcementEndsAt = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    }


    private var defaultTeeTimeBinding: Binding<Date> {
        Binding(
            get: {
                let minutes = draftSettings.defaultScheduledTeeTimeMinutesFromMidnight
                    ?? SeriesSettings.fallbackDefaultTeeMinutesFromMidnight
                let cal = Calendar.current
                var c = cal.dateComponents([.year, .month, .day], from: Date())
                c.hour = minutes / 60
                c.minute = minutes % 60
                c.second = 0
                return cal.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                let h = c.hour ?? 16
                let m = c.minute ?? 30
                draftSettings.defaultScheduledTeeTimeMinutesFromMidnight = h * 60 + m
            }
        )
    }

    private func playDayCircle(weekday: Int) -> some View {
        let symbols = ["S", "M", "T", "W", "T", "F", "S"]
        let label = symbols[weekday - 1]
        let selected = (draftSettings.recurringPlayWeekdays ?? []).contains(weekday)
        return Button {
            Haptics.fire(.light)
            var set = Set(draftSettings.recurringPlayWeekdays ?? [])
            if selected {
                set.remove(weekday)
            } else {
                set.insert(weekday)
            }
            draftSettings.recurringPlayWeekdays = set.isEmpty ? nil : set.sorted()
        } label: {
            Text(label)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(selected ? .white : palette.foregroundColor)
                .frame(width: 32, height: 32)
                .background(selected ? Color.accentGreen : settingsElevatedSurfaceColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var resolvedCompetitionScope: CompetitionScope {
        draftSettings.defaultRoundConfig.competitionScope ?? draftSettings.defaultRoundConfig.template.resolvedScope
    }

    private var templateName: String {
        FormatTemplateRegistry.template(for: draftSettings.defaultRoundConfig.formatTemplateID).name
    }

    private var availableTemplates: [GameTemplate] {
        FormatTemplateRegistry.seriesTemplates
    }

    private var defaultAwardsDescription: String {
        if draftSettings.useTeams {
            return "Team awards feed team standings. Individual awards feed player standings. Placement uses finishing order, while win/tie/loss uses matchup results."
        }
        if resolvedCompetitionScope == .matchup {
            return "Individual awards feed player standings. Placement uses finishing order, while win/tie/loss uses scheduled player matchups."
        }
        return "Individual awards feed player standings. Placement uses finishing order, while manual leaves the round ready for commissioner review."
    }

    private var teamScoringModeLabel: String {
        switch draftSettings.defaultRoundConfig.teamScoring.mode {
        case .all:
            return "All"
        case .bestN:
            return "Best \(draftSettings.defaultRoundConfig.teamScoring.count)"
        case .worstN:
            return "Worst \(draftSettings.defaultRoundConfig.teamScoring.count)"
        }
    }

    private var teamScoringKindLabel: String {
        switch draftSettings.defaultRoundConfig.teamScoring.mode {
        case .all: return "All"
        case .bestN: return "Best"
        case .worstN: return "Worst"
        }
    }

    private var defaultCourseSegmentBinding: Binding<HoleSegment> {
        .init(
            get: { draftSettings.defaultCourse?.holeSegment ?? .full18 },
            set: { newValue in
                guard var defaultCourse = draftSettings.defaultCourse else { return }
                if draftSettings.defaultCourseRotationMode == .alternateFrontBack,
                   !newValue.isNineHoleLeagueSegment {
                    defaultCourse.holeSegment = .front9
                } else {
                    defaultCourse.holeSegment = newValue
                }
                draftSettings.defaultCourse = defaultCourse
            }
        )
    }

    private var defaultCourseSegmentTitle: String {
        switch defaultCourseSegmentBinding.wrappedValue {
        case .front9:
            return "Front 9"
        case .back9:
            return "Back 9"
        case .full18:
            return "Full 18"
        default:
            return "Full 18"
        }
    }

    private var attendanceDefaultTitle: String {
        switch draftSettings.attendanceDefault {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .no:
            return "Declined"
        }
    }

    private var pairGroupingTitle: String {
        switch draftSettings.podGroupingDefault {
        case .disabled:
            return "Disabled"
        case .alignByIndex:
            return "Align by pair"
        }
    }

    private var announcementCanPost: Bool {
        announcementMessage.trimmingCharacters(in: .whitespacesAndNewlines).isPopulated
            && announcementEndsAt > announcementStartsAt
    }

    private var hasUnsavedChanges: Bool {
        draftSettings != viewModel.series.settings
    }

    private var rulesConfirmationState: SeriesLeagueRulesConfirmationState {
        viewModel.leagueRulesConfirmationState(for: draftSettings)
    }

    private var rulesConfirmationTitle: String {
        switch rulesConfirmationState {
        case .notConfirmed:
            return "Not confirmed yet"
        case let .confirmed(confirmedAt):
            return "Confirmed \(confirmedAt.formattedDate)"
        case .needsReconfirmation:
            return "Rules changed, reconfirm required"
        }
    }

    private var rulesConfirmationSubtitle: String {
        switch rulesConfirmationState {
        case .notConfirmed:
            return "Review the gameplay defaults, standings, and scoring, then confirm them to complete the checklist."
        case .confirmed:
            return "This stays complete until league gameplay rules change."
        case let .needsReconfirmation(confirmedAt):
            if let confirmedAt {
                return "Last confirmed \(confirmedAt.formattedDate). Review the updates and confirm again."
            }
            return "Review the updated gameplay rules and confirm again."
        }
    }

    private var rulesConfirmationColor: Color {
        switch rulesConfirmationState {
        case .confirmed:
            return .accentGreen
        case .notConfirmed:
            return .neutral2
        case .needsReconfirmation:
            return .systemOrange
        }
    }

    private var rulesConfirmationIcon: String {
        switch rulesConfirmationState {
        case .confirmed:
            return "checkmark.seal.fill"
        case .notConfirmed:
            return "circle.dashed"
        case .needsReconfirmation:
            return "exclamationmark.triangle.fill"
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .padding(.leading, 4)
            content()
        }
    }

    private func collapsibleCard<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SeriesSheetCard(palette: palette) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.neutral)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            content()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
    }

    private func settingsToggleLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Text(subtitle)
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private func builderField<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text(subtitle)
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)

            content()
        }
        .padding(.vertical, 2)
    }

    private func settingsChip(_ title: String, selected: Bool) -> some View {
        Chip(
            text: title,
            size: .small,
            foreground: selected ? .white : palette.foregroundColor,
            background: selected ? Color.accentGreen : Color.neutral6
        )
    }

    private func settingsMenuChip(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
            Icon(name: "f078", size: 12, weight: .solid)
                .foregroundStyle(Color.neutral)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settingsElevatedSurfaceColor)
        .cornerRadius(16)
    }

    private func settingsActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .multilineTextAlignment(.trailing)
        }
        .buttonStyle(.plain)
    }

    private func toolRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text(subtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.neutral)
        }
        .padding(12)
        .background(Color.neutral6)
        .cornerRadius(16)
    }

    private func normalizeDraftProfilesForCompetition() {
        if let defaultTeamScoringProfileID = draftSettings.defaultTeamScoringProfileID,
           let profile = viewModel.scoringProfiles.first(where: { $0.id == defaultTeamScoringProfileID }),
           (!draftSettings.useTeams || resolvedCompetitionScope != .matchup),
           profile.kind == .winTieLoss {
            draftSettings.defaultTeamScoringProfileID = viewModel.scoringProfiles.first {
                !$0.isArchived && $0.competitorType == .team && $0.kind == .placement
            }?.id
        }

        if let defaultIndividualScoringProfileID = draftSettings.defaultIndividualScoringProfileID,
           let profile = viewModel.scoringProfiles.first(where: { $0.id == defaultIndividualScoringProfileID }),
           (resolvedCompetitionScope != .matchup || draftSettings.useTeams),
           profile.kind == .winTieLoss {
            draftSettings.defaultIndividualScoringProfileID = viewModel.scoringProfiles.first {
                !$0.isArchived && $0.competitorType == .member && $0.kind == .placement
            }?.id
        }
    }

    private func normalizeSelectedTemplate() {
        guard !availableTemplates.contains(where: { $0.id == draftSettings.defaultRoundConfig.formatTemplateID }) else { return }
        draftSettings.defaultRoundConfig.formatTemplateID = availableTemplates.first?.id ?? FormatTemplateRegistry.strokePlay.id
    }

    private func normalizeDefaultCourseHoleSegmentForAlternateRotation() {
        guard draftSettings.defaultCourseRotationMode == .alternateFrontBack,
              var course = draftSettings.defaultCourse,
              !course.holeSegment.isNineHoleLeagueSegment
        else { return }
        course.holeSegment = .front9
        draftSettings.defaultCourse = course
    }

    private func openDefaultCourse() {
        Task { @MainActor in
            dismiss()
            try? await Task.sleep(nanoseconds: 150_000_000)
            onSetDefaultCourse()
        }
    }

    private func openHandicaps() {
        Task { @MainActor in
            dismiss()
            try? await Task.sleep(nanoseconds: 150_000_000)
            onOpenHandicaps()
        }
    }
}

private struct SeriesInvitePlayerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel

    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = []
    @State private var isSearching = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "League Invites",
                subtitle: "Search Hackers players and send league invites without creating duplicate members.",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    SeriesSheetCard(palette: palette) {
                        Text("Invite Players".uppercased())
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        TextField("Search Hackers players by name", text: $searchText)
                            .fontStyle(kFontName, size: 15, weight: .regular)
                            .foregroundStyle(palette.foregroundColor)
                            .mutedGlassTextFieldContainer(cornerRadius: 14)

                        if searchText.isEmpty {
                            Text("Search for existing Hackers players, then send a league invite without adding a duplicate roster record.")
                                .fontStyle(kFontName, size: 13, weight: .regular)
                                .foregroundStyle(Color.neutral)
                        } else if isSearching {
                            ProgressView()
                                .tint(Color.accentGreen)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else if searchedPlayers.isEmpty {
                            Text("No matching players found.")
                                .fontStyle(kFontName, size: 13, weight: .regular)
                                .foregroundStyle(Color.neutral)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(searchedPlayers, id: \.id) { player in
                                    playerRow(player)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .task(id: searchText) {
            await performSearch()
        }
    }

    private func playerRow(_ player: Player) -> some View {
        let isActiveMember = viewModel.activeMembers.contains { $0.playerID == player.id }
        let pendingInvite = viewModel.invites.first { $0.invitedPlayerID == player.id && $0.status == .pending }

        return SeriesSheetRow {
            HStack(spacing: 12) {
                PlayerAvatarView(initials: player.name.initials, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if isActiveMember {
                        Text("Already in league")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.neutral)
                    } else if pendingInvite != nil {
                        Text("Invite pending")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.accentGreen)
                    } else {
                        Text("Hackers player")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }

                Spacer(minLength: 0)

                if isActiveMember {
                    Chip(
                        text: "Member",
                        size: .xSmall,
                        foreground: palette.foregroundColor,
                        background: Color.neutral5
                    )
                } else if pendingInvite != nil {
                    Chip(
                        text: "Pending",
                        size: .xSmall,
                        foreground: Color.accentGreen,
                        background: Color.accentGreen.opacity(colorScheme.translucent)
                    )
                } else {
                    Button {
                        Task {
                            await viewModel.createInvite(for: player)
                        }
                    } label: {
                        Chip(
                            text: "Invite",
                            size: .xSmall,
                            foreground: .white,
                            background: Color.accentGreen
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func performSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchedPlayers = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            try await Task.sleep(nanoseconds: 250_000_000)
        } catch {
            return
        }

        guard trimmed == searchText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

        switch await FirebaseService.shared.searchPlayersByName(trimmed) {
        case .success(let results):
            searchedPlayers = results
                .filter { $0.id != viewModel.currentPlayerID }
                .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
        case .failure:
            searchedPlayers = []
        }
    }
}
