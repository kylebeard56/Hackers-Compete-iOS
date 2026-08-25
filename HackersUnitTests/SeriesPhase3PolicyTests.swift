@testable import Hackers
import XCTest

final class SeriesPhase3PolicyTests: XCTestCase {
    private struct StableStandingProjection: Equatable {
        let id: String
        let track: SeriesAwardTrack
        let competitorType: SeriesCompetitorType
        let competitorID: String
        let competitorName: String
        let totalPoints: Double
        let roundsCounted: Int
        let wins: Int
        let topThrees: Int
        let lastPlacement: Int?
        let bestPlacement: Int?
        let rank: Int?
        let parentID: String

        init(_ standing: SeriesStanding) {
            id = standing.id
            track = standing.awardTrack
            competitorType = standing.competitorType
            competitorID = standing.competitorID
            competitorName = standing.competitorName
            totalPoints = standing.totalPoints
            roundsCounted = standing.roundsCounted
            wins = standing.wins
            topThrees = standing.topThrees
            lastPlacement = standing.lastPlacement
            bestPlacement = standing.bestPlacement
            rank = standing.rank
            parentID = standing.parentID
        }
    }

    func testRoundDefaultsBoundaryPreservesLegacySettingsWireFormat() throws {
        var settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        let originalDefaults = settings.roundDefaults

        XCTAssertEqual(originalDefaults.course, settings.defaultCourse)
        XCTAssertEqual(originalDefaults.configuration, settings.defaultRoundConfig)
        XCTAssertEqual(originalDefaults.teamScoringProfileID, settings.defaultTeamScoringProfileID)
        XCTAssertEqual(originalDefaults.individualScoringProfileID, settings.defaultIndividualScoringProfileID)

        var updatedDefaults = originalDefaults
        updatedDefaults.configuration.scoreBasisOverride = .net
        updatedDefaults.scheduledTeeTimeMinutesFromMidnight = 900
        settings.roundDefaults = updatedDefaults

        let dictionary = try settings.toDictionary()
        XCTAssertNil(dictionary["round_defaults"])
        XCTAssertNotNil(dictionary["default_round_config"])
        XCTAssertEqual(dictionary["default_scheduled_tee_time_minutes_from_midnight"] as? Int, 900)
        XCTAssertEqual(settings.defaultRoundConfig.scoreBasisOverride, .net)
    }

