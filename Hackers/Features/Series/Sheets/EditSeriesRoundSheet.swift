//
//  EditSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct EditSeriesRoundSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    let seriesRound: SeriesRound
    var onSaved: () -> Void

    @State private var title = ""
    @State private var scheduledDate = Date()
    @State private var hasDate = false
    @State private var selectedTemplateID = FormatTemplateRegistry.strokePlay.id
    @State private var competitionScope: CompetitionScope = .field
    @State private var scoreOwnerScope: RoundScoreOwnerScope = .individual
    @State private var matchupScoringStyle: RoundMatchupScoringStyle = .aggregateRoundTotal
    @State private var holeWinPoints: Double = 1
    @State private var matchWinnerBonusPoints: Double = 0
    @State private var teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
    @State private var sequentialTeeStartsEnabled = false
    @State private var podGroupingStrategy: SeriesPodGroupingStrategy = .disabled
    @State private var selectedTeamProfileID: String?
    @State private var selectedIndividualProfileID: String?
    @State private var countsTowardHandicapPool = true
    @State private var excludedHandicapMemberIDs: [String] = []
    @State private var notes = ""
    @State private var selectedCourse: SeriesCourseSelection?
    @State private var matchupPlans: [SeriesRoundMatchupPlan] = []
    @State private var plannedMatchups: [SeriesRoundPlannedMatchup] = []
    @State private var plannedTeeGroups: [SeriesRoundPlannedTeeGroup] = []
    @State private var profileEditorSeed: SeriesScoringProfileEditorSeed?
    @State private var showCoursePicker = false
    @State private var isSaving = false

    private enum RoundEditorField: Hashable {
        case title
        case notes
    }

    @FocusState private var focusedField: RoundEditorField?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var leagueDefaults: SeriesRoundConfiguration { viewModel.series.settings.defaultRoundConfig }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Edit Round",
                    subtitle: "Update the schedule, format, awards, and notes for this week.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    basicsSection
                    courseSection
                    formatSection
                    handicapParticipationSection
                    if competitionScope == .matchup {
                        matchupSection
                    }
                    planningSection
                    scoringSection
                    notesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "Saving..." : "Save changes")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(isSaving ? palette.foregroundColor : palette.backgroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSaving ? Color.neutral3 : palette.foregroundColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showCoursePicker) {
            SeriesRoundCoursePickerSheet(initialSelection: selectedCourse) { selection in
                selectedCourse = selection
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.createBuiltInScoringProfilesIfNeeded()
            title = seriesRound.title
            if let scheduledAt = seriesRound.scheduledAt {
                hasDate = true
                scheduledDate = Date(timeIntervalSince1970: scheduledAt.unix)
            }
            selectedTemplateID = seriesRound.roundConfig.formatTemplateID
            normalizeSelectedTemplate()
            competitionScope = seriesRound.roundConfig.resolvedCompetitionScope
            scoreOwnerScope = seriesRound.roundConfig.scoreOwnerScope
            matchupScoringStyle = seriesRound.roundConfig.matchupScoringStyle
            holeWinPoints = seriesRound.roundConfig.resolvedHoleWinPoints
            matchWinnerBonusPoints = seriesRound.roundConfig.resolvedMatchWinnerBonusPoints
            teamScoring = seriesRound.roundConfig.teamScoring
            sequentialTeeStartsEnabled = seriesRound.roundConfig.sequentialTeeStartsEnabled ?? false
            podGroupingStrategy = seriesRound.roundConfig.podGroupingStrategy
            countsTowardHandicapPool = seriesRound.roundConfig.countsTowardHandicapPool
            excludedHandicapMemberIDs = seriesRound.roundConfig.normalizedExcludedHandicapMemberIDs
            selectedTeamProfileID = seriesRound.teamScoringProfileID
            selectedIndividualProfileID = seriesRound.individualScoringProfileID
            notes = seriesRound.notes ?? seriesRound.roundConfig.notes ?? ""
            selectedCourse = seriesRound.courseOverride ?? viewModel.suggestedCourseSelection(forRoundIndex: seriesRound.index)
            matchupPlans = seriesRound.matchupPlans.isEmpty && competitionScope == .matchup
                ? (viewModel.usesTeams
                    ? viewModel.suggestedMatchupPlans(pairGroupingStrategy: podGroupingStrategy)
                    : viewModel.suggestedIndividualMatchupPlans(preserving: seriesRound.matchupPlans))
                : seriesRound.matchupPlans.sorted { $0.index < $1.index }
            plannedMatchups = seriesRound.plannedMatchups
            plannedTeeGroups = seriesRound.plannedTeeGroups
            refreshPlanningStructure(forceRegenerate: !seriesRound.plannedTeeGroups.isPopulated)
            normalizeSelectedProfilesForCompetition()
        }
        .onChange(of: competitionScope) { _, newValue in
            if newValue == .matchup, matchupPlans.isEmpty {
                matchupPlans = viewModel.usesTeams
                    ? viewModel.suggestedMatchupPlans(
                        pairGroupingStrategy: podGroupingStrategy,
                        preserving: seriesRound.matchupPlans
                    )
                    : viewModel.suggestedIndividualMatchupPlans(preserving: seriesRound.matchupPlans)
            }
            if newValue != .matchup {
                matchupPlans = []
            }
            refreshPlanningStructure()
            normalizeSelectedProfilesForCompetition()
        }
        .onChange(of: podGroupingStrategy) { _, newValue in
            matchupPlans = matchupPlans.enumerated().map { index, plan in
                var updated = plan
                updated.index = index
                updated.podGroupingStrategy = newValue
                updated.lastUpdatedAt = .init()
                return updated
            }
            refreshPlanningStructure()
        }
        .onChange(of: matchupPlans) { _, _ in refreshPlanningStructure() }
        .onChange(of: selectedCourse) { _, _ in refreshPlanningStructure() }
        .onChange(of: scheduledDate) { _, _ in if hasDate { refreshPlanningStructure() } }
        .onChange(of: hasDate) { _, _ in refreshPlanningStructure(forceRegenerate: false) }
        .onChange(of: sequentialTeeStartsEnabled) { _, _ in refreshPlanningStructure() }
        .sheet(item: $profileEditorSeed) { seed in
            SeriesScoringProfileEditorSheet(viewModel: viewModel, seed: seed) { saved in
                if saved.competitorType == .team {
                    selectedTeamProfileID = saved.id
                } else {
                    selectedIndividualProfileID = saved.id
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var basicsSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionHeaderRow("Round", status: basicsSectionStatus)

            VStack(alignment: .leading, spacing: 8) {
                Text("Round name")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                TextField("Round title", text: $title)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .focused($focusedField, equals: .title)
                    .borderedContentStyle(
                        isActive: focusedField == .title,
                        theme: palette.theme,
                        fill: palette.cardEmbeddedRowBackground
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Schedule")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                HStack(spacing: 8) {
                    Button {
                        hasDate = false
                    } label: {
                        formChip("Flexible", selected: !hasDate)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if !hasDate {
                            scheduledDate = SeriesScheduleDefaultDatePicker.nextPresetDate(for: viewModel.series.settings)
                        }
                        hasDate = true
                    } label: {
                        formChip("Set date", selected: hasDate)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }

                if hasDate {
                    DatePicker("Scheduled date", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .borderedContentStyle(theme: palette.theme, fill: palette.cardEmbeddedRowBackground)
                } else {
                    Text("Keep the schedule flexible before and after lobby creation if you want to finalize it later.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
    }

    private var courseSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionHeaderRow("Course", status: courseSectionStatus)

            SeriesSheetRow(palette: palette) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedCourse?.cachedName ?? "No course selected")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(selectedCourse == nil ? Color.neutral : palette.foregroundColor)

                    Text(courseDetailText)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            SeriesSheetRow(palette: palette) {
                HStack(spacing: 10) {
                    Button {
                        showCoursePicker = true
                    } label: {
                        Chip(
                            text: selectedCourse == nil ? "Choose course" : "Change course",
                            size: .small,
                            foreground: .white,
                            background: Color.accentGreen
                        )
                    }
                    .buttonStyle(.plain)

                    if let leagueDefault = viewModel.suggestedCourseSelection(forRoundIndex: seriesRound.index) ?? viewModel.series.settings.defaultCourse {
                        Button {
                            selectedCourse = leagueDefault
                        } label: {
                            Chip(
                                text: "Use league default",
                                size: .small,
                                foreground: palette.foregroundColor,
                                background: Color.neutral6
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if selectedCourse != nil {
                        Button {
                            selectedCourse = nil
                        } label: {
                            Chip(
                                text: "Clear",
                                size: .small,
                                foreground: palette.foregroundColor,
                                background: Color.neutral6
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var formatSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionHeaderRow("Format", status: formatSectionStatus)

            builderField(
                title: "Template",
                subtitle: "Choose how each individual player score is computed."
            ) {
                Menu {
                    ForEach(availableTemplates, id: \.id) { template in
                        Button {
                            selectedTemplateID = template.id
                        } label: {
                            HStack {
                                Text(template.name)
                                if template.id == selectedTemplateID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    menuChipLabel(templateName)
                }
                .buttonStyle(.plain)
            }

            builderField(
                title: "Competition",
                subtitle: viewModel.usesTeams
                    ? "Field compares everyone together. Matchup compares the scheduled head-to-head pairings."
                    : "Field compares everyone together. Matchup creates player-vs-player pairings for this round."
            ) {
                HStack(spacing: 8) {
                    Button {
                        competitionScope = .field
                    } label: {
                        formChip("Field", selected: competitionScope == .field)
                    }
                    .buttonStyle(.plain)

                    Button {
                        competitionScope = .matchup
                    } label: {
                        formChip("Matchup", selected: competitionScope == .matchup)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.usesTeams {
                builderField(
                    title: "Score entry",
                    subtitle: "Collect scores by player, partnership, or full tee group. Partnerships seed from fixed pairs and can be customized in the round lobby."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            scoreOwnerScope = .individual
                        } label: {
                            formChip("Individual", selected: scoreOwnerScope == .individual)
                        }
                        .buttonStyle(.plain)

                        Button {
                            scoreOwnerScope = .partnership
                        } label: {
                            formChip("Partnership", selected: scoreOwnerScope == .partnership)
                        }
                        .buttonStyle(.plain)

                        Button {
                            scoreOwnerScope = .teeGroup
                        } label: {
                            formChip("Tee group", selected: scoreOwnerScope == .teeGroup)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.usesTeams {
                builderField(
                    title: "Count scores",
                    subtitle: "Choose whether every team score counts or only the best or worst scores."
                ) {
                    HStack(spacing: 10) {
                        Menu {
                            Button {
                                teamScoring.mode = .all
                            } label: {
                                HStack {
                                    Text("All")
                                    if teamScoring.mode == .all { Image(systemName: "checkmark") }
                                }
                            }
                            Button {
                                teamScoring.mode = .bestN
                                if teamScoring.count < 1 || teamScoring.count > 4 { teamScoring.count = 2 }
                            } label: {
                                HStack {
                                    Text("Best")
                                    if teamScoring.mode == .bestN { Image(systemName: "checkmark") }
                                }
                            }
                            Button {
                                teamScoring.mode = .worstN
                                if teamScoring.count < 1 || teamScoring.count > 4 { teamScoring.count = 2 }
                            } label: {
                                HStack {
                                    Text("Worst")
                                    if teamScoring.mode == .worstN { Image(systemName: "checkmark") }
                                }
                            }
                        } label: {
                            menuChipLabel(teamScoringKindLabel)
                        }
                        .buttonStyle(.plain)

                        if teamScoring.mode == .bestN || teamScoring.mode == .worstN {
                            Menu {
                                ForEach(1...4, id: \.self) { n in
                                    Button {
                                        teamScoring.count = n
                                    } label: {
                                        HStack {
                                            Text("\(n)")
                                            if teamScoring.count == n { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                menuChipLabel("\(teamScoring.count)")
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
                            teamScoring.scope = .perHole
                        } label: {
                            formChip("Hole", selected: teamScoring.scope == .perHole)
                        }
                        .buttonStyle(.plain)

                        Button {
                            teamScoring.scope = .perRound
                        } label: {
                            formChip("Round", selected: teamScoring.scope == .perRound)
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
                        sequentialTeeStartsEnabled = false
                    } label: {
                        formChip("Off", selected: !sequentialTeeStartsEnabled)
                    }
                    .buttonStyle(.plain)

                    Button {
                        sequentialTeeStartsEnabled = true
                    } label: {
                        formChip("On", selected: sequentialTeeStartsEnabled)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.usesTeams {
                builderField(
                    title: "Pair grouping",
                    subtitle: pairGroupingSubtitle
                ) {
                    HStack(spacing: 8) {
                        Button {
                            podGroupingStrategy = .disabled
                        } label: {
                            formChip("Manual", selected: podGroupingStrategy == .disabled)
                        }
                        .buttonStyle(.plain)

                        Button {
                            podGroupingStrategy = .alignByIndex
                        } label: {
                            formChip("Align pairs", selected: podGroupingStrategy == .alignByIndex)
                        }
                        .buttonStyle(.plain)

                        Button {
                            podGroupingStrategy = .swapPairs
                        } label: {
                            formChip(pairGroupingSwapTitle, selected: podGroupingStrategy == .swapPairs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var matchupSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionTitle("Matchups")

            Text(viewModel.usesTeams
                ? "Adjust weekly team pairings here. If you leave the matchup list empty, the app can still auto-pair teams by order."
                : "Set the player-vs-player pairings for this round. These pairings drive individual matchup scoring and WLT awards.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            if matchupPlans.isEmpty {
                SeriesSheetRow(palette: palette) {
                    Text(viewModel.usesTeams
                        ? "No matchups yet. Auto-fill from team order or add one manually."
                        : "No pairings yet. Auto-fill from the current player order or add one manually.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            } else {
                ForEach(Array(matchupPlans.enumerated()), id: \.element.id) { index, plan in
                    SeriesSheetRow(palette: palette) {
                        matchupRow(index: index, plan: plan)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    matchupPlans = viewModel.usesTeams
                        ? viewModel.suggestedMatchupPlans(
                            pairGroupingStrategy: podGroupingStrategy,
                            preserving: matchupPlans
                        )
                        : viewModel.suggestedIndividualMatchupPlans(preserving: matchupPlans)
                } label: {
                    Chip(
                        text: "Auto-fill",
                        size: .small,
                        foreground: palette.foregroundColor,
                        background: palette.cardEmbeddedRowBackground
                    )
                }
                .buttonStyle(.plain)

                Button {
                    matchupPlans.append(
                        SeriesRoundMatchupPlan(
                            id: HackersID.string(),
                            index: matchupPlans.count,
                            podGroupingStrategy: podGroupingStrategy,
                            createdAt: .init(),
                            lastUpdatedAt: .init()
                        )
                    )
                } label: {
                    Chip(
                        text: "Add matchup",
                        size: .small,
                        foreground: .white,
                        background: Color.accentGreen
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
    }

    private var handicapParticipationSection: some View {
        SeriesRoundHandicapParticipationCard(
            viewModel: viewModel,
            seriesRound: seriesRound,
            selectedTemplateID: selectedTemplateID,
            countsTowardHandicapPool: $countsTowardHandicapPool,
            excludedHandicapMemberIDs: $excludedHandicapMemberIDs
        )
    }

    private var scoringSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionTitle("Series Points")

            Text(seriesPointsDescription)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            if competitionScope == .matchup {
                builderField(
                    title: "Matchup scoring",
                    subtitle: "Use one winner for the whole round, or award configurable points hole-by-hole and add an optional match winner bonus."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            matchupScoringStyle = .aggregateRoundTotal
                        } label: {
                            formChip("Round winner", selected: matchupScoringStyle == .aggregateRoundTotal)
                        }
                        .buttonStyle(.plain)

                        Button {
                            matchupScoringStyle = .holeByHolePoints
                        } label: {
                            formChip("Hole points", selected: matchupScoringStyle == .holeByHolePoints)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if matchupScoringStyle == .holeByHolePoints {
                    builderField(
                        title: "Hole value",
                        subtitle: "Points awarded to the hole winner."
                    ) {
                        Menu {
                            ForEach([0.5, 1, 2, 3], id: \.self) { value in
                                Button {
                                    holeWinPoints = value
                                } label: {
                                    HStack {
                                        Text(value == floor(value) ? String(Int(value)) : String(format: "%.1f", value))
                                        if holeWinPoints == value { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            menuChipLabel(holeWinPoints == floor(holeWinPoints)
                                ? String(Int(holeWinPoints))
                                : String(format: "%.1f", holeWinPoints))
                        }
                        .buttonStyle(.plain)
                    }

                    builderField(
                        title: "Winner bonus",
                        subtitle: "Extra points awarded only when there is a unique match winner."
                    ) {
                        Menu {
                            ForEach([0.0, 1, 2, 3, 4], id: \.self) { value in
                                Button {
                                    matchWinnerBonusPoints = value
                                } label: {
                                    HStack {
                                        Text(value == floor(value) ? String(Int(value)) : String(format: "%.1f", value))
                                        if matchWinnerBonusPoints == value { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            menuChipLabel(matchWinnerBonusPoints == floor(matchWinnerBonusPoints)
                                ? String(Int(matchWinnerBonusPoints))
                                : String(format: "%.1f", matchWinnerBonusPoints))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.usesTeams {
                SeriesScoringProfileSelectionCard(
                    viewModel: viewModel,
                    title: "Team awards",
                    subtitle: "Choose how team points are assigned for this round.",
                    competitorType: .team,
                    competitionScope: competitionScope,
                    supportsWinTieLoss: competitionScope == .matchup,
                    selectedProfileID: $selectedTeamProfileID
                ) { seed in
                    profileEditorSeed = seed
                }
            }

            SeriesScoringProfileSelectionCard(
                viewModel: viewModel,
                title: "Individual awards",
                subtitle: "Choose how player points are assigned for this round.",
                competitorType: .member,
                competitionScope: competitionScope,
                supportsWinTieLoss: competitionScope == .matchup && !viewModel.usesTeams,
                selectedProfileID: $selectedIndividualProfileID
            ) { seed in
                profileEditorSeed = seed
            }
        }
    }

    private var notesSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionHeaderRow("Notes", status: .optional)

            Text("Use this space for weekly instructions, pairings context, weather notes, or commissioner reminders.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            TextEditor(text: $notes)
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .notes)
                .borderedContentStyle(
                    isActive: focusedField == .notes,
                    theme: palette.theme,
                    fill: palette.cardEmbeddedRowBackground
                )
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let resolvedCompetitionScope = competitionScope
        let roundConfig = SeriesRoundConfiguration(
            formatTemplateID: selectedTemplateID,
            competitionScope: resolvedCompetitionScope,
            teamScoring: teamScoring,
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: scoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            matchupMode: resolvedCompetitionScope == .matchup
                ? (viewModel.usesTeams ? .teamVsTeam : .individualVsIndividual)
                : .field,
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            countsTowardHandicapPool: countsTowardHandicapPool,
            excludedHandicapMemberIDs: excludedHandicapMemberIDs
        )
        let resolvedMatchups = normalizedMatchupPlans()
        let plannedStructure = persistedPlanningStructure()

        Task {
            await viewModel.updateSeriesRound(
                seriesRound,
                title: title,
                scheduledAt: hasDate ? Time(for: scheduledDate) : nil,
                courseOverride: selectedCourse,
                shouldUpdateCourseOverride: true,
                roundConfig: roundConfig,
                teamScoringProfileID: selectedTeamProfileID,
                individualScoringProfileID: selectedIndividualProfileID,
                matchupPlans: resolvedMatchups,
                plannedMatchups: plannedStructure.matchups,
                plannedTeeGroups: plannedStructure.teeGroups,
                notes: notes.isEmpty ? nil : notes
            )
            isSaving = false
            onSaved()
            dismiss()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
    }

    private var courseDetailText: String {
        guard let selectedCourse else {
            return "This round can inherit the league default later, or you can leave it blank for now."
        }
        if let leagueDefault = viewModel.series.settings.defaultCourse,
           selectedCourse.courseID == leagueDefault.courseID {
            switch viewModel.series.settings.defaultCourseRotationMode {
            case .fixed:
                return "\(selectedCourse.holeSegment.title) from league default"
            case .alternateFrontBack:
                return "\(selectedCourse.holeSegment.title) from the alternating league default"
            }
        }
        return selectedCourse.holeSegment.title
    }

    private var pairGroupingDisplayPlans: [SeriesRoundMatchupPlan] {
        let configuredPlans = matchupPlans.filter { $0.teamAID.isPopulated && $0.teamBID.isPopulated }
        if configuredPlans.isPopulated { return configuredPlans }
        return viewModel.suggestedMatchupPlans(
            pairGroupingStrategy: podGroupingStrategy,
            preserving: seriesRound.matchupPlans
        )
    }

    private var pairGroupingSwapTitle: String {
        viewModel.pairGroupingTitle(for: .swapPairs, matchupPlans: pairGroupingDisplayPlans)
    }

    private var pairGroupingSubtitle: String {
        viewModel.pairGroupingSubtitle(for: podGroupingStrategy, matchupPlans: pairGroupingDisplayPlans)
    }

    private var planningMembers: [SeriesMember] {
        viewModel.eligibleMembers
    }

    private var planningTeamsByID: [String: SeriesTeam] {
        Dictionary(uniqueKeysWithValues: viewModel.sortedTeams.map { ($0.id, $0) })
    }

    private var planningMembersByID: [String: SeriesMember] {
        Dictionary(uniqueKeysWithValues: planningMembers.map { ($0.id, $0) })
    }

    private var planningCourseSelection: SeriesCourseSelection? {
        selectedCourse ?? viewModel.suggestedCourseSelection(forRoundIndex: seriesRound.index)
    }

    private var planningHoleRange: HoleRange {
        planningCourseSelection?.holeSegment.holeRange ?? .init(startHole: 1, endHole: 18)
    }

    private func normalizedMatchupPlans() -> [SeriesRoundMatchupPlan] {
        guard competitionScope == .matchup else { return [] }

        let source = matchupPlans.isEmpty
            ? (viewModel.usesTeams
                ? viewModel.suggestedMatchupPlans(
                    pairGroupingStrategy: podGroupingStrategy,
                    preserving: seriesRound.matchupPlans
                )
                : viewModel.suggestedIndividualMatchupPlans(preserving: seriesRound.matchupPlans))
            : matchupPlans

        return source.enumerated().compactMap { index, plan in
            var updated = plan
            if viewModel.usesTeams {
                guard plan.teamAID.isPopulated, plan.teamBID.isPopulated, plan.teamAID != plan.teamBID else { return nil }
            } else {
                guard let memberAID = plan.memberAID,
                      let memberBID = plan.memberBID,
                      memberAID.isPopulated,
                      memberBID.isPopulated,
                      memberAID != memberBID else { return nil }
                updated.memberAID = memberAID
                updated.memberBID = memberBID
                updated.teamAID = ""
                updated.teamBID = ""
            }
            updated.index = index
            updated.podGroupingStrategy = viewModel.usesTeams ? podGroupingStrategy : .disabled
            updated.lastUpdatedAt = .init()
            return updated
        }
    }

    private var planningDraftRound: SeriesRound {
        let roundConfig = SeriesRoundConfiguration(
            formatTemplateID: selectedTemplateID,
            competitionScope: competitionScope,
            teamScoring: teamScoring,
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: scoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            matchupMode: competitionScope == .matchup
                ? (viewModel.usesTeams ? .teamVsTeam : .individualVsIndividual)
                : .field,
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            countsTowardHandicapPool: countsTowardHandicapPool,
            excludedHandicapMemberIDs: excludedHandicapMemberIDs
        )
        return SeriesRound(
            id: seriesRound.id,
            title: title,
            index: seriesRound.index,
            status: seriesRound.status,
            scheduledAt: hasDate ? Time(for: scheduledDate) : nil,
            roundID: seriesRound.roundID,
            startedAt: seriesRound.startedAt,
            completedAt: seriesRound.completedAt,
            courseOverride: planningCourseSelection,
            roundConfig: roundConfig,
            teamScoringProfileID: selectedTeamProfileID,
            individualScoringProfileID: selectedIndividualProfileID,
            matchupPlans: normalizedMatchupPlans(),
            plannedMatchups: plannedMatchups,
            plannedTeeGroups: plannedTeeGroups,
            partnershipPlans: seriesRound.partnershipPlans,
            notes: notes.isEmpty ? nil : notes,
            awardsStatus: seriesRound.awardsStatus,
            awardsFinalizedAt: seriesRound.awardsFinalizedAt,
            lastScoreAdjustmentAt: seriesRound.lastScoreAdjustmentAt,
            lastScoreAdjustmentByMemberID: seriesRound.lastScoreAdjustmentByMemberID,
            lastScoreAdjustmentReason: seriesRound.lastScoreAdjustmentReason,
            scoreAdjustmentCount: seriesRound.scoreAdjustmentCount,
            createdAt: seriesRound.createdAt,
            lastUpdatedAt: .init(),
            parentID: seriesRound.parentID
        )
    }

    private func persistedPlanningStructure() -> SeriesRoundPlannedStructure {
        let structure = SeriesRoundPlanningService.resolvedPlannedStructure(
            series: viewModel.series,
            seriesRound: planningDraftRound,
            members: planningMembers,
            teams: viewModel.sortedTeams,
            pods: viewModel.pods,
            courseSelection: planningCourseSelection
        )
        return .init(
            matchups: normalizedMatchupPlans().map {
                SeriesRoundPlannedMatchup(plan: $0, source: .manualOverride)
            },
            teeGroups: structure.teeGroups
        )
    }

    private func refreshPlanningStructure(forceRegenerate: Bool = false) {
        let draft = SeriesRound(
            id: planningDraftRound.id,
            title: planningDraftRound.title,
            index: planningDraftRound.index,
            status: planningDraftRound.status,
            scheduledAt: planningDraftRound.scheduledAt,
            roundID: planningDraftRound.roundID,
            startedAt: planningDraftRound.startedAt,
            completedAt: planningDraftRound.completedAt,
            courseOverride: planningDraftRound.courseOverride,
            roundConfig: planningDraftRound.roundConfig,
            teamScoringProfileID: planningDraftRound.teamScoringProfileID,
            individualScoringProfileID: planningDraftRound.individualScoringProfileID,
            matchupPlans: planningDraftRound.matchupPlans,
            plannedMatchups: normalizedMatchupPlans().map {
                SeriesRoundPlannedMatchup(plan: $0, source: .manualOverride)
            },
            plannedTeeGroups: forceRegenerate ? [] : plannedTeeGroups,
            partnershipPlans: planningDraftRound.partnershipPlans,
            notes: planningDraftRound.notes,
            awardsStatus: planningDraftRound.awardsStatus,
            awardsFinalizedAt: planningDraftRound.awardsFinalizedAt,
            lastScoreAdjustmentAt: planningDraftRound.lastScoreAdjustmentAt,
            lastScoreAdjustmentByMemberID: planningDraftRound.lastScoreAdjustmentByMemberID,
            lastScoreAdjustmentReason: planningDraftRound.lastScoreAdjustmentReason,
            scoreAdjustmentCount: planningDraftRound.scoreAdjustmentCount,
            createdAt: planningDraftRound.createdAt,
            lastUpdatedAt: planningDraftRound.lastUpdatedAt,
            parentID: planningDraftRound.parentID
        )
        let structure = SeriesRoundPlanningService.resolvedPlannedStructure(
            series: viewModel.series,
            seriesRound: draft,
            members: planningMembers,
            teams: viewModel.sortedTeams,
            pods: viewModel.pods,
            courseSelection: planningCourseSelection
        )
        plannedMatchups = structure.matchups
        if forceRegenerate || !plannedTeeGroups.contains(where: \.hasManualOverrides) {
            plannedTeeGroups = structure.teeGroups
        }
    }

    private var planningSection: some View {
        SeriesRoundTeeSheetPlanningCard(
            palette: palette,
            holeRange: planningHoleRange,
            plannedMatchups: plannedMatchups,
            membersByID: planningMembersByID,
            teamsByID: planningTeamsByID,
            plannedTeeGroups: $plannedTeeGroups,
            onRegenerate: { refreshPlanningStructure(forceRegenerate: true) },
            onResetManualOverrides: { refreshPlanningStructure(forceRegenerate: true) }
        )
    }

    private func matchupRow(index: Int, plan: SeriesRoundMatchupPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Matchup \(index + 1)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Button {
                    matchupPlans.removeAll { $0.id == plan.id }
                    matchupPlans = matchupPlans.enumerated().map { rowIndex, item in
                        var updated = item
                        updated.index = rowIndex
                        return updated
                    }
                } label: {
                    Chip(
                        text: "Remove",
                        size: .xSmall,
                        foreground: .systemError,
                        background: Color.systemError.opacity(colorScheme.translucent)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if viewModel.usesTeams {
                    matchupTeamMenu(
                        title: "Team A",
                        selection: teamName(for: plan.teamAID) ?? "Choose",
                        availableTeams: availableTeams(for: plan, currentTeamID: plan.teamAID)
                    ) { selectedTeamID in
                        updateMatchup(planID: plan.id, teamAID: selectedTeamID)
                    }
                } else {
                    matchupMemberMenu(
                        title: "Player A",
                        selection: memberName(for: plan.memberAID) ?? "Choose",
                        availableMembers: availableMembers(for: plan, currentMemberID: plan.memberAID)
                    ) { selectedMemberID in
                        updateMatchup(planID: plan.id, memberAID: selectedMemberID)
                    }
                }

                Text("vs")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)

                if viewModel.usesTeams {
                    matchupTeamMenu(
                        title: "Team B",
                        selection: teamName(for: plan.teamBID) ?? "Choose",
                        availableTeams: availableTeams(for: plan, currentTeamID: plan.teamBID)
                    ) { selectedTeamID in
                        updateMatchup(planID: plan.id, teamBID: selectedTeamID)
                    }
                } else {
                    matchupMemberMenu(
                        title: "Player B",
                        selection: memberName(for: plan.memberBID) ?? "Choose",
                        availableMembers: availableMembers(for: plan, currentMemberID: plan.memberBID)
                    ) { selectedMemberID in
                        updateMatchup(planID: plan.id, memberBID: selectedMemberID)
                    }
                }
            }
        }
    }

    private func matchupTeamMenu(
        title: String,
        selection: String,
        availableTeams: [SeriesTeam],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            Menu {
                ForEach(availableTeams, id: \.id) { team in
                    Button(team.name) {
                        onSelect(team.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection)
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(selection == "Choose" ? Color.neutral : palette.foregroundColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Icon(name: "f078", size: 12, weight: .solid)
                        .foregroundStyle(Color.neutral)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.neutral6)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func availableTeams(for plan: SeriesRoundMatchupPlan, currentTeamID: String) -> [SeriesTeam] {
        let usedTeamIDs = Set(
            matchupPlans
                .filter { $0.id != plan.id }
                .flatMap { [$0.teamAID, $0.teamBID] }
                .filter(\.isPopulated)
        )
        return viewModel.sortedTeams.filter { team in
            team.id == currentTeamID || !usedTeamIDs.contains(team.id)
        }
    }

    private func matchupMemberMenu(
        title: String,
        selection: String,
        availableMembers: [SeriesMember],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            Menu {
                ForEach(availableMembers, id: \.id) { member in
                    Button(member.name.fullName) {
                        onSelect(member.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection)
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(selection == "Choose" ? Color.neutral : palette.foregroundColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Icon(name: "f078", size: 12, weight: .solid)
                        .foregroundStyle(Color.neutral)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.neutral6)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func availableMembers(for plan: SeriesRoundMatchupPlan, currentMemberID: String?) -> [SeriesMember] {
        let usedMemberIDs = Set(
            matchupPlans
                .filter { $0.id != plan.id }
                .flatMap { [$0.memberAID, $0.memberBID] }
                .compactMap { $0 }
                .filter(\.isPopulated)
        )
        return viewModel.eligibleMembers.filter { member in
            member.id == currentMemberID || !usedMemberIDs.contains(member.id)
        }
    }

    private func teamName(for teamID: String) -> String? {
        viewModel.sortedTeams.first(where: { $0.id == teamID })?.name
    }

    private func memberName(for memberID: String?) -> String? {
        guard let memberID else { return nil }
        return viewModel.eligibleMembers.first(where: { $0.id == memberID })?.name.fullName
    }

    private func updateMatchup(
        planID: String,
        teamAID: String? = nil,
        teamBID: String? = nil,
        memberAID: String? = nil,
        memberBID: String? = nil
    ) {
        guard let index = matchupPlans.firstIndex(where: { $0.id == planID }) else { return }
        if let teamAID { matchupPlans[index].teamAID = teamAID }
        if let teamBID { matchupPlans[index].teamBID = teamBID }
        if let memberAID { matchupPlans[index].memberAID = memberAID }
        if let memberBID { matchupPlans[index].memberBID = memberBID }
        matchupPlans[index].lastUpdatedAt = .init()
    }

    private func labeledMenu<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            content()
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
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

    private func formChip(_ title: String, selected: Bool) -> some View {
        Chip(
            text: title,
            size: .small,
            foreground: selected ? .white : palette.foregroundColor,
            background: selected ? Color.accentGreen : palette.cardEmbeddedRowBackground
        )
    }

    private func menuChipLabel(_ title: String) -> some View {
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
        .glassCardEffect(cornerRadius: 16, tint: palette.whiteGlassButtonColor)
    }

    private var templateName: String {
        FormatTemplateRegistry.template(for: selectedTemplateID).name
    }

    private var availableTemplates: [GameTemplate] {
        FormatTemplateRegistry.seriesTemplates
    }

    private var seriesPointsDescription: String {
        if viewModel.usesTeams {
            return "Team awards feed the team standings. Individual awards feed player standings. Placement uses finishing order, while win/tie/loss uses matchup results."
        }
        if competitionScope == .matchup {
            return "Individual awards feed player standings. Placement uses finishing order, while win/tie/loss uses the scheduled head-to-head results."
        }
        return "Individual awards feed player standings. Placement uses finishing order, while manual leaves the round ready for commissioner review."
    }

    private var teamScoringModeLabel: String {
        switch teamScoring.mode {
        case .all:
            return "All"
        case .bestN:
            return "Best \(teamScoring.count)"
        case .worstN:
            return "Worst \(teamScoring.count)"
        }
    }

    private var teamScoringKindLabel: String {
        switch teamScoring.mode {
        case .all: return "All"
        case .bestN: return "Best"
        case .worstN: return "Worst"
        }
    }

    private var basicsSectionStatus: SeriesRoundSheetSectionStatus {
        let titleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if titleEmpty { return .review }
        if !hasDate { return .optional }
        return .confirmed
    }

    private var courseSectionStatus: SeriesRoundSheetSectionStatus {
        if selectedCourse == nil { return .review }
        if let def = viewModel.series.settings.defaultCourse,
           selectedCourse?.courseID == def.courseID {
            return .leagueDefault
        }
        return .confirmed
    }

    private var formatSectionStatus: SeriesRoundSheetSectionStatus {
        let d = leagueDefaults
        if selectedTemplateID != d.formatTemplateID { return .confirmed }
        if competitionScope != d.resolvedCompetitionScope { return .confirmed }
        if teamScoring != d.teamScoring { return .confirmed }
        if sequentialTeeStartsEnabled != (d.sequentialTeeStartsEnabled ?? false) { return .confirmed }
        if podGroupingStrategy != d.podGroupingStrategy { return .confirmed }
        return .leagueDefault
    }

    private func sectionHeaderRow(_ title: String, status: SeriesRoundSheetSectionStatus) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            sectionStatusChip(status)
        }
    }

    @ViewBuilder
    private func sectionStatusChip(_ status: SeriesRoundSheetSectionStatus) -> some View {
        switch status {
        case .required:
            Chip(text: "Required", size: .xSmall, tint: Color.accentYellow)
        case .review:
            Chip(text: "Review", size: .xSmall, tint: Color.accentYellow)
        case .optional:
            Chip(text: "Optional", size: .xSmall, foreground: Color.neutral, background: palette.cardEmbeddedRowBackground)
        case .confirmed:
            Chip(text: "Ready", size: .xSmall, foreground: .white, background: Color.accentGreen)
        case .leagueDefault:
            Chip(text: "League default", size: .xSmall, foreground: Color.neutral, background: palette.cardEmbeddedRowBackground)
        }
    }

    private func normalizeSelectedProfilesForCompetition() {
        if let currentTeamProfileID = selectedTeamProfileID,
           let profile = viewModel.scoringProfiles.first(where: { $0.id == currentTeamProfileID }),
           (!viewModel.usesTeams || competitionScope != .matchup),
           profile.kind == .winTieLoss {
            self.selectedTeamProfileID = viewModel.scoringProfiles.first {
                !$0.isArchived && $0.competitorType == .team && $0.kind == .placement
            }?.id
        }

        if let currentIndividualProfileID = selectedIndividualProfileID,
           let profile = viewModel.scoringProfiles.first(where: { $0.id == currentIndividualProfileID }),
           (competitionScope != .matchup || viewModel.usesTeams),
           profile.kind == .winTieLoss {
            self.selectedIndividualProfileID = viewModel.scoringProfiles.first {
                !$0.isArchived && $0.competitorType == .member && $0.kind == .placement
            }?.id
        }
    }

    private func normalizeSelectedTemplate() {
        guard !availableTemplates.contains(where: { $0.id == selectedTemplateID }) else { return }
        selectedTemplateID = availableTemplates.first?.id ?? FormatTemplateRegistry.strokePlay.id
    }
}

private enum SeriesRoundSheetSectionStatus {
    case required
    case review
    case optional
    case confirmed
    case leagueDefault
}

struct SeriesRoundCoursePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var roundSession: RoundSession

    let initialSelection: SeriesCourseSelection?
    var onSelected: (SeriesCourseSelection) -> Void

    @StateObject private var courseViewModel: CourseSelectionViewModel = {
        let vm = CourseSelectionViewModel()
        vm.isSetSeriesRoundCourseMode = true
        return vm
    }()

    var body: some View {
        CourseSelectionView(
            viewModel: courseViewModel,
            presentationType: .sheet,
            onCreation: nil,
            onModification: nil
        )
        .environmentObject(appSession)
        .environmentObject(locationService)
        .environmentObject(roundSession)
        .task {
            courseViewModel.onSetSeriesRoundCourse = { segment in
                let selection = SeriesCourseSelection(
                    courseID: segment.courseInfo.golfCourseApiID.map(String.init) ?? segment.courseInfo.id,
                    cachedName: segment.courseInfo.name,
                    defaultTeeBoxID: segment.defaultTee ?? "",
                    holeSegment: segment.holeSegment
                )
                onSelected(selection)
                dismiss()
            }
        }
        .task {
            await prefillSelection()
        }
    }

    private func prefillSelection() async {
        guard let initialSelection, initialSelection.courseID.isPopulated else { return }

        let course: Course?
        if let apiID = Int(initialSelection.courseID) {
            do {
                let apiCourse = try await GolfCourseAPI.shared.getCourse(by: apiID)
                course = Course(from: apiCourse, with: String(apiID), useStableTeeIDs: true)
            } catch {
                course = nil
            }
        } else {
            switch await FirebaseService.shared.getCourseByID(initialSelection.courseID) {
            case .success(let loadedCourse):
                course = loadedCourse
            case .failure:
                course = nil
            }
        }

        guard let course else { return }
        await MainActor.run {
            courseViewModel.select(course: course, source: .seriesRoundDefault, trackEvent: false)
            courseViewModel.holeSegment = initialSelection.holeSegment
            if initialSelection.defaultTeeBoxID.isPopulated,
               let tee = course.tees.first(where: { $0.id == initialSelection.defaultTeeBoxID }) {
                courseViewModel.selectedTee = tee
            }
        }
    }
}
