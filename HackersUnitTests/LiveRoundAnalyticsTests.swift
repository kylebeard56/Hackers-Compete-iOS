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
        XCTAssertEqual(first.projection.sampleCount, 3)
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

    func testWiderHistoricalStandardDeviationProducesWiderFinishBand() async throws {
        let lowVariance = try await RoundProjectionSimulator.shared.simulate(
            input: dispersionInput(relativeScores: [0, 0, 0, 0, 0, 0]),
            iterations: 2_000,
            seed: 81
        )
        let highVariance = try await RoundProjectionSimulator.shared.simulate(
            input: dispersionInput(relativeScores: [-2, -1, 0, 2, 4, 6]),
            iterations: 2_000,
            seed: 81
        )

        let lowWidth = lowVariance.projection.upperFinish - lowVariance.projection.lowerFinish
        let highWidth = highVariance.projection.upperFinish - highVariance.projection.lowerFinish
        XCTAssertGreaterThan(highWidth, lowWidth)
    }

    private func projectionInput(
        scoreBasis: ScoreBasis,
        sampleMultiplier: Int = 1
    ) -> PlayerProjectionInput {
        let baseSamples = [
            ProjectionHistoricalSample(sourceID: "sample-0", grossRelativeToPar: 0, weight: 8),
            ProjectionHistoricalSample(sourceID: "sample-1", grossRelativeToPar: 1, weight: 5),
            ProjectionHistoricalSample(sourceID: "sample-2", grossRelativeToPar: 2, weight: 2),
        ]
        let samples = (0..<sampleMultiplier).flatMap { offset in
            baseSamples.map {
                ProjectionHistoricalSample(
                    sourceID: "\($0.sourceID)-\(offset)",
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
                .init(holeNumber: 1, par: 4, strokesReceived: 1, recordedGross: 4, isUnresolvedPickup: false, historicalSamples: samples),
                .init(holeNumber: 2, par: 4, strokesReceived: 1, recordedGross: 5, isUnresolvedPickup: false, historicalSamples: samples),
                .init(holeNumber: 3, par: 3, strokesReceived: 1, recordedGross: 2, isUnresolvedPickup: false, historicalSamples: samples),
                .init(holeNumber: 4, par: 5, strokesReceived: 0, recordedGross: nil, isUnresolvedPickup: false, historicalSamples: samples),
                .init(holeNumber: 5, par: 4, strokesReceived: 0, recordedGross: nil, isUnresolvedPickup: false, historicalSamples: samples),
                .init(holeNumber: 6, par: 4, strokesReceived: 0, recordedGross: nil, isUnresolvedPickup: false, historicalSamples: samples),
            ]
        )
    }

    private func dispersionInput(relativeScores: [Int]) -> PlayerProjectionInput {
        let samples = relativeScores.enumerated().map { index, score in
            ProjectionHistoricalSample(
                sourceID: "dispersion-\(index)",
                grossRelativeToPar: score,
                weight: 1
            )
        }
        return PlayerProjectionInput(
            participantID: "dispersion-player",
            scoreBasis: .gross,
            handicapAllowance: 0,
            holes: (1...18).map { holeNumber in
                ProjectionHoleInput(
                    holeNumber: holeNumber,
                    par: 4,
                    strokesReceived: 0,
                    recordedGross: nil,
                    isUnresolvedPickup: false,
                    historicalSamples: samples
                )
            }
        )
    }
}

final class MatchupProbabilitySimulatorTests: XCTestCase {
    func testExpectedShareSplitsTieProbabilityEvenly() {
        XCTAssertEqual(
            MatchupProbabilityTrendPoint(
                holesCompleted: 0,
                leftWin: 46,
                tie: 8,
                rightWin: 46
            ).leftExpectedShare,
            50
        )
        XCTAssertEqual(
            MatchupProbabilityTrendPoint(
                holesCompleted: 8,
                leftWin: 60,
                tie: 20,
                rightWin: 20
            ).leftExpectedShare,
            70
        )
        XCTAssertEqual(
            MatchupProbabilityTrendPoint(
                holesCompleted: 9,
                leftWin: 100,
                tie: 0,
                rightWin: 0
            ).leftExpectedShare,
            100
        )
    }