    func testLegacyDocumentsDecodeWithoutPolicyAndResolveLegacySnapshot() throws {
        let settings = try JSONDecoder().decode(SeriesSettings.self, from: Data(#"{}"#.utf8))
        let round = try JSONDecoder().decode(
            SeriesRound.self,
            from: Data(#"{"id":"legacy","title":"Week 1","index":0,"parent_id":"series"}"#.utf8)
        )
        let series = Series(id: "series", name: "Legacy", settings: settings)
        let resolved = SeriesStandingsPolicyResolver.resolve(round: round, settings: settings)

        XCTAssertNil(settings.standingsPolicyRevision)
        XCTAssertNil(round.policyBinding)
        XCTAssertEqual(resolved.source, .legacySnapshot)
        XCTAssertTrue(resolved.hasValidFingerprint)
        XCTAssertEqual(
            SeriesStandingsPolicyResolver.compatibility(for: round, in: series).map(\.classification),
            [.eligible]
        )
    }

    func testPolicyRevisionAndRoundBindingRoundTripWithStableFingerprint() throws {
        var settings = baseSettings()
        let policy = SeriesStandingsPolicyResolver.strictPolicy(settings: settings)
        let revision = SeriesStandingsPolicyResolver.makeRevision(
            id: "policy-2",
            sequence: 2,
            policy: policy,
            createdAt: SeriesBehaviorFixtures.fixedTime
        )
        settings.standingsPolicyRevision = revision
        let binding = try XCTUnwrap(SeriesStandingsPolicyResolver.bindingForNewRound(settings: settings))
        let round = baseRound(policyBinding: binding)

        let data = try JSONEncoder().encode(round)
        let decoded = try JSONDecoder().decode(SeriesRound.self, from: data)
        let dictionary = try round.toDictionary()
        let encodedBinding = try XCTUnwrap(dictionary["policy_binding"] as? [String: Any])

        XCTAssertEqual(decoded.policyBinding, binding)
        XCTAssertEqual(revision.resolvedPolicyFingerprint, SeriesStandingsPolicyResolver.fingerprint(for: policy))
        XCTAssertEqual(revision.resolvedPolicyFingerprint.count, 64)
        XCTAssertEqual(binding.resolvedSubstitutesScore, true)
        XCTAssertEqual(encodedBinding["revision_id"] as? String, "policy-2")
        XCTAssertEqual(encodedBinding["revision_sequence"] as? Int, 2)
        XCTAssertEqual(encodedBinding["resolved_substitutes_score"] as? Bool, true)
    }

    func testFingerprintCanonicalizesRuleAndConstraintOrdering() {
        let team = SeriesStandingsRule(
            id: "team",
            track: .team,
            acceptedFormatTemplateIDs: ["stroke_play", "best_ball"],
            acceptedScoreBases: [.net, .gross],
            acceptedHoleCounts: [18, 9]
        )
        let individual = SeriesStandingsRule(id: "individual", track: .individual)
        let reorderedTeam = SeriesStandingsRule(
            id: "team",
            track: .team,
            acceptedFormatTemplateIDs: ["best_ball", "stroke_play"],
            acceptedScoreBases: [.gross, .net],
            acceptedHoleCounts: [9, 18]
        )

        XCTAssertEqual(
            SeriesStandingsPolicyResolver.fingerprint(for: .init(rules: [team, individual])),
            SeriesStandingsPolicyResolver.fingerprint(for: .init(rules: [individual, reorderedTeam]))
        )
    }

    func testStrictCompatibilityAcceptsTeamAndIndividualGrossEighteenHoleBestTwoStrokePlay() {
        let context = boundContext(settings: baseSettings(), round: baseRound())
        let classifications = classificationsByTrack(round: context.round, series: context.series)

        XCTAssertEqual(classifications[.team], .eligible)
        XCTAssertEqual(classifications[.individual], .eligible)
    }

    func testStrictCompatibilityAcceptsNineHolePolicyAndCanNormalizeNineToEighteen() {
        var nineHoleSettings = baseSettings()
        nineHoleSettings.defaultCourse?.holeSegment = .front9
        var nineHoleRound = baseRound()
        nineHoleRound.courseOverride?.holeSegment = .front9
        let nineHoleContext = boundContext(settings: nineHoleSettings, round: nineHoleRound)

        XCTAssertEqual(
            classificationsByTrack(round: nineHoleContext.round, series: nineHoleContext.series)[.team],
            .eligible
        )

        let normalizedContext = boundContext(
            settings: baseSettings(),
            round: nineHoleRound,
            normalizationPolicy: .nineHoleToEighteenHole
        )
        XCTAssertEqual(
            classificationsByTrack(round: normalizedContext.round, series: normalizedContext.series)[.team],
            .normalized([.holeCount(from: 9, to: 18)])
        )
    }

    func testStrictCompatibilityExcludesGrossNetAndStrokeMatchMismatches() {
        var netRound = baseRound()
        netRound.roundConfig.scoreBasisOverride = .net
        let netContext = boundContext(settings: baseSettings(), round: netRound)

        XCTAssertExcluded(classificationsByTrack(round: netContext.round, series: netContext.series)[.team])
        XCTAssertExcluded(classificationsByTrack(round: netContext.round, series: netContext.series)[.individual])

        var matchRound = baseRound()
        matchRound.roundConfig.formatTemplateID = FormatTemplateRegistry.matchPlayIndividual.id
        let matchContext = boundContext(settings: baseSettings(), round: matchRound)

        XCTAssertExcluded(classificationsByTrack(round: matchContext.round, series: matchContext.series)[.team])
        XCTAssertExcluded(classificationsByTrack(round: matchContext.round, series: matchContext.series)[.individual])
    }

    func testBestNScopeMismatchExcludesTeamRuleButNotIndividualRule() {
        var round = baseRound()
        round.roundConfig.teamScoring.scope = .perHole
        let context = boundContext(settings: baseSettings(), round: round)
        let classifications = classificationsByTrack(round: context.round, series: context.series)

        XCTAssertExcluded(classifications[.team])
        XCTAssertEqual(classifications[.individual], .eligible)
    }

    func testSubstituteBehaviorMismatchExcludesBothRules() {
        let settings = baseSettings()
        let policy = SeriesStandingsPolicyResolver.strictPolicy(settings: settings)
        let revision = SeriesStandingsPolicyResolver.makeRevision(id: "policy", sequence: 1, policy: policy)
        let mismatchedBinding = SeriesRoundPolicyBinding(
            revisionID: revision.id,
            revisionSequence: revision.sequence,
            policy: revision.policy,
            resolvedPolicyFingerprint: revision.resolvedPolicyFingerprint,
            resolvedSubstitutesScore: false
        )
        let round = baseRound(policyBinding: mismatchedBinding)
        let series = Series(id: "series", name: "League", settings: settings)
        let classifications = classificationsByTrack(round: round, series: series)

        XCTAssertExcluded(classifications[.team])
        XCTAssertExcluded(classifications[.individual])
    }

    func testMalformedFingerprintAndMissingCourseAreInvalid() {
        let settings = baseSettings()
        let policy = SeriesStandingsPolicyResolver.strictPolicy(settings: settings)
        let badBinding = SeriesRoundPolicyBinding(
            revisionID: "bad",
            revisionSequence: 1,
            policy: policy,
            resolvedPolicyFingerprint: "not-the-fingerprint",
            resolvedSubstitutesScore: true
        )
        let badRound = baseRound(policyBinding: badBinding)
        let series = Series(id: "series", name: "League", settings: settings)

        XCTAssertInvalid(classificationsByTrack(round: badRound, series: series)[.team])

        var noCourseRound = baseRound()
        noCourseRound.courseOverride = nil
        var noCourseSeries = series
        noCourseSeries.settings.defaultCourse = nil
        let revision = SeriesStandingsPolicyResolver.makeRevision(id: "strict", sequence: 1, policy: policy)
        noCourseRound.policyBinding = SeriesStandingsPolicyResolver.binding(for: revision, substitutesScore: true)

        XCTAssertInvalid(classificationsByTrack(round: noCourseRound, series: noCourseSeries)[.team])
    }

    func testDuplicateRuleIDsAreInvalid() {
        let settings = baseSettings()
        let duplicatePolicy = SeriesStandingsPolicy(rules: [
            SeriesStandingsRule(id: "duplicate", track: .team),
            SeriesStandingsRule(id: "duplicate", track: .individual),
        ])
        let revision = SeriesStandingsPolicyResolver.makeRevision(id: "duplicate", sequence: 1, policy: duplicatePolicy)
        let round = baseRound(policyBinding: SeriesStandingsPolicyResolver.binding(for: revision, substitutesScore: true))
        let classifications = SeriesStandingsPolicyResolver.compatibility(
            for: round,
            in: Series(id: "series", name: "League", settings: settings)
        )

        XCTAssertEqual(classifications.count, 2)
        XCTAssertTrue(classifications.allSatisfy {
            if case .invalid = $0.classification { return true }
            return false
        })
    }

    func testLifecycleGuardAllowsPlannedAndLobbyChangesButLocksLiveAndComplete() {
        let series = Series(id: "series", name: "League", settings: baseSettings())
        let original = baseRound()
        var changed = original
        changed.roundConfig.scoreBasisOverride = .net

        XCTAssertTrue(SeriesRoundLifecycleGuard.permitsScoreContractChange(
            from: original,
            to: changed,
            effectiveStatus: .planned,
            in: series
        ))
        XCTAssertTrue(SeriesRoundLifecycleGuard.permitsScoreContractChange(
            from: original,
            to: changed,
            effectiveStatus: .lobby,
            in: series
        ))
        XCTAssertFalse(SeriesRoundLifecycleGuard.permitsScoreContractChange(
            from: original,
            to: changed,
            effectiveStatus: .live,
            in: series
        ))
        XCTAssertFalse(SeriesRoundLifecycleGuard.permitsScoreContractChange(
            from: original,
            to: changed,
            effectiveStatus: .complete,
            in: series
        ))
    }

    func testLifecycleGuardAllowsNonScoringMetadataChangesAfterCompletion() {
        let series = Series(id: "series", name: "League", settings: baseSettings())
        let original = baseRound()
        var changed = original
        changed.title = "Corrected display title"
        changed.scheduledAt = Time()
        changed.notes = "Commissioner note"
        changed.roundConfig.notes = "Format explanation"

        XCTAssertTrue(SeriesRoundLifecycleGuard.permitsScoreContractChange(
            from: original,
            to: changed,
            effectiveStatus: .complete,
            in: series
        ))
    }

    @MainActor
    func testLegacyGoldenStandingsRetainAllRankingAndAggregationFields() {
        let before = SeriesViewModel.computedStandings(
            from: SeriesBehaviorFixtures.goldenAwards,
            seriesID: SeriesBehaviorFixtures.seriesID,
            sort: SeriesViewModel.standingsSort
        )
        let legacyRound = SeriesBehaviorFixtures.configuredRound
        let legacyCompatibility = SeriesStandingsPolicyResolver.compatibility(
            for: legacyRound,
            in: Series(id: SeriesBehaviorFixtures.seriesID, name: "Legacy", settings: SeriesBehaviorFixtures.bestTwoNineHoleSettings)
        )
        let after = SeriesViewModel.computedStandings(
            from: SeriesBehaviorFixtures.goldenAwards,
            seriesID: SeriesBehaviorFixtures.seriesID,
            sort: SeriesViewModel.standingsSort
        )

        XCTAssertEqual(legacyCompatibility.count, 2)
        XCTAssertTrue(legacyCompatibility.allSatisfy { $0.classification == .eligible })
        XCTAssertEqual(before.map(StableStandingProjection.init), after.map(StableStandingProjection.init))
    }

    private func baseSettings() -> SeriesSettings {
        var config = SeriesRoundConfiguration(
            formatTemplateID: FormatTemplateRegistry.bestBall.id,
            competitionScope: .field,
            teamScoring: .init(mode: .bestN, count: 2, scope: .perRound),
            teamAssignmentMode: .seriesTeams,
            scoreBasisOverride: .gross
        )
        config.matchupMode = .field
        return SeriesSettings(
            defaultCourse: SeriesCourseSelection(
                courseID: "course",
                cachedName: "Policy Club",
                defaultTeeBoxID: "blue",
                holeSegment: .full18
            ),
            defaultRoundConfig: config,
            useTeams: true,
            useIndividualStandings: true,
            useTeamStandings: true,
            substitutesScore: true
        )
    }

    private func baseRound(policyBinding: SeriesRoundPolicyBinding? = nil) -> SeriesRound {
        let settings = baseSettings()
        return SeriesRound(
            id: "round",
            title: "Week 1",
            courseOverride: settings.defaultCourse,
            roundConfig: settings.defaultRoundConfig,
            policyBinding: policyBinding,
            parentID: "series"
        )
    }

    private func boundContext(
        settings: SeriesSettings,
        round: SeriesRound,
        normalizationPolicy: SeriesRoundNormalizationPolicy = .none
    ) -> (series: Series, round: SeriesRound) {
        var settings = settings
        let policy = SeriesStandingsPolicyResolver.strictPolicy(
            settings: settings,
            normalizationPolicy: normalizationPolicy
        )
        let revision = SeriesStandingsPolicyResolver.makeRevision(id: "policy", sequence: 1, policy: policy)
        settings.standingsPolicyRevision = revision
        var round = round
        round.policyBinding = SeriesStandingsPolicyResolver.binding(
            for: revision,
            substitutesScore: settings.substitutesScore
        )
        return (Series(id: "series", name: "League", settings: settings), round)
    }

    private func classificationsByTrack(
        round: SeriesRound,
        series: Series
    ) -> [SeriesAwardTrack: SeriesRoundPolicyCompatibility] {
        Dictionary(uniqueKeysWithValues: SeriesStandingsPolicyResolver.compatibility(for: round, in: series).map {
            ($0.rule.track, $0.classification)
        })
    }

    private func XCTAssertExcluded(
        _ classification: SeriesRoundPolicyCompatibility?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .excluded = classification else {
            XCTFail("Expected excluded, got \(String(describing: classification))", file: file, line: line)
            return
        }
    }

    private func XCTAssertInvalid(
        _ classification: SeriesRoundPolicyCompatibility?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .invalid = classification else {
            XCTFail("Expected invalid, got \(String(describing: classification))", file: file, line: line)
            return
        }
    }
}
