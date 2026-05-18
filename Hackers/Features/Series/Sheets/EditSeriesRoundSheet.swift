//
//  EditSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct EditSeriesRoundSheet: View {
    private enum MatchupSource: Hashable {
        case byTeam
        case byPair
        case byIndividual

        var title: String {
            switch self {
            case .byTeam:
                return "By team"
            case .byPair:
                return "By pair"
            case .byIndividual:
                return "By individual"
            }
        }

        init(mode: SeriesMatchupMode, usesTeams: Bool) {
            guard usesTeams else {
                self = .byIndividual
                return
            }
            switch mode {
            case .teeGroupPartnerships:
                self = .byPair
            case .individualVsIndividual:
                self = .byIndividual
            case .teamVsTeam, .field, .none:
                self = .byTeam
            }
        }
    }

    private enum MatchupAutoFillAction: String, Identifiable, Hashable {
        case random
        case byHandicap
        case mirrorTeeSheet
        case currentTeamOrder

        var id: String { rawValue }

        var title: String {
            switch self {
            case .random:
                return "Random"
            case .byHandicap:
                return "By handicap"
            case .mirrorTeeSheet:
                return "Mirror tee sheet"
            case .currentTeamOrder:
                return "Current team order"
            }
        }
    }

    private struct MatchupSourceMenuOption: Identifiable {
        let source: MatchupSource
        let subtitle: String?
        let isDisabled: Bool
        let isSelected: Bool

        var id: MatchupSource { source }
    }

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
    @State private var sharedScoreAllowanceText = ""
    @State private var teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
    @State private var selectionDomain: ScoringSelectionDomain?
    @State private var sequentialTeeStartsEnabled = false
    @State private var podGroupingStrategy: SeriesPodGroupingStrategy = .disabled
    @State private var matchupSource: MatchupSource = .byTeam
    @State private var selectedTeamProfileID: String?
    @State private var selectedIndividualProfileID: String?
    @State private var handicapEntryFormat: HandicapEntryFormat = .strokes
    @State private var handicapNormalizationMode: HandicapNormalizationMode = .off
    @State private var handicapStrokeBasis: SeriesHandicapStrokeBasis?
    @State private var courseHandicapAvailable = false
    @State private var countsTowardHandicapPool = true
    @State private var excludedHandicapMemberIDs: [String] = []
    @State private var notes = ""
    @State private var selectedCourse: SeriesCourseSelection?
    @State private var matchupPlans: [SeriesRoundMatchupPlan] = []
    @State private var plannedMatchups: [SeriesRoundPlannedMatchup] = []
    @State private var plannedTeeGroups: [SeriesRoundPlannedTeeGroup] = []
    @State private var partnershipPlans: [SeriesRoundPartnershipPlan] = []
    @State private var profileEditorSeed: SeriesScoringProfileEditorSeed?
    @State private var showCoursePicker = false
    @State private var showMatchupAutoFillDialog = false
    @State private var isSaving = false

    private enum RoundEditorField: Hashable {
        case title
        case notes
    }

    @FocusState private var focusedField: RoundEditorField?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var leagueDefaults: SeriesRoundConfiguration { viewModel.series.settings.defaultRoundConfig }
    private var teamMatchupUsesWLT: Bool {
        viewModel.usesTeams && competitionScope == .matchup && matchupSource != .byIndividual
    }
    private var individualMatchupUsesWLT: Bool {
        competitionScope == .matchup && (!viewModel.usesTeams || matchupSource == .byIndividual)
    }
    private var selectedMatchupSourceTitle: String { matchupSource.title }
    private var matchupSourceMenuOptions: [MatchupSourceMenuOption] {
        [
            MatchupSourceMenuOption(
                source: .byTeam,
                subtitle: nil,
                isDisabled: false,
                isSelected: matchupSource == .byTeam
            ),
            MatchupSourceMenuOption(
                source: .byPair,
                subtitle: "Set pairs in tee sheet below",
                isDisabled: !canSelectPairMatchupSource,
                isSelected: matchupSource == .byPair
            ),
            MatchupSourceMenuOption(
                source: .byIndividual,
                subtitle: nil,
                isDisabled: false,
                isSelected: matchupSource == .byIndividual
            ),
        ]
    }
    private var matchupAutoFillActions: [MatchupAutoFillAction] {
        switch matchupSource {
        case .byTeam:
            return [.random, .currentTeamOrder]
        case .byPair:
            return [.random, .mirrorTeeSheet]
        case .byIndividual:
            return [.random, .byHandicap, .mirrorTeeSheet]
        }
    }

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
                    handicapSettingsSection
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
            matchupSource = MatchupSource(mode: seriesRound.roundConfig.matchupMode, usesTeams: viewModel.usesTeams)
            matchupScoringStyle = seriesRound.roundConfig.matchupScoringStyle
            holeWinPoints = seriesRound.roundConfig.resolvedHoleWinPoints
            matchWinnerBonusPoints = seriesRound.roundConfig.resolvedMatchWinnerBonusPoints
            sharedScoreAllowanceText = allowanceText(
                from: seriesRound.roundConfig.sharedScoreHandicapConfig ?? FormatTemplateRegistry.template(for: selectedTemplateID).requirements.defaultHandicapConfig
            )
            teamScoring = seriesRound.roundConfig.teamScoring
            selectionDomain = seriesRound.roundConfig.selectionDomain
            sequentialTeeStartsEnabled = seriesRound.roundConfig.sequentialTeeStartsEnabled ?? false
            podGroupingStrategy = seriesRound.roundConfig.podGroupingStrategy
            handicapEntryFormat = seriesRound.roundConfig.handicapEntryFormat
            handicapStrokeBasis = seriesRound.roundConfig.handicapStrokeBasis
            handicapNormalizationMode = normalizedHandicapNormalizationMode(
                seriesRound.roundConfig.handicapNormalizationMode,
                for: competitionScope
            )
            countsTowardHandicapPool = seriesRound.roundConfig.countsTowardHandicapPool
            excludedHandicapMemberIDs = seriesRound.roundConfig.normalizedExcludedHandicapMemberIDs
            selectedTeamProfileID = seriesRound.teamScoringProfileID
            selectedIndividualProfileID = seriesRound.individualScoringProfileID
            notes = seriesRound.notes ?? seriesRound.roundConfig.notes ?? ""
            selectedCourse = seriesRound.courseOverride ?? viewModel.suggestedCourseSelection(forRoundIndex: seriesRound.index)
            await refreshCourseHandicapAvailability()
            matchupPlans = competitionScope == .matchup
                ? seriesRound.matchupPlans.sorted { $0.index < $1.index }
                : []
            plannedMatchups = seriesRound.plannedMatchups
            plannedTeeGroups = seriesRound.plannedTeeGroups
            partnershipPlans = seriesRound.partnershipPlans
            refreshPlanningStructure(forceRegenerate: !seriesRound.plannedTeeGroups.isPopulated)
            normalizeSelectedProfilesForCompetition()
        }
        .onChange(of: competitionScope) { _, newValue in
            if newValue == .matchup, matchupPlans.isEmpty {
                matchupPlans = seriesRound.matchupPlans.sorted { $0.index < $1.index }
            }
            if newValue != .matchup {
                matchupPlans = []
            }
            handicapNormalizationMode = normalizedHandicapNormalizationMode(handicapNormalizationMode, for: newValue)
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
        .onChange(of: selectedCourse) { _, _ in
            refreshPlanningStructure()
            Task { await refreshCourseHandicapAvailability() }
        }
        .onChange(of: scheduledDate) { _, _ in if hasDate { refreshPlanningStructure() } }
        .onChange(of: hasDate) { _, _ in refreshPlanningStructure(forceRegenerate: false) }
        .onChange(of: sequentialTeeStartsEnabled) { _, _ in refreshPlanningStructure() }
        .onChange(of: plannedTeeGroups) { _, _ in
            partnershipPlans = normalizedPartnershipPlans()
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
        .confirmationDialog(
            "Auto-fill matchups",
            isPresented: $showMatchupAutoFillDialog,
            titleVisibility: .visible
        ) {
            ForEach(matchupAutoFillActions) { action in
                Button(action.title) {
                    applyMatchupAutoFill(action)
                }
            }
            Button("Cancel", role: .cancel) {}
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
                    Text(selectedCourseName)
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
                                text: "Use series default",
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
                            sharedScoreAllowanceText = allowanceText(from: template.requirements.defaultHandicapConfig)
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

            if viewModel.usesTeams && selectedTemplate.scoreSource == .shared {
                builderField(
                    title: "Score entry",
                    subtitle: scoreEntryScopeSubtitle
                ) {
                    HStack(spacing: 8) {
                        Button {
                            scoreOwnerScope = .individual
                        } label: {
                            formChip(scoreOwnerScopeTitle(for: .individual), selected: scoreOwnerScope == .individual)
                        }
                        .buttonStyle(.plain)

                        Button {
                            scoreOwnerScope = .partnership
                        } label: {
                            formChip(scoreOwnerScopeTitle(for: .partnership), selected: scoreOwnerScope == .partnership)
                        }
                        .buttonStyle(.plain)

                        Button {
                            scoreOwnerScope = .teeGroup
                        } label: {
                            formChip(scoreOwnerScopeTitle(for: .teeGroup), selected: scoreOwnerScope == .teeGroup)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedTemplate.scoreSource == .shared {
                builderField(
                    title: "Handicap allowance",
                    subtitle: "Comma-separated percentages applied from lowest to highest course handicap."
                ) {
                    TextField("35,15", text: $sharedScoreAllowanceText)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .borderedContentStyle(theme: palette.theme, fill: palette.cardEmbeddedRowBackground)
                }
            }

            if viewModel.usesTeams {
                builderField(
                    title: "Count scores",
                    subtitle: "Choose which scores count and how they're computed for leaderboard."
                ) {
                    VStack(alignment: .trailing, spacing: 8) {
                        if teamScoring.mode == .bestN || teamScoring.mode == .worstN {
                            HStack(spacing: 8) {
                                Menu {
                                    countScoresMenuButtons
                                } label: {
                                    menuChipLabel(teamScoringModeLabel)
                                }
                                .buttonStyle(.plain)

                                Text("per")
                                    .fontStyle(kFontName, size: 15, weight: .regular)
                                    .foregroundStyle(Color.secondary)

                                Menu {
                                    ForEach(AggregationScope.allCases, id: \.self) { scope in
                                        Button {
                                            teamScoring.scope = scope
                                        } label: {
                                            HStack {
                                                Text(scope == .perRound ? "Round" : "Hole")
                                                if teamScoring.scope == scope { Image(systemName: "checkmark") }
                                            }
                                        }
                                    }
                                } label: {
                                    menuChipLabel(teamScoringScopeLabel)
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 8) {
                                Text("from")
                                    .fontStyle(kFontName, size: 15, weight: .regular)
                                    .foregroundStyle(Color.secondary)

                                Menu {
                                    Button {
                                        selectionDomain = nil
                                    } label: {
                                        HStack {
                                            Text("Auto")
                                            if selectionDomain == nil { Image(systemName: "checkmark") }
                                        }
                                    }
                                    ForEach(ScoringSelectionDomain.allCases, id: \.self) { domain in
                                        Button {
                                            selectionDomain = domain
                                        } label: {
                                            HStack {
                                                Text(selectionDomainTitle(for: domain))
                                                if selectionDomain == domain { Image(systemName: "checkmark") }
                                            }
                                        }
                                    }
                                } label: {
                                    menuChipLabel(selectionDomainLabel)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Menu {
                                countScoresMenuButtons
                            } label: {
                                menuChipLabel(teamScoringModeLabel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
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

    private var handicapSettingsSection: some View {
        SeriesSheetCard(palette: palette) {
            sectionHeaderRow("Handicap", status: handicapSettingsSectionStatus)

            SeriesSheetRow(palette: palette) {
                handicapOptionsRow
            }
        }
    }

    private var handicapOptionsRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Playing handicap options")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text(handicapOptionsSummary)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            handicapOptionsMenu
        }
    }

    private var handicapOptionsMenu: some View {
        HandicapOptionsMenu(
            handicapEntryFormat: $handicapEntryFormat,
            handicapNormalizationMode: $handicapNormalizationMode,
            handicapStrokeBasis: $handicapStrokeBasis,
            courseHandicapAvailable: courseHandicapAvailable,
            competitionScope: competitionScope,
            resolvedAutoBasis: nil,
            palette: palette,
            courseHandicapSubtitle: courseHandicapAvailable
                ? "Use member index and this round's selected tee to seed playing strokes"
                : "Select a course and tee with rating/slope to use course handicap"
        )
    }

    private var handicapOptionsSummary: String {
        let course = handicapEntryFormat == .courseHandicap ? "Course HCP on" : "Course HCP off"
        let normalized = handicapNormalizationMode == .off ? "Normalize off" : "Normalize on"
        return "\(course) - \(normalized) - \(handicapStrokeBasisDisplay)"
    }

    private var handicapStrokeBasisDisplay: String {
        handicapStrokeBasis?.displayName ?? "Auto"
    }

    private var handicapStrokeBasisDescription: String {
        handicapStrokeBasis == nil ? "Auto - infer 9-hole or 18-hole from the round" : "\(handicapStrokeBasisDisplay) values"
    }

    private var handicapSettingsSectionStatus: SeriesRoundSheetSectionStatus {
        if handicapEntryFormat == .courseHandicap, !courseHandicapAvailable { return .review }
        if handicapEntryFormat == .strokes, handicapNormalizationMode == .off { return .optional }
        return .confirmed
    }

    private var matchupSection: some View {
        SeriesSheetCard(palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Matchups")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text(matchupSectionSubtitle)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

                HStack(spacing: 10) {
                    if viewModel.usesTeams {
                        Menu {
                            ForEach(matchupSourceMenuOptions) { option in
                                Button {
                                    selectMatchupSource(option.source)
                                } label: {
                                    matchupSourceMenuItem(option)
                                }
                                .disabled(option.isDisabled)
                            }
                        } label: {
                            menuChipLabel(selectedMatchupSourceTitle)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showMatchupAutoFillDialog = true
                    } label: {
                        sparkleActionChipLabel("Auto-fill")
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }

            if matchupPlans.isEmpty {
                SeriesSheetRow(palette: palette) {
                    Text(matchupEmptyStateText)
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

            fullWidthCardActionButton("Add matchup") {
                appendEmptyMatchupRow()
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
                    subtitle: "Choose whether teams score directly or by summing each player's points for this round.",
                    competitorType: .team,
                    competitionScope: competitionScope,
                    supportsWinTieLoss: teamMatchupUsesWLT,
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
                supportsWinTieLoss: individualMatchupUsesWLT,
                selectedProfileID: $selectedIndividualProfileID
            ) { seed in
                profileEditorSeed = seed
            }

            reviewPointStructureCard
        }
    }

    private var reviewPointStructureCard: some View {
        SeriesSheetRow(palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.neutral2)
                    Text("Example scoring")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }

                Text(pointsConfidenceSummary.example)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pointsConfidenceSummary: SeriesRoundPointsConfidenceSummary {
        return SeriesRoundPointsConfidenceBuilder.summary(
            roundConfig: confidenceRoundConfig,
            teamProfile: selectedTeamScoringProfile,
            individualProfile: selectedIndividualScoringProfile,
            plannedTeeGroups: plannedTeeGroups,
            partnershipPlans: normalizedPartnershipPlans(),
            members: planningMembers,
            teams: viewModel.sortedTeams,
            courseSelection: planningCourseSelection
        )
    }

    private var selectedTeamScoringProfile: SeriesScoringProfile? {
        guard let selectedTeamProfileID else { return nil }
        return viewModel.scoringProfiles.first { $0.id == selectedTeamProfileID }
    }

    private var selectedIndividualScoringProfile: SeriesScoringProfile? {
        guard let selectedIndividualProfileID else { return nil }
        return viewModel.scoringProfiles.first { $0.id == selectedIndividualProfileID }
    }

    private var confidenceRoundConfig: SeriesRoundConfiguration {
        SeriesRoundConfiguration(
            formatTemplateID: selectedTemplateID,
            competitionScope: competitionScope,
            teamScoring: teamScoring,
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: effectiveScoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            selectionDomain: selectionDomain,
            matchupMode: resolvedMatchupMode(for: competitionScope),
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            sharedScoreHandicapConfig: sharedScoreAllowanceConfig,
            handicapStrokeBasis: handicapStrokeBasis,
            handicapEntryFormat: resolvedHandicapEntryFormat,
            handicapNormalizationMode: resolvedHandicapNormalizationMode(for: competitionScope),
            countsTowardHandicapPool: countsTowardHandicapPool,
            excludedHandicapMemberIDs: excludedHandicapMemberIDs
        )
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
        var roundConfig = SeriesRoundConfiguration(
            formatTemplateID: selectedTemplateID,
            competitionScope: resolvedCompetitionScope,
            teamScoring: teamScoring,
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: effectiveScoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            selectionDomain: selectionDomain,
            matchupMode: resolvedMatchupMode(for: resolvedCompetitionScope),
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            sharedScoreHandicapConfig: sharedScoreAllowanceConfig,
            handicapStrokeBasis: handicapStrokeBasis,
            handicapEntryFormat: resolvedHandicapEntryFormat,
            handicapNormalizationMode: resolvedHandicapNormalizationMode(for: competitionScope),
            countsTowardHandicapPool: countsTowardHandicapPool,
            excludedHandicapMemberIDs: excludedHandicapMemberIDs
        )
        roundConfig.allowCourseOverride = seriesRound.roundConfig.allowCourseOverride
        roundConfig.allowFormatOverride = seriesRound.roundConfig.allowFormatOverride
        roundConfig.allowLobbyBackPropagation = resolvedAllowLobbyBackPropagation()
        roundConfig.scoreBasisOverride = seriesRound.roundConfig.scoreBasisOverride
        let resolvedMatchups = normalizedMatchupPlans()
        let plannedStructure = persistedPlanningStructure()
        let resolvedPartnershipPlans = normalizedPartnershipPlans()

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
                partnershipPlans: resolvedPartnershipPlans,
                notes: notes.isEmpty ? nil : notes
            )
            isSaving = false
            onSaved()
            dismiss()
        }
    }

    private func resolvedAllowLobbyBackPropagation() -> Bool {
        guard let linked = viewModel.linkedRound(for: seriesRound) else {
            return seriesRound.roundConfig.allowLobbyBackPropagation
        }

        switch linked.status {
        case .lobby, .live, .paused:
            return false
        case .complete, .archived:
            return seriesRound.roundConfig.allowLobbyBackPropagation
        }
    }

    private func resolvedHandicapNormalizationMode(for competitionScope: CompetitionScope) -> HandicapNormalizationMode {
        normalizedHandicapNormalizationMode(handicapNormalizationMode, for: competitionScope)
    }

    private var resolvedHandicapEntryFormat: HandicapEntryFormat {
        courseHandicapAvailable ? handicapEntryFormat : .strokes
    }

    private func normalizedHandicapNormalizationMode(_ mode: HandicapNormalizationMode, for competitionScope: CompetitionScope) -> HandicapNormalizationMode {
        guard mode != .off else { return .off }
        return competitionScope == .matchup ? .matchup : .field
    }

    @MainActor
    private func refreshCourseHandicapAvailability() async {
        let available = await SeriesRoundCourseHandicapAvailability.isAvailable(for: planningCourseSelection)
        courseHandicapAvailable = available
        if !available, handicapEntryFormat == .courseHandicap {
            handicapEntryFormat = .strokes
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
    }

    private var courseDetailText: String {
        guard let selectedCourse else {
            return "This round can inherit the \(viewModel.series.experiencePreset.displayName.lowercased()) default later, or you can leave it blank for now."
        }
        if let seriesDefault = viewModel.series.settings.defaultCourse,
           selectedCourse.courseID == seriesDefault.courseID {
            switch viewModel.series.settings.defaultCourseRotationMode {
            case .fixed:
                return "\(selectedCourse.holeSegment.title) from \(viewModel.series.experiencePreset.displayName.lowercased()) default"
            case .alternateFrontBack:
                return "\(selectedCourse.holeSegment.title) from the alternating \(viewModel.series.experiencePreset.displayName.lowercased()) default"
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

    private var matchupSectionSubtitle: String {
        guard viewModel.usesTeams else {
            return "Set the player-vs-player pairings for this round. These pairings drive individual matchup scoring and WLT awards."
        }
        if matchupSource == .byPair {
            return "Choose pair-vs-pair matchups using the pairs defined in the tee sheet below."
        }
        if matchupSource == .byIndividual {
            return "Set player-vs-player pairings inside this team round. These matchups drive individual matchup scoring and player WLT awards."
        }
        return "Use team rows for classic head-to-head matchups, or switch to pair-vs-pair groups or individual player matchups."
    }

    private var extractablePairGroups: [SeriesRoundPlannedTeeGroup] {
        plannedTeeGroups.sorted { $0.index < $1.index }.filter {
            SeriesTeeGroupMirrorAnalyzer.status(
                for: $0,
                partnershipPlans: partnershipPlans,
                membersByID: planningMembersByID
            ) == .ready
        }
    }

    private var canSelectPairMatchupSource: Bool {
        matchupSource == .byPair || extractablePairGroups.isPopulated || normalizedPartnershipPlans().count >= 2
    }

    private var matchupEmptyStateText: String {
        if viewModel.usesTeams && matchupSource == .byPair {
            return "No matches yet. Use Auto-fill from the tee sheet or add one manually."
        }
        if viewModel.usesTeams && matchupSource == .byTeam {
            return "No matchups yet. Use Auto-fill or add one manually."
        }
        return "No pairings yet. Use Auto-fill or add one manually."
    }

    private struct PairMatchupOption: Identifiable, Hashable {
        var id: String
        var teamID: String
        var memberIDs: [String]
        var title: String
        var subtitle: String
        var sortKey: String
    }

    private var pairMatchupOptions: [PairMatchupOption] {
        let validPlans = normalizedPartnershipPlans().filter(\.isValid)
        let groupsByPairID = Dictionary(uniqueKeysWithValues: plannedTeeGroups.flatMap { group in
            SeriesTeeGroupMirrorAnalyzer.pairs(
                for: group,
                partnershipPlans: validPlans,
                membersByID: planningMembersByID
            ).map { ($0.id, group) }
        })

        return validPlans.compactMap { plan in
            let subtitle = pairNamesText(for: plan.memberIDs)
            guard subtitle.isPopulated else { return nil }
            if let group = groupsByPairID[plan.id] {
                let pairs = SeriesTeeGroupMirrorAnalyzer.pairs(
                    for: group,
                    partnershipPlans: validPlans,
                    membersByID: planningMembersByID
                )
                let pairIndex = pairs.firstIndex { $0.id == plan.id } ?? 0
                let letter = String(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")[safe: pairIndex] ?? Character("A"))
                return PairMatchupOption(
                    id: plan.id,
                    teamID: plan.teamID,
                    memberIDs: plan.memberIDs,
                    title: "Group \(group.index + 1) Pair \(letter)",
                    subtitle: subtitle,
                    sortKey: String(format: "0_%03d_%03d", group.index, pairIndex)
                )
            }

            let fallbackTitle = plan.label?.isPopulated == true ? plan.label! : "Pair"
            return PairMatchupOption(
                id: plan.id,
                teamID: plan.teamID,
                memberIDs: plan.memberIDs,
                title: fallbackTitle,
                subtitle: subtitle,
                sortKey: "1_\(fallbackTitle.lowercased())_\(subtitle.lowercased())"
            )
        }
        .sorted { $0.sortKey < $1.sortKey }
    }

    private func normalizedMatchupPlans() -> [SeriesRoundMatchupPlan] {
        guard competitionScope == .matchup else { return [] }

        let source = matchupPlans.isEmpty ? defaultMatchupPlans(preserving: seriesRound.matchupPlans) : matchupPlans

        return source.enumerated().compactMap { index, plan in
            var updated = plan
            if viewModel.usesTeams && matchupSource == .byPair {
                guard let pairAID = plan.pairAID,
                      let pairBID = plan.pairBID,
                      pairAID.isPopulated,
                      pairBID.isPopulated,
                      pairAID != pairBID else { return nil }
                updated.pairAID = pairAID
                updated.pairBID = pairBID
                updated.teamAID = ""
                updated.teamBID = ""
                updated.memberAID = nil
                updated.memberBID = nil
            } else if viewModel.usesTeams && matchupSource == .byTeam {
                guard plan.teamAID.isPopulated, plan.teamBID.isPopulated, plan.teamAID != plan.teamBID else { return nil }
                updated.pairAID = nil
                updated.pairBID = nil
                updated.memberAID = nil
                updated.memberBID = nil
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
                updated.pairAID = nil
                updated.pairBID = nil
            }
            updated.index = index
            updated.podGroupingStrategy = viewModel.usesTeams ? podGroupingStrategy : .disabled
            updated.lastUpdatedAt = .init()
            return updated
        }
    }

    private func defaultMatchupPlans(preserving existingPlans: [SeriesRoundMatchupPlan] = []) -> [SeriesRoundMatchupPlan] {
        if viewModel.usesTeams {
            switch matchupSource {
            case .byTeam:
                return viewModel.suggestedMatchupPlans(
                    pairGroupingStrategy: podGroupingStrategy,
                    preserving: existingPlans
                )
            case .byPair:
                return autofilledPairMatchupPlans()
            case .byIndividual:
                return viewModel.suggestedIndividualMatchupPlans(preserving: existingPlans)
            }
        }
        return viewModel.suggestedIndividualMatchupPlans(preserving: existingPlans)
    }

    private func normalizedPartnershipPlans() -> [SeriesRoundPartnershipPlan] {
        let teamEntries: [(String, String)] = planningMembers.compactMap { member in
            guard let teamID = member.teamID, teamID.isPopulated else { return nil }
            return (member.id, teamID)
        }
        let teamIDByMemberID = Dictionary(uniqueKeysWithValues: teamEntries)
        var usedMemberIDs: Set<String> = []

        return partnershipPlans.compactMap { plan -> SeriesRoundPartnershipPlan? in
            let memberIDs = Array(Set(plan.memberIDs.filter(\.isPopulated))).sorted()
            guard memberIDs.count == 2 else { return nil }
            let memberAID = memberIDs[0]
            let memberBID = memberIDs[1]
            guard !usedMemberIDs.contains(memberAID), !usedMemberIDs.contains(memberBID) else { return nil }
            guard let teamID = teamIDByMemberID[memberAID],
                  teamIDByMemberID[memberBID] == teamID else {
                return nil
            }
            usedMemberIDs.insert(memberAID)
            usedMemberIDs.insert(memberBID)

            var updated = plan
            updated.id = updated.id.isPopulated ? updated.id : HackersID.string()
            updated.teamID = teamID
            updated.memberIDs = memberIDs
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
            scoreOwnerScope: effectiveScoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            selectionDomain: selectionDomain,
            matchupMode: resolvedMatchupMode(for: competitionScope),
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            sharedScoreHandicapConfig: sharedScoreAllowanceConfig,
            handicapStrokeBasis: handicapStrokeBasis,
            handicapEntryFormat: resolvedHandicapEntryFormat,
            handicapNormalizationMode: resolvedHandicapNormalizationMode(for: competitionScope),
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
            partnershipPlans: normalizedPartnershipPlans(),
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
            partnershipPlans: normalizedPartnershipPlans(),
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
        } else {
            plannedTeeGroups = SeriesRoundCreationMapping.plannedTeeGroupsWithSchedule(
                plannedTeeGroups,
                holeRange: planningHoleRange,
                useShotgunStart: sequentialTeeStartsEnabled,
                scheduledTeeTime: planningDraftRound.scheduledAt.map { Date(timeIntervalSince1970: $0.unix) },
                preserveStartingHoles: true
            )
        }
    }

    private func resolvedMatchupMode(for scope: CompetitionScope) -> SeriesMatchupMode {
        guard scope == .matchup else { return .field }
        guard viewModel.usesTeams else { return .individualVsIndividual }
        switch matchupSource {
        case .byTeam:
            return .teamVsTeam
        case .byPair:
            return .teeGroupPartnerships
        case .byIndividual:
            return .individualVsIndividual
        }
    }

    private func selectTeamMatchupSource() {
        selectMatchupSource(.byTeam)
    }

    private func selectPairMatchupSource() {
        selectMatchupSource(.byPair)
    }

    private func selectIndividualMatchupSource() {
        selectMatchupSource(.byIndividual)
    }

    private func selectMatchupSource(_ source: MatchupSource) {
        guard source != .byPair || canSelectPairMatchupSource else { return }
        if source == .byPair {
            ensurePartnershipPlansFromReadyGroups()
        }
        switch source {
        case .byTeam:
            selectionDomain = .team
        case .byPair:
            selectionDomain = .partnership
        case .byIndividual:
            selectionDomain = .participant
        }
        matchupSource = source
        matchupPlans = clearedMatchupPlansForSourceSwitch()
        refreshPlanningStructure()
        normalizeSelectedProfilesForCompetition()
    }

    private func clearedMatchupPlansForSourceSwitch() -> [SeriesRoundMatchupPlan] {
        matchupPlans.enumerated().map { index, plan in
            var updated = plan
            updated.index = index
            updated.teamAID = ""
            updated.teamBID = ""
            updated.memberAID = nil
            updated.memberBID = nil
            updated.pairAID = nil
            updated.pairBID = nil
            updated.lastUpdatedAt = .init()
            return updated
        }
    }

    private func ensurePartnershipPlansFromReadyGroups() {
        partnershipPlans = mergedPartnershipPlansFromReadyGroups()
    }

    private func mergedPartnershipPlansFromReadyGroups() -> [SeriesRoundPartnershipPlan] {
        var plans = normalizedPartnershipPlans()
        let membersByID = planningMembersByID
        for group in plannedTeeGroups.sorted(by: { $0.index < $1.index }) {
            let groupMemberIDs = Set(group.memberIDs)
            let storedPairs = plans.filter { Set($0.memberIDs).isSubset(of: groupMemberIDs) }
            if storedPairs.count == 2, Set(storedPairs.map(\.teamID)).count == 2 { continue }
            let orderedSeats = group.seats.sorted { $0.teeOrder < $1.teeOrder }
            guard orderedSeats.count == 4 else { continue }
            let candidatePairs = [
                Array(orderedSeats[0...1]).map(\.memberID),
                Array(orderedSeats[2...3]).map(\.memberID)
            ]
            let resolvedPairs: [(teamID: String, memberIDs: [String])] = candidatePairs.compactMap { memberIDs in
                let teamIDs = Set(memberIDs.compactMap { membersByID[$0]?.teamID }.filter(\.isPopulated))
                guard teamIDs.count == 1, let teamID = teamIDs.first else { return nil }
                return (teamID, memberIDs)
            }
            guard resolvedPairs.count == 2, Set(resolvedPairs.map(\.teamID)).count == 2 else { continue }
            let replacedMemberIDs = Set(resolvedPairs.flatMap(\.memberIDs))
            plans.removeAll { !$0.memberIDs.filter(replacedMemberIDs.contains).isEmpty }
            for (index, pair) in resolvedPairs.enumerated() {
                plans.append(
                    SeriesRoundPartnershipPlan(
                        id: "extracted_\(group.id)_pair_\(index)",
                        teamID: pair.teamID,
                        memberIDs: pair.memberIDs,
                        label: index == 0 ? "Pair A" : "Pair B",
                        createdAt: .init(),
                        lastUpdatedAt: .init()
                    )
                )
            }
        }
        return plans
    }

    private func autofilledPairMatchupPlans() -> [SeriesRoundMatchupPlan] {
        let currentOptionsByID = Dictionary(uniqueKeysWithValues: pairMatchupOptions.map { ($0.id, $0) })
        return plannedTeeGroups.sorted { $0.index < $1.index }.enumerated().compactMap { index, group in
            let pairs = SeriesTeeGroupMirrorAnalyzer.pairs(
                for: group,
                partnershipPlans: normalizedPartnershipPlans(),
                membersByID: planningMembersByID
            )
            let teamIDs = Set(pairs.map(\.teamID).filter(\.isPopulated))
            guard pairs.count == 2, teamIDs.count == 2 else { return nil }
            guard currentOptionsByID[pairs[0].id] != nil, currentOptionsByID[pairs[1].id] != nil else { return nil }

            let existing = matchupPlans.first {
                Set([$0.pairAID ?? "", $0.pairBID ?? ""]) == Set([pairs[0].id, pairs[1].id])
            }
            return SeriesRoundMatchupPlan(
                id: existing?.id ?? HackersID.string(),
                pairAID: pairs[0].id,
                pairBID: pairs[1].id,
                index: index,
                podGroupingStrategy: .disabled,
                notes: existing?.notes,
                isLocked: existing?.isLocked ?? false,
                createdAt: existing?.createdAt ?? .init(),
                lastUpdatedAt: .init()
            )
        }
    }

    private func autofillTeamMatchupsByCurrentOrder() -> [SeriesRoundMatchupPlan] {
        buildTeamMatchupPlans(from: viewModel.sortedTeams.map(\.id))
    }

    private func autofillTeamMatchupsRandom() -> [SeriesRoundMatchupPlan] {
        buildTeamMatchupPlans(from: viewModel.sortedTeams.map(\.id).shuffled())
    }

    private func autofillIndividualMatchupsRandom() -> [SeriesRoundMatchupPlan] {
        buildMemberMatchupPlans(from: teamAwareOrderedMemberPairings(from: planningMembers.map(\.id).shuffled()))
    }

    private func autofillIndividualMatchupsByHandicap() -> [SeriesRoundMatchupPlan] {
        let orderedMemberIDs = SeriesRoundMatchupMemberOptionBuilder.sortedMembers(planningMembers) { memberID in
            viewModel.effectiveHandicap(for: memberID)
        }
        .map(\.id)
        return buildMemberMatchupPlans(from: teamAwareOrderedMemberPairings(from: orderedMemberIDs))
    }

    private func autofillIndividualMatchupsFromTeeSheet() -> [SeriesRoundMatchupPlan] {
        let pairings = plannedTeeGroups
            .sorted { $0.index < $1.index }
            .flatMap { group -> [(String, String)] in
                let orderedSeats = group.seats.sorted { $0.teeOrder < $1.teeOrder }
                return stride(from: 0, to: orderedSeats.count - 1, by: 2).compactMap { index in
                    guard index + 1 < orderedSeats.count else { return nil }
                    return (orderedSeats[index].memberID, orderedSeats[index + 1].memberID)
                }
            }
        return buildMemberMatchupPlans(from: pairings)
    }

    private func autofillPairMatchupsRandom() -> [SeriesRoundMatchupPlan] {
        ensurePartnershipPlansFromReadyGroups()
        return buildPairMatchupPlans(from: pairMatchupOptions.map(\.id).shuffled())
    }

    private func buildTeamMatchupPlans(from orderedTeamIDs: [String]) -> [SeriesRoundMatchupPlan] {
        let pairings: [(String, String)] = stride(from: 0, to: orderedTeamIDs.count - 1, by: 2).compactMap { index in
            guard index + 1 < orderedTeamIDs.count else { return nil }
            return (orderedTeamIDs[index], orderedTeamIDs[index + 1])
        }
        return pairings.enumerated().compactMap { index, pairing in
            guard pairing.0.isPopulated, pairing.1.isPopulated, pairing.0 != pairing.1 else { return nil }
            let existing = matchupPlans.first {
                Set([$0.teamAID, $0.teamBID]) == Set([pairing.0, pairing.1])
            }
            return SeriesRoundMatchupPlan(
                id: existing?.id ?? HackersID.string(),
                teamAID: pairing.0,
                teamBID: pairing.1,
                index: index,
                podGroupingStrategy: podGroupingStrategy,
                notes: existing?.notes,
                isLocked: existing?.isLocked ?? false,
                createdAt: existing?.createdAt ?? .init(),
                lastUpdatedAt: .init()
            )
        }
    }

    private func buildMemberMatchupPlans(from orderedMemberIDs: [String]) -> [SeriesRoundMatchupPlan] {
        let pairings: [(String, String)] = stride(from: 0, to: orderedMemberIDs.count - 1, by: 2).compactMap { index in
            guard index + 1 < orderedMemberIDs.count else { return nil }
            return (orderedMemberIDs[index], orderedMemberIDs[index + 1])
        }
        return buildMemberMatchupPlans(from: pairings)
    }

    private func teamAwareOrderedMemberPairings(from orderedMemberIDs: [String]) -> [(String, String)] {
        var remaining = orderedMemberIDs.filter(\.isPopulated)
        var pairings: [(String, String)] = []

        while !remaining.isEmpty {
            let memberID = remaining.removeFirst()
            guard let opponentIndex = remaining.firstIndex(where: { canAutoPairMembers(memberID, with: $0) }) else {
                continue
            }
            let opponentID = remaining.remove(at: opponentIndex)
            pairings.append((memberID, opponentID))
        }

        return pairings
    }

    private func canAutoPairMembers(_ memberID: String, with opponentID: String) -> Bool {
        guard memberID != opponentID else { return false }
        guard viewModel.usesTeams else { return true }

        let memberTeamID = planningMembersByID[memberID]?.teamID
        let opponentTeamID = planningMembersByID[opponentID]?.teamID
        if let memberTeamID, memberTeamID.isPopulated,
           let opponentTeamID, opponentTeamID.isPopulated {
            return memberTeamID != opponentTeamID
        }
        return true
    }

    private func buildMemberMatchupPlans(from pairings: [(String, String)]) -> [SeriesRoundMatchupPlan] {
        pairings.enumerated().compactMap { index, pairing in
            guard pairing.0.isPopulated, pairing.1.isPopulated, pairing.0 != pairing.1 else { return nil }
            let existing = matchupPlans.first {
                Set([$0.memberAID ?? "", $0.memberBID ?? ""]) == Set([pairing.0, pairing.1])
            }
            return SeriesRoundMatchupPlan(
                id: existing?.id ?? HackersID.string(),
                memberAID: pairing.0,
                memberBID: pairing.1,
                index: index,
                podGroupingStrategy: .disabled,
                notes: existing?.notes,
                isLocked: existing?.isLocked ?? false,
                createdAt: existing?.createdAt ?? .init(),
                lastUpdatedAt: .init()
            )
        }
    }

    private func buildPairMatchupPlans(from orderedPairIDs: [String]) -> [SeriesRoundMatchupPlan] {
        stride(from: 0, to: orderedPairIDs.count - 1, by: 2).enumerated().compactMap { step, index in
            let left = orderedPairIDs[index]
            let right = orderedPairIDs[index + 1]
            guard left.isPopulated, right.isPopulated, left != right else { return nil }
            let existing = matchupPlans.first {
                Set([$0.pairAID ?? "", $0.pairBID ?? ""]) == Set([left, right])
            }
            return SeriesRoundMatchupPlan(
                id: existing?.id ?? HackersID.string(),
                pairAID: left,
                pairBID: right,
                index: step,
                podGroupingStrategy: .disabled,
                notes: existing?.notes,
                isLocked: existing?.isLocked ?? false,
                createdAt: existing?.createdAt ?? .init(),
                lastUpdatedAt: .init()
            )
        }
    }

    private func applyMatchupAutoFill(_ action: MatchupAutoFillAction) {
        switch (matchupSource, action) {
        case (.byTeam, .random):
            matchupPlans = autofillTeamMatchupsRandom()
        case (.byTeam, .currentTeamOrder):
            matchupPlans = autofillTeamMatchupsByCurrentOrder()
        case (.byPair, .random):
            matchupPlans = autofillPairMatchupsRandom()
        case (.byPair, .mirrorTeeSheet):
            ensurePartnershipPlansFromReadyGroups()
            matchupPlans = autofilledPairMatchupPlans()
        case (.byIndividual, .random):
            matchupPlans = autofillIndividualMatchupsRandom()
        case (.byIndividual, .byHandicap):
            matchupPlans = autofillIndividualMatchupsByHandicap()
        case (.byIndividual, .mirrorTeeSheet):
            matchupPlans = autofillIndividualMatchupsFromTeeSheet()
        default:
            break
        }
    }

    private var planningSection: some View {
        SeriesRoundTeeSheetPlanningCard(
            palette: palette,
            holeRange: planningHoleRange,
            plannedMatchups: plannedMatchups,
            eligibleMembers: planningMembers,
            membersByID: planningMembersByID,
            teamsByID: planningTeamsByID,
            handicapsEnabled: viewModel.series.handicapConfig.isEnabled,
            effectiveHandicapText: handicapValueText(for:),
            plannedTeeGroups: $plannedTeeGroups,
            partnershipPlans: $partnershipPlans,
            showPairStatus: matchupSource == .byPair,
            onRegenerate: { refreshPlanningStructure(forceRegenerate: true) },
            onResetManualOverrides: { refreshPlanningStructure(forceRegenerate: true) }
        )
    }

    private func pairNamesText(for memberIDs: [String]) -> String {
        memberIDs.compactMap(formattedPlayerLabel(for:)).joined(separator: " + ")
    }

    private func matchupPlayerLine(for memberID: String) -> String {
        let formatted = formattedPlayerLabel(for: memberID)
        guard let name = planningMembersByID[memberID]?.name else { return formatted ?? "Unknown player" }
        let fullName = name.trimmedFullName
        guard fullName.count > 18 else { return formatted ?? fullName }

        let given = name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard given.isPopulated, family.isPopulated else { return formatted ?? fullName }
        let shortName = "\(given) \(family.prefix(1))."
        let metadata = playerInlineMetadata(for: memberID)
        return metadata.isPopulated ? "\(shortName) • \(metadata)" : shortName
    }

    private func matchupRow(index: Int, plan: SeriesRoundMatchupPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Match \(index + 1)")
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
                if viewModel.usesTeams && matchupSource == .byPair {
                    matchupPairMenu(
                        title: "Pair A",
                        plan: plan,
                        selection: pairOption(for: plan.pairAID)
                    ) { selectedPairID in
                        assignPair(selectedPairID, to: plan.id, side: .a)
                    }
                } else if viewModel.usesTeams && matchupSource == .byTeam {
                    matchupTeamMenu(
                        title: "Team A",
                        selection: teamName(for: plan.teamAID) ?? "Choose",
                        availableTeams: availableTeams(for: plan, currentTeamID: plan.teamAID)
                    ) { selectedTeamID in
                        assignTeam(selectedTeamID, to: plan.id, side: .a)
                    }
                } else {
                    matchupMemberMenu(
                        title: "Player A",
                        selectionID: plan.memberAID,
                        availableMembers: availableMembers(for: plan, currentMemberID: plan.memberAID)
                    ) { selectedMemberID in
                        assignMember(selectedMemberID, to: plan.id, side: .a)
                    }
                }

                Text("vs")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)

                if viewModel.usesTeams && matchupSource == .byPair {
                    matchupPairMenu(
                        title: "Pair B",
                        plan: plan,
                        selection: pairOption(for: plan.pairBID)
                    ) { selectedPairID in
                        assignPair(selectedPairID, to: plan.id, side: .b)
                    }
                } else if viewModel.usesTeams && matchupSource == .byTeam {
                    matchupTeamMenu(
                        title: "Team B",
                        selection: teamName(for: plan.teamBID) ?? "Choose",
                        availableTeams: availableTeams(for: plan, currentTeamID: plan.teamBID)
                    ) { selectedTeamID in
                        assignTeam(selectedTeamID, to: plan.id, side: .b)
                    }
                } else {
                    matchupMemberMenu(
                        title: "Player B",
                        selectionID: plan.memberBID,
                        availableMembers: availableMembers(for: plan, currentMemberID: plan.memberBID)
                    ) { selectedMemberID in
                        assignMember(selectedMemberID, to: plan.id, side: .b)
                    }
                }
            }
        }
    }

    private func matchupPairMenu(
        title: String,
        plan: SeriesRoundMatchupPlan,
        selection: PairMatchupOption?,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            Menu {
                ForEach(availablePairOptions(for: plan, currentPairID: selection?.id), id: \.id) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                            Text(option.subtitle)
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selection?.title.isPopulated == true ? selection!.title : "Choose")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(selection?.title.isPopulated == true ? palette.foregroundColor : Color.neutral)
                        .lineLimit(1)

                    if let selection {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(selection.memberIDs.prefix(2)), id: \.self) { memberID in
                                Text(matchupPlayerLine(for: memberID))
                                    .fontStyle(kFontName, size: 11, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("Select a planned pair")
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    Icon(name: "f078", size: 12, weight: .solid)
                        .foregroundStyle(Color.neutral)
                        .padding(.trailing, 12)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.neutral6)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
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
        let siblingTeamID = siblingTeamID(for: plan, currentTeamID: currentTeamID)
        return viewModel.sortedTeams.filter { team in
            team.id != siblingTeamID
        }
    }

    private func matchupMemberMenu(
        title: String,
        selectionID: String?,
        availableMembers: [SeriesMember],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            let sections = matchupMemberOptionSections(for: availableMembers)
            Menu {
                ForEach(sections) { section in
                    if viewModel.usesTeams {
                        Section(section.title) {
                            memberMenuButtons(for: section.options, onSelect: onSelect)
                        }
                    } else {
                        memberMenuButtons(for: section.options, onSelect: onSelect)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    playerSelectionMenuLabel(for: selectionID)
                    Spacer(minLength: 0)
                    Icon(name: "f078", size: 12, weight: .solid)
                        .foregroundStyle(Color.neutral)
                        .padding(.top, 2)
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
        let siblingMemberID = siblingMemberID(for: plan, currentMemberID: currentMemberID)
        let siblingTeamID = siblingMemberID.flatMap { planningMembersByID[$0]?.teamID }
        return viewModel.eligibleMembers.filter { member in
            if member.id == siblingMemberID { return false }
            if viewModel.usesTeams,
               let siblingTeamID,
               siblingTeamID.isPopulated,
               member.teamID == siblingTeamID {
                return false
            }
            return true
        }
    }

    private func availablePairOptions(for plan: SeriesRoundMatchupPlan, currentPairID: String?) -> [PairMatchupOption] {
        return pairMatchupOptions.filter { option in
            option.id != siblingPairID(for: plan, currentPairID: currentPairID)
        }
    }

    private func siblingTeamID(for plan: SeriesRoundMatchupPlan, currentTeamID: String?) -> String? {
        if currentTeamID == plan.teamAID { return plan.teamBID }
        if currentTeamID == plan.teamBID { return plan.teamAID }
        if plan.teamAID.isPopulated { return plan.teamAID }
        return plan.teamBID.isPopulated ? plan.teamBID : nil
    }

    private func teamName(for teamID: String) -> String? {
        viewModel.sortedTeams.first(where: { $0.id == teamID })?.name
    }

    private func siblingPairID(for plan: SeriesRoundMatchupPlan, currentPairID: String?) -> String? {
        if currentPairID == plan.pairAID { return plan.pairBID }
        if currentPairID == plan.pairBID { return plan.pairAID }
        return plan.pairAID ?? plan.pairBID
    }

    private func pairOption(for pairID: String?) -> PairMatchupOption? {
        guard let pairID else { return nil }
        return pairMatchupOptions.first(where: { $0.id == pairID })
    }

    private func siblingMemberID(for plan: SeriesRoundMatchupPlan, currentMemberID: String?) -> String? {
        if currentMemberID == plan.memberAID { return plan.memberBID }
        if currentMemberID == plan.memberBID { return plan.memberAID }
        return plan.memberAID ?? plan.memberBID
    }

    private func memberName(for memberID: String?) -> String? {
        guard let memberID else { return nil }
        return formattedPlayerLabel(for: memberID)
    }

    private func playerDisplayName(for memberID: String?) -> String? {
        guard let memberID else { return nil }
        let name = planningMembersByID[memberID]?.name.trimmedFullName
        if let name, name.isPopulated {
            return name
        }
        return nil
    }

    private func playerSubtitle(for memberID: String?) -> String? {
        guard let memberID else { return nil }
        let metadata = playerInlineMetadata(for: memberID)
        if metadata.isPopulated {
            return metadata
        }
        return nil
    }

    @ViewBuilder
    private func playerSelectionMenuLabel(for memberID: String?) -> some View {
        let title = playerDisplayName(for: memberID) ?? "Choose"
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(memberID == nil ? Color.neutral : palette.foregroundColor)
                .lineLimit(1)
            if let subtitle = playerSubtitle(for: memberID) {
                Text(subtitle)
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(2)
            } else if memberID == nil {
                Text("Select a player")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(2)
            }
        }
    }

    private func formattedPlayerLabel(for memberID: String) -> String? {
        let name = planningMembersByID[memberID]?.name.trimmedFullName
        let metadata = playerInlineMetadata(for: memberID)
        let resolvedName: String? = {
            if let name, name.isPopulated { return name }
            return nil
        }()
        let resolvedMetadata: String? = metadata.isPopulated ? metadata : nil
        switch (resolvedName, resolvedMetadata) {
        case let (name?, metadata?):
            return "\(name) • \(metadata)"
        case let (name?, nil):
            return name
        case let (nil, metadata?):
            return metadata
        default:
            return nil
        }
    }

    private func playerInlineMetadata(for memberID: String) -> String {
        var components: [String] = []
        if let teamID = planningMembersByID[memberID]?.teamID,
           let teamName = planningTeamsByID[teamID]?.name,
           teamName.isPopulated {
            components.append(teamName)
        }
        if let handicap = handicapText(for: memberID) {
            components.append(handicap)
        }
        return components.joined(separator: " • ")
    }

    private func handicapText(for memberID: String) -> String? {
        guard viewModel.series.handicapConfig.isEnabled else { return nil }
        guard let value = handicapValueText(for: memberID) else { return nil }
        return "HCP \(value)"
    }

    private func handicapValueText(for memberID: String) -> String? {
        guard let handicap = viewModel.effectiveHandicap(for: memberID),
              handicap.isFinite else { return nil }
        return formatHandicapValue(handicap)
    }

    private func formatHandicapValue(_ handicap: Double) -> String {
        let rounded = handicap.rounded(.toNearestOrAwayFromZero)
        if abs(handicap - rounded) < 0.05 {
            return String(Int(rounded))
        }
        let oneDecimal = String(format: "%.1f", handicap)
        return oneDecimal.hasSuffix(".0") ? String(oneDecimal.dropLast(2)) : oneDecimal
    }

    private func matchupMemberOptionSections(for members: [SeriesMember]) -> [SeriesRoundMatchupMemberOptionSection] {
        SeriesRoundMatchupMemberOptionBuilder.sections(
            members: members,
            teams: viewModel.sortedTeams,
            usesTeams: viewModel.usesTeams
        ) { memberID in
            viewModel.effectiveHandicap(for: memberID)
        }
    }

    @ViewBuilder
    private func memberMenuButtons(
        for options: [SeriesRoundMatchupMemberOption],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        ForEach(options) { option in
            Button {
                onSelect(option.memberID)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                    }
                }
            }
        }
    }

    private func updateMatchup(
        planID: String,
        teamAID: String? = nil,
        teamBID: String? = nil,
        memberAID: String? = nil,
        memberBID: String? = nil,
        pairAID: String? = nil,
        pairBID: String? = nil
    ) {
        guard let index = matchupPlans.firstIndex(where: { $0.id == planID }) else { return }
        if let teamAID { matchupPlans[index].teamAID = teamAID }
        if let teamBID { matchupPlans[index].teamBID = teamBID }
        if let memberAID { matchupPlans[index].memberAID = memberAID }
        if let memberBID { matchupPlans[index].memberBID = memberBID }
        if let pairAID { matchupPlans[index].pairAID = pairAID }
        if let pairBID { matchupPlans[index].pairBID = pairBID }
        matchupPlans[index].lastUpdatedAt = .init()
    }

    private enum MatchupSide {
        case a
        case b
    }

    private func assignTeam(_ teamID: String, to planID: String, side: MatchupSide) {
        guard let targetIndex = matchupPlans.firstIndex(where: { $0.id == planID }) else { return }
        let oppositeTeamID = side == .a ? matchupPlans[targetIndex].teamBID : matchupPlans[targetIndex].teamAID
        let currentTeamID = side == .a ? matchupPlans[targetIndex].teamAID : matchupPlans[targetIndex].teamBID
        guard teamID != oppositeTeamID, teamID != currentTeamID else { return }

        clearExistingTeamAssignment(teamID, excludingPlanID: planID)
        if side == .a {
            matchupPlans[targetIndex].teamAID = teamID
        } else {
            matchupPlans[targetIndex].teamBID = teamID
        }
        matchupPlans[targetIndex].lastUpdatedAt = .init()
    }

    private func assignPair(_ pairID: String, to planID: String, side: MatchupSide) {
        guard let targetIndex = matchupPlans.firstIndex(where: { $0.id == planID }) else { return }
        let oppositePairID = side == .a ? matchupPlans[targetIndex].pairBID : matchupPlans[targetIndex].pairAID
        let currentPairID = side == .a ? matchupPlans[targetIndex].pairAID : matchupPlans[targetIndex].pairBID
        guard pairID != oppositePairID, pairID != currentPairID else { return }

        clearExistingPairAssignment(pairID, excludingPlanID: planID)
        if side == .a {
            matchupPlans[targetIndex].pairAID = pairID
        } else {
            matchupPlans[targetIndex].pairBID = pairID
        }
        matchupPlans[targetIndex].lastUpdatedAt = .init()
    }

    private func assignMember(_ memberID: String, to planID: String, side: MatchupSide) {
        guard let targetIndex = matchupPlans.firstIndex(where: { $0.id == planID }) else { return }
        let oppositeMemberID = side == .a ? matchupPlans[targetIndex].memberBID : matchupPlans[targetIndex].memberAID
        let currentMemberID = side == .a ? matchupPlans[targetIndex].memberAID : matchupPlans[targetIndex].memberBID
        guard memberID != oppositeMemberID, memberID != currentMemberID else { return }
        if viewModel.usesTeams,
           let oppositeMemberID,
           let oppositeTeamID = planningMembersByID[oppositeMemberID]?.teamID,
           oppositeTeamID.isPopulated,
           planningMembersByID[memberID]?.teamID == oppositeTeamID {
            return
        }

        clearExistingMemberAssignment(memberID, excludingPlanID: planID)
        if side == .a {
            matchupPlans[targetIndex].memberAID = memberID
        } else {
            matchupPlans[targetIndex].memberBID = memberID
        }
        matchupPlans[targetIndex].lastUpdatedAt = .init()
    }

    private func clearExistingTeamAssignment(_ teamID: String, excludingPlanID: String) {
        for index in matchupPlans.indices where matchupPlans[index].id != excludingPlanID {
            var didClear = false
            if matchupPlans[index].teamAID == teamID {
                matchupPlans[index].teamAID = ""
                didClear = true
            }
            if matchupPlans[index].teamBID == teamID {
                matchupPlans[index].teamBID = ""
                didClear = true
            }
            if didClear {
                matchupPlans[index].lastUpdatedAt = .init()
            }
        }
    }

    private var selectedCourseName: String {
        if let selectedCourse, selectedCourse.cachedName.isPopulated {
            return selectedCourse.cachedName
        }
        return "No course selected"
    }

    private func clearExistingPairAssignment(_ pairID: String, excludingPlanID: String) {
        for index in matchupPlans.indices where matchupPlans[index].id != excludingPlanID {
            var didClear = false
            if matchupPlans[index].pairAID == pairID {
                matchupPlans[index].pairAID = nil
                didClear = true
            }
            if matchupPlans[index].pairBID == pairID {
                matchupPlans[index].pairBID = nil
                didClear = true
            }
            if didClear {
                matchupPlans[index].lastUpdatedAt = .init()
            }
        }
    }

    private func clearExistingMemberAssignment(_ memberID: String, excludingPlanID: String) {
        for index in matchupPlans.indices where matchupPlans[index].id != excludingPlanID {
            var didClear = false
            if matchupPlans[index].memberAID == memberID {
                matchupPlans[index].memberAID = nil
                didClear = true
            }
            if matchupPlans[index].memberBID == memberID {
                matchupPlans[index].memberBID = nil
                didClear = true
            }
            if didClear {
                matchupPlans[index].lastUpdatedAt = .init()
            }
        }
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

    private func appendEmptyMatchupRow() {
        matchupPlans.append(
            SeriesRoundMatchupPlan(
                id: HackersID.string(),
                index: matchupPlans.count,
                podGroupingStrategy: podGroupingStrategy,
                createdAt: .init(),
                lastUpdatedAt: .init()
            )
        )
    }

    private func sparkleActionChipLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.foregroundColor)
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCardEffect(cornerRadius: 16, tint: palette.whiteGlassButtonColor)
    }

    private func matchupSourceMenuItem(_ option: MatchupSourceMenuOption) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.source.title)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                if let subtitle = option.subtitle {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 11, weight: .regular)
                }
            }
            Spacer(minLength: 8)
            if option.isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(option.isDisabled ? Color.neutral : palette.foregroundColor)
    }

    private func fullWidthCardActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.backgroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(palette.foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
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

    private var selectedTemplate: GameTemplate {
        FormatTemplateRegistry.template(for: selectedTemplateID)
    }

    private var effectiveScoreOwnerScope: RoundScoreOwnerScope {
        selectedTemplate.scoreSource == .shared ? scoreOwnerScope : .individual
    }

    private var isSharedTeamTemplate: Bool {
        selectedTemplate.scoreSource == .shared && selectedTemplate.requirements.requiresTeams
    }

    private var scoreEntryScopeSubtitle: String {
        isSharedTeamTemplate
            ? "Collect one shared score by team, partnership, or tee group. Partnerships seed from fixed pairs and can be customized in the round lobby."
            : "Collect scores by player, partnership, or full tee group. Partnerships seed from fixed pairs and can be customized in the round lobby."
    }

    private func scoreOwnerScopeTitle(for scope: RoundScoreOwnerScope) -> String {
        switch scope {
        case .individual:
            return isSharedTeamTemplate ? "Team" : "Individual"
        case .partnership:
            return "Partnership"
        case .teeGroup:
            return "Tee group"
        }
    }

    private var sharedScoreAllowanceConfig: HandicapConfiguration? {
        let percentages = allowancePercentages(from: sharedScoreAllowanceText)
        guard percentages.isPopulated else { return nil }
        return HandicapConfiguration(percentage: 1.0, isTeamCombined: true, positionPercentages: percentages)
    }

    private var availableTemplates: [GameTemplate] {
        FormatTemplateRegistry.seriesTemplates
    }

    private func allowanceText(from config: HandicapConfiguration) -> String {
        guard let percentages = config.positionPercentages, percentages.isPopulated else { return "" }
        return percentages.map { percentage in
            let whole = percentage * 100
            if abs(whole - whole.rounded()) < 0.000_001 {
                return "\(Int(whole.rounded()))"
            }
            return String(format: "%.1f", whole)
        }
        .joined(separator: ",")
    }

    private func allowancePercentages(from text: String) -> [Double] {
        text
            .split(separator: ",")
            .compactMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let value = Double(trimmed), value >= 0 else { return nil }
                return value > 1 ? value / 100 : value
            }
    }

    private var seriesPointsDescription: String {
        if viewModel.usesTeams {
            if matchupSource == .byIndividual && competitionScope == .matchup {
                return "Team awards feed the team standings. Individual awards feed player standings. Team awards use finishing order, while individual win/tie/loss uses the scheduled head-to-head results."
            }
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

    private var teamScoringScopeLabel: String {
        teamScoring.scope == .perRound ? "Round" : "Hole"
    }

    @ViewBuilder
    private var countScoresMenuButtons: some View {
        Button {
            teamScoring.mode = .all
        } label: {
            HStack {
                Text("All scores")
                if teamScoring.mode == .all { Image(systemName: "checkmark") }
            }
        }

        Divider()

        ForEach(1...4, id: \.self) { count in
            Button {
                teamScoring.mode = .bestN
                teamScoring.count = count
            } label: {
                HStack {
                    Text("Best \(count)")
                    if teamScoring.mode == .bestN, teamScoring.count == count {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }

        Divider()

        ForEach(1...4, id: \.self) { count in
            Button {
                teamScoring.mode = .worstN
                teamScoring.count = count
            } label: {
                HStack {
                    Text("Worst \(count)")
                    if teamScoring.mode == .worstN, teamScoring.count == count {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    private var teamScoringKindLabel: String {
        switch teamScoring.mode {
        case .all: return "All"
        case .bestN: return "Best"
        case .worstN: return "Worst"
        }
    }

    private var selectionDomainLabel: String {
        guard let selectionDomain else { return "Auto" }
        return selectionDomainTitle(for: selectionDomain)
    }

    private func selectionDomainTitle(for domain: ScoringSelectionDomain) -> String {
        switch domain {
        case .participant:
            return "Player"
        case .team:
            return "Team"
        case .partnership:
            return "Pair"
        case .teeGroup:
            return "Tee group"
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
        if resolvedMatchupMode(for: competitionScope) != d.matchupMode { return .confirmed }
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
            Chip.ready
        case .leagueDefault:
            Chip(text: "League default", size: .xSmall, foreground: Color.neutral, background: palette.cardEmbeddedRowBackground)
        }
    }

    private func normalizeSelectedProfilesForCompetition() {
        if let currentTeamProfileID = selectedTeamProfileID,
           let profile = viewModel.scoringProfiles.first(where: { $0.id == currentTeamProfileID }),
           (!viewModel.usesTeams || competitionScope != .matchup || matchupSource == .byIndividual),
           profile.kind == .winTieLoss {
            self.selectedTeamProfileID = viewModel.scoringProfiles.first {
                !$0.isArchived && $0.competitorType == .team && $0.kind != .winTieLoss
            }?.id
        }

        if let currentIndividualProfileID = selectedIndividualProfileID,
           let profile = viewModel.scoringProfiles.first(where: { $0.id == currentIndividualProfileID }),
           (competitionScope != .matchup || (viewModel.usesTeams && matchupSource != .byIndividual)),
           profile.kind == .winTieLoss {
            self.selectedIndividualProfileID = viewModel.scoringProfiles.first {
                !$0.isArchived && $0.competitorType == .member && $0.kind != .winTieLoss
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