    func testFinalCountingStatusExpandsTieAcrossCutoff() {
        let statuses = MatchupCountingStatusResolver.resolve(
            participantIDs: ["greg", "kyle", "andrew", "joey"],
            countingParticipantIDs: ["greg", "kyle"],
            totalsByParticipantID: [
                "greg": -5,
                "kyle": -2,
                "andrew": -2,
                "joey": 1,
            ]
        )

        XCTAssertEqual(statuses["greg"], .counted)
        XCTAssertEqual(statuses["kyle"], .tiedAtCutoff)
        XCTAssertEqual(statuses["andrew"], .tiedAtCutoff)
        XCTAssertEqual(statuses["joey"], .notCounted)
    }

    func testFinalCountingStatusKeepsUntiedSelectionDefinitive() {
        let statuses = MatchupCountingStatusResolver.resolve(
            participantIDs: ["greg", "kyle", "andrew"],
            countingParticipantIDs: ["greg", "kyle"],
            totalsByParticipantID: ["greg": -5, "kyle": -2, "andrew": 0]
        )

        XCTAssertEqual(statuses["greg"], .counted)
        XCTAssertEqual(statuses["kyle"], .counted)
        XCTAssertEqual(statuses["andrew"], .notCounted)
    }

    func testTargetedSimulationOnlyRequiresPlayersFromRequestedMatchup() async throws {
        let snapshot = MockLobbySixteenWithTeams.snapshotWithMatchups
        let participantIDs = Set(snapshot.participants.compactMap { participant in
            participant.teamID == "team_red" || participant.teamID == "team_blue"
                ? participant.id
                : nil
        })
        let targetedSimulations = simulations(for: snapshot).filter {
            participantIDs.contains($0.key)
        }

        let values = try await MatchupProbabilitySimulator.shared.simulate(
            snapshot: snapshot,
            scoreBasis: .gross,
            playerSimulations: targetedSimulations,
            matchupIDs: ["m1"],
            participantIDs: participantIDs
        )

        XCTAssertEqual(Set(values.keys), ["m1"])
        XCTAssertEqual(values["m1"]?.isSupported, true)
    }

    func testBestTwoTeamScenariosFlowThroughScoringEngine() async throws {
        let snapshot = MockLiveRoundBest2of4Matchup.snapshot
        let simulations = simulations(for: snapshot)

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
        XCTAssertEqual(probability.participantCountingProbabilities["p01"], 100)
        XCTAssertEqual(probability.participantCountingProbabilities["p02"], 100)
        XCTAssertEqual(probability.participantCountingProbabilities["p05"], 0)
        XCTAssertEqual(
            probability.participantCountingProbabilities.values.reduce(0, +),
            400
        )
    }

    func testNoShowsAreExcludedWhileUnequalBestTwoSidesRemainSupported() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.attendanceConfirmationEnabled = true
        snapshot.participants = snapshot.participants.map { participant in
            var copy = participant
            if participant.id == "p01" || participant.id == "p02" {
                copy.presenceStatus = .noShow
            } else {
                copy.presenceStatus = .active
            }
            return copy
        }
        let eligibleIDs = Set(
            ScoringEngine.scoringEligibleParticipants(
                snapshot.participants,
                substitutesScore: snapshot.configuration.substitutesScore,
                attendanceConfirmationEnabled: true
            ).map(\.id)
        )
        let simulations = simulations(for: snapshot).filter { eligibleIDs.contains($0.key) }

        let values = try await MatchupProbabilitySimulator.shared.simulate(
            snapshot: snapshot,
            scoreBasis: .gross,
            playerSimulations: simulations
        )
        let probability = try XCTUnwrap(values["m1"])

