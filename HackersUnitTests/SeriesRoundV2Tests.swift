//
//  SeriesRoundV2Tests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundV2Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testScheduledRoundBecomesLobbyWithinTwentyFourHours() {
        var round = RoundV2(
            id: "round-v2",
            schedule: .init(scheduledAt: .init(for: now.addingTimeInterval(25 * 60 * 60))),
            provisioning: .init(phase: .ready)
        )
        XCTAssertEqual(SeriesRoundPresentationResolverV2.resolve(round: round, now: now), .scheduled)

        round.schedule = .init(scheduledAt: .init(for: now.addingTimeInterval(24 * 60 * 60)))
        XCTAssertEqual(SeriesRoundPresentationResolverV2.resolve(round: round, now: now), .lobby)
    }

    func testMeaningfulLobbyActivationOverridesSchedule() {
        let context = SeriesContextV2(
            seriesID: "series-v2",
            roundIndex: 0,
            appliedDefaultsRevision: 1,
            lobbyActivatedAt: .init(for: now),
            standingsPolicyBinding: nil,
            teamScoringProfileBinding: nil,
            individualScoringProfileBinding: nil,
            rules: .init(),
            legacySeriesRoundID: nil,
            migratedFromV1: false
        )
        let round = RoundV2(
            id: "round-v2",
            schedule: .init(scheduledAt: .init(for: now.addingTimeInterval(10 * 24 * 60 * 60))),
            seriesContext: context,
            provisioning: .init(phase: .ready)
        )
        XCTAssertEqual(SeriesRoundPresentationResolverV2.resolve(round: round, now: now), .lobby)
    }

    func testGameplayAndSeriesResultStatesRemainIndependent() {
        let round = RoundV2(id: "round-v2", status: .completed, provisioning: .init(phase: .ready))
        let state = SeriesRoundResultStateV2(
            id: "round-v2",
            status: .needsReview,
            latestGenerationID: nil,
            semanticHash: nil,
            failureCode: nil,
            finalizedAt: nil,
            createdAt: .init(for: now),
            lastUpdatedAt: .init(for: now),
            parentID: "series-v2"
        )
        XCTAssertEqual(SeriesRoundPresentationResolverV2.resolve(round: round, resultState: state, now: now), .needsReview)
    }

    func testDefaultsPreviewIsExplicitAndRevisionAware() {
        let context = SeriesContextV2(
            seriesID: "series-v2",
            roundIndex: 0,
            appliedDefaultsRevision: 1,
            lobbyActivatedAt: nil,
            standingsPolicyBinding: nil,
            teamScoringProfileBinding: nil,
            individualScoringProfileBinding: nil,
            rules: .init(),
            legacySeriesRoundID: nil,
            migratedFromV1: false
        )
        let round = RoundV2(id: "round-v2", seriesContext: context)
        let series = SeriesV2(
            id: "series-v2",
            settings: .init(roundDefaultsRevision: 2)
        )
        let preview = SeriesDefaultsPreviewV2.make(round: round, series: series)
        XCTAssertTrue(preview.hasChanges)
        XCTAssertEqual(preview.appliedRevision, 1)
        XCTAssertEqual(preview.availableRevision, 2)
        XCTAssertTrue(preview.changedFields.isEmpty)
    }

    func testStagedMigrationSelectsOnlyV1() {
        let v1 = Series(id: "series", name: "League")
        let v2 = SeriesV2(
            id: "series",
            name: "League",
            migration: .init(sourceSeriesID: "series", phase: .ready, validatedAt: .init(for: now))
        )
        let selected = SeriesVersionSelectorV2.select(v1: v1, v2: v2)
        guard let selected, case .v1(let value) = selected else {
            return XCTFail("A ready but inactive V2 copy must stay hidden")
        }
        XCTAssertEqual(value.id, v1.id)
    }

    func testActiveMigrationSelectsOnlyV2() {
        let v1 = Series(id: "series", name: "League")
        let v2 = SeriesV2(
            id: "series",
            name: "League",
            migration: .init(sourceSeriesID: "series", phase: .ready, validatedAt: .init(for: now))
        )
        let routing = SeriesRoutingV2(
            id: "series",
            sourceSeriesID: "series",
            targetSeriesID: "series",
            phase: .active,
            revision: 1,
            minimumClientVersion: "2.0.0",
            activatedAt: .init(for: now),
            rolledBackAt: nil,
            createdAt: .init(for: now),
            lastUpdatedAt: .init(for: now)
        )
        let selected = SeriesVersionSelectorV2.select(v1: v1, v2: v2, routing: routing)
        guard let selected, case .v2(let value) = selected else {
            return XCTFail("An active route must select the V2 copy")
        }
        XCTAssertEqual(value.id, v2.id)
    }

    func testActiveMigrationNeverFallsBackToStaleV1() {
        let v1 = Series(id: "series", name: "League")
        let routing = SeriesRoutingV2(
            id: "series",
            sourceSeriesID: "series",
            targetSeriesID: "series",
            phase: .active,
            revision: 1,
            minimumClientVersion: "2.0.0",
            activatedAt: .init(for: now),
            rolledBackAt: nil,
            createdAt: .init(for: now),
            lastUpdatedAt: .init(for: now)
        )
        XCTAssertNil(SeriesVersionSelectorV2.select(v1: v1, v2: nil, routing: routing))
    }

    func testRolledBackMigrationSelectsV1() {
        let v1 = Series(id: "series", name: "League")
        let v2 = SeriesV2(
            id: "series",
            name: "League",
            migration: .init(sourceSeriesID: "series", phase: .rolledBack)
        )
        let selected = SeriesVersionSelectorV2.select(v1: v1, v2: v2)
        guard let selected, case .v1 = selected else {
            return XCTFail("A rolled-back route must restore V1")
        }
    }

    func testLegacyValidatedMetadataDecodesAsReady() throws {
        let data = Data("""
        {
          "source_series_id": "series",
          "validated_at": { "iso": "2033-05-18T03:33:20Z", "unix": 2000000000 }
        }
        """.utf8)
        let metadata = try JSONDecoder().decode(SeriesMigrationMetadataV2.self, from: data)
        XCTAssertEqual(metadata.phase, .ready)
        XCTAssertEqual(metadata.cutoverRevision, 0)
    }
}
