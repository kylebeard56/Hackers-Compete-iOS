@testable import Hackers
import XCTest

final class SeriesPhase6StandingsRolloutTests: XCTestCase {
    func testBestTwoNineHoleDraftBuildsStrictLowestAveragePolicy() throws {
        var settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        settings.useIndividualStandings = false
        settings.useTeamStandings = true
        let draft = SeriesStandingsTiebreakDraft(team: .init(
            isEnabled: true,
            direction: .lowestFirst,
            scoreComponent: .total,
            minimumEligibleRounds: 2
        ))

        let revision = try SeriesStandingsRollout.makeRevision(
            settings: settings,
            draft: draft,
            id: "policy_1",
            createdAt: SeriesBehaviorFixtures.fixedTime
        ).get()
        let rule = try XCTUnwrap(revision.policy.rules.first)
        let tiebreaker = try XCTUnwrap(rule.resolvedTiebreakers.first)

        XCTAssertEqual(revision.sequence, 1)
        XCTAssertEqual(rule.track, .team)
        XCTAssertEqual(rule.acceptedHoleCounts, [9])
        XCTAssertEqual(rule.acceptedScoreBases, [.gross])
        XCTAssertEqual(rule.acceptedScoringFamilies, [.strokePlay])
        XCTAssertEqual(rule.requiredTeamScoring, .init(mode: .bestN, count: 2, scope: .perRound))
        XCTAssertEqual(tiebreaker.id, "team_scoring_average")
        XCTAssertEqual(tiebreaker.direction, .lowestFirst)
        XCTAssertEqual(tiebreaker.minimumEligibleRounds, 2)
        XCTAssertTrue(SeriesStandingsPolicyResolver.isValidTiebreakPolicy(rule))
    }

    func testPolicySaveRequiresCourseAndEnabledStandingTrack() {
        var settings = SeriesSettings(useIndividualStandings: false, useTeamStandings: true)
        let draft = SeriesStandingsTiebreakDraft(team: .init(isEnabled: true))

        XCTAssertEqual(
            SeriesStandingsRollout.makeRevision(settings: settings, draft: draft, id: "policy").failure,
            .missingDefaultCourse
        )

        settings.defaultCourse = SeriesCourseSelection(courseID: "course", holeSegment: .front9)
        settings.useTeamStandings = false
        XCTAssertEqual(
            SeriesStandingsRollout.makeRevision(settings: settings, draft: draft, id: "policy").failure,
            .noEnabledStandingsTrack
        )
    }

    func testPolicyCannotConfigureDisabledTrack() {
        var settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        settings.useTeamStandings = false
        settings.useIndividualStandings = true
        let draft = SeriesStandingsTiebreakDraft(team: .init(isEnabled: true))

        XCTAssertEqual(
            SeriesStandingsRollout.makeRevision(settings: settings, draft: draft, id: "policy").failure,
            .disabledTrack(.team)
        )
    }

    func testGeneralSettingsDraftCannotOverwriteRolloutManagedFields() throws {
        var current = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        let revision = try SeriesStandingsRollout.makeRevision(
            settings: current,
            draft: .init(team: .init(isEnabled: true)),
            id: "managed"
        ).get()
        current.standingsPolicyRevision = revision
        current.standingsReadAuthority = .canonicalWhenReady

        var staleDraft = current
        staleDraft.defaultRoundConfig.notes = "Updated elsewhere"
        staleDraft.standingsPolicyRevision = nil
        staleDraft.standingsReadAuthority = .legacy

        let protected = SeriesStandingsRollout.preservingManagedSettings(
            draft: staleDraft,
            current: current
        )

        XCTAssertEqual(protected.defaultRoundConfig.notes, "Updated elsewhere")
        XCTAssertEqual(protected.standingsPolicyRevision, revision)
        XCTAssertEqual(protected.standingsReadAuthority, .canonicalWhenReady)
    }

    func testScoringContractChangeFallsBackToLegacyAuthority() throws {
        var current = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        let revision = try SeriesStandingsRollout.makeRevision(
            settings: current,
            draft: .init(team: .init(isEnabled: true)),
            id: "active"
        ).get()
        current.standingsPolicyRevision = revision
        current.standingsReadAuthority = .canonicalWhenReady

        var changed = current
        changed.defaultRoundConfig.teamScoring = .init(mode: .bestN, count: 3, scope: .perRound)
        let protected = SeriesStandingsRollout.preservingManagedSettings(
            draft: changed,
            current: current
        )

        XCTAssertEqual(protected.standingsPolicyRevision, revision)
        XCTAssertEqual(protected.standingsReadAuthority, .legacy)
    }

    func testDraftRoundTripsExistingPolicyOptions() throws {
        let settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        let source = SeriesStandingsTiebreakDraft(team: .init(
            isEnabled: true,
            direction: .highestFirst,
            scoreComponent: .scoreToPar,
            minimumEligibleRounds: 4
        ))
        let revision = try SeriesStandingsRollout.makeRevision(
            settings: settings,
            draft: source,
            id: "round_trip"
        ).get()
        var configured = settings
        configured.standingsPolicyRevision = revision

        XCTAssertEqual(SeriesStandingsRollout.draft(from: configured), source)
    }

    func testPreviewClassifiesHistoricalRoundsBeforeWrites() throws {
        let settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        let revision = try SeriesStandingsRollout.makeRevision(
            settings: settings,
            draft: .init(team: .init(isEnabled: true)),
            id: "preview"
        ).get()
        let matching = SeriesRound(
            id: "matching",
            status: .complete,
            roundID: "round_1",
            courseOverride: settings.defaultCourse,
            roundConfig: settings.defaultRoundConfig,
            parentID: "series"
        )
        var mismatchedCourse = settings.defaultCourse
        mismatchedCourse?.holeSegment = .full18
        let excluded = SeriesRound(
            id: "excluded",
            status: .complete,
            roundID: "round_2",
            courseOverride: mismatchedCourse,
            roundConfig: settings.defaultRoundConfig,
            parentID: "series"
        )

        let preview = SeriesStandingsRollout.preview(
            series: Series(id: "series", settings: settings),
            completedRounds: [matching, excluded],
            revision: revision
        )
        let team = try XCTUnwrap(preview.tracks[.team])

        XCTAssertEqual(preview.completedRoundCount, 2)
        XCTAssertEqual(team.eligibleRoundCount, 1)
        XCTAssertEqual(team.excludedRoundCount, 1)
        XCTAssertEqual(team.invalidRoundCount, 0)
    }

    func testAverageFormatterUsesOneDecimalAndRejectsNonFiniteValues() {
        XCTAssertEqual(SeriesStandingsAverageFormatter.string(72.75), "72.8")
        XCTAssertEqual(SeriesStandingsAverageFormatter.string(73.4), "73.4")
        XCTAssertEqual(SeriesStandingsAverageFormatter.string(nil), "—")
        XCTAssertEqual(SeriesStandingsAverageFormatter.string(.infinity), "—")
    }
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
