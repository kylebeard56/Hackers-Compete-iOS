//
//  SeriesRoundCardPresentationTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundCardPresentationTests: XCTestCase {
    func testEquivalentV1AndV2ConfigurationProducesSamePresentationSemantics() {
        let teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
        let v1Round = SeriesRound(
            id: "series-round",
            roundConfig: .init(
                formatTemplateID: FormatTemplateRegistry.bestBall.id,
                competitionScope: .matchup,
                teamScoring: teamScoring,
                scoreBasisOverride: .net
            ),
            parentID: "series"
        )
        let v1 = V1SeriesRoundCardAdapter.resolvedConfiguration(
            seriesRound: v1Round,
            linkedRound: nil,
            series: Series(id: "series")
        )
        let v2Round = RoundV2(
            id: "round-v2",
            configuration: .init(
                templateID: FormatTemplateRegistry.bestBall.id,
                formatSummary: .init(from: FormatTemplateRegistry.bestBall),
                competitionScope: .matchup,
                teamScoring: teamScoring,
                scoreBasis: .net
            )
        )
        let v2 = V2SeriesRoundCardAdapter.resolvedConfiguration(round: v2Round)

        XCTAssertEqual(v1.templateID, v2.templateID)
        XCTAssertEqual(v1.competitionScope, v2.competitionScope)
        XCTAssertEqual(v1.teamScoring, v2.teamScoring)
        XCTAssertEqual(v1.scoreBasis, v2.scoreBasis)
        XCTAssertEqual(v1.presentationKind, v2.presentationKind)
        XCTAssertEqual(v1.scoringRuleLabel, v2.scoringRuleLabel)
        XCTAssertEqual(v1.defaultContributorRole, v2.defaultContributorRole)
    }

    func testLinkedV1PlayableRoundOverridesPlannedShellConfiguration() {
        let shell = SeriesRound(
            id: "series-round",
            roundID: "round",
            roundConfig: .init(
                formatTemplateID: FormatTemplateRegistry.strokePlay.id,
                teamScoring: .init(mode: .bestN, count: 3, scope: .perRound),
                scoreBasisOverride: .gross
            ),
            parentID: "series"
        )
        let linkedConfig = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: .init(basis: .net)
            ),
            formatSummary: .init(from: FormatTemplateRegistry.stableford),
            competitionScope: .matchup,
            teamScoring: .init(mode: .worstN, count: 2, scope: .perHole),
            handicapsEnabled: true
        )
        let resolved = V1SeriesRoundCardAdapter.resolvedConfiguration(
            seriesRound: shell,
            linkedRound: Round(id: "round", configuration: linkedConfig),
            series: Series(id: "series")
        )

        XCTAssertEqual(resolved.templateID, FormatTemplateRegistry.stableford.id)
        XCTAssertEqual(resolved.teamScoring, .init(mode: .worstN, count: 2, scope: .perHole))
        XCTAssertEqual(resolved.scoreBasis, .net)
        XCTAssertEqual(resolved.scoringRuleLabel, "Worst 2 per hole")
        XCTAssertEqual(resolved.defaultContributorRole, .variablePerHole)
    }

    func testV2SeriesDefaultChangesDoNotMutateExistingRoundPresentation() {
        let frozen = RoundV2(
            id: "round",
            configuration: .init(
                templateID: FormatTemplateRegistry.bestBall.id,
                formatSummary: .init(from: FormatTemplateRegistry.bestBall),
                competitionScope: .matchup,
                teamScoring: .init(mode: .bestN, count: 2, scope: .perRound),
                scoreBasis: .net
            )
        )
        let before = V2SeriesRoundCardAdapter.resolvedConfiguration(round: frozen)
        var series = SeriesV2(id: "series")
        series.settings.roundDefaults.configuration.teamScoring = .init(mode: .worstN, count: 3, scope: .perHole)
        series.settings.roundDefaults.configuration.scoreBasis = .gross
        series.settings.roundDefaultsRevision += 1
        let after = V2SeriesRoundCardAdapter.resolvedConfiguration(round: frozen)

        XCTAssertEqual(before, after)
        XCTAssertEqual(after.scoringRuleLabel, "Best 2 per round")
        XCTAssertEqual(after.scoreBasis, .net)
    }

    func testV2CardBehaviorUsesFrozenSeriesContextRules() {
        let context = SeriesContextV2(
            seriesID: "series",
            roundIndex: 0,
            appliedDefaultsRevision: 1,
            lobbyActivatedAt: nil,
            standingsPolicyBinding: nil,
            teamScoringProfileBinding: nil,
            individualScoringProfileBinding: nil,
            rules: .init(attendanceEnabled: false),
            legacySeriesRoundID: nil,
            migratedFromV1: false
        )
        let round = RoundV2(id: "round", seriesContext: context)
        var currentDefaults = SeriesRoundRulesSnapshotV2(attendanceEnabled: true)

        XCTAssertEqual(V2SeriesRoundCardAdapter.primaryAction(round: round, resultState: nil), .openLobby)
        currentDefaults.attendanceEnabled = true
        XCTAssertTrue(currentDefaults.attendanceEnabled)
        XCTAssertEqual(V2SeriesRoundCardAdapter.primaryAction(round: round, resultState: nil), .openLobby)
    }

    func testTeamScoringVariantsHaveTruthfulLabelsAndContributorRoles() {
        let cases: [(RoundTeamScoringConfiguration, String, SeriesRoundCardContributorRole)] = [
            (.init(mode: .all, count: 1, scope: .perHole), "All scores count", .allScoresCount),
            (.init(mode: .bestN, count: 1, scope: .perRound), "Best 1 per round", .selectedForRound),
            (.init(mode: .bestN, count: 2, scope: .perRound), "Best 2 per round", .selectedForRound),
            (.init(mode: .bestN, count: 3, scope: .perRound), "Best 3 per round", .selectedForRound),
            (.init(mode: .worstN, count: 2, scope: .perRound), "Worst 2 per round", .selectedForRound),
            (.init(mode: .bestN, count: 2, scope: .perHole), "Best 2 per hole", .variablePerHole),
            (.init(mode: .worstN, count: 3, scope: .perHole), "Worst 3 per hole", .variablePerHole)
        ]

        for (teamScoring, label, role) in cases {
            let value = resolved(teamScoring: teamScoring)
            XCTAssertEqual(value.scoringRuleLabel, label)
            XCTAssertEqual(value.defaultContributorRole, role)
        }
    }

    func testScoreOwnerAndCompetitionScopesChooseNativePresentation() {
        XCTAssertEqual(resolved(scope: .matchup, owner: .individual).presentationKind, .matchup)
        XCTAssertEqual(resolved(scope: .field, owner: .individual).presentationKind, .leaderboard)
        XCTAssertEqual(resolved(scope: .field, owner: .partnership).presentationKind, .sharedScore)
        XCTAssertEqual(resolved(scope: .field, owner: .teeGroup).presentationKind, .sharedScore)
    }

    func testLegacyCanonicalResultDecodesWithoutCardProjection() throws {
        let source = canonicalResult(cardProjection: nil)
        let encoded = try JSONEncoder().encode(source)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "card_projection")
        let decoded = try JSONDecoder().decode(
            SeriesRoundResult.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertNil(decoded.cardProjection)
        XCTAssertEqual(decoded.linkedRoundID, "round")
    }

    func testCardProjectionRoundTripsAsDerivedDisplayData() throws {
        let state = SeriesRoundCardViewState(
            id: "series-round",
            canonicalRoundID: "round",
            title: "Week 4",
            courseName: "The Preserve",
            scheduleLabel: "Sat, Aug 8",
            lifecycle: .finalized,
            presentationKind: .matchup,
            formatLabel: "Best Ball",
            scoringRuleLabel: "Best 2 per round",
            scoreBasis: .net,
            showsHandicap: true,
            isProvisional: false,
            sides: [],
            viewer: nil,
            participantCountLabel: "8 players",
            primaryAction: .viewResults,
            isAdjusted: false,
            setupDiffers: false
        )
        let source = canonicalResult(cardProjection: .init(state: state))
        let decoded = try JSONDecoder().decode(SeriesRoundResult.self, from: JSONEncoder().encode(source))

        XCTAssertEqual(decoded.cardProjection?.version, SeriesRoundCardViewState.projectionVersion)
        XCTAssertEqual(decoded.cardProjection?.state, state)
        XCTAssertNil(decoded.cardProjection?.state.viewer)
    }

    private func resolved(
        teamScoring: RoundTeamScoringConfiguration = .init(),
        scope: CompetitionScope = .field,
        owner: RoundScoreOwnerScope = .individual
    ) -> SeriesRoundCardResolvedConfiguration {
        .init(
            templateID: FormatTemplateRegistry.strokePlay.id,
            formatName: "Stroke Play",
            competitionScope: scope,
            teamScoring: teamScoring,
            scoreOwnerScope: owner,
            scoreBasis: .gross,
            usesHandicaps: false,
            highestWins: false
        )
    }

    private func canonicalResult(cardProjection: SeriesRoundCardProjection?) -> SeriesRoundResult {
        SeriesRoundResult(
            id: "generation",
            seriesRoundID: "series-round",
            linkedRoundID: "round",
            sourceRevision: "source",
            sourceUpdatedAt: 1,
            policyRevisionID: nil,
            policyFingerprint: "policy",
            processorVersion: 3,
            semanticHash: "semantic",
            compatibility: [],
            performanceMetrics: [],
            pointAwards: [],
            handicapSamples: [],
            cardProjection: cardProjection,
            parentID: "series"
        )
    }
}
