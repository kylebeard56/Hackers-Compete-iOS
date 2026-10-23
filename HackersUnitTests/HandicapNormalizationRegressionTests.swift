import XCTest
@testable import Hackers

@MainActor
final class HandicapNormalizationRegressionTests: XCTestCase {
    func testEveryPlayerReceivesDifferenceFromBestHandicap() throws {
        for segment in [HoleSegment.full18, .front9, .back9] {
            let snapshot = fixture(segment: segment, handicaps: [4, 12, 14, 18])
            let model = LiveRoundViewModel()
            model.set(snapshot: snapshot)
            let actual = snapshot.participants.map { participant in
                segment.holeRange.holeNumbers.reduce(0) {
                    $0 + model.strokesReceivedOnHole(participant: participant, holeNumber: $1)
                }
            }
            XCTAssertEqual(actual, [0, 8, 10, 14], "Subtract the best handicap from every player's allowance")
            XCTAssertEqual(ScoringEngine.scoringParticipants(in: snapshot, basis: .net).map(\.adjustedHandicap), actual)
            XCTAssertEqual(model.snapshot.participants.map(\.adjustedHandicap), [4, 12, 14, 18])
        }
    }

    func testFieldNormalizationMatchesScorecardAndStablefordForEveryLayout() throws {
        for segment in [HoleSegment.full18, .front9, .back9] {
            for handicaps in [[4, 12], [-2, 10], [-4, -2]] {
                let snapshot = fixture(segment: segment, handicaps: handicaps)
                let model = LiveRoundViewModel()
                model.set(snapshot: snapshot)
                let result = model.engineResult(for: .net)
                for participant in snapshot.participants {
                    let row = try XCTUnwrap(result.rows.first { $0.scoringUnitID == participant.id })
                    var expectedPoints = 0
                    for hole in segment.holeRange.holeNumbers {
                        let net = try XCTUnwrap(row.holeValues[hole]?.netStrokes)
                        XCTAssertEqual(model.strokesReceivedOnHole(participant: participant, holeNumber: hole), 4 - net)
                        XCTAssertEqual(model.netStrokesOnHole(participant: participant, holeNumber: hole), net)
                        expectedPoints += try XCTUnwrap(model.stablefordPoints(displayedStrokes: net, par: 4))
                    }
                    XCTAssertEqual(model.stablefordPointSummary(for: participant, basis: .net).total, expectedPoints)
                    XCTAssertEqual(model.stablefordPointSummary(for: participant, basis: .gross).total,
                        segment.holeCount * 2)
                }
                XCTAssertEqual(model.snapshot.participants.map(\.adjustedHandicap), handicaps)
                XCTAssertEqual(model.snapshot.participants.map(\.leagueHandicapStrokesAtCreation), handicaps.map(Optional.some))
            }
        }
    }

    func testChangingNormalizationModeUpdatesDisplayWithoutChangingSavedAllowances() throws {
        var snapshot = fixture(handicaps: [4, 12], mode: .off)
        let model = LiveRoundViewModel()
        for mode in [HandicapNormalizationMode.off, .field, .off] {
            snapshot.round.configuration.handicapNormalizationMode = mode
            model.set(snapshot: snapshot)
            let totals = snapshot.participants.map { participant in
                snapshot.holeRange!.holeNumbers.reduce(0) {
                    $0 + model.strokesReceivedOnHole(participant: participant, holeNumber: $1)
                }
            }
            XCTAssertEqual(totals, mode == .field ? [0, 8] : [4, 12])
            XCTAssertEqual(model.snapshot.participants.map(\.adjustedHandicap), [4, 12])
        }
    }

    func testExcludedPlayersDoNotSetDisplayedNormalizationBaseline() throws {
        var snapshot = fixture(handicaps: [4, 12, 0, -4])
        snapshot.participants[2].isSubstitute = true
        snapshot.participants[3].presenceStatus = .noShow
        snapshot.round.configuration.substitutesScore = false
        snapshot.round.configuration.attendanceConfirmationEnabled = true
        let model = LiveRoundViewModel()
        model.set(snapshot: snapshot)
        let rows = model.engineResult(for: .net).rows
        XCTAssertEqual(Set(rows.map(\.scoringUnitID)), Set(["p0", "p1"]))
        let totals = snapshot.participants.prefix(2).map { participant in
            snapshot.holeRange!.holeNumbers.reduce(0) {
                $0 + model.strokesReceivedOnHole(participant: participant, holeNumber: $1)
            }
        }
        XCTAssertEqual(totals, [0, 8])
        XCTAssertEqual(ScoringEngine.scoringParticipants(in: snapshot, basis: .net).map(\.adjustedHandicap), [0, 8])
        XCTAssertEqual(ScoringEngine.scoringParticipants(in: snapshot, basis: .gross).map(\.adjustedHandicap), [4, 12])
    }

