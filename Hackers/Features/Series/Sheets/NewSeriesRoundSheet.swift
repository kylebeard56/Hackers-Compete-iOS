//
//  NewSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct NewSeriesRoundSheet: View {
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
    @State private var sharedScoreAllowanceText = ""
    @State private var teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
    @State private var sequentialTeeStartsEnabled = false
    @State private var podGroupingStrategy: SeriesPodGroupingStrategy = .disabled
    @State private var matchupSource: MatchupSource = .byTeam
    @State private var selectedTeamProfileID: String?
    @State private var selectedIndividualProfileID: String?
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
    @State private var isCreating = false

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
            matchupSource = MatchupSource(mode: defaults.matchupMode, usesTeams: viewModel.usesTeams)
            matchupScoringStyle = defaults.matchupScoringStyle
            holeWinPoints = defaults.resolvedHoleWinPoints
            matchWinnerBonusPoints = defaults.resolvedMatchWinnerBonusPoints
            sharedScoreAllowanceText = allowanceText(
                from: defaults.sharedScoreHandicapConfig ?? FormatTemplateRegistry.template(for: selectedTemplateID).requirements.defaultHandicapConfig
            )
            teamScoring = defaults.teamScoring
            sequentialTeeStartsEnabled = defaults.sequentialTeeStartsEnabled ?? false
            podGroupingStrategy = defaults.podGroupingStrategy
            countsTowardHandicapPool = defaults.countsTowardHandicapPool
            excludedHandicapMemberIDs = defaults.normalizedExcludedHandicapMemberIDs
            selectedCourse = viewModel.suggestedCourseSelectionForNextRound()
            matchupPlans = []
            refreshPlanningStructure(forceRegenerate: true)
            normalizeSelectedProfilesForCompetition()
        }
        .onChange(of: competitionScope) { _, newValue in
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

                    if let leagueDefault = viewModel.series.settings.defaultCourse {
                        Button {
                            selectedCourse = viewModel.suggestedCourseSelectionForNextRound() ?? leagueDefault
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

            if viewModel.usesTeams {
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

            if FormatTemplateRegistry.template(for: selectedTemplateID).scoreSource == .shared {
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
                                menuChipLabel(teamScoring.scope == .perRound ? "Round" : "Hole")
                            }
                            .buttonStyle(.plain)
                        }
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
            seriesRound: nil,
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
                    title: nil,
                    subtitle: "Choose how team points are assigned for this round.",
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
                title: nil,
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
            scoreOwnerScope: scoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            matchupMode: resolvedMatchupMode(for: competitionScope),
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            sharedScoreHandicapConfig: sharedScoreAllowanceConfig,
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
            matchupMode: resolvedMatchupMode(for: resolvedCompetitionScope),
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            sharedScoreHandicapConfig: sharedScoreAllowanceConfig,
            countsTowardHandicapPool: countsTowardHandicapPool,
            excludedHandicapMemberIDs: excludedHandicapMemberIDs
        )
        let resolvedMatchups = normalizedMatchupPlans()
        let plannedStructure = persistedPlanningStructure()
        let resolvedPartnershipPlans = normalizedPartnershipPlans()
        Task {
            _ = await viewModel.addRound(
                title: trimmedTitle.isEmpty ? "Round \(viewModel.rounds.count + 1)" : trimmedTitle,
                scheduledAt: hasDate ? Time(for: scheduledDate) : nil,
                courseOverride: selectedCourse,
                roundConfig: roundConfig,
                teamScoringProfileID: selectedTeamProfileID,
                individualScoringProfileID: selectedIndividualProfileID,
                matchupPlans: resolvedMatchups,
                plannedMatchups: plannedStructure.matchups,
                plannedTeeGroups: plannedStructure.teeGroups,
                partnershipPlans: resolvedPartnershipPlans,
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
            if let seriesDefault = viewModel.suggestedCourseSelectionForNextRound() {
                return "\(viewModel.series.experiencePreset.displayName) default available: \(seriesDefault.holeSegment.title)"
            }
            return "Pick a course now or leave it blank until the round is ready."
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
            preserving: matchupPlans
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
        selectedCourse ?? viewModel.suggestedCourseSelectionForNextRound()
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

        let source = matchupPlans.isEmpty ? defaultMatchupPlans() : matchupPlans

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
            scoreOwnerScope: scoreOwnerScope,
            matchupScoringStyle: matchupScoringStyle,
            holeWinPoints: competitionScope == .matchup ? holeWinPoints : nil,
            matchWinnerBonusPoints: competitionScope == .matchup ? matchWinnerBonusPoints : nil,
            matchTiePolicy: .half,
            sequentialTeeStartsEnabled: sequentialTeeStartsEnabled,
            matchupMode: resolvedMatchupMode(for: competitionScope),
            podGroupingStrategy: podGroupingStrategy,
            teamAssignmentMode: viewModel.usesTeams ? .seriesTeams : .manual,
            teeGroupMode: podGroupingStrategy.usesPodAlignment ? .podAligned : .auto,
            notes: notes.isEmpty ? nil : notes,
            sharedScoreHandicapConfig: sharedScoreAllowanceConfig,
            countsTowardHandicapPool: countsTowardHandicapPool,
            excludedHandicapMemberIDs: excludedHandicapMemberIDs
        )
        return SeriesRound(
            id: "draft_round",
            title: title,
            scheduledAt: hasDate ? Time(for: scheduledDate) : nil,
            courseOverride: planningCourseSelection,
            roundConfig: roundConfig,
            matchupPlans: normalizedMatchupPlans(),
            plannedMatchups: plannedMatchups,
            plannedTeeGroups: plannedTeeGroups,
            partnershipPlans: normalizedPartnershipPlans(),
            notes: notes.isEmpty ? nil : notes,
            parentID: viewModel.seriesID
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
            scheduledAt: planningDraftRound.scheduledAt,
            courseOverride: planningDraftRound.courseOverride,
            roundConfig: planningDraftRound.roundConfig,
            matchupPlans: planningDraftRound.matchupPlans,
            plannedMatchups: normalizedMatchupPlans().map {
                SeriesRoundPlannedMatchup(plan: $0, source: .manualOverride)
            },
            plannedTeeGroups: forceRegenerate ? [] : plannedTeeGroups,
            partnershipPlans: normalizedPartnershipPlans(),
            notes: planningDraftRound.notes,
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

    private func siblingPairID(for plan: SeriesRoundMatchupPlan, currentPairID: String?) -> String? {
        if currentPairID == plan.pairAID { return plan.pairBID }
        if currentPairID == plan.pairBID { return plan.pairAID }
        return plan.pairAID ?? plan.pairBID
    }

    private func teamName(for teamID: String) -> String? {
        viewModel.sortedTeams.first(where: { $0.id == teamID })?.name
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
}

struct SeriesRoundTeeSheetPlanningCard: View {
    let palette: DesignPalette
    let holeRange: HoleRange
    let plannedMatchups: [SeriesRoundPlannedMatchup]
    /// Roster members eligible for this round (used for the Unassigned bucket).
    let eligibleMembers: [SeriesMember]
    let membersByID: [String: SeriesMember]
    let teamsByID: [String: SeriesTeam]
    let handicapsEnabled: Bool
    let effectiveHandicapText: (String) -> String?
    @Binding var plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    @Binding var partnershipPlans: [SeriesRoundPartnershipPlan]
    let showPairStatus: Bool
    let onRegenerate: () -> Void
    let onResetManualOverrides: () -> Void

    @State private var deleteGroupConfirmationID: String?

    private var sortedGroups: [SeriesRoundPlannedTeeGroup] {
        plannedTeeGroups.sorted { $0.index < $1.index }
    }

    private var hasManualOverrides: Bool {
        sortedGroups.contains(where: \.hasManualOverrides)
    }

    private var visiblePlannedMatchups: [SeriesRoundPlannedMatchup] {
        plannedMatchups.filter { $0.source != .manualOverride }
    }

    private var assignedMemberIDs: Set<String> {
        Set(plannedTeeGroups.flatMap { $0.seats.map(\.memberID) })
    }

    private var unassignedMembers: [SeriesMember] {
        eligibleMembers
            .filter { !assignedMemberIDs.contains($0.id) }
            .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
    }

    private enum TeeSeatCluster: Identifiable {
        case single(SeriesRoundPlannedSeat)
        case pair(SeriesRoundPlannedSeat, SeriesRoundPlannedSeat)

        var id: String {
            switch self {
            case .single(let s):
                return "single_\(s.id)"
            case .pair(let a, let b):
                return "pair_\(a.id)_\(b.id)"
            }
        }
    }

    /// Clusters for display, including stable “Pair A / Pair B” labels (pairs ordered alphabetically within the group).
    private enum TeeGroupDisplayCluster: Identifiable {
        case single(SeriesRoundPlannedSeat)
        case pair(top: SeriesRoundPlannedSeat, bottom: SeriesRoundPlannedSeat, title: String)

        var id: String {
            switch self {
            case .single(let s): return "single_\(s.id)"
            case .pair(let a, let b, _): return "pair_\(a.id)_\(b.id)"
            }
        }
    }

    var body: some View {
        SeriesSheetCard(palette: palette) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tee sheet")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text("This is the tee sheet the live round will start from. Manual edits and round-local partners stay in place until you reset them.")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    Spacer(minLength: 0)

                    Menu {
                        Button {
                            onRegenerate()
                        } label: {
                            menuActionLabel(
                                title: "Regenerate",
                                subtitle: "Rebuild the tee sheet from the current round format and matchup setup."
                            )
                        }

                        Button {
                            onResetManualOverrides()
                        } label: {
                            menuActionLabel(
                                title: "Reset overrides",
                                subtitle: "Remove manual tee-group edits and return to the generated layout."
                            )
                        }
                        .disabled(!hasManualOverrides)
                    } label: {
                        Circle()
                            .fill(palette.cardEmbeddedRowBackground)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(palette.foregroundColor)
                            }
                    }
                    .buttonStyle(.plain)
                }

                if visiblePlannedMatchups.isPopulated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Matchups")
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        ForEach(visiblePlannedMatchups) { matchup in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Match \(matchup.matchupPlan.index + 1)")
                                        .fontStyle(kFontName, size: 13, weight: .semibold)
                                        .foregroundStyle(palette.foregroundColor)
                                    Text(matchupLabel(for: matchup))
                                        .fontStyle(kFontName, size: 12, weight: .regular)
                                        .foregroundStyle(Color.neutral)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                sourceChip(matchup.source)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tee Groups")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    ForEach(sortedGroups) { group in
                        teeGroupCard(group)
                    }

                    fullWidthCardActionButton("Add tee group") {
                        addGroup()
                    }

                    if unassignedMembers.isPopulated {
                        unassignedSection
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete tee group?",
            isPresented: Binding(
                get: { deleteGroupConfirmationID != nil },
                set: { if !$0 { deleteGroupConfirmationID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = deleteGroupConfirmationID {
                    removeGroup(id: id)
                }
                deleteGroupConfirmationID = nil
            }
            Button("Cancel", role: .cancel) {
                deleteGroupConfirmationID = nil
            }
        } message: {
            Text("Players in this group will move to Unassigned until you assign them to a tee group.")
        }
    }

    private var unassignedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unassigned")
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Text("These players are not on a tee group yet—same idea as unassigned players in the round lobby.")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(unassignedMembers, id: \.id) { member in
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardEmbeddedRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func teeGroupCard(_ group: SeriesRoundPlannedTeeGroup) -> some View {
        let currentSortedIndex = sortedGroups.firstIndex(where: { $0.id == group.id }) ?? 0
        let mirrorStatus = SeriesTeeGroupMirrorAnalyzer.status(
            for: group,
            partnershipPlans: partnershipPlans,
            membersByID: membersByID
        )
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Menu {
                        if sortedGroups.count > 1 {
                            Section("Move to position") {
                                ForEach(0..<sortedGroups.count, id: \.self) { slot in
                                    Button("Position \(slot + 1)") {
                                        moveGroup(id: group.id, toSortedSlot: slot)
                                    }
                                    .disabled(slot == currentSortedIndex)
                                }
                            }
                        }
                        Button("Delete group", role: .destructive) {
                            if group.seats.isEmpty {
                                removeGroup(id: group.id)
                            } else {
                                deleteGroupConfirmationID = group.id
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text("Group \(group.index + 1)")
                                    .fontStyle(kFontName, size: 13, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.neutral)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if showPairStatus, mirrorStatus == .ready {
                        Chip.ready
                    }

                    Spacer(minLength: 0)
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(group.hasManualOverrides
                        ? "This group was manually configured"
                        : "This group was automatically generated from game format")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if let teeTime = group.teeTime, teeTime.isPopulated {
                        Chip(
                            text: teeTime.formattedTeeTime,
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: palette.cardEmbeddedRowBackground
                        )
                    }

                    Menu {
                        ForEach(unassignedMembers, id: \.id) { member in
                            Button {
                                addMember(member.id, to: group.id)
                            } label: {
                                playerMenuLabel(for: member.id)
                            }
                        }
                    } label: {
                        Chip(
                            text: "Add players",
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: palette.cardEmbeddedRowBackground
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(unassignedMembers.isEmpty)

                    Menu {
                        ForEach(holeRange.holeNumbers, id: \.self) { hole in
                            Button("Hole \(hole)") {
                                updateGroup(group.id) { current in
                                    current.startingHole = hole
                                    current.source = .manualOverride
                                }
                            }
                        }
                    } label: {
                        Chip(
                            text: "Start on \(group.startingHole)",
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: palette.cardEmbeddedRowBackground
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if group.seats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No players assigned yet.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                    if !unassignedMembers.isEmpty {
                        Menu {
                            ForEach(unassignedMembers, id: \.id) { member in
                                Button {
                                    addMember(member.id, to: group.id)
                                } label: {
                                    playerMenuLabel(for: member.id)
                                }
                            }
                        } label: {
                            Chip(
                                text: "Add players",
                                size: .xSmall,
                                foreground: palette.foregroundColor,
                                background: palette.cardEmbeddedRowBackground
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(displayClusters(for: group)) { cluster in
                Group {
                    switch cluster {
                    case .single(let seat):
                        singleSeatRow(seat: seat, group: group)
                    case .pair(let top, let bottom, let title):
                        partnerPairRows(top: top, bottom: bottom, group: group, pairTitle: title)
                    }
                }
            }
        }
        .padding(12)
        .background(palette.cardNestedGroupBackground)
        //.background(Color.accentGreen.opacity(palette.colorScheme.translucent))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func seatClusters(for group: SeriesRoundPlannedTeeGroup) -> [TeeSeatCluster] {
        let seats = group.seats.sorted { $0.teeOrder < $1.teeOrder }
        var consumed = Set<String>()
        var out: [TeeSeatCluster] = []
        for seat in seats {
            if consumed.contains(seat.memberID) { continue }
            if let partnerID = partnerPlan(for: seat.memberID)?.memberIDs.first(where: { $0 != seat.memberID }),
               seats.contains(where: { $0.memberID == partnerID }),
               let partnerSeat = seats.first(where: { $0.memberID == partnerID }) {
                consumed.insert(seat.memberID)
                consumed.insert(partnerID)
                if seat.teeOrder <= partnerSeat.teeOrder {
                    out.append(.pair(seat, partnerSeat))
                } else {
                    out.append(.pair(partnerSeat, seat))
                }
            } else {
                consumed.insert(seat.memberID)
                out.append(.single(seat))
            }
        }
        return out
    }

    private func displayClusters(for group: SeriesRoundPlannedTeeGroup) -> [TeeGroupDisplayCluster] {
        let raw = seatClusters(for: group)
        var pairSortInfo: [(clusterID: String, sortKey: String)] = []
        for cluster in raw {
            if case .pair(let top, let bottom) = cluster {
                let n1 = memberName(for: top.memberID)
                let n2 = memberName(for: bottom.memberID)
                let sortKey = [n1, n2].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.first ?? n1
                pairSortInfo.append((cluster.id, sortKey))
            }
        }
        pairSortInfo.sort { lhs, rhs in
            let nameOrder = lhs.sortKey.localizedCaseInsensitiveCompare(rhs.sortKey)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.clusterID < rhs.clusterID
        }
        var titleByPairID: [String: String] = [:]
        for (index, item) in pairSortInfo.enumerated() {
            let letter = Self.pairLetter(at: index)
            titleByPairID[item.clusterID] = "Pair \(letter)"
        }
        return raw.map { cluster -> TeeGroupDisplayCluster in
            switch cluster {
            case .single(let seat):
                return .single(seat)
            case .pair(let top, let bottom):
                let title = titleByPairID[cluster.id] ?? "Pair A"
                return .pair(top: top, bottom: bottom, title: title)
            }
        }
    }

    private static func pairLetter(at index: Int) -> String {
        guard index >= 0, index < 26 else { return "?" }
        let scalar = UnicodeScalar(65 + index)!
        return String(scalar)
    }

    @ViewBuilder
    private func singleSeatRow(seat: SeriesRoundPlannedSeat, group: SeriesRoundPlannedTeeGroup) -> some View {
        seatRowContent(seat: seat, group: group, showPartnerSubtext: true, isPartnerCluster: false)
    }

    @ViewBuilder
    private func partnerPairRows(
        top: SeriesRoundPlannedSeat,
        bottom: SeriesRoundPlannedSeat,
        group: SeriesRoundPlannedTeeGroup,
        pairTitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.accentGreen.opacity(0.55))
                .frame(width: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(pairTitle)
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                VStack(spacing: 0) {
                    seatRowContent(seat: top, group: group, showPartnerSubtext: false, isPartnerCluster: true)
                    Divider()
                        .padding(.vertical, 2)
                    seatRowContent(seat: bottom, group: group, showPartnerSubtext: false, isPartnerCluster: true)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(palette.cardEmbeddedRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pairTitle) \(memberName(for: top.memberID)) and \(memberName(for: bottom.memberID))")
    }

    @ViewBuilder
    private func seatRowContent(
        seat: SeriesRoundPlannedSeat,
        group: SeriesRoundPlannedTeeGroup,
        showPartnerSubtext: Bool,
        isPartnerCluster: Bool
    ) -> some View {
        let ordered = group.seats.sorted { $0.teeOrder < $1.teeOrder }
        let idx = ordered.firstIndex(where: { $0.id == seat.id }) ?? 0
        let canMoveUp = idx > 0
        let canMoveDown = idx < ordered.count - 1

        HStack(alignment: .top, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                teeOrderCircleBadge(teeOrder: seat.teeOrder)
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerDisplayName(for: seat.memberID))
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    if let teamName = playerTeamSubtitle(for: seat.memberID) {
                        HStack(spacing: 6) {
                            teamSwatch(for: seat.memberID)
                            Text(teamName)
                                .fontStyle(kFontName, size: 11, weight: .regular)
                                .foregroundStyle(Color.neutral)
                        }
                    }
                    if let handicap = playerHandicapText(for: seat.memberID) {
                        Text(handicap)
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    if showPartnerSubtext {
                        Text(partnerSummary(for: seat.memberID, in: group))
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }
            }

            Spacer(minLength: 0)

            seatActionMenu(seat: seat, group: group, canMoveUp: canMoveUp, canMoveDown: canMoveDown)
        }
        .padding(.vertical, 10)
        .padding(.leading, isPartnerCluster ? 0 : 12)
        .padding(.trailing, isPartnerCluster ? 4 : 5)
        .background(isPartnerCluster ? Color.clear : palette.cardEmbeddedRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func teamSwatch(for memberID: String) -> some View {
        if let teamID = membersByID[memberID]?.teamID,
           let color = teamsByID[teamID]?.displaySwatchColor {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func seatActionMenu(
        seat: SeriesRoundPlannedSeat,
        group: SeriesRoundPlannedTeeGroup,
        canMoveUp: Bool,
        canMoveDown: Bool
    ) -> some View {
        Menu {
            Section("Position") {
                Button("Move up") {
                    moveSeat(seat, in: group.id, direction: -1)
                }
                .disabled(!canMoveUp)
                Button("Move down") {
                    moveSeat(seat, in: group.id, direction: 1)
                }
                .disabled(!canMoveDown)
            }
            Section("Move to group") {
                ForEach(sortedGroups.filter { $0.id != group.id }) { target in
                    Button("Group \(target.index + 1)") {
                        moveSeat(seat, from: group.id, to: target.id)
                    }
                }
            }
            Section("Partner") {
                Button("No partner") {
                    clearPartner(for: seat.memberID)
                }
                ForEach(pairablePartners(for: seat.memberID, in: group), id: \.id) { partner in
                    Button {
                        setPartner(for: seat.memberID, partnerID: partner.id)
                    } label: {
                        playerMenuLabel(for: partner.id)
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.neutral.opacity(0.22))
                    .frame(width: 23, height: 23)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.foregroundColor.opacity(0.9))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func teeOrderCircleBadge(teeOrder: Int) -> some View {
        Group {
            if (1...50).contains(teeOrder) {
                Image(systemName: "\(teeOrder).circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.neutral)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.neutral.opacity(0.55), lineWidth: 1)
                    Text("\(teeOrder)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.neutral)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(width: 22, height: 22)
            }
        }
        .accessibilityLabel("Tee position \(teeOrder)")
    }

    private func memberName(for memberID: String) -> String {
        formattedPlayerLabel(for: memberID)
    }

    private func playerDisplayName(for memberID: String) -> String {
        let name = membersByID[memberID]?.name.trimmedFullName
        if let name, name.isPopulated {
            return name
        }
        return "Unknown player"
    }

    private func playerTeamSubtitle(for memberID: String) -> String? {
        guard let teamName = teamName(for: memberID), teamName.isPopulated else { return nil }
        return teamName
    }

    private func playerHandicapText(for memberID: String) -> String? {
        handicapText(for: memberID)
    }

    private func teamName(for memberID: String) -> String? {
        guard let teamID = membersByID[memberID]?.teamID else { return nil }
        return teamsByID[teamID]?.name
    }

    private func formattedPlayerLabel(for memberID: String) -> String {
        let name = membersByID[memberID]?.name.trimmedFullName
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
            return "Unknown player"
        }
    }

    @ViewBuilder
    private func playerMenuLabel(for memberID: String) -> some View {
        let subtitle = playerInlineMetadata(for: memberID)
        VStack(alignment: .leading, spacing: 2) {
            Text(playerDisplayName(for: memberID))
                .fontStyle(kFontName, size: 13, weight: .semibold)
            if subtitle.isPopulated {
                Text(subtitle)
                    .fontStyle(kFontName, size: 11, weight: .regular)
            }
        }
    }

    private func playerInlineMetadata(for memberID: String) -> String {
        var components: [String] = []
        if let teamName = teamName(for: memberID), teamName.isPopulated {
            components.append(teamName)
        }
        if let handicap = handicapText(for: memberID) {
            components.append(handicap)
        }
        return components.joined(separator: " • ")
    }

    private func handicapText(for memberID: String) -> String? {
        guard handicapsEnabled, let text = effectiveHandicapText(memberID), text.isPopulated else { return nil }
        return "HCP \(text)"
    }

    private func matchupLabel(for matchup: SeriesRoundPlannedMatchup) -> String {
        let plan = matchup.matchupPlan
        if plan.validTeamPairing {
            return "\(teamsByID[plan.teamAID]?.name ?? "Team A") vs \(teamsByID[plan.teamBID]?.name ?? "Team B")"
        }
        if let pairAID = plan.pairAID,
           let pairBID = plan.pairBID {
            return "\(pairName(for: pairAID)) vs \(pairName(for: pairBID))"
        }
        if let memberAID = plan.memberAID,
           let memberBID = plan.memberBID {
            return "\(memberName(for: memberAID)) vs \(memberName(for: memberBID))"
        }
        return "Incomplete matchup"
    }

    private func pairName(for pairID: String) -> String {
        if let plan = partnershipPlans.first(where: { $0.id == pairID }) {
            return plan.memberIDs.compactMap { membersByID[$0]?.name.fullName }.joined(separator: " + ")
        }
        return "Pair"
    }

    @ViewBuilder
    private func sourceChip(_ source: SeriesRoundPlanSource) -> some View {
        Chip(
            text: source == .manualOverride ? "Manual" : "Auto",
            size: .xSmall,
            foreground: source == .manualOverride ? Color.accentGreen : Color.neutral,
            background: source == .manualOverride
                ? Color.accentGreen.opacity(palette.scheme.translucent)
                : palette.cardEmbeddedRowBackground
        )
    }

    private func menuActionLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .semibold)
            Text(subtitle)
                .fontStyle(kFontName, size: 11, weight: .regular)
        }
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

    private func partnerPlan(for memberID: String) -> SeriesRoundPartnershipPlan? {
        partnershipPlans.first { $0.memberIDs.contains(memberID) }
    }

    private func partnerSummary(for memberID: String, in group: SeriesRoundPlannedTeeGroup) -> String {
        if let partnerID = partnerPlan(for: memberID)?.memberIDs.first(where: { $0 != memberID }) {
            return "Partner: \(memberName(for: partnerID))"
        }
        let options = pairablePartners(for: memberID, in: group)
        return options.isEmpty ? "No eligible partner in this group" : "No partner selected"
    }

    private func pairablePartners(for memberID: String, in group: SeriesRoundPlannedTeeGroup) -> [SeriesMember] {
        guard let teamID = membersByID[memberID]?.teamID, teamID.isPopulated else { return [] }
        let currentPartnerID = partnerPlan(for: memberID)?.memberIDs.first(where: { $0 != memberID })
        return group.seats.compactMap { seat -> SeriesMember? in
            guard seat.memberID != memberID,
                  let member = membersByID[seat.memberID],
                  member.teamID == teamID else {
                return nil
            }
            if let partnerPlan = partnerPlan(for: seat.memberID),
               !partnerPlan.memberIDs.contains(memberID),
               seat.memberID != currentPartnerID {
                return nil
            }
            return member
        }
        .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
    }

    private func updateGroup(_ id: String, mutate: (inout SeriesRoundPlannedTeeGroup) -> Void) {
        guard let index = plannedTeeGroups.firstIndex(where: { $0.id == id }) else { return }
        var updated = plannedTeeGroups[index]
        mutate(&updated)
        plannedTeeGroups[index] = normalized(updated)
        pruneInvalidPartnerships()
    }

    private func normalized(_ group: SeriesRoundPlannedTeeGroup) -> SeriesRoundPlannedTeeGroup {
        group.renumberedPreservingSeatOrder()
    }

    private func moveSeat(_ seat: SeriesRoundPlannedSeat, in groupID: String, direction: Int) {
        updateGroup(groupID) { group in
            guard let index = group.seats.firstIndex(where: { $0.id == seat.id }) else { return }
            let destination = index + direction
            guard destination >= 0, destination < group.seats.count else { return }
            group.seats.swapAt(index, destination)
            group.source = .manualOverride
            group.seats = group.seats.map {
                var next = $0
                next.source = .manualOverride
                return next
            }
        }
    }

    private func moveSeat(_ seat: SeriesRoundPlannedSeat, from sourceGroupID: String, to targetGroupID: String) {
        guard sourceGroupID != targetGroupID,
              let sourceIndex = plannedTeeGroups.firstIndex(where: { $0.id == sourceGroupID }),
              let targetIndex = plannedTeeGroups.firstIndex(where: { $0.id == targetGroupID }),
              let seatIndex = plannedTeeGroups[sourceIndex].seats.firstIndex(where: { $0.id == seat.id }) else { return }

        var sourceGroup = plannedTeeGroups[sourceIndex]
        var targetGroup = plannedTeeGroups[targetIndex]
        var movedSeat = sourceGroup.seats.remove(at: seatIndex)
        movedSeat.source = .manualOverride
        sourceGroup.source = .manualOverride
        targetGroup.source = .manualOverride
        targetGroup.seats.append(movedSeat)
        plannedTeeGroups[sourceIndex] = normalized(sourceGroup)
        plannedTeeGroups[targetIndex] = normalized(targetGroup)
        pruneInvalidPartnerships()
    }

    private func addMember(_ memberID: String, to groupID: String) {
        updateGroup(groupID) { group in
            guard !group.seats.contains(where: { $0.memberID == memberID }) else { return }
            group.source = .manualOverride
            group.seats.append(
                SeriesRoundPlannedSeat(
                    id: HackersID.string(),
                    memberID: memberID,
                    teeOrder: group.seats.count + 1,
                    source: .manualOverride
                )
            )
        }
    }

    private func addGroup() {
        let nextIndex = plannedTeeGroups.count
        plannedTeeGroups.append(
            SeriesRoundPlannedTeeGroup(
                id: HackersID.string(),
                index: nextIndex,
                teeTime: nil,
                startingHole: TeeTimeGroup.sequentialStartingHole(
                    forSequenceIndex: nextIndex,
                    in: holeRange
                ),
                seats: [],
                source: .manualOverride
            )
        )
    }

    private func removeGroup(id: String) {
        guard let idx = plannedTeeGroups.firstIndex(where: { $0.id == id }) else { return }
        plannedTeeGroups.remove(at: idx)
        for i in plannedTeeGroups.indices {
            plannedTeeGroups[i].index = i
        }
        pruneInvalidPartnerships()
    }

    private func moveGroup(id: String, toSortedSlot target: Int) {
        var ordered = plannedTeeGroups.sorted { $0.index < $1.index }
        guard let from = ordered.firstIndex(where: { $0.id == id }),
              target >= 0, target < ordered.count,
              from != target else { return }
        let moved = ordered.remove(at: from)
        ordered.insert(moved, at: target)
        for i in ordered.indices {
            ordered[i].index = i
            ordered[i].source = .manualOverride
        }
        plannedTeeGroups = ordered
        pruneInvalidPartnerships()
    }

    private func setPartner(for memberID: String, partnerID: String) {
        guard memberID != partnerID,
              let teamID = membersByID[memberID]?.teamID,
              teamID.isPopulated,
              membersByID[partnerID]?.teamID == teamID else {
            return
        }

        partnershipPlans.removeAll { plan in
            plan.memberIDs.contains(memberID) || plan.memberIDs.contains(partnerID)
        }
        partnershipPlans.append(
            SeriesRoundPartnershipPlan(
                id: HackersID.string(),
                teamID: teamID,
                memberIDs: [memberID, partnerID],
                createdAt: .init(),
                lastUpdatedAt: .init()
            )
        )
        pruneInvalidPartnerships()
    }

    private func clearPartner(for memberID: String) {
        partnershipPlans.removeAll { $0.memberIDs.contains(memberID) }
    }

    private func pruneInvalidPartnerships() {
        let teamIDByMemberID = Dictionary(uniqueKeysWithValues: membersByID.compactMap { entry -> (String, String)? in
            let (memberID, member) = entry
            guard let teamID = member.teamID, teamID.isPopulated else { return nil }
            return (memberID, teamID)
        })
        var usedMemberIDs: Set<String> = []

        partnershipPlans = partnershipPlans.compactMap { plan in
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
            updated.teamID = teamID
            updated.memberIDs = memberIDs
            updated.lastUpdatedAt = .init()
            return updated
        }
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
    private var handicapMode: SeriesHandicapMode { viewModel.series.handicapConfig.mode }
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
            HStack(spacing: 8) {
                Text("SERIES HANDICAPS")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Chip(
                    text: handicapMode.isEnabled ? "ON" : "OFF",
                    size: .xSmall,
                    foreground: handicapMode.isEnabled ? Color.accentGreen : Color.neutral,
                    background: handicapMode.isEnabled
                        ? Color.accentGreen.opacity(palette.scheme.translucent)
                        : palette.cardEmbeddedRowBackground
                )
            }

            if handicapMode == .dynamic {
                Toggle(
                    isOn: Binding(
                        get: { formatSupportsAccrual && countsTowardHandicapPool },
                        set: { countsTowardHandicapPool = $0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Counts toward handicap updates")
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
            } else {
                Text(staticModeSummary)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if handicapMode == .dynamic, formatSupportsAccrual, countsTowardHandicapPool {
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
                            Text("Add players before customizing handicap participation.")
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else if handicapMode == .dynamic, formatSupportsAccrual {
                Text("This round will not feed the handicap pool.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            } else if handicapMode == .dynamic {
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
            return "By default every included player in this round contributes a score to the handicap pool."
        }
        return "Unavailable for this format."
    }

    private var staticModeSummary: String {
        switch handicapMode {
        case .off:
            return "Series handicaps are off. This round won't feed or use the shared handicap pool until handicaps are enabled in settings."
        case .fixed:
            return "Series handicaps are fixed for scoring. This round can still use handicap-based scoring, but its results will not change the shared handicap pool."
        case .dynamic:
            return ""
        }
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
            Text("Choose which players in this round should feed the handicap pool. Team actions below are just shortcuts that toggle those members for you.")
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