        XCTAssertEqual(eligibleIDs.count, 6)
        XCTAssertTrue(probability.isSupported)
        XCTAssertEqual(probability.leftWin, 100)
    }

    func testBestTwoTreatsUnresolvedPickupAsNonCounting() async throws {
        let snapshot = MockLiveRoundBest2of4Matchup.snapshot
        let simulations = simulations(
            for: snapshot,
            unresolvedPickups: ["p01": [1]]
        )

        let values = try await MatchupProbabilitySimulator.shared.simulate(
            snapshot: snapshot,
            scoreBasis: .gross,
            playerSimulations: simulations
        )
        let probability = try XCTUnwrap(values["m1"])

        XCTAssertTrue(probability.isSupported)
        XCTAssertEqual(probability.leftWin, 100)
    }

    func testAggregateStrokePlayRequiresUnresolvedPickupToBeResolved() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.teamScoring = .init(mode: .all, count: 2, scope: .perRound)
        let simulations = simulations(
            for: snapshot,
            unresolvedPickups: ["p01": [1]]
        )

        let values = try await MatchupProbabilitySimulator.shared.simulate(
            snapshot: snapshot,
            scoreBasis: .gross,
            playerSimulations: simulations
        )
        let probability = try XCTUnwrap(values["m1"])

        XCTAssertFalse(probability.isSupported)
        XCTAssertEqual(
            probability.unsupportedReason,
            "Resolve picked-up holes before estimating this matchup."
        )
    }

    func testStablefordTreatsUnresolvedPickupAsZeroContribution() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.formatSummary = RoundFormatSummary(
            from: FormatTemplateRegistry.stableford
        )
        snapshot.round.configuration.teamScoring = .init(mode: .all, count: 2, scope: .perRound)
        snapshot.segments[0].templateID = FormatTemplateRegistry.stableford.id
        let simulations = simulations(
            for: snapshot,
            unresolvedPickups: ["p01": [1]]
        )

        let values = try await MatchupProbabilitySimulator.shared.simulate(
            snapshot: snapshot,
            scoreBasis: .gross,
            playerSimulations: simulations
        )
        let probability = try XCTUnwrap(values["m1"])

        XCTAssertTrue(probability.isSupported)
        XCTAssertNil(probability.unsupportedReason)
    }

    private func simulations(
        for snapshot: RoundSnapshot,
        unresolvedPickups: [String: Set<Int>] = [:]
    ) -> [String: PlayerProjectionSimulation] {
        let holeCount = snapshot.roundSegment?.holeRange.count ?? 18
        let runCount = 100
        return Dictionary(uniqueKeysWithValues: snapshot.participants.map { participant in
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
                    grossHoleScenarios: Array(repeating: grossHoles, count: runCount),
                    unresolvedPickupHoleNumbers: unresolvedPickups[participant.id] ?? []
                )
            )
        })
    }
}

