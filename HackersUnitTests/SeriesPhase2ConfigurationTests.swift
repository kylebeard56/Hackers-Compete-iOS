//
//  SeriesPhase2ConfigurationTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesPhase2ConfigurationTests: XCTestCase {
    private struct DraftFieldCase {
        let name: String
        let mutate: (inout SeriesRoundDraft) -> Void
        let persisted: (SeriesRoundConfiguration) -> Bool
    }

    func testEveryExposedConfigurationFieldSurvivesDraftPersistReloadEditCycle() throws {
        let cases: [DraftFieldCase] = [
            .init(name: "format", mutate: { $0.selectedTemplateID = FormatTemplateRegistry.bestBall.id }, persisted: { $0.formatTemplateID == FormatTemplateRegistry.bestBall.id }),
            .init(name: "competition", mutate: { $0.competitionScope = .matchup }, persisted: { $0.competitionScope == .matchup }),
            .init(name: "score owner", mutate: {
                $0.selectedTemplateID = FormatTemplateRegistry.captainsChoice.id
                $0.scoreOwnerScope = .teeGroup
            }, persisted: { $0.scoreOwnerScope == .teeGroup }),
            .init(name: "match scoring", mutate: {
                $0.competitionScope = .matchup
                $0.matchupScoringStyle = .holeByHolePoints
            }, persisted: { $0.matchupScoringStyle == .holeByHolePoints }),
            .init(name: "hole points", mutate: {
                $0.competitionScope = .matchup
                $0.holeWinPoints = 2.5
            }, persisted: { $0.holeWinPoints == 2.5 }),
            .init(name: "winner bonus", mutate: {
                $0.competitionScope = .matchup
                $0.matchWinnerBonusPoints = 4
            }, persisted: { $0.matchWinnerBonusPoints == 4 }),
            .init(name: "allowance", mutate: { $0.sharedScoreAllowanceText = "35,15" }, persisted: {
                $0.sharedScoreHandicapConfig?.positionPercentages == [0.35, 0.15]
            }),
            .init(name: "max score", mutate: { $0.maxScoreOverPar = .double }, persisted: { $0.maxScoreOverPar == .double }),
            .init(name: "team scoring", mutate: {
                $0.teamScoring = .init(mode: .bestN, count: 2, scope: .perRound)
            }, persisted: { $0.teamScoring == .init(mode: .bestN, count: 2, scope: .perRound) }),
            .init(name: "selection domain", mutate: { $0.selectionDomain = .team }, persisted: { $0.selectionDomain == .team }),
            .init(name: "sequential starts", mutate: { $0.sequentialTeeStartsEnabled = true }, persisted: { $0.sequentialTeeStartsEnabled == true }),
            .init(name: "pod strategy", mutate: { $0.podGroupingStrategy = .swapPairs }, persisted: {
                $0.podGroupingStrategy == .swapPairs && $0.teeGroupMode == .podAligned
            }),
            .init(name: "matchup source", mutate: {
                $0.competitionScope = .matchup
                $0.matchupSource = .byIndividual
            }, persisted: { $0.matchupMode == .individualVsIndividual }),
            .init(name: "handicap entry", mutate: { $0.handicapEntryFormat = .courseHandicap }, persisted: { $0.handicapEntryFormat == .courseHandicap }),
            .init(name: "handicap normalization", mutate: { $0.handicapNormalizationMode = .field }, persisted: { $0.handicapNormalizationMode == .field }),
            .init(name: "handicap basis", mutate: { $0.handicapStrokeBasis = .nineHole }, persisted: { $0.handicapStrokeBasis == .nineHole }),
            .init(name: "handicap participation", mutate: { $0.countsTowardHandicapPool = false }, persisted: { !$0.countsTowardHandicapPool }),
            .init(name: "handicap exclusions", mutate: { $0.excludedHandicapMemberIDs = ["m2", "m1", "m2"] }, persisted: {
                $0.excludedHandicapMemberIDs == ["m1", "m2"]
            }),
        ]

        for fieldCase in cases {
            var draft = SeriesRoundDraft(settings: .init(useTeams: true), suggestedCourse: nil, usesTeams: true)
            fieldCase.mutate(&draft)
            let values = try draft.persistedValues(
                usesTeams: true,
                courseHandicapAvailable: true,
                fallbackTitle: "Week 1"
            )
            XCTAssertTrue(fieldCase.persisted(values.roundConfig), fieldCase.name)

            let persistedRound = SeriesRound(
                id: "week1",
                title: values.title,
                scheduledAt: values.scheduledAt,
                courseOverride: values.courseOverride,
                roundConfig: values.roundConfig,
                teamScoringProfileID: values.teamScoringProfileID,
                individualScoringProfileID: values.individualScoringProfileID,
                matchupPlans: values.matchupPlans,
                plannedMatchups: values.plannedMatchups,
                plannedTeeGroups: values.plannedTeeGroups,
                partnershipPlans: values.partnershipPlans,
                notes: values.notes,
                parentID: "series1"
            )
            let data = try JSONEncoder().encode(persistedRound)
            let reloadedRound = try JSONDecoder().decode(SeriesRound.self, from: data)
            let editDraft = SeriesRoundDraft(seriesRound: reloadedRound, fallbackCourse: nil, usesTeams: true)
            let reloadedValues = try editDraft.persistedValues(
                usesTeams: true,
                courseHandicapAvailable: true,
                fallbackTitle: "Week 1"
            )

            XCTAssertEqual(reloadedValues.roundConfig, values.roundConfig, fieldCase.name)
        }
    }

    func testEditDraftPreservesFieldsNotExposedByEditor() throws {
        var source = SeriesRoundConfiguration()
        source.matchTiePolicy = .carryover
        source.allowCourseOverride = false
        source.allowFormatOverride = false
        source.allowLobbyBackPropagation = false
        source.scoreBasisOverride = .net
        let round = SeriesRound(id: "week1", roundConfig: source, parentID: "series1")

        var draft = SeriesRoundDraft(seriesRound: round, fallbackCourse: nil, usesTeams: true)
        draft.title = "Renamed"
        let persisted = try draft.persistedValues(
            usesTeams: true,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 1"
        ).roundConfig

        XCTAssertEqual(persisted.matchTiePolicy, .carryover)
        XCTAssertFalse(persisted.allowCourseOverride)
        XCTAssertFalse(persisted.allowFormatOverride)
        XCTAssertFalse(persisted.allowLobbyBackPropagation)
        XCTAssertEqual(persisted.scoreBasisOverride, .net)
    }

    func testRoundPayloadSurvivesCreateReloadAndEditDraftCycle() throws {
        let scheduled = Date(timeIntervalSince1970: 1_800_000_000)
        let course = SeriesCourseSelection(
            courseID: "course1",
            cachedName: "Test Course",
            defaultTeeBoxID: "white",
            holeSegment: .back9
        )
        let matchup = SeriesRoundMatchupPlan(
            id: "match1",
            teamAID: "red",
            teamBID: "blue",
            index: 1,
            isLocked: true
        )
        let plannedMatchup = SeriesRoundPlannedMatchup(
            id: "match1",
            plan: matchup,
            source: .manualOverride
        )
        let teeGroup = SeriesRoundPlannedTeeGroup(
            id: "group1",
            index: 0,
            startingHole: 10,
            seats: [.init(memberID: "m1", teeOrder: 1, source: .manualOverride)],
            source: .manualOverride
        )
        let partnership = SeriesRoundPartnershipPlan(
            id: "pair1",
            teamID: "red",
            memberIDs: ["m1", "m2"],
            label: "Red Pair"
        )

        var draft = SeriesRoundDraft(settings: .init(useTeams: true), suggestedCourse: course, usesTeams: true)
        draft.title = "  Week 4  "
        draft.hasDate = true
        draft.scheduledDate = scheduled
        draft.competitionScope = .matchup
        draft.matchupSource = .byTeam
        draft.selectedTeamProfileID = "team-profile"
        draft.selectedIndividualProfileID = "individual-profile"
        draft.notes = "  Bring scorecards  "
        draft.matchupPlans = [matchup]
        draft.plannedMatchups = [plannedMatchup]
        draft.plannedTeeGroups = [teeGroup]
        draft.partnershipPlans = [partnership]

        let created = try draft.persistedValues(
            usesTeams: true,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 4"
        )
        let round = SeriesRound(
            id: "week4",
            title: created.title,
            scheduledAt: created.scheduledAt,
            courseOverride: created.courseOverride,
            roundConfig: created.roundConfig,
            teamScoringProfileID: created.teamScoringProfileID,
            individualScoringProfileID: created.individualScoringProfileID,
            matchupPlans: created.matchupPlans,
            plannedMatchups: created.plannedMatchups,
            plannedTeeGroups: created.plannedTeeGroups,
            partnershipPlans: created.partnershipPlans,
            notes: created.notes,
            parentID: "series1"
        )
        let reloaded = try JSONDecoder().decode(SeriesRound.self, from: JSONEncoder().encode(round))
        let edited = try SeriesRoundDraft(
            seriesRound: reloaded,
            fallbackCourse: nil,
            usesTeams: true
        ).persistedValues(
            usesTeams: true,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 4"
        )

        XCTAssertEqual(edited, created)
        XCTAssertEqual(edited.title, "Week 4")
        XCTAssertEqual(edited.courseOverride, course)
        XCTAssertEqual(edited.notes, "Bring scorecards")
    }

    func testClearingNotesProducesExplicitNilPersistenceValue() throws {
        let round = SeriesRound(id: "week1", notes: "Old note", parentID: "series1")
        var draft = SeriesRoundDraft(seriesRound: round, fallbackCourse: nil, usesTeams: false)
        draft.notes = "   "

        let values = try draft.persistedValues(
            usesTeams: false,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 1"
        )

        XCTAssertNil(values.notes)
        XCTAssertNil(values.roundConfig.notes)
    }

    func testUntouchedFallbackCourseDoesNotBecomeRoundOverride() throws {
        let fallback = SeriesCourseSelection(
            courseID: "league-course",
            cachedName: "League Course",
            defaultTeeBoxID: "blue",
            holeSegment: .front9
        )
        let round = SeriesRound(id: "week1", courseOverride: nil, parentID: "series1")
        var draft = SeriesRoundDraft(seriesRound: round, fallbackCourse: fallback, usesTeams: false)

        let untouched = try draft.persistedValues(
            usesTeams: false,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 1"
        )
        XCTAssertNil(untouched.courseOverride)

        draft.selectedCourse = fallback
        let explicitlySelected = try draft.persistedValues(
            usesTeams: false,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 1"
        )
        XCTAssertEqual(explicitlySelected.courseOverride, fallback)
    }

    func testNewDraftCopiesCurrentDefaultsWithoutMutatingFutureRounds() throws {
        var defaults = SeriesRoundConfiguration()
        defaults.maxScoreOverPar = .triple
        defaults.allowLobbyBackPropagation = false
        let settings = SeriesSettings(defaultRoundConfig: defaults, defaultTeamScoringProfileID: "team-profile")
        let draft = SeriesRoundDraft(settings: settings, suggestedCourse: nil, usesTeams: true)
        let values = try draft.persistedValues(
            usesTeams: true,
            courseHandicapAvailable: true,
            fallbackTitle: "Week 1"
        )

        XCTAssertEqual(values.roundConfig.maxScoreOverPar, .triple)
        XCTAssertFalse(values.roundConfig.allowLobbyBackPropagation)
        XCTAssertEqual(values.teamScoringProfileID, "team-profile")
    }

    func testInvalidAllowanceIsRejectedInsteadOfSilentlyDropped() {
        var draft = SeriesRoundDraft(settings: .init(), suggestedCourse: nil, usesTeams: false)
        draft.sharedScoreAllowanceText = "35,oops,15"

        XCTAssertThrowsError(
            try draft.persistedValues(
                usesTeams: false,
                courseHandicapAvailable: true,
                fallbackTitle: "Week 1"
            )
        ) { error in
            XCTAssertEqual(error as? SeriesRoundDraftValidationError, .invalidSharedScoreAllowance("oops"))
        }
    }

    func testLeagueDefaultChangeDoesNotRewriteExistingRoundMaxScore() {
        var settings = SeriesSettings()
        settings.defaultRoundConfig.maxScoreOverPar = .bogey
        let series = Series(id: "series1", settings: settings)
        var roundConfig = SeriesRoundConfiguration()
        roundConfig.maxScoreOverPar = .sext
        let seriesRound = SeriesRound(id: "week1", roundConfig: roundConfig, parentID: "series1")

        let format = SeriesRoundCreationMapping.primaryGameFormatForRound(series: series, seriesRound: seriesRound)

        XCTAssertEqual(format.configuration.maxScoreOverPar, .sext)
    }

    func testMatchingLinkedLobbyHasNoDivergence() {
        var config = SeriesRoundConfiguration()
        config.maxScoreOverPar = .double
        config.handicapStrokeBasis = .nineHole
        let series = Series(id: "series1", settings: .init(useTeams: true))
        let seriesRound = SeriesRound(id: "week1", roundID: "round1", roundConfig: config, parentID: "series1")
        let linkedRound = matchingLinkedRound(series: series, seriesRound: seriesRound)

        XCTAssertNil(
            SeriesRoundConfigurationReconciler.divergence(
                series: series,
                seriesRound: seriesRound,
                linkedRound: linkedRound
            )
        )
    }

    func testLinkedLobbyChangesProduceFieldLevelDivergence() {
        let series = Series(id: "series1", settings: .init(useTeams: true))
        let seriesRound = SeriesRound(id: "week1", roundID: "round1", parentID: "series1")
        var linkedRound = matchingLinkedRound(series: series, seriesRound: seriesRound)
        linkedRound.configuration.teamScoring = .init(mode: .bestN, count: 2, scope: .perRound)
        linkedRound.configuration.handicapNormalizationMode = .field

        let divergence = SeriesRoundConfigurationReconciler.divergence(
            series: series,
            seriesRound: seriesRound,
            linkedRound: linkedRound
        )

        XCTAssertEqual(divergence?.fields, [.teamScoring, .handicap])
    }

    func testAdoptingLinkedLobbyChangesLinkedFieldsAndPreservesSeriesOnlyFields() {
        var base = SeriesRoundConfiguration()
        base.allowCourseOverride = false
        base.allowFormatOverride = false
        base.allowLobbyBackPropagation = false
        base.notes = "Series-only note"
        var linked = RoundConfiguration()
        linked.formatSummary = RoundFormatSummary(from: FormatTemplateRegistry.bestBall)
        linked.primaryFormat = SeriesRoundConfiguration(
            formatTemplateID: FormatTemplateRegistry.bestBall.id
        ).legacyGameFormat
        linked.primaryFormat.configuration.maxScoreOverPar = .double
        linked.teamScoring = .init(mode: .bestN, count: 2, scope: .perHole)
        linked.handicapNormalizationMode = .field

        let adopted = SeriesRoundConfigurationReconciler.adoptingLinkedConfiguration(
            from: Round(id: "round1", configuration: linked),
            segment: nil,
            preserving: base
        )

        XCTAssertEqual(adopted.formatTemplateID, FormatTemplateRegistry.bestBall.id)
        XCTAssertEqual(adopted.maxScoreOverPar, .double)
        XCTAssertEqual(adopted.teamScoring, .init(mode: .bestN, count: 2, scope: .perHole))
        XCTAssertEqual(adopted.handicapNormalizationMode, .field)
        XCTAssertFalse(adopted.allowCourseOverride)
        XCTAssertFalse(adopted.allowFormatOverride)
        XCTAssertFalse(adopted.allowLobbyBackPropagation)
        XCTAssertEqual(adopted.notes, "Series-only note")
    }

