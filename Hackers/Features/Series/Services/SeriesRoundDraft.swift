//
//  SeriesRoundDraft.swift
//  Hackers
//

import Foundation

enum SeriesRoundMatchupSource: String, CaseIterable, Hashable, Sendable {
    case byTeam = "by_team"
    case byPair = "by_pair"
    case byIndividual = "by_individual"

    var title: String {
        switch self {
        case .byTeam: return "By team"
        case .byPair: return "By pair"
        case .byIndividual: return "By individual"
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

    func matchupMode(scope: CompetitionScope, usesTeams: Bool) -> SeriesMatchupMode {
        guard scope == .matchup else { return .field }
        guard usesTeams else { return .individualVsIndividual }
        switch self {
        case .byTeam: return .teamVsTeam
        case .byPair: return .teeGroupPartnerships
        case .byIndividual: return .individualVsIndividual
        }
    }
}

enum SeriesRoundDraftValidationError: Error, Equatable, LocalizedError {
    case invalidSharedScoreAllowance(String)
    case invalidTeamScoringCount

    var errorDescription: String? {
        switch self {
        case .invalidSharedScoreAllowance(let value):
            return "\"\(value)\" is not a valid handicap allowance. Enter comma-separated percentages from 0 to 100."
        case .invalidTeamScoringCount:
            return "Team scoring must count at least one score."
        }
    }
}

struct SeriesRoundDraftPersistenceValues: Equatable {
    let title: String
    let scheduledAt: Time?
    let courseOverride: SeriesCourseSelection?
    let roundConfig: SeriesRoundConfiguration
    let teamScoringProfileID: String?
    let individualScoringProfileID: String?
    let matchupPlans: [SeriesRoundMatchupPlan]
    let plannedMatchups: [SeriesRoundPlannedMatchup]
    let plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    let partnershipPlans: [SeriesRoundPartnershipPlan]
    let notes: String?
}

struct SeriesRoundDraft: Equatable {
    var title: String
    var scheduledDate: Date
    var hasDate: Bool
    var selectedTemplateID: String
    var competitionScope: CompetitionScope
    var scoreOwnerScope: RoundScoreOwnerScope
    var matchupScoringStyle: RoundMatchupScoringStyle
    var holeWinPoints: Double
    var matchWinnerBonusPoints: Double
    var maxScoreOverPar: MaxScoreOverPar
    var teamScoring: RoundTeamScoringConfiguration
    var selectionDomain: ScoringSelectionDomain?
    var sequentialTeeStartsEnabled: Bool
    var podGroupingStrategy: SeriesPodGroupingStrategy
    var matchupSource: SeriesRoundMatchupSource
    var selectedTeamProfileID: String?
    var selectedIndividualProfileID: String?
    var handicapEntryFormat: HandicapEntryFormat
    var handicapNormalizationMode: HandicapNormalizationMode
    var handicapStrokeBasis: SeriesHandicapStrokeBasis?
    var countsTowardHandicapPool: Bool
    var excludedHandicapMemberIDs: [String]
    var notes: String
    var matchupPlans: [SeriesRoundMatchupPlan]
    var plannedMatchups: [SeriesRoundPlannedMatchup]
    var plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    var partnershipPlans: [SeriesRoundPartnershipPlan]

    private var displayedCourse: SeriesCourseSelection?
    private var originalCourseOverride: SeriesCourseSelection?
    private var courseSelectionWasEdited: Bool
    private var displayedSharedScoreAllowanceText: String
    private var originalSharedScoreHandicapConfig: HandicapConfiguration?
    private var sharedScoreAllowanceWasEdited: Bool
    private var sourceConfiguration: SeriesRoundConfiguration

    var selectedCourse: SeriesCourseSelection? {
        get { displayedCourse }
        set {
            displayedCourse = newValue
            courseSelectionWasEdited = true
        }
    }

    var sharedScoreAllowanceText: String {
        get { displayedSharedScoreAllowanceText }
        set {
            displayedSharedScoreAllowanceText = newValue
            sharedScoreAllowanceWasEdited = true
        }
    }

    init(
        settings: SeriesSettings,
        suggestedCourse: SeriesCourseSelection?,
        usesTeams: Bool,
        scheduledDate: Date = Date()
    ) {
        let config = settings.defaultRoundConfig
        let scope = config.resolvedCompetitionScope
        title = ""
        self.scheduledDate = scheduledDate
        hasDate = false
        selectedTemplateID = config.formatTemplateID
        competitionScope = scope
        scoreOwnerScope = config.scoreOwnerScope
        matchupScoringStyle = config.matchupScoringStyle
        holeWinPoints = config.resolvedHoleWinPoints
        matchWinnerBonusPoints = config.resolvedMatchWinnerBonusPoints
        displayedSharedScoreAllowanceText = Self.allowanceText(
            from: config.sharedScoreHandicapConfig
                ?? FormatTemplateRegistry.template(for: config.formatTemplateID).requirements.defaultHandicapConfig
        )
        maxScoreOverPar = config.maxScoreOverPar ?? .quad
        teamScoring = config.teamScoring
        selectionDomain = config.selectionDomain
        sequentialTeeStartsEnabled = config.sequentialTeeStartsEnabled ?? false
        podGroupingStrategy = config.podGroupingStrategy
        matchupSource = SeriesRoundMatchupSource(mode: config.matchupMode, usesTeams: usesTeams)
        selectedTeamProfileID = settings.defaultTeamScoringProfileID
        selectedIndividualProfileID = settings.defaultIndividualScoringProfileID
        handicapEntryFormat = settings.handicapConfig.entryFormat
        handicapNormalizationMode = Self.normalizedHandicapMode(settings.handicapConfig.normalizationMode, scope: scope)
        handicapStrokeBasis = nil
        countsTowardHandicapPool = config.countsTowardHandicapPool
        excludedHandicapMemberIDs = config.normalizedExcludedHandicapMemberIDs
        notes = config.notes ?? ""
        matchupPlans = []
        plannedMatchups = []
        plannedTeeGroups = []
        partnershipPlans = []
        displayedCourse = suggestedCourse
        originalCourseOverride = nil
        courseSelectionWasEdited = true
        originalSharedScoreHandicapConfig = config.sharedScoreHandicapConfig
        sharedScoreAllowanceWasEdited = false
        sourceConfiguration = config
    }

    init(
        seriesRound: SeriesRound,
        fallbackCourse: SeriesCourseSelection?,
        usesTeams: Bool
    ) {
        let config = seriesRound.roundConfig
        let scope = config.resolvedCompetitionScope
        title = seriesRound.title
        scheduledDate = seriesRound.scheduledAt.map { Date(timeIntervalSince1970: $0.unix) } ?? Date()
        hasDate = seriesRound.scheduledAt != nil
        selectedTemplateID = config.formatTemplateID
        competitionScope = scope
        scoreOwnerScope = config.scoreOwnerScope
        matchupScoringStyle = config.matchupScoringStyle
        holeWinPoints = config.resolvedHoleWinPoints
        matchWinnerBonusPoints = config.resolvedMatchWinnerBonusPoints
        displayedSharedScoreAllowanceText = Self.allowanceText(
            from: config.sharedScoreHandicapConfig
                ?? FormatTemplateRegistry.template(for: config.formatTemplateID).requirements.defaultHandicapConfig
        )
        maxScoreOverPar = config.maxScoreOverPar ?? .quad
        teamScoring = config.teamScoring
        selectionDomain = config.selectionDomain
        sequentialTeeStartsEnabled = config.sequentialTeeStartsEnabled ?? false
        podGroupingStrategy = config.podGroupingStrategy
        matchupSource = SeriesRoundMatchupSource(mode: config.matchupMode, usesTeams: usesTeams)
        selectedTeamProfileID = seriesRound.teamScoringProfileID
        selectedIndividualProfileID = seriesRound.individualScoringProfileID
        handicapEntryFormat = config.handicapEntryFormat
        handicapNormalizationMode = Self.normalizedHandicapMode(config.handicapNormalizationMode, scope: scope)
        handicapStrokeBasis = config.handicapStrokeBasis
        countsTowardHandicapPool = config.countsTowardHandicapPool
        excludedHandicapMemberIDs = config.normalizedExcludedHandicapMemberIDs
        notes = seriesRound.notes ?? config.notes ?? ""
        matchupPlans = scope == .matchup ? seriesRound.matchupPlans.sorted { $0.index < $1.index } : []
        plannedMatchups = seriesRound.plannedMatchups
        plannedTeeGroups = seriesRound.plannedTeeGroups
        partnershipPlans = seriesRound.partnershipPlans
        displayedCourse = seriesRound.courseOverride ?? fallbackCourse
        originalCourseOverride = seriesRound.courseOverride
        courseSelectionWasEdited = false
        originalSharedScoreHandicapConfig = config.sharedScoreHandicapConfig
        sharedScoreAllowanceWasEdited = false
        sourceConfiguration = config
    }

    var scheduledAt: Time? {
        hasDate ? Time(for: scheduledDate) : nil
    }

    func persistedValues(
        usesTeams: Bool,
        courseHandicapAvailable: Bool,
        fallbackTitle: String
    ) throws -> SeriesRoundDraftPersistenceValues {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return SeriesRoundDraftPersistenceValues(
            title: trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle,
            scheduledAt: scheduledAt,
            courseOverride: courseSelectionWasEdited ? displayedCourse : originalCourseOverride,
            roundConfig: try persistedConfiguration(
                usesTeams: usesTeams,
                courseHandicapAvailable: courseHandicapAvailable,
                notes: trimmedNotes
            ),
            teamScoringProfileID: selectedTeamProfileID,
            individualScoringProfileID: selectedIndividualProfileID,
            matchupPlans: matchupPlans.sorted { $0.index < $1.index },
            plannedMatchups: plannedMatchups,
            plannedTeeGroups: plannedTeeGroups,
            partnershipPlans: partnershipPlans,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
    }

    func persistedConfiguration(
        usesTeams: Bool,
        courseHandicapAvailable: Bool,
        notes: String? = nil
    ) throws -> SeriesRoundConfiguration {
        if teamScoring.mode != .all, teamScoring.count < 1 {
            throw SeriesRoundDraftValidationError.invalidTeamScoringCount
        }

        var config = sourceConfiguration
        let template = FormatTemplateRegistry.template(for: selectedTemplateID)
        config.formatTemplateID = selectedTemplateID
        config.competitionScope = competitionScope
        config.teamScoring = teamScoring
        config.scoreOwnerScope = template.scoreSource == .shared ? scoreOwnerScope : .individual
        config.matchupScoringStyle = matchupScoringStyle
        config.holeWinPoints = competitionScope == .matchup ? holeWinPoints : nil
        config.matchWinnerBonusPoints = competitionScope == .matchup ? matchWinnerBonusPoints : nil
        config.sequentialTeeStartsEnabled = sequentialTeeStartsEnabled
        config.selectionDomain = selectionDomain
        config.matchupMode = matchupSource.matchupMode(scope: competitionScope, usesTeams: usesTeams)
        config.podGroupingStrategy = podGroupingStrategy
        config.teamAssignmentMode = usesTeams ? .seriesTeams : .manual
        config.teeGroupMode = podGroupingStrategy.usesPodAlignment ? .podAligned : .auto
        config.notes = notes?.isEmpty == false ? notes : nil
        config.sharedScoreHandicapConfig = sharedScoreAllowanceWasEdited
            ? try sharedScoreAllowanceConfiguration()
            : originalSharedScoreHandicapConfig
        config.maxScoreOverPar = maxScoreOverPar
        config.handicapStrokeBasis = handicapStrokeBasis
        config.handicapEntryFormat = courseHandicapAvailable ? handicapEntryFormat : .strokes
        config.handicapNormalizationMode = Self.normalizedHandicapMode(
            handicapNormalizationMode,
            scope: competitionScope
        )
        config.countsTowardHandicapPool = countsTowardHandicapPool
        config.excludedHandicapMemberIDs = Array(Set(excludedHandicapMemberIDs.filter(\.isPopulated))).sorted()
        return config
    }

    mutating func adoptPersistedValues(_ values: SeriesRoundDraftPersistenceValues) {
        title = values.title
        sourceConfiguration = values.roundConfig
        originalCourseOverride = values.courseOverride
        displayedCourse = values.courseOverride
        courseSelectionWasEdited = false
        originalSharedScoreHandicapConfig = values.roundConfig.sharedScoreHandicapConfig
        displayedSharedScoreAllowanceText = Self.allowanceText(
            from: values.roundConfig.sharedScoreHandicapConfig
                ?? FormatTemplateRegistry.template(for: values.roundConfig.formatTemplateID).requirements.defaultHandicapConfig
        )
        sharedScoreAllowanceWasEdited = false
        excludedHandicapMemberIDs = values.roundConfig.normalizedExcludedHandicapMemberIDs
    }

    private func sharedScoreAllowanceConfiguration() throws -> HandicapConfiguration? {
        let pieces = sharedScoreAllowanceText.split(separator: ",", omittingEmptySubsequences: false)
        if pieces.count == 1, pieces[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }

        let percentages = try pieces.map { raw -> Double in
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Double(token), value >= 0, value <= 100 else {
                throw SeriesRoundDraftValidationError.invalidSharedScoreAllowance(token)
            }
            return value > 1 ? value / 100 : value
        }
        return HandicapConfiguration(
            percentage: 1,
            isTeamCombined: true,
            positionPercentages: percentages
        )
    }

    static func allowanceText(from config: HandicapConfiguration) -> String {
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

    static func normalizedHandicapMode(
        _ mode: HandicapNormalizationMode,
        scope: CompetitionScope
    ) -> HandicapNormalizationMode {
        guard mode != .off else { return .off }
        return scope == .matchup ? .matchup : .field
    }
}