final class LiveRoundProjectionIntegrationTests: XCTestCase {
    @MainActor
    func testHandicappedMatchupProbabilityRemainsNetWhileGrossScoresAreDisplayed() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.handicapsEnabled = true
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)
        viewModel.matchupScoreBasis = .gross

        let matchup = try XCTUnwrap(snapshot.roundSegment?.matchups?.first)
        XCTAssertEqual(viewModel.matchupProbabilityScoreBasis, .net)
        XCTAssertEqual(
            viewModel.matchupProbabilityRevision(for: matchup),
            viewModel.matchupProbabilityRevision(for: matchup, scoreBasis: .net)
        )

        await viewModel.refreshMatchupProbabilities()

        let probabilities = viewModel.publishableMatchupProbabilities
        XCTAssertFalse(probabilities.isEmpty)
        XCTAssertTrue(probabilities.values.allSatisfy { $0.scoreBasis == .net })

        let originalProbabilities = viewModel.matchupProbabilities
        viewModel.matchupScoreBasis = .net
        XCTAssertEqual(viewModel.matchupProbabilities, originalProbabilities)
    }

    @MainActor
    func testNonHandicappedMatchupProbabilityUsesGrossCompetitionBasis() {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.handicapsEnabled = false
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)
        viewModel.matchupScoreBasis = .net

        XCTAssertEqual(viewModel.matchupProbabilityScoreBasis, .gross)
    }

    @MainActor
    func testMatchupRevisionOnlyChangesForMatchupContainingScoredPlayer() throws {
        var snapshot = MockLobbySixteenWithTeams.snapshotWithMatchups
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)

        let matchups = try XCTUnwrap(snapshot.roundSegment?.matchups)
        let firstMatchup = try XCTUnwrap(matchups.first { $0.id == "m1" })
        let secondMatchup = try XCTUnwrap(matchups.first { $0.id == "m2" })
        let scoredParticipant = try XCTUnwrap(snapshot.participants.first { $0.id == "p01" })
        let unaffectedParticipant = try XCTUnwrap(snapshot.participants.first { $0.id == "p03" })
        let segment = try XCTUnwrap(snapshot.roundSegment)

        let firstRevisionBefore = viewModel.matchupProbabilityRevision(for: firstMatchup, scoreBasis: .gross)
        let secondRevisionBefore = viewModel.matchupProbabilityRevision(for: secondMatchup, scoreBasis: .gross)
        let playerRevisionBefore = viewModel.playerProjectionRevision(
            for: unaffectedParticipant,
            scoreBasis: .gross
        )

        snapshot.scoring.append(ScoreEntry(
            id: ScoreEntry.makeID(hole: 1, segment: segment.id, scoringUnit: scoredParticipant.id),
            holeNumber: 1,
            segmentID: segment.id,
            groupID: scoredParticipant.groupID ?? "",
            scoringUnitID: scoredParticipant.id,
            participantIDs: [scoredParticipant.id],
            strokes: 4,
            pickedUp: false,
            entryID: scoredParticipant.id,
            parentID: snapshot.round.id
        ))
        viewModel.set(snapshot: snapshot)

        XCTAssertNotEqual(
            viewModel.matchupProbabilityRevision(for: firstMatchup, scoreBasis: .gross),
            firstRevisionBefore
        )
        XCTAssertEqual(
            viewModel.matchupProbabilityRevision(for: secondMatchup, scoreBasis: .gross),
            secondRevisionBefore
        )
        XCTAssertEqual(
            viewModel.playerProjectionRevision(for: unaffectedParticipant, scoreBasis: .gross),
            playerRevisionBefore
        )
    }

    func testQualityRadarOrderRunsClockwiseFromBestToWorst() {
        XCTAssertEqual(
            GrossScoreOutcomeBucket.qualityRadarOrder,
            [.birdieOrBetter, .par, .bogey, .doubleBogey, .tripleBogey]
        )
    }

    @MainActor
    func testGrossAndNetUseTheSameProductionGrossScenarios() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.handicapsEnabled = true
        let participant = try XCTUnwrap(snapshot.participants.first)
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)

        let grossResult = await viewModel.playerSimulation(for: participant, scoreBasis: .gross)
        let netResult = await viewModel.playerSimulation(for: participant, scoreBasis: .net)
        let gross = try XCTUnwrap(grossResult)
        let net = try XCTUnwrap(netResult)

        XCTAssertEqual(gross.grossHoleScenarios, net.grossHoleScenarios)
        XCTAssertTrue(gross.finishScenarios.isEmpty)
        XCTAssertTrue(net.finishScenarios.isEmpty)
        XCTAssertNotEqual(gross.projection.medianFinish, net.projection.medianFinish)
        XCTAssertNotEqual(
            viewModel.projectionRevision(scoreBasis: .gross),
            viewModel.projectionRevision(scoreBasis: .net)
        )
    }

    @MainActor
    func testUnresolvedPickupExplainsWhyPlayerFinishIsUnavailable() throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        let participant = try XCTUnwrap(snapshot.participants.first)
        let scoredIndex = try XCTUnwrap(
            snapshot.scoring.firstIndex {
                $0.scoringUnitID == participant.id && $0.holeNumber == 1
            }
        )
        snapshot.scoring[scoredIndex].strokes = nil
        snapshot.scoring[scoredIndex].relativeToPar = nil
        snapshot.scoring[scoredIndex].pickedUp = true
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)

        XCTAssertEqual(
            viewModel.playerProjectionUnavailableReason(for: participant),
            "Finish projection needs a resolved score for each picked-up hole."
        )
    }

    @MainActor
    func testPickupWithRecordedMaximumDoesNotBlockPlayerFinish() throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        let participant = try XCTUnwrap(snapshot.participants.first)
        let scoredIndex = try XCTUnwrap(
            snapshot.scoring.firstIndex {
                $0.scoringUnitID == participant.id && $0.holeNumber == 1
            }
        )
        snapshot.scoring[scoredIndex].strokes = 8
        snapshot.scoring[scoredIndex].relativeToPar = nil
        snapshot.scoring[scoredIndex].pickedUp = true
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)

        XCTAssertNil(viewModel.playerProjectionUnavailableReason(for: participant))
    }

    @MainActor
    func testMatchupTimelineReplaysEveryRecordedCheckpoint() async throws {
        let snapshot = MockLiveRoundBest2of4Matchup.snapshot
        let matchup = try XCTUnwrap(snapshot.roundSegment?.matchups?.first)
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)

        let probabilityTimeline = await viewModel.matchupProbabilityTimeline(
            for: matchup,
            scoreBasis: .gross
        )

        XCTAssertNil(probabilityTimeline.unsupportedReason)
        XCTAssertEqual(probabilityTimeline.points.map(\.holesCompleted), [0, 1, 2, 3, 4])
        XCTAssertTrue(probabilityTimeline.points.allSatisfy {
            $0.leftWin + $0.tie + $0.rightWin == 100
        })
        XCTAssertEqual(
            probabilityTimeline.latest?.participantCountingProbabilities.count,
            snapshot.participants.count
        )

        let scoreTimeline = viewModel.matchupScoreTimeline(for: matchup, scoreBasis: .gross)
        XCTAssertEqual(scoreTimeline.map(\.holesCompleted), [1, 2, 3, 4])
        XCTAssertEqual(scoreTimeline.last?.holesCompleted, probabilityTimeline.points.last?.holesCompleted)

        let cachedTimeline = await viewModel.matchupProbabilityTimeline(
            for: matchup,
            scoreBasis: .gross
        )
        XCTAssertEqual(cachedTimeline, probabilityTimeline)
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
    func testCumulativeStrokeTrendUsesCompletedHoleOrderForGrossAndNet() throws {
        let relativeScores = [0, 1, -1]
        let (viewModel, participant) = try makeViewModel(relativeScores: relativeScores)
        let gross = viewModel.cumulativeStrokeTrend(for: participant, basis: .gross)
        let net = viewModel.cumulativeStrokeTrend(for: participant, basis: .net)

        XCTAssertEqual(gross.map(\.holesCompleted), [1, 2, 3])
        XCTAssertEqual(gross.map(\.holeNumber), Array(viewModel.courseOrderHoleNumbers.prefix(3)))

        var expectedGross = 0
        let expectedGrossTotals = zip(viewModel.courseOrderHoleNumbers, relativeScores).map {
            expectedGross += (viewModel.hole(for: $0.0)?.par ?? 0) + $0.1
            return expectedGross
        }
        XCTAssertEqual(gross.map(\.strokes), expectedGrossTotals)

        var expectedNet = 0
        let expectedNetTotals = zip(viewModel.courseOrderHoleNumbers, relativeScores).map {
            let grossStrokes = (viewModel.hole(for: $0.0)?.par ?? 0) + $0.1
            expectedNet += grossStrokes - viewModel.strokesReceivedOnHole(
                participant: participant,
                holeNumber: $0.0
            )
            return expectedNet
        }
        XCTAssertEqual(net.map(\.strokes), expectedNetTotals)
    }

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
        XCTAssertEqual(counts[.tripleBogey], 2)

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


