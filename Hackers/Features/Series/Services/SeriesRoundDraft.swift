//
//  SeriesRoundDraft.swift
//  Hackers
//

import Foundation
import Combine

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
    case unavailableCourseHandicap
    case courseValidation(String)

    var errorDescription: String? {
        switch self {
        case .invalidSharedScoreAllowance(let value):
            return "\"\(value)\" is not a valid handicap allowance. Enter comma-separated percentages from 0 to 100."
        case .invalidTeamScoringCount:
            return "Team scoring must count at least one score."
        case .unavailableCourseHandicap:
            return "Verify the selected course, tee, and hole segment before saving Handicap Index scoring. Retry the course check or select the tee again."
        case .courseValidation(let message): return message
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
        courseValidation: SeriesCourseHandicapValidation,
        fallbackTitle: String
    ) throws -> SeriesRoundDraftPersistenceValues {
        if handicapEntryFormat == .courseHandicap {
            guard courseValidation.selection == displayedCourse,
                  courseValidation.permitsConfiguration,
                  let selection = courseValidation.selection,
                  let segment = courseValidation.courseSegment,
                  SeriesRoundCourseHandicapAvailability.evaluate(selection, segment: segment).permitsConfiguration else {
                throw SeriesRoundDraftValidationError.courseValidation(courseValidation.message)
            }
        }
        return try persistedValues(usesTeams: usesTeams,
            courseHandicapAvailable: courseValidation.permitsConfiguration, fallbackTitle: fallbackTitle)
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
        if handicapEntryFormat == .courseHandicap, !courseHandicapAvailable {
            throw SeriesRoundDraftValidationError.unavailableCourseHandicap
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
        config.handicapEntryFormat = handicapEntryFormat
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


/// One course/tee/segment snapshot for setup presentation and validation. Course
/// metadata is checked through the same calculator used by the live round.
struct SeriesCourseHandicapValidation: Equatable {
    enum Status: Equatable {
        case checking, ready, loadFailed, teeUnavailable, missingData, estimated, noCourse
    }

    let selection: SeriesCourseSelection?
    var status: Status
    var courseSegment: CourseSegment?
    var calculation: CourseHandicapCalculation?

    var permitsConfiguration: Bool { status == .ready || status == .estimated }

    var message: String {
        let tee = selection?.defaultTeeName ?? "selected"
        let segment = selection?.holeSegment.title ?? "selected holes"
        switch status {
        case .checking: return "Checking course data…"
        case .ready: return "\(tee) tees · \(segment)"
        case .loadFailed: return "Could not load course data for \(selection?.cachedName ?? "this course"). Retry or select the course again."
        case .teeUnavailable: return "Unable to verify \(tee) tees. Select the tee again; its saved identity is unavailable or has changed."
        case .missingData:
            let fields = calculation?.missingFields.map {
                switch $0 {
                case "course rating": return "Course Rating"
                case "slope rating": return "Slope"
                case "par": return "hole pars"
                default: return $0
                }
            }.joined(separator: ", ") ?? "course data"
            return "Unable to verify \(tee) tees — \(segment): \(fields). Retry or select another tee."
        case .estimated: return "\(tee) tees · \(segment): estimated rating or slope. Estimates require approval before use; series handicaps require exact segment data."
        case .noCourse: return "Select a course and tee to verify Handicap Index scoring."
        }
    }

    var detail: String? {
        guard let calculation else { return nil }
        return [calculation.rating.map { "Rating \(String(format: "%.1f", $0))" },
                calculation.slope.map { "Slope \($0)" }, calculation.par.map { "Par \($0)" }]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

enum SeriesRoundCourseHandicapAvailability {
    typealias Loader = @MainActor (SeriesCourseSelection) async throws -> Course

    /// Preserve the actual library document, including custom/OCR course data.
    /// A provider reference is provenance, not a replacement document identity.
    static func selection(from segment: CourseSegment) -> SeriesCourseSelection {
        let tee = segment.defaultTee.flatMap { segment.tee(from: $0) }
        return SeriesCourseSelection(courseID: segment.courseInfo.seriesCourseSelectionID,
            cachedName: segment.courseInfo.name, defaultTeeBoxID: segment.defaultTee ?? "",
            defaultTeeName: tee?.name, defaultTeeGender: tee?.gender, holeSegment: segment.holeSegment)
    }

    @MainActor
    static func loadCourse(for selection: SeriesCourseSelection) async throws -> Course {
        // Read the selected document before considering the provider. In particular,
        // do not canonicalize a UUID tee into another cached course's tee IDs.
        if let course = try await FirebaseService.shared.getLibraryCourse(id: selection.courseID) { return course }
        if let apiID = GolfCourseID(selection.courseID) {
            return try await GolfCourseRepository.shared.course(by: apiID)
        }
        throw SeriesCourseDataError.courseUnavailable
    }

    enum SeriesCourseDataError: Error { case courseUnavailable }

    static func evaluate(_ selection: SeriesCourseSelection, course: Course) -> SeriesCourseHandicapValidation {
        guard course.id == selection.courseID else {
            return .init(selection: selection, status: .loadFailed)
        }
        // Never choose the first tee or match by name after a stale ID. The user
        // must explicitly review a changed identity, even if its ratings look valid.
        guard let tee = course.tees.first(where: { $0.id == selection.defaultTeeBoxID }),
              selection.defaultTeeName.map({ $0.caseInsensitiveCompare(tee.name) == .orderedSame }) ?? true,
              selection.defaultTeeGender.map({ $0.caseInsensitiveCompare(tee.gender) == .orderedSame }) ?? true else {
            return .init(selection: selection, status: .teeUnavailable)
        }
        let segment = CourseSegment(courseInfo: CourseInfo(course: course, for: selection.holeSegment),
            holeRange: selection.holeSegment.holeRange, defaultTee: tee.id)
        return evaluate(selection, segment: segment)
    }

    static func evaluate(_ selection: SeriesCourseSelection, segment: CourseSegment) -> SeriesCourseHandicapValidation {
        guard selection.courseID == segment.courseInfo.seriesCourseSelectionID,
              selection.holeSegment == segment.holeSegment,
              selection.defaultTeeBoxID == segment.defaultTee,
              let tee = segment.tee(from: selection.defaultTeeBoxID),
              selection.defaultTeeName.map({ $0.caseInsensitiveCompare(tee.name) == .orderedSame }) ?? true,
              selection.defaultTeeGender.map({ $0.caseInsensitiveCompare(tee.gender) == .orderedSame }) ?? true else {
            return .init(selection: selection, status: .teeUnavailable)
        }
        let calculation = HandicapCalculator.calculation(index: 0,
            tee: segment.tee(from: selection.defaultTeeBoxID), segment: selection.holeSegment, indexBasis: .eighteenHole)
        let status: SeriesCourseHandicapValidation.Status = switch calculation.status {
        case .exact: .ready
        case .estimated: .estimated
        case .unavailable: .missingData
        }
        return .init(selection: selection, status: status, courseSegment: segment, calculation: calculation)
    }

    @MainActor
    static func check(_ selection: SeriesCourseSelection?, load: Loader = loadCourse) async -> SeriesCourseHandicapValidation {
        guard let selection, selection.courseID.isPopulated else { return .init(selection: selection, status: .noCourse) }
        do {
            let course = try await load(selection)
            try Task.checkCancellation()
            return evaluate(selection, course: course)
        } catch {
            return .init(selection: selection, status: .loadFailed)
        }
    }

    @MainActor
    static func isAvailable(for selection: SeriesCourseSelection?) async -> Bool {
        await check(selection).permitsConfiguration
    }
}

/// A response can publish only for its request and selection. This also protects
/// against a loader that doesn't cooperate with Swift task cancellation.
@MainActor
final class SeriesCourseHandicapValidationStore: ObservableObject {
    @Published private(set) var result = SeriesCourseHandicapValidation(selection: nil, status: .checking)
    private var requestID = UUID()
    private let load: SeriesRoundCourseHandicapAvailability.Loader

    init(load: @escaping SeriesRoundCourseHandicapAvailability.Loader = SeriesRoundCourseHandicapAvailability.loadCourse) {
        self.load = load
    }

    func refresh(_ selection: SeriesCourseSelection?) async {
        let request = UUID()
        requestID = request
        result = .init(selection: selection, status: .checking)
        let checked = await SeriesRoundCourseHandicapAvailability.check(selection, load: load)
        guard requestID == request, !Task.isCancelled else { return }
        result = checked
    }

    func current(for selection: SeriesCourseSelection?) -> SeriesCourseHandicapValidation {
        result.selection == selection ? result : .init(selection: selection, status: .checking)
    }

    func revalidate(_ selection: SeriesCourseSelection?) async -> SeriesCourseHandicapValidation {
        await refresh(selection)
        return current(for: selection)
    }
}