#if SANDBOX
    @MainActor
    func testDesignStudioMatchupScopeRevealsDependentSection() {
        let store = DesignStudioSeriesRoundStore()

        XCTAssertEqual(store.applicableSections.count, 6)
        XCTAssertTrue(store.applicableSections.contains(.matchups))
        XCTAssertEqual(store.readyCount, 3)
        XCTAssertEqual(store.nextSection, .matchups)
        XCTAssertTrue(store.validationIssues.contains { $0.hasPrefix("Matchups:") })
    }

    @MainActor
    func testDesignStudioFieldScopeRemovesMatchupsAndRecalculatesProgress() {
        let store = DesignStudioSeriesRoundStore()

        store.setCompetitionScope(.field)

        XCTAssertEqual(store.applicableSections.count, 5)
        XCTAssertFalse(store.applicableSections.contains(.matchups))
        XCTAssertEqual(store.readyCount, 3)
        XCTAssertEqual(store.nextSection, .handicapEligibility)
        XCTAssertFalse(store.validationIssues.contains { $0.hasPrefix("Matchups:") })
    }

    @MainActor
    func testDesignStudioAutoFillAndTeeGenerationAdvanceRecommendedWork() {
        let store = DesignStudioSeriesRoundStore()

        store.autoFillMatchups()
        XCTAssertEqual(store.status(for: .matchups), .ready)
        XCTAssertEqual(store.nextSection, .teeSheet)

        store.generateTeeSheet()
        XCTAssertEqual(store.status(for: .teeSheet), .ready)
        XCTAssertEqual(store.nextSection, .handicapEligibility)
    }
