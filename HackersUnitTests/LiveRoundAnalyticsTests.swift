@testable import Hackers
import Foundation
import XCTest

final class RoundResumeStoreTests: XCTestCase {
    func testRoundResumeStateRoundTripsAndClears() {
        let suiteName = "RoundResumeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsRoundResumeStore(defaults: defaults, key: "resume")
        let timestamp = Date(timeIntervalSince1970: 1_725_000_000)
        let state = RoundResumeState(
            roundID: "round_1",
            seriesID: "series_1",
            destination: .liveRound,
            selectedHole: 7,
            selectedTab: .matchups,
            timestamp: timestamp
        )

        store.save(state)
        XCTAssertEqual(store.load(), state)

        store.clear()
        XCTAssertNil(store.load())
    }

    func testTableRoundResumeStateRoundTrips() {
        let suiteName = "RoundResumeStoreTests.Table.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsRoundResumeStore(defaults: defaults, key: "resume")
        let state = RoundResumeState(
            roundID: "round_table",
            destination: .liveRound,
            selectedHole: 12,
            selectedTab: .table
        )

        store.save(state)

        XCTAssertEqual(store.load(), state)
    }

    func testLegacyScoringRoundResumeStateStillDecodes() throws {
        let json = """
        {
          "roundID": "legacy_round",
          "destination": "live_round",
          "selectedHole": 3,
          "selectedTab": "scoring",
          "timestamp": 1725000000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(RoundResumeState.self, from: json)

        XCTAssertEqual(decoded.selectedTab, .scoring)
        XCTAssertEqual(decoded.selectedHole, 3)
    }

    func testEmbeddedScoreTableRequiresExplicitEditMode() {
        XCTAssertFalse(
            ScorecardInteractionMode.view.allowsScoreEditing(
                presentation: .embeddedLiveTable,
                hasPermission: true
            )
        )
        XCTAssertTrue(
            ScorecardInteractionMode.edit.allowsScoreEditing(
                presentation: .embeddedLiveTable,
                hasPermission: true
            )
        )
        XCTAssertFalse(
            ScorecardInteractionMode.edit.allowsScoreEditing(
                presentation: .embeddedLiveTable,
                hasPermission: false
            )
        )
        XCTAssertTrue(
            ScorecardInteractionMode.view.allowsScoreEditing(
                presentation: .modal,
                hasPermission: true
            )
        )
    }

    func testResumeRoutingUsesAuthoritativeRoundStatus() {
        XCTAssertEqual(RoundResumeRouter.resolve(status: .lobby), .lobby)
        XCTAssertEqual(RoundResumeRouter.resolve(status: .live), .liveRound)
        XCTAssertEqual(RoundResumeRouter.resolve(status: .paused), .liveRound)
        XCTAssertEqual(RoundResumeRouter.resolve(status: .complete), .outcome)
        XCTAssertEqual(RoundResumeRouter.resolve(status: .archived), .discard)
    }
}

final class RoundProjectionSimulatorTests: XCTestCase {
    func testSeededProjectionIsDeterministicAndKeepsActualHolesFixed() async throws {
        let input = projectionInput(scoreBasis: .gross)

        let first = try await RoundProjectionSimulator.shared.simulate(
            input: input,
            iterations: 1_000,
            seed: 42
        )
        let retry = try await RoundProjectionSimulator.shared.simulate(
            input: input,
            iterations: 1_000,
            seed: 42
        )

        XCTAssertEqual(first.projection, retry.projection)
        XCTAssertEqual(first.finishScenarios, retry.finishScenarios)
        XCTAssertEqual(first.projection.holesCompleted, 3)
        XCTAssertEqual(
            first.projection.actualTrend,
            [
                ProjectionTrendPoint(holeNumber: 1, value: 0),
                ProjectionTrendPoint(holeNumber: 2, value: 1),
                ProjectionTrendPoint(holeNumber: 3, value: 0),
            ]
        )
        XCTAssertLessThanOrEqual(first.projection.lowerFinish, first.projection.medianFinish)
        XCTAssertLessThanOrEqual(first.projection.medianFinish, first.projection.upperFinish)
    }

    func testNetProjectionUsesAllocatedStrokesFromSameGrossScenarios() async throws {
        let gross = try await RoundProjectionSimulator.shared.simulate(
            input: projectionInput(scoreBasis: .gross),
            iterations: 1_000,
            seed: 99
        )
        let net = try await RoundProjectionSimulator.shared.simulate(
            input: projectionInput(scoreBasis: .net),
            iterations: 1_000,
            seed: 99
        )

        XCTAssertEqual(gross.finishScenarios.count, net.finishScenarios.count)
        for (grossFinish, netFinish) in zip(gross.finishScenarios, net.finishScenarios) {
            XCTAssertEqual(netFinish, grossFinish - 3)
        }
        XCTAssertEqual(net.projection.medianFinish, gross.projection.medianFinish - 3)
    }

    func testProjectionReportsConfidenceFromHistoricalSampleVolume() async throws {
        let limited = try await RoundProjectionSimulator.shared.simulate(
            input: projectionInput(scoreBasis: .gross, sampleMultiplier: 0),
            iterations: 250,
            seed: 1
        )
        let high = try await RoundProjectionSimulator.shared.simulate(
            input: projectionInput(scoreBasis: .gross, sampleMultiplier: 16),
            iterations: 250,
            seed: 1
        )

        XCTAssertEqual(limited.projection.confidence, .limited)
        XCTAssertEqual(high.projection.confidence, .high)
    }

    private func projectionInput(
        scoreBasis: ScoreBasis,
        sampleMultiplier: Int = 1
    ) -> PlayerProjectionInput {
        let baseSamples = [
            ProjectionHistoricalSample(grossRelativeToPar: 0, weight: 8),
            ProjectionHistoricalSample(grossRelativeToPar: 1, weight: 5),
            ProjectionHistoricalSample(grossRelativeToPar: 2, weight: 2),
        ]
        let samples = (0..<sampleMultiplier).flatMap { offset in
            baseSamples.map {
                ProjectionHistoricalSample(
                    grossRelativeToPar: $0.grossRelativeToPar + (offset % 2),
                    weight: $0.weight + Double(offset) / 100
                )
            }
        }
        return PlayerProjectionInput(
            participantID: "p1",
            scoreBasis: scoreBasis,
            handicapAllowance: 6,
            holes: [
                .init(holeNumber: 1, par: 4, strokesReceived: 1, recordedGross: 4, historicalSamples: samples),
                .init(holeNumber: 2, par: 4, strokesReceived: 1, recordedGross: 5, historicalSamples: samples),
                .init(holeNumber: 3, par: 3, strokesReceived: 1, recordedGross: 2, historicalSamples: samples),
                .init(holeNumber: 4, par: 5, strokesReceived: 0, recordedGross: nil, historicalSamples: samples),
                .init(holeNumber: 5, par: 4, strokesReceived: 0, recordedGross: nil, historicalSamples: samples),
                .init(holeNumber: 6, par: 4, strokesReceived: 0, recordedGross: nil, historicalSamples: samples),
            ]
        )
    }
}

final class MatchupProbabilitySimulatorTests: XCTestCase {
    func testBestTwoTeamScenariosFlowThroughScoringEngine() async throws {
        let snapshot = MockLiveRoundBest2of4Matchup.snapshot
        let holeCount = snapshot.roundSegment?.holeRange.count ?? 18
        let runCount = 100
        let simulations = Dictionary(uniqueKeysWithValues: snapshot.participants.map { participant in
            let isRed = participant.teamID == "team_red"
            let grossHoles = Array(repeating: isRed ? 0 : 1, count: holeCount)
            let finish = grossHoles.reduce(0, +)
            let projection = PlayerFinishProjection(
                participantID: participant.id,
                scoreBasis: .gross,
                holesCompleted: 0,
                sampleCount: 0,
                confidence: .limited,
                lowerFinish: finish,
                medianFinish: finish,
                upperFinish: finish,
                actualTrend: [],
                projectedTrend: []
            )
            return (
                participant.id,
                PlayerProjectionSimulation(
                    projection: projection,
                    finishScenarios: Array(repeating: finish, count: runCount),
                    holeScenarios: Array(repeating: grossHoles, count: runCount),
                    grossHoleScenarios: Array(repeating: grossHoles, count: runCount)
                )
            )
        })

        let values = try await MatchupProbabilitySimulator.shared.simulate(
            snapshot: snapshot,
            scoreBasis: .gross,
            playerSimulations: simulations
        )
        let probability = try XCTUnwrap(values["m1"])

        XCTAssertTrue(probability.isSupported)
        XCTAssertEqual(probability.leftWin, 100)
        XCTAssertEqual(probability.tie, 0)
        XCTAssertEqual(probability.rightWin, 0)
        XCTAssertEqual(probability.leftWin + probability.tie + probability.rightWin, 100)
    }
}

final class ProjectionCalibrationMetricsTests: XCTestCase {
    func testIntervalCoverageAndRolloutGate() {
        let observations = (0..<10).map { index in
            ProjectionHoldoutObservation(
                actualFinish: index < 8 ? 0 : 3,
                lowerFinish: -1,
                upperFinish: 1
            )
        }

        XCTAssertEqual(ProjectionCalibrationMetrics.intervalCoverage(observations), 0.8)
        XCTAssertTrue(ProjectionCalibrationMetrics.playerIntervalsMeetRolloutGate(observations))
    }

    func testMatchupBrierGateRequiresNoRegressionFromHandicapBaseline() {
        let outcomes: [MatchupCalibrationOutcome] = [.left, .right]
        let projection = outcomes.map { outcome in
            MatchupCalibrationObservation(
                leftProbability: outcome == .left ? 0.75 : 0.15,
                tieProbability: 0.10,
                rightProbability: outcome == .right ? 0.75 : 0.15,
                outcome: outcome
            )
        }
        let baseline = outcomes.map { outcome in
            MatchupCalibrationObservation(
                leftProbability: 0.45,
                tieProbability: 0.10,
                rightProbability: 0.45,
                outcome: outcome
            )
        }

        XCTAssertTrue(
            ProjectionCalibrationMetrics.matchupProbabilitiesMeetRolloutGate(
                observations: projection,
                handicapBaseline: baseline
            )
        )
    }
}

@MainActor
final class SeriesRoundPredictionContextTests: XCTestCase {
    func testOldCanonicalResultDecodesWithoutPredictionContext() throws {
        let source = result(predictionContext: nil)
        let encoded = try JSONEncoder().encode(source)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "prediction_context")

        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SeriesRoundResult.self, from: legacyData)

        XCTAssertNil(decoded.predictionContext)
        XCTAssertEqual(decoded.semanticHash, source.semanticHash)
    }

    func testPredictionContextRoundTripsWithoutChangingSemanticHash() throws {
        let context = SeriesRoundPredictionContext(
            courseID: "course_1",
            courseName: "The Hound",
            holeSegment: .front9,
            holeSamples: [
                .init(
                    seriesMemberID: "member_1",
                    participantID: "participant_1",
                    teeBoxID: "blue",
                    holeNumber: 1,
                    par: 4,
                    grossStrokes: 5
                )
            ]
        )
        let source = result(predictionContext: context)
        let decoded = try JSONDecoder().decode(
            SeriesRoundResult.self,
            from: JSONEncoder().encode(source)
        )

        XCTAssertEqual(decoded.predictionContext, context)
        XCTAssertEqual(decoded.semanticHash, "standings-semantic-hash")
    }

    func testCanonicalBuilderMapsIndividualGrossHoleToSeriesMember() throws {
        var snapshot = MockLobbyFoursome.snapshot
        var participant = try XCTUnwrap(snapshot.participants.first)
        participant.seriesMemberID = "member_1"
        snapshot.participants[0] = participant
        let hole = try XCTUnwrap(snapshot.defaultTee?.holes.first)
        snapshot.scoring = [
            ScoreEntry(
                id: ScoreEntry.makeID(hole: hole.number, segment: "segment_1", scoringUnit: participant.id),
                holeNumber: hole.number,
                segmentID: "segment_1",
                groupID: participant.groupID ?? "group_1",
                scoringUnitID: participant.id,
                participantIDs: [participant.id],
                strokes: hole.par + 1,
                entryMode: .strokes,
                entryID: participant.id,
                parentID: snapshot.round.id
            )
        ]

        let context = try XCTUnwrap(SeriesRoundCanonicalBuilder.predictionContext(snapshot: snapshot))
        let sample = try XCTUnwrap(context.holeSamples.first)

        XCTAssertEqual(context.courseID, "course_id")
        XCTAssertEqual(sample.seriesMemberID, "member_1")
        XCTAssertEqual(sample.holeNumber, hole.number)
        XCTAssertEqual(sample.par, hole.par)
        XCTAssertEqual(sample.grossStrokes, hole.par + 1)
    }

    private func result(
        predictionContext: SeriesRoundPredictionContext?
    ) -> SeriesRoundResult {
        SeriesRoundResult(
            id: "generation_1",
            seriesRoundID: "series_round_1",
            linkedRoundID: "round_1",
            sourceRevision: "source_1",
            sourceUpdatedAt: 1,
            policyRevisionID: nil,
            policyFingerprint: "policy_1",
            processorVersion: SeriesRoundCanonicalBuilder.processorVersion,
            semanticHash: "standings-semantic-hash",
            compatibility: [],
            performanceMetrics: [],
            pointAwards: [],
            handicapSamples: [],
            predictionContext: predictionContext,
            parentID: "series_1"
        )
    }
}

final class SeriesHandicapTrendTests: XCTestCase {
    func testTrendUsesBaselinesButOnlyPlotsCompletedOfficialRounds() throws {
        let baselineTime = Time(iso: "2026-01-01T00:00:00Z", unix: 100)
        let roundOneTime = Time(iso: "2026-02-01T00:00:00Z", unix: 200)
        let roundTwoTime = Time(iso: "2026-03-01T00:00:00Z", unix: 300)
        let scores = [
            handicapScore(id: "baseline", gross: 43, source: .baseline, roundID: nil, time: baselineTime),
            handicapScore(id: "round_1", gross: 41, source: .round, roundID: "linked_1", time: roundOneTime),
            handicapScore(id: "unofficial", gross: 30, source: .round, roundID: "linked_2", time: roundTwoTime, official: false),
            handicapScore(id: "round_2", gross: 45, source: .round, roundID: "linked_2", time: roundTwoTime),
        ]
        let rounds = [
            SeriesRound(id: "sr_2", title: "Week 2", index: 1, status: .complete, roundID: "linked_2", completedAt: roundTwoTime),
            SeriesRound(id: "sr_1", title: "Week 1", index: 0, status: .complete, roundID: "linked_1", completedAt: roundOneTime),
            SeriesRound(id: "sr_3", title: "Week 3", index: 2, status: .live, roundID: "linked_3"),
        ]

        let trend = SeriesHandicapProjectionService.trend(
            memberID: "member_1",
            scores: scores,
            rounds: rounds,
            handicapConfig: .init(isEnabled: true, config: .league2025)
        )

        XCTAssertEqual(trend.map(\.roundTitle), ["Week 1", "Week 2"])
        XCTAssertEqual(trend.map(\.sourceRoundID), ["linked_1", "linked_2"])
        XCTAssertEqual(trend.map(\.date), [
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 300),
        ])
    }

    private func handicapScore(
        id: String,
        gross: Double,
        source: SeriesHandicapScoreSourceType,
        roundID: String?,
        time: Time,
        official: Bool = true
    ) -> SeriesHandicapScore {
        SeriesHandicapScore(
            id: id,
            memberID: "member_1",
            score: gross,
            par: 36,
            holeSegment: .front9,
            source: source,
            sourceRoundID: roundID,
            recordedAt: time,
            createdAt: time,
            lastUpdatedAt: time,
            parentID: "series_1",
            countsTowardHandicapIndex: official
        )
    }
}

@MainActor
final class PlayerInsightsRoundAnalyticsTests: XCTestCase {
    func testGrossOutcomeMixAndHandicapUsageFollowRecordedHoles() throws {
        let (viewModel, participant) = try makeViewModel(relativeScores: [-1, 0, 1, 2, 3, 4])

        let counts = Dictionary(
            uniqueKeysWithValues: viewModel.grossScoreOutcomeCounts(for: participant).map {
                ($0.bucket, $0.count)
            }
        )
        XCTAssertEqual(counts[.birdieOrBetter], 1)
        XCTAssertEqual(counts[.par], 1)
        XCTAssertEqual(counts[.bogey], 1)
        XCTAssertEqual(counts[.doubleBogey], 1)
        XCTAssertEqual(counts[.tripleBogey], 1)
        XCTAssertEqual(counts[.fourOrWorse], 1)

        let usage = viewModel.handicapStrokeUsage(for: participant)
        let expectedUsed = viewModel.courseOrderHoleNumbers.prefix(6).reduce(0) {
            $0 + viewModel.strokesReceivedOnHole(participant: participant, holeNumber: $1)
        }
        let expectedTotal = viewModel.courseOrderHoleNumbers.reduce(0) {
            $0 + viewModel.strokesReceivedOnHole(participant: participant, holeNumber: $1)
        }
        XCTAssertEqual(usage.used, expectedUsed)
        XCTAssertEqual(usage.total, expectedTotal)
        XCTAssertEqual(usage.used + usage.remaining, expectedTotal)
        XCTAssertNil(viewModel.completedAveragePaceTrend(for: participant, basis: .gross))
    }

    func testCompletedRoundAveragePaceConnectsEvenToFinalScore() throws {
        let snapshot = MockLobbyFoursome.snapshot
        let holeCount = try XCTUnwrap(snapshot.holeRange?.holeNumbers.count)
        let scores = Array(repeating: 1, count: holeCount)
        let (viewModel, participant) = try makeViewModel(snapshot: snapshot, relativeScores: scores)

        let pace = try XCTUnwrap(
            viewModel.completedAveragePaceTrend(for: participant, basis: .gross)
        )
        XCTAssertEqual(pace.first?.value, 0)
        XCTAssertEqual(pace.last?.value, holeCount)
        XCTAssertEqual(pace.last?.holeNumber, viewModel.courseOrderHoleNumbers.last)
    }

    private func makeViewModel(
        snapshot: RoundSnapshot = MockLobbyFoursome.snapshot,
        relativeScores: [Int]
    ) throws -> (LiveRoundViewModel, RoundParticipant) {
        var snapshot = snapshot
        var participant = try XCTUnwrap(snapshot.participants.first)
        participant.handicapSnapshot = nil
        participant.leagueHandicapStrokesAtCreation = 6
        participant.adjustedHandicap = 6
        snapshot.participants = [participant]
        snapshot.round.configuration.handicapsEnabled = true

        let holeRange = try XCTUnwrap(snapshot.holeRange)
        let segment = RoundSegment(
            id: "segment_1",
            roundID: snapshot.round.id,
            holeRange: holeRange,
            gameFormat: .strokePlay,
            scoringUnits: [
                ScoringUnit(
                    id: participant.id,
                    owner: .participant,
                    ownerIDs: [participant.id],
                    scoringMethod: .individual
                )
            ],
            parentID: snapshot.round.id
        )
        snapshot.segments = [segment]
        let holes = snapshot.holeRange?.holeNumbers ?? []
        snapshot.scoring = zip(holes, relativeScores).map { pair in
            let (holeNumber, relative) = pair
            return ScoreEntry(
                id: ScoreEntry.makeID(
                    hole: holeNumber,
                    segment: segment.id,
                    scoringUnit: participant.id
                ),
                holeNumber: holeNumber,
                segmentID: segment.id,
                groupID: participant.groupID ?? "",
                scoringUnitID: participant.id,
                participantIDs: [participant.id],
                relativeToPar: relative,
                entryMode: .relativeToPar,
                entryID: participant.id,
                parentID: snapshot.round.id
            )
        }

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)
        return (viewModel, participant)
    }
}