    func testLegacyEighteenHoleStrokeBasisIsConvertedOnlyOnceOnNineHoles() throws {
        for segment in [HoleSegment.front9, .back9] {
            var snapshot = fixture(segment: segment, handicaps: [4, 12])
            snapshot.round.configuration.handicapStrokeBasis = .eighteenHole
            let model = LiveRoundViewModel()
            model.set(snapshot: snapshot)
            let totals = snapshot.participants.map { participant in
                segment.holeRange.holeNumbers.reduce(0) {
                    $0 + model.strokesReceivedOnHole(participant: participant, holeNumber: $1)
                }
            }
            XCTAssertEqual(totals, [0, 4])
            XCTAssertEqual(model.engineResult(for: .net).rows.first { $0.scoringUnitID == "p1" }?.total, -4)
        }
    }

    func testMatchupNormalizationKeepsSeparateBaselinesAndDoesNotNormalizeFieldDisplay() throws {
        var snapshot = fixture(handicaps: [4, 12, 14, 20], mode: .matchup)
        snapshot.round.configuration.competitionScope = .matchup
        snapshot.segments[0].templateID = FormatTemplateRegistry.matchPlayIndividual.id
        snapshot.segments[0].competitionScope = .matchup
        snapshot.segments[0].matchups = [
            .init(id: "first", teamIDs: [], participantIDs: ["p0", "p1"], mode: .individual),
            .init(id: "second", teamIDs: [], participantIDs: ["p2", "p3"], mode: .individual)
        ]
        let model = LiveRoundViewModel()
        model.set(snapshot: snapshot)
        let result = model.engineResult(for: .net)
        for (matchup, ids, allowances) in [("first", ["p0", "p1"], [0, 8]), ("second", ["p2", "p3"], [0, 6])] {
            let match = try XCTUnwrap(result.matchupResults.first { $0.matchup.id == matchup })
            for (id, allowance) in zip(ids, allowances) {
                let row = try XCTUnwrap(match.rows.first { $0.scoringUnitID == id })
                let total = row.holeValues.values.reduce(0) { $0 + 4 - ($1.netStrokes ?? 4) }
                XCTAssertEqual(total, allowance)
            }
        }
        XCTAssertEqual(snapshot.participants.map { ScoringEngine.playingHandicapAllowance(for: $0, in: snapshot) }, [4, 12, 14, 20])
    }