@MainActor
final class LiveRoundResumeRegressionTests: XCTestCase {
    private func store() -> UserDefaultsRoundResumeStore {
        UserDefaultsRoundResumeStore(defaults: UserDefaults(suiteName: "LiveRoundResume.\(UUID())")!)
    }

    func testStandardAndShotgunRelaunchRestoreLastDisplayedHole() {
        for (start, current) in [(1, 5), (7, 10)] {
            let persistence = store()
            let app = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
            app.activeRoundID = MockLiveRound2v2.roundID
            app.updateLiveRoundResume(selectedHole: start, selectedTab: .scoring)
            app.updateLiveRoundResume(selectedHole: current, selectedTab: .scoring)

            let relaunched = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
            var snapshot = MockLiveRound2v2.snapshot
            snapshot.teeGroups = snapshot.teeGroups.map { group in
                var group = group
                group.startingHole = start
                return group
            }
            let model = LiveRoundViewModel()
            model.set(snapshot: snapshot)
            model.restoreCurrentHole(relaunched.roundResumeState?.selectedHole)
            XCTAssertEqual(model.currentHoleNumber, current)
            // Repeated cache/server snapshots and late access loading must not reset selection.
            model.set(snapshot: snapshot)
            XCTAssertEqual(model.currentHoleNumber, current)
            XCTAssertFalse(model.isOverviewVisible)
            XCTAssertFalse(model.isLoadingOverview)
            XCTAssertNil(model.seriesScoreboardSnapshot)
        }
    }

