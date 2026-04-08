//
//  SeriesLeagueSettingsView.swift
//  Hackers
//

import SwiftUI

struct SeriesLeagueSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession

    @ObservedObject var viewModel: SeriesViewModel

    @State private var draftSettings = SeriesSettings()
    @State private var hasLoaded = false

    @State private var showInviteSheet = false
    @State private var showDefaultCourseSheet = false
    @State private var showHandicapSettingsSheet = false
    @State private var showDefaultTeeTimeSheet = false
    @State private var profileEditorSeed: SeriesScoringProfileEditorSeed?

    // Collapsible section state
    @State private var courseLogisticsExpanded = false
    @State private var formatExpanded = false
    @State private var teamPointsExpanded = false
    @State private var individualPointsExpanded = false

    @State private var isLoadingDefaultCourseForTeeMenu = false

    /// Tees for the default-tee Menu, sourced from the view model's cache / linked rounds (same path as SeriesRosterView).
    private var defaultLeagueTees: [Tee] {
        viewModel.teeChoices(for: draftSettings.defaultCourse)
    }

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
                    subtitle: "Manage logistics and league configuration.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    leagueBasicsSection
                    pointsAwardsSection
                    behaviorSection
                    rulesConfirmationSection
                    invitesSection.hidden()
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    PrimaryButton(
                        appearance: .fill,
                        title: "Save",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
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
                }
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
        .sheet(isPresented: $showDefaultCourseSheet) {
            SetSeriesDefaultCourseSheet(viewModel: viewModel) {
                draftSettings.defaultCourse = viewModel.series.settings.defaultCourse
                showDefaultCourseSheet = false
            }
            .environmentObject(appSession)
            .environmentObject(locationService)
            .environmentObject(roundSession)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHandicapSettingsSheet) {
            SeriesHandicapSettingsView(viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDefaultTeeTimeSheet) {
            WheelTimePickerSheet(
                title: "Set default time",
                primaryButtonTitle: "Set time",
                initialDate: defaultTeeTimeWheelSeedDate,
                onComplete: { date in
                    if let d = date {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        let h = c.hour ?? 0
                        let m = c.minute ?? 0
                        draftSettings.defaultScheduledTeeTimeMinutesFromMidnight = h * 60 + m
                    } else {
                        draftSettings.defaultScheduledTeeTimeMinutesFromMidnight = nil
                    }
                    showDefaultTeeTimeSheet = false
                }
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(360)])
        }
        .task(id: draftSettings.defaultCourse?.courseID) {
            isLoadingDefaultCourseForTeeMenu = true
            await viewModel.ensureTeeChoicesLoaded(for: draftSettings.defaultCourse)
            isLoadingDefaultCourseForTeeMenu = false
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
                                Text(draftSettings.defaultCourse?.cachedName ?? "No course selected")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(draftSettings.defaultCourse == nil ? Color.neutral : palette.foregroundColor)
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

                if draftSettings.defaultCourse != nil {
                    builderField(
                        title: "Default tee",
                        subtitle: "New rounds will default to this tee."
                    ) {
                        HStack(spacing: 8) {
                            defaultTeeMenuPill
                            if draftSettings.defaultCourse?.defaultTeeBoxID.isPopulated == true {
                                Button {
                                    Haptics.fire(.light)
                                    clearDefaultLeagueTeeSelection()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.systemError.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                builderField(
                    title: "Default tee time",
                    subtitle: "Used when commissioners turn on a scheduled date for a new round."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            Haptics.fire(.light)
                            showDefaultTeeTimeSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Text(defaultTeeTimeChipTitle)
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

                        if draftSettings.defaultScheduledTeeTimeMinutesFromMidnight != nil {
                            Button {
                                Haptics.fire(.light)
                                draftSettings.defaultScheduledTeeTimeMinutesFromMidnight = nil
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
        }
    }

    private var behaviorSection: some View {
        settingsGroup(title: "Behavior") {
            SeriesSheetCard(palette: palette) {
                Toggle(isOn: $draftSettings.useTeams) {
                    settingsToggleLabel(title: "Use teams", subtitle: "Enable persistent teams and optional fixed pairs.")
                }
                .tint(.accentGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SeriesSheetCard(palette: palette) {
                Toggle(isOn: $draftSettings.useTeamStandings) {
                    settingsToggleLabel(title: "Show team standings", subtitle: "Publish a separate team leaderboard.")
                }
                .tint(.accentGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SeriesSheetCard(palette: palette) {
                Toggle(isOn: $draftSettings.useIndividualStandings) {
                    settingsToggleLabel(title: "Show individual standings", subtitle: "Publish an individual leaderboard too.")
                }
                .tint(.accentGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SeriesSheetCard(palette: palette) {
                Toggle(isOn: $draftSettings.allowRoundEditsAfterLobbyCreation) {
                    settingsToggleLabel(title: "Allow editing after start", subtitle: "Keep round settings adjustable from the league.")
                }
                .tint(.accentGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SeriesSheetCard(palette: palette) {
                Toggle(isOn: $draftSettings.allowManualAwardOverrides) {
                    settingsToggleLabel(title: "Allow commissioner overrides", subtitle: "Keep manual control for edge cases and testing.")
                }
                .tint(.accentGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SeriesSheetCard(palette: palette) {
                Toggle(isOn: $draftSettings.isAttendanceEnabled) {
                    settingsToggleLabel(
                        title: "Collect attendance",
                        subtitle: draftSettings.isAttendanceEnabled
                            ? "Only accepted and pending invites will be added to rounds."
                            : "All players in the series will be added to planned rounds."
                    )
                }
                .tint(.accentGreen)
                .frame(maxWidth: .infinity, alignment: .leading)

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

    private var rulesConfirmationSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionTitle("League Rules")

            SeriesSheetRow(palette: palette) {
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
                    SeriesSheetRow(palette: palette) {
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

    private var defaultTeeTimeChipTitle: String {
        guard let minutes = draftSettings.defaultScheduledTeeTimeMinutesFromMidnight else {
            return "Set time"
        }
        return dateFromMinutesSinceMidnight(minutes).toTimeFormat
    }

    private var defaultTeeTimeWheelSeedDate: Date {
        if let minutes = draftSettings.defaultScheduledTeeTimeMinutesFromMidnight {
            return dateFromMinutesSinceMidnight(minutes)
        }
        return dateFromMinutesSinceMidnight(SeriesSettings.fallbackDefaultTeeMinutesFromMidnight)
    }

    private func dateFromMinutesSinceMidnight(_ minutes: Int) -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day], from: Date())
        c.hour = minutes / 60
        c.minute = minutes % 60
        c.second = 0
        return cal.date(from: c) ?? Date()
    }

    private var defaultLeagueTeeMenuChipTitle: String {
        if isLoadingDefaultCourseForTeeMenu { return "Loading…" }
        if defaultLeagueTees.isEmpty { return "Tees unavailable" }
        let id = draftSettings.defaultCourse?.defaultTeeBoxID ?? ""
        if id.isPopulated, let tee = defaultLeagueTees.first(where: { $0.id == id }) {
            let stats = leagueTeeParYardsLine(tee: tee, tees: defaultLeagueTees)
            return stats.isEmpty ? tee.name : "\(tee.name) (\(stats))"
        }
        return "Choose tee"
    }

    @ViewBuilder
    private var defaultTeeMenuPill: some View {
        if isLoadingDefaultCourseForTeeMenu {
            defaultLeagueTeeMenuStaticPill(title: "Loading…", showChevron: false)
        } else if defaultLeagueTees.isEmpty {
            defaultLeagueTeeMenuStaticPill(title: "Tees unavailable", showChevron: false)
        } else {
            Menu {
                defaultLeagueTeeMenuSections(for: defaultLeagueTees)
            } label: {
                defaultLeagueTeeMenuPillLabel(title: defaultLeagueTeeMenuChipTitle, showChevron: true, lineLimit: 2)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func defaultLeagueTeeMenuSections(for tees: [Tee]) -> some View {
        let segment = draftSettings.defaultCourse?.holeSegment ?? .full18
        let maleTees = sortedTeesForLeagueMenu(tees: tees, holeSegment: segment) { $0.gender == Gender.male.rawValue }
        let femaleTees = sortedTeesForLeagueMenu(tees: tees, holeSegment: segment) { $0.gender == Gender.female.rawValue }
        let otherTees = sortedTeesForLeagueMenu(tees: tees, holeSegment: segment) {
            $0.gender != Gender.male.rawValue && $0.gender != Gender.female.rawValue
        }
        if maleTees.isPopulated {
            Menu {
                ForEach(maleTees, id: \.id) { tee in
                    defaultLeagueTeeMenuButton(for: tee, tees: tees)
                }
            } label: { Text("Men's") }
        }
        if femaleTees.isPopulated {
            Menu {
                ForEach(femaleTees, id: \.id) { tee in
                    defaultLeagueTeeMenuButton(for: tee, tees: tees)
                }
            } label: { Text("Women's") }
        }
        if otherTees.isPopulated {
            Menu {
                ForEach(otherTees, id: \.id) { tee in
                    defaultLeagueTeeMenuButton(for: tee, tees: tees)
                }
            } label: { Text("Other") }
        }
    }

    private func defaultLeagueTeeMenuButton(for tee: Tee, tees: [Tee]) -> some View {
        let stats = leagueTeeParYardsLine(tee: tee, tees: tees)
        return Button {
            Haptics.fire(.light)
            selectDefaultLeagueTee(tee.id)
        } label: {
            if draftSettings.defaultCourse?.defaultTeeBoxID == tee.id {
                Label(tee.name, systemImage: "checkmark")
            } else {
                Text(tee.name)
            }
            if stats.isPopulated {
                Text(stats)
            }
//            HStack(alignment: .firstTextBaseline) {
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(tee.name)
//                        //.fontStyle(kFontName, size: 15, weight: .regular)
//                    if stats.isPopulated {
//                        Text(stats)
//                            //.fontStyle(kFontName, size: 12, weight: .regular)
//                            //.foregroundStyle(Color.neutral)
//                    }
//                }
//                .frame(maxWidth: .infinity, alignment: .leading)
//                if draftSettings.defaultCourse?.defaultTeeBoxID == tee.id {
//                    Image(systemName: "checkmark")
//                }
//            }
        }
    }

    private func defaultLeagueTeeMenuPillLabel(title: String, showChevron: Bool, lineLimit: Int = 1) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if showChevron {
                Icon(name: "f078", size: 12, weight: .solid)
                    .foregroundStyle(Color.neutral)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settingsElevatedSurfaceColor)
        .cornerRadius(16)
    }

    private func defaultLeagueTeeMenuStaticPill(title: String, showChevron: Bool) -> some View {
        defaultLeagueTeeMenuPillLabel(title: title, showChevron: showChevron)
    }

    private func selectDefaultLeagueTee(_ teeID: String) {
        guard var c = draftSettings.defaultCourse else { return }
        c.defaultTeeBoxID = teeID
        draftSettings.defaultCourse = c
    }

    private func clearDefaultLeagueTeeSelection() {
        guard var c = draftSettings.defaultCourse else { return }
        c.defaultTeeBoxID = ""
        draftSettings.defaultCourse = c
    }

    private func leagueDefaultHoleRange(tees: [Tee]) -> HoleRange? {
        let segment = draftSettings.defaultCourse?.holeSegment ?? .full18
        let totalHoles = tees.map(\.totalHoles).max() ?? segment.holeCount
        return segment.toHoleRange(totalHoles: totalHoles)
    }

    private func leagueTeePar(tee: Tee, range: HoleRange) -> Int {
        tee.holes.reduce(0) { result, hole in
            range.contains(hole.number) ? result + hole.par : result
        }
    }

    private func leagueTeeYardage(tee: Tee, range: HoleRange) -> Int {
        tee.holes.reduce(0) { result, hole in
            range.contains(hole.number) ? result + hole.yardage : result
        }
    }

    /// "Par 72 / 6038 yds" for the league default segment (or all tee holes if range unavailable).
    private func leagueTeeParYardsLine(tee: Tee, tees: [Tee]) -> String {
        if let range = leagueDefaultHoleRange(tees: tees) {
            let par = leagueTeePar(tee: tee, range: range)
            let yds = leagueTeeYardage(tee: tee, range: range)
            return "Par \(par) / \(yds) yds"
        }
        guard tee.holes.isPopulated else { return "" }
        let par = tee.holes.reduce(0) { $0 + $1.par }
        let yds = tee.holes.reduce(0) { $0 + $1.yardage }
        return "Par \(par) / \(yds) yds"
    }

    private func sortedTeesForLeagueMenu(
        tees: [Tee],
        holeSegment: HoleSegment,
        where predicate: (Tee) -> Bool
    ) -> [Tee] {
        let totalHoles = tees.map(\.totalHoles).max() ?? holeSegment.holeCount
        guard let range = holeSegment.toHoleRange(totalHoles: totalHoles) else {
            return tees.filter(predicate).sorted { $0.name < $1.name }
        }
        return tees.filter(predicate).sorted { lhs, rhs in
            let yl = leagueTeeYardage(tee: lhs, range: range)
            let yr = leagueTeeYardage(tee: rhs, range: range)
            if yl != yr { return yl > yr }
            return lhs.name < rhs.name
        }
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
        "Individual points set how each round adds to the series leaderboard."
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
            background: selected ? Color.accentGreen : palette.cardEmbeddedRowBackground
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
        showDefaultCourseSheet = true
    }

    private func openHandicaps() {
        showHandicapSettingsSheet = true
    }
}

private struct SeriesInvitePlayerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel

    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = []
    @State private var isSearching = false

    @FocusState private var searchFocused: Bool

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
                            .focused($searchFocused)
                            .borderedContentStyle(
                                isActive: searchFocused,
                                theme: palette.theme,
                                fill: palette.cardEmbeddedRowBackground
                            )

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

        return SeriesSheetRow(palette: palette) {
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
