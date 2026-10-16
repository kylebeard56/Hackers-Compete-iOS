import XCTest
@testable import Hackers

/// Isolated release-gate reproducers. These intentionally assert the required
/// behavior; do not suppress failures or include a failing build in TestFlight.
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
