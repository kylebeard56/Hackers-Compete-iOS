//
//  NewSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct NewSeriesRoundSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    var onCreated: () -> Void

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
    @State private var profileEditorSeed: SeriesScoringProfileEditorSeed?
    @State private var showCoursePicker = false
    @State private var isCreating = false

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
                    title: "Schedule Round",
                    subtitle: "Set the date, format, points, and weekly round notes.",
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
                        createRound()
                    } label: {
                        Text(isCreating ? "Creating..." : "Create round")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(isCreating ? palette.foregroundColor : palette.backgroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isCreating ? Color.neutral3 : palette.foregroundColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreating)
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
            selectedTeamProfileID = viewModel.series.settings.defaultTeamScoringProfileID
            selectedIndividualProfileID = viewModel.series.settings.defaultIndividualScoringProfileID
            let defaults = viewModel.series.settings.defaultRoundConfig
            selectedTemplateID = defaults.formatTemplateID
            normalizeSelectedTemplate()
            competitionScope = defaults.resolvedCompetitionScope
            scoreOwnerScope = defaults.scoreOwnerScope
            matchupScoringStyle = defaults.matchupScoringStyle
            holeWinPoints = defaults.resolvedHoleWinPoints
            matchWinnerBonusPoints = defaults.resolvedMatchWinnerBonusPoints
            teamScoring = defaults.teamScoring
            sequentialTeeStartsEnabled = defaults.sequentialTeeStartsEnabled ?? false
            podGroupingStrategy = defaults.podGroupingStrategy
            countsTowardHandicapPool = defaults.countsTowardHandicapPool
            excludedHandicapMemberIDs = defaults.normalizedExcludedHandicapMemberIDs
            selectedCourse = viewModel.suggestedCourseSelectionForNextRound()
            matchupPlans = competitionScope == .matchup
                ? (viewModel.usesTeams
                    ? viewModel.suggestedMatchupPlans(pairGroupingStrategy: podGroupingStrategy)
                    : viewModel.suggestedIndividualMatchupPlans())
                : []
            normalizeSelectedProfilesForCompetition()
        }
        .onChange(of: competitionScope) { _, newValue in
            if newValue == .matchup, matchupPlans.isEmpty {
                matchupPlans = viewModel.usesTeams
                    ? viewModel.suggestedMatchupPlans(pairGroupingStrategy: podGroupingStrategy)
                    : viewModel.suggestedIndividualMatchupPlans()
            }
            if newValue != .matchup {
                matchupPlans = []
            }
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
        }
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
                    Text("Leave this flexible if you just want a placeholder round for now.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
    }

    private var basicsSectionStatus: SeriesRoundSheetSectionStatus {
        let titleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if titleEmpty { return .review }
        if !hasDate { return .optional }
        return .confirmed
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

                    if let leagueDefault = viewModel.series.settings.defaultCourse {
                        Button {
                            selectedCourse = viewModel.suggestedCourseSelectionForNextRound() ?? leagueDefault
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
                ? "Keep weekly pairings explicit here. Pairs are only a shortcut for tee-group suggestions, not a requirement for team scoring."
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
            seriesRound: nil,
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
                    title: nil,
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
                title: nil,
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

    private func createRound() {
        guard !isCreating else { return }
        isCreating = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
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
        Task {
            _ = await viewModel.addRound(
                title: trimmedTitle.isEmpty ? "Round \(viewModel.rounds.count + 1)" : trimmedTitle,
                scheduledAt: hasDate ? Time(for: scheduledDate) : nil,
                courseOverride: selectedCourse,
                roundConfig: roundConfig,
                teamScoringProfileID: selectedTeamProfileID,
                individualScoringProfileID: selectedIndividualProfileID,
                matchupPlans: resolvedMatchups,
                notes: notes.isEmpty ? nil : notes
            )
            isCreating = false
            onCreated()
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
            if let leagueDefault = viewModel.suggestedCourseSelectionForNextRound() {
                return "League default available: \(leagueDefault.holeSegment.title)"
            }
            return "Pick a course now or leave it blank until the round is ready."
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
            preserving: matchupPlans
        )
    }

    private var pairGroupingSwapTitle: String {
        viewModel.pairGroupingTitle(for: .swapPairs, matchupPlans: pairGroupingDisplayPlans)
    }

    private var pairGroupingSubtitle: String {
        viewModel.pairGroupingSubtitle(for: podGroupingStrategy, matchupPlans: pairGroupingDisplayPlans)
    }

    private func normalizedMatchupPlans() -> [SeriesRoundMatchupPlan] {
        guard competitionScope == .matchup else { return [] }

        let source = matchupPlans.isEmpty
            ? (viewModel.usesTeams
                ? viewModel.suggestedMatchupPlans(pairGroupingStrategy: podGroupingStrategy)
                : viewModel.suggestedIndividualMatchupPlans())
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
}

private enum SeriesRoundSheetSectionStatus {
    case required
    case review
    case optional
    case confirmed
    case leagueDefault
}

struct SeriesRoundHandicapParticipationCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound?
    let selectedTemplateID: String
    @Binding var countsTowardHandicapPool: Bool
    @Binding var excludedHandicapMemberIDs: [String]

    @State private var showCustomizationSheet = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var members: [SeriesMember] { viewModel.handicapParticipationMembers(for: seriesRound) }
    private var template: GameTemplate { FormatTemplateRegistry.template(for: selectedTemplateID) }
    private var formatSupportsAccrual: Bool { template.supportsLeagueHandicapAccrual }
    private var visibleExcludedMemberIDs: [String] {
        let memberIDs = Set(members.map(\.id))
        return Array(
            Set(excludedHandicapMemberIDs.filter { memberIDs.contains($0) })
        ).sorted()
    }
    private var includedCount: Int {
        max(0, members.count - visibleExcludedMemberIDs.count)
    }

    var body: some View {
        SeriesSheetCard(palette: palette) {
            Text("LEAGUE HANDICAP")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Toggle(
                isOn: Binding(
                    get: { formatSupportsAccrual && countsTowardHandicapPool },
                    set: { countsTowardHandicapPool = $0 }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Counts toward league handicaps")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text(toggleSubtitle)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.accentGreen)
            .disabled(!formatSupportsAccrual)

            if !viewModel.series.handicapConfig.isEnabled {
                Text("League handicaps are off at the series level. This round setting will apply if handicaps are enabled later.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if formatSupportsAccrual, countsTowardHandicapPool {
                SeriesSheetRow(palette: palette) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Participation")
                                    .fontStyle(kFontName, size: 13, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                                Text(participationSummary)
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }

                            Spacer(minLength: 0)

                            Button {
                                showCustomizationSheet = true
                            } label: {
                                Chip(
                                    text: "Customize",
                                    size: .small,
                                    foreground: .white,
                                    background: Color.accentGreen
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!members.isPopulated)
                        }

                        if !members.isPopulated {
                            Text("Add league members before customizing handicap participation.")
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else if formatSupportsAccrual {
                Text("This round will not feed the league handicap pool.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("This format doesn't allow handicap accrual because players are not keeping their own eligible stroke-based scores.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: enforceFormatEligibility)
        .onChange(of: selectedTemplateID) { _, _ in
            enforceFormatEligibility()
        }
        .sheet(isPresented: $showCustomizationSheet) {
            SeriesRoundHandicapCustomizationSheet(
                viewModel: viewModel,
                seriesRound: seriesRound,
                excludedMemberIDs: $excludedHandicapMemberIDs
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var toggleSubtitle: String {
        if formatSupportsAccrual {
            return "By default every included player in this round contributes a score to the league handicap pool."
        }
        return "Unavailable for this format."
    }

    private var participationSummary: String {
        if visibleExcludedMemberIDs.isEmpty {
            return members.isEmpty
                ? "No players available yet."
                : "All \(members.count) players currently count."
        }
        return "\(includedCount) of \(members.count) players count. \(visibleExcludedMemberIDs.count) excluded."
    }

    private func enforceFormatEligibility() {
        if !formatSupportsAccrual {
            countsTowardHandicapPool = false
        }
    }
}

private struct SeriesRoundHandicapCustomizationSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound?
    @Binding var excludedMemberIDs: [String]

    @State private var draftExcludedMemberIDs: [String] = []

    private struct MemberGroup: Identifiable {
        let id: String
        let title: String
        let members: [SeriesMember]
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var members: [SeriesMember] { viewModel.handicapParticipationMembers(for: seriesRound) }
    private var excludedMemberIDSet: Set<String> { Set(draftExcludedMemberIDs) }
    private var includedCount: Int { max(0, members.count - excludedMemberIDSet.count) }

    private var groups: [MemberGroup] {
        guard viewModel.usesTeams else {
            return members.isEmpty ? [] : [MemberGroup(id: "players", title: "Players", members: members)]
        }

        let membersByTeamID = Dictionary(grouping: members, by: \.teamID)
        var built: [MemberGroup] = []

        for team in viewModel.sortedTeams {
            let groupedMembers = (membersByTeamID[team.id] ?? [])
                .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
            guard groupedMembers.isPopulated else { continue }
            built.append(MemberGroup(id: team.id, title: team.name, members: groupedMembers))
        }

        let unassignedMembers = (membersByTeamID[nil] ?? [])
            .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
        if unassignedMembers.isPopulated {
            built.append(MemberGroup(id: "unassigned", title: "Unassigned", members: unassignedMembers))
        }

        return built.isEmpty && members.isPopulated
            ? [MemberGroup(id: "players", title: "Players", members: members)]
            : built
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Handicap Participation",
                    subtitle: "\(includedCount) of \(members.count) players currently count.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    summaryCard
                    if groups.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(groups) { group in
                            groupCard(group)
                        }
                    }
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
                        isDisabled: .constant(false),
                        isLoading: .constant(false),
                        onTap: {
                            excludedMemberIDs = Array(Set(draftExcludedMemberIDs.filter(\.isPopulated))).sorted()
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
        .onAppear {
            let memberIDs = Set(members.map(\.id))
            draftExcludedMemberIDs = Array(
                Set(excludedMemberIDs.filter { memberIDs.contains($0) })
            ).sorted()
        }
    }

    private var summaryCard: some View {
        SeriesSheetCard(palette: palette) {
            Text("Choose which players in this round should feed the league handicap pool. Team actions below are just shortcuts that toggle those members for you.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    draftExcludedMemberIDs = []
                } label: {
                    Chip(
                        text: "Include all",
                        size: .small,
                        foreground: .white,
                        background: Color.accentGreen
                    )
                }
                .buttonStyle(.plain)

                Button {
                    draftExcludedMemberIDs = members.map(\.id)
                } label: {
                    Chip(
                        text: "Exclude all",
                        size: .small,
                        foreground: palette.foregroundColor,
                        background: palette.cardEmbeddedRowBackground
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
    }

    private var emptyStateCard: some View {
        SeriesSheetCard(palette: palette) {
            Text("No players are available for this round yet.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private func groupCard(_ group: MemberGroup) -> some View {
        SeriesSheetCard(palette: palette) {
            HStack(spacing: 10) {
                Text(group.title.uppercased())
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Button {
                    toggleGroup(group)
                } label: {
                    Chip(
                        text: groupFullyExcluded(group) ? "Include team" : "Exclude team",
                        size: .xSmall,
                        foreground: groupFullyExcluded(group) ? .white : palette.foregroundColor,
                        background: groupFullyExcluded(group) ? Color.accentGreen : palette.cardEmbeddedRowBackground
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(group.members, id: \.id) { member in
                SeriesSheetRow(palette: palette) {
                    Button {
                        toggleMember(member.id)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.name.fullName)
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)

                                if let teamID = member.teamID,
                                   let teamName = viewModel.sortedTeams.first(where: { $0.id == teamID })?.name {
                                    Text(teamName)
                                        .fontStyle(kFontName, size: 12, weight: .regular)
                                        .foregroundStyle(Color.neutral)
                                }
                            }

                            Spacer(minLength: 0)

                            Image(systemName: excludedMemberIDSet.contains(member.id) ? "circle" : "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    excludedMemberIDSet.contains(member.id)
                                        ? Color.neutral3
                                        : Color.accentGreen
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func groupFullyExcluded(_ group: MemberGroup) -> Bool {
        group.members.allSatisfy { excludedMemberIDSet.contains($0.id) }
    }

    private func toggleGroup(_ group: MemberGroup) {
        if groupFullyExcluded(group) {
            draftExcludedMemberIDs.removeAll { memberID in
                group.members.contains(where: { $0.id == memberID })
            }
            return
        }

        let memberIDs = Set(group.members.map(\.id))
        draftExcludedMemberIDs = Array(excludedMemberIDSet.union(memberIDs)).sorted()
    }

    private func toggleMember(_ memberID: String) {
        if excludedMemberIDSet.contains(memberID) {
            draftExcludedMemberIDs.removeAll { $0 == memberID }
        } else {
            draftExcludedMemberIDs = Array(excludedMemberIDSet.union([memberID])).sorted()
        }
    }
}