    func testDisplayedHoleIsCapturedByScoreSessionAcrossNavigation() throws {
        let model = LiveRoundViewModel()
        let snapshot = MockLiveRound2v2.snapshot
        model.set(snapshot: snapshot)
        model.restoreCurrentHole(10)
        let participant = try XCTUnwrap(snapshot.participants.first)
        let entry = model.scoringSession(for: participant, holeNumber: model.currentHoleNumber)
        model.selectHole(11)
        XCTAssertEqual(entry.holeNumber, 10)
        XCTAssertNotEqual(
            ScoreEntry.makeID(hole: entry.holeNumber, segment: "segment", scoringUnit: participant.id),
            ScoreEntry.makeID(hole: 7, segment: "segment", scoringUnit: participant.id)
        )
    }

    func testExitPreservesHoleAndSuppressesAutomaticResumeUntilReopened() async {
        let persistence = store()
        let app = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
        app.activeRoundID = "round"
        app.updateLiveRoundResume(selectedHole: 5, selectedTab: .scoring)
        app.routeTo(.liveRound)
        app.exitLiveRound()
        XCTAssertEqual(persistence.load()?.selectedHole, 5)
        XCTAssertEqual(persistence.load()?.wasExplicitlyExited, true)
        let relaunched = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
        await relaunched.restoreRoundOrRouteToDashboard()
        XCTAssertNil(relaunched.activeRoundID)
        relaunched.activeRoundID = "round"
        relaunched.routeTo(.liveRound)
        XCTAssertEqual(persistence.load()?.selectedHole, 5)
        XCTAssertNotEqual(persistence.load()?.wasExplicitlyExited, true)
    }

    func testEachUnfinishedRoundRetainsItsOwnHole() {
        let persistence = store()
        let app = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
        app.activeRoundID = "first"
        app.updateLiveRoundResume(selectedHole: 5, selectedTab: .scoring)
        app.exitLiveRound()
        app.activeRoundID = "second"
        app.updateLiveRoundResume(selectedHole: 10, selectedTab: .scoring)
        app.activeRoundID = "first"
        app.routeTo(.liveRound)
        XCTAssertEqual(app.roundResumeState?.selectedHole, 5)
        XCTAssertEqual(persistence.load(roundID: "second")?.selectedHole, 10)
    }

    func testLiveRelaunchRoutesWithoutNetworkAndCompletionClearsResume() async {
        let persistence = store()
        persistence.save(RoundResumeState(roundID: "offline", destination: .liveRound, selectedHole: 10))
        let app = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
        await app.restoreRoundOrRouteToDashboard()
        XCTAssertEqual(app.activeRoundID, "offline")
        XCTAssertEqual(app.roundResumeState?.selectedHole, 10)
        app.clearRoundResume()
        XCTAssertNil(persistence.load())
        XCTAssertNil(persistence.load(roundID: "offline"))
    }

    func testRestoredHoleSurvivesDelayedStartupNudge() async throws {
        let persistence = store()
        let app = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
        let session = RoundSession()
        session.snapshot = MockLiveRound2v2.snapshot
        app.activeRoundID = session.snapshot.round.id
        app.ephemeralParticipantID = session.snapshot.participants.first?.id
        let model = LiveRoundViewModel()
        model.seriesAccessOverride = .init(seriesID: nil, isCommissioner: false)
        model.bind(appSession: app, roundSession: session)
        await model.ensureParticipantResolved()
        model.restoreCurrentHole(5)
        try await Task.sleep(for: .milliseconds(750))
        XCTAssertEqual(model.currentHoleNumber, 5)
        session.snapshot = MockLiveRound2v2.snapshot
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.currentHoleNumber, 5)
    }

    func testRestoredHoleSurvivesReadinessTimeoutBeforeSnapshotHydration() throws {
        let persistence = store()
        let app = AppSession(roundResumeStore: persistence, restoresAuthentication: false)
        app.activeRoundID = MockLiveRound2v2.roundID
        app.updateLiveRoundResume(selectedHole: 5, selectedTab: .scoring)

        let model = LiveRoundViewModel()
        model.set(snapshot: .init())
        model.restoreCurrentHole(app.roundResumeState?.selectedHole)

        // This is the value LiveRound persists when the readiness timeout opens
        // score entry before any cached or server snapshot is usable.
        app.updateLiveRoundResume(selectedHole: model.currentHoleNumber, selectedTab: .scoring)
        XCTAssertEqual(persistence.load()?.selectedHole, 5)

        model.set(snapshot: MockLiveRound2v2.snapshot)
        XCTAssertEqual(model.currentHoleNumber, 5)
        XCTAssertEqual(persistence.load()?.selectedHole, 5)
    }
}