#endif

    private func matchingLinkedRound(series: Series, seriesRound: SeriesRound) -> Round {
        let desired = seriesRound.roundConfig
        let template = desired.template
        let primaryFormat = SeriesRoundCreationMapping.primaryGameFormatForRound(
            series: series,
            seriesRound: seriesRound
        )
        let configuration = RoundConfiguration(
            primaryFormat: primaryFormat,
            formatSummary: RoundFormatSummary(from: template),
            competitionScope: SeriesRoundCreationMapping.resolvedCompetitionScope(for: seriesRound),
            teamScoring: desired.teamScoring,
            matchupResolutionStyle: desired.matchupResolutionStyle,
            scoreOwnerScope: template.scoreSource == .shared ? desired.scoreOwnerScope : .individual,
            matchupScoringStyle: desired.matchupScoringStyle,
            holeWinPoints: desired.holeWinPoints,
            matchWinnerBonusPoints: desired.matchWinnerBonusPoints,
            matchTiePolicy: desired.matchTiePolicy,
            selectionDomain: desired.selectionDomain,
            sequentialTeeStartsEnabled: desired.sequentialTeeStartsEnabled,
            handicapStrokeBasis: desired.handicapStrokeBasis,
            sharedScoreHandicapConfig: desired.sharedScoreHandicapConfig,
            handicapEntryFormat: desired.handicapEntryFormat,
            handicapNormalizationMode: desired.handicapNormalizationMode
        )
        return Round(id: "round1", status: .lobby, configuration: configuration)
    }
}
