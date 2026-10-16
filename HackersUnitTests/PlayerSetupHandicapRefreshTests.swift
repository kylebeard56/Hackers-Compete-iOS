import XCTest
@testable import Hackers

@MainActor
final class PlayerSetupHandicapRefreshTests: XCTestCase {
    private func session(_ holes: HoleSegment = .full18, status: RoundStatus = .lobby) -> RoundSession {
        let tee = Tee(id: "tee", name: "White", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        let course = CourseSegment(courseInfo: .init(id: "course", name: "Course", totalHoles: 18, tees: [tee]),
            holeRange: holes.holeRange, defaultTee: tee.id)
        let session = RoundSession()
        session.snapshot = .init(round: Round(id: "round", status: status,
            configuration: .init(courses: [course], handicapIndexBasis: .eighteenHole,
                handicapsEnabled: true, handicapEntryFormat: .courseHandicap)))
        return session
    }

    private func player(_ id: String = "player", registered: Bool = true) throws -> Player {
        var player = Player(id: id, userID: registered ? "user-\(id)" : nil, name: Name("Test", id))
        player.handicaps = [.init(value: 30)] // Legacy strokes must never become an Index.
        player.personalHandicap = .init(manual: try .init(value: 22.6, source: .external,
            updatedAt: .init(for: Date(timeIntervalSince1970: 100))))
        return player
    }

    private func calculated(_ index: Double) -> PersonalHandicapCalculation {
        .init(index: index, status: .qualified, asOf: .init(), methodVersion: "test",
            qualifyingScoreIDs: ["r1", "r2", "r3"], qualifyingHoles: 54, requiredHoles: 54,
            poolScoreIDs: ["r1", "r2", "r3"], countingScoreIDs: ["r1"])
    }

    private func participant(_ player: Player, in session: RoundSession) -> RoundParticipant {
        PersonalHandicapRoundPrefill.participant(.init(player: player, teeBoxID: "tee"),
            player: player, configuration: session.snapshot.configuration, isLeagueRound: false)
    }

    func testUnavailableNetworkKeepsLastCalculatedIndexForNineAndEighteenHoleSetup() async throws {
        var saved = try player()
        saved.personalHandicap?.calculation = calculated(12.4)
        for holes: HoleSegment in [.back9, .full18] {
            let session = session(holes)
            let result = await session.refreshingPersonalHandicapsForSetup([saved]) { _ in
                throw URLError(.notConnectedToInternet)
            }
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result[0].personalHandicap, saved.personalHandicap)
            let added = participant(result[0], in: session)
            XCTAssertEqual(added.handicapIndex, 12.4)
            XCTAssertEqual(added.personalHandicapInput?.source, .calculated)
            XCTAssertEqual(added.handicapResolution?.effectiveStrokes, holes == .full18 ? 12 : 6)
        }
    }

    func testRefreshFailurePreservesOfflineManualFallbackSourceAndDate() async throws {
        let saved = try player(registered: false)
        let session = session()
        let result = await session.refreshingPersonalHandicapsForSetup([saved]) { _ in
            throw NSError(domain: "Firestore", code: 7)
        }
        XCTAssertTrue(result[0].isOffline)
        XCTAssertEqual(result[0].personalHandicap?.manual, saved.personalHandicap?.manual)
        let added = participant(result[0], in: session)
        XCTAssertEqual(added.handicapIndex, 22.6)
        XCTAssertEqual(added.personalHandicapInput?.source, .external)
        XCTAssertEqual(added.personalHandicapInput?.sourceUpdatedAt, saved.personalHandicap?.manual?.updatedAt)
    }

    func testLegacyStrokesAndMissingProfileRemainUnresolvedAfterTimeout() async throws {
        var saved = try player()
        saved.personalHandicap = nil
        let session = session()
        let result = await session.refreshingPersonalHandicapsForSetup([saved]) { _ in throw URLError(.timedOut) }
        XCTAssertEqual(result.count, 1)
        let added = participant(result[0], in: session)
        XCTAssertNil(added.handicapIndex)
        XCTAssertNil(added.personalHandicapInput)
        XCTAssertNil(added.handicapResolution?.effectiveStrokes)
    }

    func testFailedPlayerDoesNotPreventRemainingPlayersRefreshing() async throws {
        let failed = try player("offline", registered: false)
        let registered = try player("registered")
        var latest = registered
        latest.personalHandicap?.calculation = calculated(9.8)
        var requested: [String] = []
        let result = await session().refreshingPersonalHandicapsForSetup([failed, registered]) { id in
            requested.append(id)
            if id == failed.id { throw URLError(.networkConnectionLost) }
            return latest
        }
        XCTAssertEqual(requested, [failed.id, registered.id])
        XCTAssertEqual(result.map(\.id), [failed.id, registered.id])
        XCTAssertEqual(result[0].personalHandicap, failed.personalHandicap)
        XCTAssertEqual(result[1].personalHandicap?.effectiveIndex, 9.8)
    }

    func testSuccessfulRefreshUsesLatestIndexWithoutReplacingOtherPlayerFields() async throws {
        let saved = try player()
        var latest = saved
        latest.name = Name("Server", "Name")
        latest.handicaps = [.init(value: 1)]
        latest.personalHandicap?.calculation = calculated(7.2)
        let session = session()
        let result = await session.refreshingPersonalHandicapsForSetup([saved]) { _ in latest }
        XCTAssertEqual(result[0].name, saved.name)
        XCTAssertEqual(result[0].handicaps, saved.handicaps)
        XCTAssertEqual(result[0].personalHandicap?.manual, saved.personalHandicap?.manual)
        let added = participant(result[0], in: session)
        XCTAssertEqual(added.handicapIndex, 7.2)
        XCTAssertEqual(added.personalHandicapInput?.source, .calculated)
    }

    func testMissingRefreshResultKeepsSavedProfile() async throws {
        let saved = try player()
        let result = await session().refreshingPersonalHandicapsForSetup([saved]) { _ in nil }
        XCTAssertEqual(result[0].personalHandicap, saved.personalHandicap)
    }

    func testLeagueLobbySkipsPersonalRefreshAndKeepsFrozenParticipants() async throws {
        let saved = try player()
        let session = session()
        var frozen = participant(saved, in: session)
        frozen.seriesMemberID = "member"
        frozen.leagueHandicapStrokesAtCreation = 10
        session.snapshot.participants = [frozen]
        var calls = 0
        let result = await session.refreshingPersonalHandicapsForSetup([saved]) { _ in calls += 1; return nil }
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(result[0].personalHandicap, saved.personalHandicap)
        XCTAssertEqual(session.snapshot.participants, [frozen])
    }

    func testCompletedRoundSkipsRefreshAndNeverRewritesHistoricalSnapshot() async throws {
        let saved = try player()
        let session = session()
        let frozen = participant(saved, in: session)
        session.snapshot.participants = [frozen]
        session.snapshot.round.status = .complete
        var calls = 0
        _ = await session.refreshingPersonalHandicapsForSetup([saved]) { _ in calls += 1; throw URLError(.notConnectedToInternet) }
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(session.snapshot.participants, [frozen])
    }
}
