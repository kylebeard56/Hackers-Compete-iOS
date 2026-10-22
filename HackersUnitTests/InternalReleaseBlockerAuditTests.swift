import XCTest
@testable import Hackers

/// Release blockers retained as normal regression coverage.
final class InternalReleaseBlockerAuditTests: XCTestCase {
    private func snapshot(_ id: String, playedAt: Double) -> RoundSnapshot {
        let tee = Tee(id: "tee", name: "White", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        let course = CourseSegment(courseInfo: .init(id: "course", name: "Course", totalHoles: 18, tees: [tee]),
            holeRange: .init(startHole: 1, endHole: 18), defaultTee: tee.id)
        let time = Time(for: Date(timeIntervalSince1970: playedAt))
        let round = Round(id: id, status: .complete, players: ["player"], firstScoredAt: time,
            configuration: .init(formatSummary: .init(templateID: "stroke_play"), courses: [course]),
            createdAt: time, lastUpdatedAt: time)
        var participant = RoundParticipant(id: "participant", playerID: "player", teeBoxID: tee.id)
        participant.seriesMemberID = "league-member"
        let segment = RoundSegment(id: "segment", roundID: id, holeRange: course.holeRange,
            templateID: "stroke_play", scoringUnits: [.init(id: participant.id, owner: .participant, ownerIDs: [participant.id])])
        let scores = (1...18).map { ScoreEntry(id: "h\($0)", holeNumber: $0, segmentID: segment.id,
            scoringUnitID: participant.id, participantIDs: [participant.id], strokes: 10, parentID: id) }
        return .init(round: round, participants: [participant], segments: [segment], scoring: scores)
    }

    func testPlusPersonalIndexMustRetainSignedPlayingStrokes() throws {
        let course = snapshot("round", playedAt: 1_700_000_000).configuration.courses[0]
        let config = RoundConfiguration(courses: [course], handicapIndexBasis: .eighteenHole,
            handicapsEnabled: true, handicapEntryFormat: .courseHandicap)
        var player = Player(id: "player", userID: "user", name: Name("Plus", "Player"))
        player.personalHandicap = .init(manual: try .init(value: -2, source: .manual))
        let participant = PersonalHandicapRoundPrefill.participant(.init(player: player, teeBoxID: "tee"),
            player: player, configuration: config, isLeagueRound: false)
        XCTAssertEqual(participant.handicapResolution?.calculation?.courseHandicap, -2)
        XCTAssertEqual(participant.adjustedHandicap, -2, "Plus two must not become scratch")
        XCTAssertEqual(ScoringEngine.strokesReceived(handicap: -2, holeHandicap: 18, useHandicaps: true), -1)
    }

    func testResavingManualIndexMustNotRecalculateUnchangedHistoricalLeagueCards() throws {
        let base = 1_700_000_000.0
        let reviews = (0..<3).map { n in
            PersonalHandicapEligibility.review(snapshot("league-\(n)", playedAt: base + Double(n) * 86400), playerID: "player")
        }
        var profile = Player(id: "player", userID: "user", name: Name("Historical", "Player"))
        profile.personalHandicap = .init(manual: try .init(value: 10, source: .manual,
            updatedAt: .init(for: Date(timeIntervalSince1970: base - 86400))))
        let before = PersonalHandicapEngine.rebuild(playerID: "player", reviews: reviews, manual: profile.personalHandicap?.manual)
        let resaved = try profile.settingManualPersonalHandicap(.init(value: 10, source: .manual,
            updatedAt: .init(for: Date(timeIntervalSince1970: base + 3 * 86400))), as: "user")
        let after = PersonalHandicapEngine.rebuild(playerID: "player", reviews: reviews, manual: resaved.personalHandicap?.manual)
        XCTAssertEqual(before.calculation.qualifiedIndex, 44)
        XCTAssertEqual(before.scores.first?.adjustedGrossScore, 118)
        XCTAssertEqual(after.scores.first?.personalIndexAtPlay, 10)
        XCTAssertEqual(after.scores.first?.adjustedGrossScore, before.scores.first?.adjustedGrossScore)
        XCTAssertEqual(after.calculation.qualifiedIndex, before.calculation.qualifiedIndex)
    }
}

extension InternalReleaseBlockerAuditTests {
    func testPlusStrokesAcrossFullAndNineHoleMapsPreserveTotalsAndOrder() {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) }
        for handicap in [-38, -20, -18, -2, 0, 2, 18, 20, 38] {
            let allocations = holes.map { ScoringEngine.strokesReceived(handicap: handicap,
                holeNumber: $0.number, holes: holes, playedHoleNumbers: Array(1...18), useHandicaps: true) }
            XCTAssertEqual(allocations.reduce(0, +), handicap)
            for i in 0..<18 {
                XCTAssertEqual(allocations[i], ScoringEngine.strokesReceived(handicap: handicap, holeHandicap: i + 1, useHandicaps: true))
            }
        }
        let plusTwo = holes.map { ScoringEngine.strokesReceived(handicap: -2,
            holeNumber: $0.number, holes: holes, playedHoleNumbers: Array(1...18), useHandicaps: true) }
        XCTAssertEqual(plusTwo, Array(repeating: 0, count: 16) + [-1, -1])
        let nine = Array(10...18)
        let nineStrokes = nine.map { ScoringEngine.strokesReceived(handicap: -2,
            holeNumber: $0, holes: holes, playedHoleNumbers: nine, useHandicaps: true, handicapStrokeBasis: .nineHole) }
        XCTAssertEqual(nineStrokes, Array(repeating: 0, count: 7) + [-1, -1])
        XCTAssertEqual(ScoringEngine.handicapStrokesForPlayedHoles(handicap: -2, basis: .eighteenHole, holesInPlay: 9), -1)
        XCTAssertEqual(ScoringEngine.strokesReceived(handicap: -2, holeHandicap: 18, useHandicaps: false), 0)
    }

    func testPlusNormalizationUsesSignedBaselineAndCapsStayUpperBounds() {
        let field = [RoundParticipant(id: "plus", adjustedHandicap: -2), RoundParticipant(id: "positive", adjustedHandicap: 10)]
        XCTAssertEqual(HandicapCalculator.normalizedParticipantsForField(field).map(\.adjustedHandicap), [0, 12])
        let regular = [RoundParticipant(id: "a", adjustedHandicap: 5), RoundParticipant(id: "b", adjustedHandicap: 10)]
        XCTAssertEqual(HandicapCalculator.normalizedParticipantsForField(regular).map(\.adjustedHandicap), [0, 5])
        let course = snapshot("caps", playedAt: 100).configuration.courses[0]
        let plus = HandicapCalculator.participant(.init(id: "p", teeBoxID: "tee"), applying: -2, format: .courseHandicap,
            courseSegment: course, maximumHandicap: 21, handicapStrokeBasis: .eighteenHole)
        let positive = HandicapCalculator.participant(.init(id: "p", teeBoxID: "tee"), applying: 30, format: .courseHandicap,
            courseSegment: course, maximumHandicap: 21, handicapStrokeBasis: .eighteenHole)
        XCTAssertEqual(plus.adjustedHandicap, -2)
        XCTAssertEqual(positive.adjustedHandicap, 21)
    }

    func testEditingManualValueRetainsHistoricalInputsAndProvenanceAfterRoundTrip() throws {
        let base = 1_700_000_000.0
        let sources = (0..<3).map { snapshot("edited-\($0)", playedAt: base + Double($0) * 86400) }
        let reviews = sources.map { PersonalHandicapEligibility.review($0, playerID: "player") }
        var player = Player(id: "player", userID: "user", name: Name("Test", "Player"))
        player.personalHandicap = .init(manual: try .init(value: 10, source: .external,
            updatedAt: .init(for: Date(timeIntervalSince1970: base - 86400))))
        let before = PersonalHandicapEngine.rebuild(playerID: "player", reviews: reviews, manual: player.personalHandicap?.manual)
        let edited = try player.settingManualPersonalHandicap(.init(value: 20, source: .manual,
            updatedAt: .init(for: Date(timeIntervalSince1970: base + 4 * 86400))), as: "user")
        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(edited))
        let after = PersonalHandicapEngine.rebuild(playerID: "player", reviews: reviews,
            manual: decoded.personalHandicap?.manual, manualHistory: decoded.personalHandicap?.manualHistory ?? [])
        XCTAssertEqual(after.scores.map(\.personalIndexAtPlay), before.scores.map(\.personalIndexAtPlay))
        XCTAssertEqual(after.scores.map(\.personalIndexProvenance), before.scores.map(\.personalIndexProvenance))
        XCTAssertEqual(after.scores.map(\.adjustedGrossScore), before.scores.map(\.adjustedGrossScore))
        XCTAssertEqual(after.calculation.qualifiedIndex, before.calculation.qualifiedIndex)
        XCTAssertEqual(after.scores.first?.personalIndexProvenance, "external_as_of_recorded_play")
        XCTAssertEqual(decoded.personalHandicap?.manualHistory.count, 2)
        XCTAssertEqual(decoded.personalHandicap?.manualInput(at: .init(for: Date(timeIntervalSince1970: base)))?.value, 10)
        XCTAssertEqual(decoded.personalHandicap?.manualInput(at: .init(for: Date(timeIntervalSince1970: base + 5 * 86400)))?.value, 20)
        // No source scorecards or frozen league allowances were touched.
        XCTAssertTrue(sources.allSatisfy { $0.scoring.allSatisfy { $0.strokes == 10 } })
        XCTAssertTrue(sources.allSatisfy { $0.participants[0].adjustedHandicap == 0 })
    }

    func testManualEditsAndClearApplyOnlyFromTheirEffectiveDates() throws {
        func date(_ n: Double) -> Time { .init(for: Date(timeIntervalSince1970: n)) }
        var player = Player(id: "player", userID: "user", name: Name("Test", "Player"))
        player.personalHandicap = .init(manual: try .init(value: 10, source: .external, updatedAt: date(100)))
        player = try player.settingManualPersonalHandicap(.init(value: 20, source: .manual, updatedAt: date(200)), as: "user", at: date(200))
        player = try player.settingManualPersonalHandicap(nil, as: "user", at: date(300))
        player = try player.settingManualPersonalHandicap(.init(value: 8, source: .external, updatedAt: date(400)), as: "user", at: date(400))
        let profile = try XCTUnwrap(player.personalHandicap)
        XCTAssertNil(profile.manualInput(at: date(99)))
        XCTAssertEqual(profile.manualInput(at: date(100))?.value, 10)
        XCTAssertEqual(profile.manualInput(at: date(150))?.source, .external)
        XCTAssertEqual(profile.manualInput(at: date(250))?.value, 20)
        XCTAssertEqual(profile.manualInput(at: date(250))?.source, .manual)
        XCTAssertNil(profile.manualInput(at: date(350)))
        XCTAssertEqual(profile.manualInput(at: date(450))?.value, 8)
    }

    func testUnchangedSaveIsNoOpAndSourceChangeIsDated() throws {
        let old = Time(for: Date(timeIntervalSince1970: 100))
        let now = Time(for: Date(timeIntervalSince1970: 200))
        var player = Player(id: "player", userID: "user", name: Name("Test", "Player"))
        player.personalHandicap = .init(manual: try .init(value: 10, source: .manual, updatedAt: old))
        let unchanged = try player.settingManualPersonalHandicap(.init(value: 10, source: .manual, updatedAt: now), as: "user", at: now)
        XCTAssertEqual(unchanged, player)
        let sourced = try player.settingManualPersonalHandicap(.init(value: 10, source: .external, updatedAt: now), as: "user", at: now)
        XCTAssertEqual(sourced.personalHandicap?.manualInput(at: old)?.source, .manual)
        XCTAssertEqual(sourced.personalHandicap?.manualInput(at: now)?.source, .external)
    }
}