    func testManualRoundOverrideAndOriginalSnapshotsRemainUnchanged() throws {
        var snapshot = fixture(handicaps: [4, 12])
        snapshot.participants[1] = snapshot.participants[1].applyingLeagueHandicapOverride(16, maximum: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let original = try encoder.encode(snapshot.participants)
        let model = LiveRoundViewModel()
        model.set(snapshot: snapshot)
        let high = snapshot.participants[1]
        let strokes = snapshot.holeRange!.holeNumbers.reduce(0) {
            $0 + model.strokesReceivedOnHole(participant: high, holeNumber: $1)
        }
        XCTAssertEqual(strokes, 12)
        XCTAssertEqual(high.leagueHandicapComputedBaseline, 12)
        XCTAssertEqual(high.lockedHandicapAllowance, 16)
        XCTAssertEqual(try encoder.encode(model.snapshot.participants), original)
    }

    func testSharedScoreDotsAndLabelsUseNormalizedAllowanceBeforeAndAfterScoring() throws {
        var snapshot = fixture(handicaps: [4, 12, 14, 20])
        snapshot.round.configuration.formatSummary = .init(from: FormatTemplateRegistry.captainsChoice)
        snapshot.round.configuration.scoreOwnerScope = .partnership
        snapshot.round.configuration.sharedScoreHandicapConfig = .scramble2Player
        snapshot.segments[0].templateID = FormatTemplateRegistry.captainsChoice.id
        snapshot.teams = [
            .init(id: "red", name: "Red", color: "red", index: 0, createdAt: .init()),
            .init(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init())
        ]
        for index in snapshot.participants.indices {
            snapshot.participants[index].teamID = index < 2 ? "red" : "blue"
        }
        snapshot.scoringGroups = [
            .init(id: "pair0", teamID: "red", kind: .partnership, memberIDs: ["p0", "p1"], parentID: snapshot.round.id),
            .init(id: "pair1", teamID: "blue", kind: .partnership, memberIDs: ["p2", "p3"], parentID: snapshot.round.id)
        ]
        snapshot.segments[0].scoringUnits = snapshot.scoringGroups.map { group in
            var unit = ScoringUnit(id: group.id, owner: .scoreOwner, ownerIDs: group.memberIDs, scoringMethod: .aggregate)
            unit.handicapAllowance = ScoringEngine.handicapAllowance(
                participants: snapshot.participants.filter { group.memberIDs.contains($0.id) }, config: .scramble2Player)
            return unit
        }
        let storedUnits = snapshot.segments[0].scoringUnits
        let scores = snapshot.scoringGroups.flatMap { group in
            snapshot.holeRange!.holeNumbers.map { hole in
                ScoreEntry(id: ScoreEntry.makeID(hole: hole, segment: "seg", scoringUnit: group.id),
                    holeNumber: hole, segmentID: "seg", scoringUnitID: group.id, participantIDs: group.memberIDs,
                    strokes: 4, pickedUp: false, entryID: "p0", parentID: snapshot.round.id)
            }
        }
        let model = LiveRoundViewModel()
        for entries in [[], scores] {
            snapshot.scoring = entries
            model.set(snapshot: snapshot)
            XCTAssertEqual(model.scoringUnitHandicapDecimalLabel(scoringUnitID: "pair0"), "HCP 1.2")
            XCTAssertEqual(model.scoringUnitHandicapDecimalLabel(scoringUnitID: "pair1"), "HCP 5.9")
            for (id, expected) in [("pair0", 1), ("pair1", 6)] {
                let total = snapshot.holeRange!.holeNumbers.reduce(0) {
                    $0 + model.scoringUnitStrokesReceived(scoringUnitID: id, holeNumber: $1)
                }
                XCTAssertEqual(total, expected)
                if !entries.isEmpty {
                    let row = try XCTUnwrap(model.engineResult(for: .net).rows.first { $0.scoringUnitID == id })
                    for hole in snapshot.holeRange!.holeNumbers {
                        let net = try XCTUnwrap(row.holeValues[hole]?.netStrokes)
                        XCTAssertEqual(model.scoringUnitStrokesReceived(scoringUnitID: id, holeNumber: hole), 4 - net)
                    }
                }
            }
            XCTAssertEqual(model.snapshot.segments[0].scoringUnits, storedUnits)
        }
    }

    func testNetProjectionUsesFieldNormalizedStrokes() async throws {
        let snapshot = fixture(handicaps: [4, 12])
        let model = LiveRoundViewModel()
        model.set(snapshot: snapshot)
        for (participant, expected) in zip(snapshot.participants, [0, -8]) {
            let simulation = await model.playerSimulation(for: participant, scoreBasis: .net)
            XCTAssertEqual(try XCTUnwrap(simulation).projection.actualTrend.last?.value, expected)
        }
    }

    func testProjectionRevisionTracksAnotherPlayersNormalizationBaseline() throws {
        var snapshot = fixture(handicaps: [4, 12])
        let model = LiveRoundViewModel()
        model.set(snapshot: snapshot)
        let high = snapshot.participants[1]
        let before = model.playerProjectionRevision(for: high, scoreBasis: .net)
        snapshot.participants[0].adjustedHandicap = 2
        snapshot.participants[0].leagueHandicapStrokesAtCreation = 2
        model.set(snapshot: snapshot)
        XCTAssertNotEqual(model.playerProjectionRevision(for: high, scoreBasis: .net), before)
    }

    private func fixture(segment: HoleSegment = .full18, handicaps: [Int],
                         mode: HandicapNormalizationMode = .field) -> RoundSnapshot {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) }
        let tee = Tee(id: "tee", name: "White", gender: "male", totalHoles: 18,
                      holes: holes, ratingFull: 72, slopeFull: 113,
                      ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        let course = CourseSegment(courseInfo: .init(id: "course", name: "Normalization", totalHoles: 18, tees: [tee]),
                                   holeRange: segment.holeRange, defaultTee: tee.id)
        let participants = handicaps.enumerated().map { offset, handicap in
            RoundParticipant(id: "p\(offset)", name: Name("Player \(offset)"), teeBoxID: tee.id,
                adjustedHandicap: handicap, leagueHandicapStrokesAtCreation: handicap, parentID: "normalization-round")
        }
        let configuration = RoundConfiguration(primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlay), courses: [course],
            competitionScope: .field, handicapStrokeBasis: .defaultBasis(holeCount: segment.holeCount),
            handicapsEnabled: true, handicapNormalizationMode: mode, substitutesScore: true)
        let round = Round(id: "normalization-round", shareCode: "NORMALIZE", createdBy: "fixture", configuration: configuration)
        let scoringSegment = RoundSegment(id: "seg", roundID: round.id, holeRange: segment.holeRange,
                                         templateID: FormatTemplateRegistry.strokePlay.id)
        let scores = participants.flatMap { participant in
            segment.holeRange.holeNumbers.map { number in
                ScoreEntry(id: ScoreEntry.makeID(hole: number, segment: scoringSegment.id, scoringUnit: participant.id),
                    holeNumber: number, segmentID: scoringSegment.id, scoringUnitID: participant.id,
                    participantIDs: [participant.id], strokes: 4, pickedUp: false, entryID: participant.id, parentID: round.id)
            }
        }
        return RoundSnapshot(round: round, participants: participants, segments: [scoringSegment], scoring: scores)
    }
}