extension InternalReleaseBlockerAuditTests {
    func testPlusHandicapChangesNetWithoutChangingGrossScorecard() throws {
        var source = snapshot("plus-net", playedAt: 100)
        source.participants[0].adjustedHandicap = -2
        source.scoring = source.scoring.map { entry in var entry = entry; entry.strokes = 4; return entry }
        let original = source.scoring
        let holes = source.configuration.courses[0].courseInfo.tees[0].holes
        let gross = ScoringEngine.computeStrokePlay(scores: source.scoring, participants: source.participants,
            segment: source.segments[0], holes: holes, basis: .gross, template: FormatTemplateRegistry.strokePlayGross)
        let net = ScoringEngine.computeStrokePlay(scores: source.scoring, participants: source.participants,
            segment: source.segments[0], holes: holes, basis: .net, template: FormatTemplateRegistry.strokePlayNet)
        XCTAssertEqual(gross.rows.first?.total, 0)
        XCTAssertEqual(net.rows.first?.total, 2)
        XCTAssertEqual(source.scoring, original)
    }

    func testCurrentManualWrittenByOlderClientJoinsDatedHistory() throws {
        func date(_ n: Double) -> Time { .init(for: Date(timeIntervalSince1970: n)) }
        let original = try ManualPersonalHandicap(value: 10, source: .manual, updatedAt: date(100))
        let current = try ManualPersonalHandicap(value: 20, source: .external, updatedAt: date(200))
        var player = Player(id: "player", userID: "user", name: Name("Test", "Player"))
        player.personalHandicap = .init(manual: current, manualHistory: [.init(effectiveAt: date(100), manual: original)])
        XCTAssertEqual(player.personalHandicap?.manualInput(at: date(150))?.value, 10)
        XCTAssertEqual(player.personalHandicap?.manualInput(at: date(250))?.value, 20)
        let edited = try player.settingManualPersonalHandicap(.init(value: 30, source: .manual, updatedAt: date(300)), as: "user", at: date(300))
        XCTAssertEqual(edited.personalHandicap?.manualInput(at: date(250)), current)
        XCTAssertEqual(edited.personalHandicap?.manualHistory.count, 3)
    }
}
