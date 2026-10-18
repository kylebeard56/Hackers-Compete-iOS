import XCTest
@testable import Hackers

final class PersonalHandicapProfileTests: XCTestCase {
    private let date = Time(for: Date(timeIntervalSince1970: 1_700_000_000))

    private func player(id: String = "p1", userID: String? = "u1", index: Double? = 23) throws -> Player {
        var player = Player(id: id, userID: userID, name: Name("Test", "Player"))
        player.personalHandicap = try .init(manual: index.map { try .init(value: $0, source: .manual, updatedAt: date) })
        return player
    }

    private func calculation(index: Double? = 12.4, status: PersonalHandicapCalculation.Status = .qualified, asOf: Double = 100) -> PersonalHandicapCalculation {
        .init(index: index, status: status, asOf: .init(for: Date(timeIntervalSince1970: asOf)), methodVersion: "test-output-contract",
              qualifyingScoreIDs: ["r1", "r2", "r3"], qualifyingHoles: 54, requiredHoles: 54,
              poolScoreIDs: ["r1", "r2", "r3"], countingScoreIDs: ["r2"])
    }

    private func tee(id: String = "t1", slope: Int = 124) -> Tee {
        Tee(id: id, name: id, gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113, ratingBack: 34.7, slopeBack: slope)
    }

    private func config(_ segment: HoleSegment = .back9, tee: Tee? = nil) -> RoundConfiguration {
        let tee = tee ?? self.tee()
        return .init(courses: [.init(courseInfo: .init(id: "c1", name: "Course", totalHoles: 18, tees: [tee]), holeRange: segment.holeRange, defaultTee: tee.id)],
                     handicapStrokeBasis: .defaultBasis(holeCount: segment.holeCount), handicapIndexBasis: .eighteenHole, handicapEntryFormat: .courseHandicap)
    }

    private func prefill(_ player: Player, configuration: RoundConfiguration? = nil) -> RoundParticipant {
        let configuration = configuration ?? config()
        return PersonalHandicapRoundPrefill.participant(RoundParticipant(player: player, teeBoxID: configuration.courses.first?.defaultTee ?? ""),
            player: player, configuration: configuration, isLeagueRound: false, capturedAt: date)
    }

    func testManualIndexRoundTripsWithExplicitBasisSourceAndDateForRegisteredPlayer() throws {
        let original = try player(index: 22.6)
        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.personalHandicap?.manual?.value, 22.6)
        XCTAssertEqual(decoded.personalHandicap?.manual?.basis, .eighteenHole)
        XCTAssertEqual(decoded.personalHandicap?.manual?.source, .manual)
        XCTAssertEqual(decoded.personalHandicap?.manual?.updatedAt, date)
        XCTAssertEqual(decoded.personalHandicap?.effectiveIndex, 22.6)
    }

    func testPersistentOfflinePlayerKeepsItsOwnManualIndexAndIdentity() throws {
        let original = try player(id: "offline", userID: nil, index: 7.8)
        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.id, "offline")
        XCTAssertNil(decoded.userID)
        XCTAssertTrue(decoded.isOffline)
        XCTAssertEqual(decoded.personalHandicap?.effectiveIndex, 7.8)
        XCTAssertNil(try player(id: "other", index: nil).personalHandicap?.effectiveIndex)
    }

    func testEditingManualPreservesCalculationAndOtherPlayerFields() throws {
        var original = try player()
        original.rounds = ["one", "two"]
        original.handicaps = [.init(value: 8)]
        original.personalHandicap?.calculation = calculation()
        let updatedDate = Time(for: Date(timeIntervalSince1970: 1_800_000_000))
        let manual = try ManualPersonalHandicap(value: 18.2, source: .external, updatedAt: updatedDate)
        let updated = try original.settingManualPersonalHandicap(manual, as: "u1", at: updatedDate)
        XCTAssertEqual(updated.personalHandicap?.manual, manual)
        XCTAssertEqual(updated.personalHandicap?.calculation, original.personalHandicap?.calculation)
        XCTAssertEqual(updated.personalHandicap?.effectiveIndex, 12.4)
        XCTAssertEqual(updated.personalHandicap?.effectiveSource, .calculated)
        XCTAssertEqual(updated.handicaps, original.handicaps)
        XCTAssertEqual(updated.rounds, original.rounds)
        XCTAssertEqual(updated.lastUpdatedAt, updatedDate)
    }

    func testManualAndCalculatedIndexesAreSeparatePersistedFields() throws {
        var original = try player()
        original.personalHandicap?.calculation = calculation()
        let dictionary = try original.personalHandicap!.toDictionary()
        XCTAssertEqual((dictionary["manual"] as? [String: Any])?["value"] as? Double, 23)
        XCTAssertEqual((dictionary["calculation"] as? [String: Any])?["index"] as? Double, 12.4)
        XCTAssertEqual(dictionary["effective_index"] as? Double, 12.4)
        XCTAssertEqual(dictionary["effective_source"] as? String, "calculated")
    }

    func testNoCalculationFallsBackToManualWithoutInventingZero() throws {
        XCTAssertEqual(try player().personalHandicap?.effectiveIndex, 23)
        XCTAssertNil(try player(index: nil).personalHandicap?.effectiveIndex)
        XCTAssertNil(PersonalHandicapProfile().effectiveSource)
        XCTAssertEqual(ManualPersonalHandicap.display(nil), "—")
    }

    func testCollectingOutputDoesNotBecomeEffectiveEvenIfItContainsAPreview() throws {
        var original = try player()
        original.personalHandicap?.calculation = calculation(index: 12.4, status: .collecting)
        XCTAssertNil(original.personalHandicap?.calculation?.qualifiedIndex)
        XCTAssertEqual(original.personalHandicap?.effectiveIndex, 23)
        XCTAssertEqual(original.personalHandicap?.effectiveSource, .manual)
    }

    func testApprovedQualifiedOutputAutomaticallyTakesOverAndRetainsManual() throws {
        var original = try player()
        let manual = original.personalHandicap?.manual
        original.personalHandicap?.calculation = calculation()
        XCTAssertEqual(original.personalHandicap?.effectiveIndex, 12.4)
        XCTAssertEqual(original.personalHandicap?.effectiveSource, .calculated)
        XCTAssertEqual(original.personalHandicap?.manual, manual)
        let round = prefill(original)
        XCTAssertEqual(round.handicapIndex, 12.4)
        XCTAssertEqual(round.personalHandicapInput?.source, .calculated)
    }

    func testInvalidQualifiedOutputCannotProduceFalseZero() throws {
        var original = try player(index: nil)
        original.personalHandicap?.calculation = calculation(index: nil)
        XCTAssertNil(original.personalHandicap?.effectiveIndex)
        original.personalHandicap?.calculation?.index = .nan
        XCTAssertNil(original.personalHandicap?.effectiveIndex)
        original.personalHandicap?.calculation?.index = 0
        original.personalHandicap?.calculation?.methodVersion = ""
        XCTAssertNil(original.personalHandicap?.effectiveIndex)
    }

    func testRemovingEligibilityFallsBackToSavedManual() throws {
        var original = try player(index: 18.3)
        original.personalHandicap?.calculation = calculation()
        let frozen = prefill(original)
        original.personalHandicap?.calculation = calculation(index: nil, status: .collecting)
        XCTAssertEqual(original.personalHandicap?.effectiveIndex, 18.3)
        XCTAssertEqual(frozen.handicapIndex, 12.4)
        XCTAssertEqual(frozen.personalHandicapInput?.source, .calculated)
    }

    func testEditingAuthorizationUsesRegisteredOwnershipAndPersistentOfflineIdentity() throws {
        XCTAssertTrue(try player().canEditPersonalHandicap(as: "u1"))
        XCTAssertFalse(try player().canEditPersonalHandicap(as: "u2"))
        XCTAssertFalse(try player().canEditPersonalHandicap(as: nil))
        var offline = try player(userID: nil)
        XCTAssertTrue(offline.canEditPersonalHandicap(as: "u2"))
        XCTAssertFalse(offline.canEditPersonalHandicap(as: nil))
        offline.needsToBeCreated = true
        XCTAssertFalse(offline.canEditPersonalHandicap(as: "u2"))
        XCTAssertThrowsError(try player().settingManualPersonalHandicap(nil, as: "u2"))
    }

    func testBlankClearsManualAndZeroRemainsAnExplicitValidIndex() throws {
        XCTAssertNil(try ManualPersonalHandicap.parse("  ", source: .manual))
        let zero = try XCTUnwrap(ManualPersonalHandicap.parse("0.0", source: .manual))
        XCTAssertEqual(zero.value, 0)
        XCTAssertEqual(ManualPersonalHandicap.display(zero.value), "0.0")
        let original = try player()
        let updated = try original.settingManualPersonalHandicap(nil, as: "u1")
        XCTAssertNil(updated.personalHandicap?.manual)
        XCTAssertNil(updated.personalHandicap?.effectiveIndex)
    }

    func testDecimalParsingRejectsMalformedAndOverpreciseInput() throws {
        for text in ["abc", "NaN", "inf", "1.23", "1.2.3", "-", "+", "1e2"] {
            XCTAssertThrowsError(try ManualPersonalHandicap.parse(text, source: .manual), text)
        }
        XCTAssertEqual(try ManualPersonalHandicap.parse("12,3", source: .external)?.value, 12.3)
        XCTAssertEqual(try ManualPersonalHandicap(value: 12.36, source: .manual).value, 12.4)
        XCTAssertThrowsError(try ManualPersonalHandicap(value: .infinity, source: .manual))
        XCTAssertThrowsError(try ManualPersonalHandicap(value: 12, source: .calculated))
    }

    func testPlusHandicapNotationSurvivesPersistenceAndRoundEditors() throws {
        let plus = try XCTUnwrap(ManualPersonalHandicap.parse("+2.3", source: .external))
        XCTAssertEqual(plus.value, -2.3)
        XCTAssertEqual(ManualPersonalHandicap.display(plus.value), "+2.3")
        XCTAssertEqual(HandicapIndexEntry.filtered("-2.3"), "-2.3")
        XCTAssertEqual(HandicapIndexEntry.filtered("-2,38"), "-2.3")
        let round = prefill(try player(index: plus.value))
        XCTAssertEqual(round.handicapIndex, -2.3)
        XCTAssertEqual(round.personalHandicapInput?.index, -2.3)
    }

    func testRejectsNineHoleManualRecordRatherThanReinterpretingIt() throws {
        let manual = try ManualPersonalHandicap(value: 8.5, source: .manual)
        var dictionary = try manual.toDictionary()
        dictionary["basis"] = try SeriesHandicapStrokeBasis.nineHole.toDictionaryValue()
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        XCTAssertThrowsError(try JSONDecoder().decode(ManualPersonalHandicap.self, from: data))
    }

    func testStalePersistedEffectiveProjectionCannotOverrideAuthoritativeInputs() throws {
        var dictionary = try PersonalHandicapProfile(manual: .init(value: 23, source: .manual)).toDictionary()
        dictionary["effective_index"] = 0
        dictionary["effective_source"] = "calculated"
        let decoded = try JSONDecoder().decode(PersonalHandicapProfile.self, from: JSONSerialization.data(withJSONObject: dictionary))
        XCTAssertEqual(decoded.effectiveIndex, 23)
        XCTAssertEqual(decoded.effectiveSource, .manual)
    }

    func testLegacyPlayerIntegerHandicapNeverBecomesAPersonalIndex() throws {
        var original = Player(id: "legacy", userID: "u1", name: .init("Legacy", "Player"), handicaps: [.init(value: 17)])
        original.personalHandicap = nil
        let dictionary = try original.toDictionary()
        XCTAssertNil(dictionary["personal_handicap"])
        let decoded = try JSONDecoder().decode(Player.self, from: JSONSerialization.data(withJSONObject: dictionary))
        XCTAssertNil(decoded.personalHandicap)
        XCTAssertEqual(decoded.handicaps.first?.value, 17)
        let round = prefill(decoded)
        XCTAssertNil(round.handicapIndex)
        XCTAssertNil(round.personalHandicapInput)
        XCTAssertNil(round.handicapResolution?.effectiveStrokes)
    }

    func testRegularRoundPrefillUsesCanonicalBackNineCalculationAnd18HoleSource() throws {
        let round = prefill(try player())
        XCTAssertEqual(round.handicapIndex, 23)
        XCTAssertEqual(round.personalHandicapInput?.basis, .eighteenHole)
        XCTAssertEqual(round.handicapResolution?.calculation?.calculationIndex, 11.5)
        XCTAssertEqual(round.handicapResolution?.calculation?.courseHandicap, 11)
        XCTAssertEqual(round.adjustedHandicap, 11)
        XCTAssertEqual(round.personalHandicapInput?.sourceUpdatedAt, date)
    }

    func testRegularRoundFull18PrefillKeepsIndexOn18HoleScale() throws {
        let round = prefill(try player(index: 22.6), configuration: config(.full18))
        XCTAssertEqual(round.handicapResolution?.calculation?.calculationIndex, 22.6)
        XCTAssertEqual(round.adjustedHandicap, 23)
        XCTAssertEqual(round.personalHandicapInput?.basis, .eighteenHole)
    }

    func testMissingTeeDataKeepsIndexUnresolvedWithoutConvertingItToStrokes() throws {
        let round = prefill(try player(), configuration: config(tee: tee(slope: 0)))
        XCTAssertEqual(round.handicapIndex, 23)
        XCTAssertEqual(round.handicapResolution?.calculation?.status, .unavailable)
        XCTAssertNil(round.handicapResolution?.effectiveStrokes)
    }

    func testUnstartedTeeChangeRecalculatesUsingCapturedIndex() throws {
        var profile = try player()
        let first = prefill(profile)
        profile = try profile.settingManualPersonalHandicap(.init(value: 3, source: .manual), as: "u1")
        let newConfig = config(tee: tee(slope: 150))
        let second = HandicapCalculator.recomputedParticipants([first], format: .courseHandicap,
            courseSegment: newConfig.courses.first, handicapStrokeBasis: .eighteenHole)[0]
        XCTAssertEqual(second.handicapIndex, 23)
        XCTAssertEqual(second.personalHandicapInput, first.personalHandicapInput)
        XCTAssertNotEqual(second.adjustedHandicap, first.adjustedHandicap)
        XCTAssertEqual(profile.personalHandicap?.effectiveIndex, 3)
    }

    func testRoundOnlyOverrideNeverChangesProfileOrCapturedProvenance() throws {
        let profile = try player()
        let original = prefill(profile)
        let override = HandicapCalculator.participant(original, applying: 7.5, format: .courseHandicap,
            courseSegment: config().courses.first, handicapStrokeBasis: .eighteenHole)
        XCTAssertEqual(override.handicapIndex, 7.5)
        XCTAssertEqual(override.personalHandicapInput?.index, 23)
        XCTAssertEqual(profile.personalHandicap?.manual?.value, 23)
        XCTAssertEqual(PersonalHandicapRoundPrefill.participant(override, player: profile, configuration: config(), isLeagueRound: false), override)
    }

    func testHistoricalParticipantRoundTripsAndCannotBePrefilledAgain() throws {
        let profile = try player()
        let original = prefill(profile)
        let decoded = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.personalHandicapInput, original.personalHandicapInput)
        XCTAssertEqual(decoded.handicapResolution, original.handicapResolution)
        for status in [RoundStatus.live, .paused, .complete, .archived] {
            let unseeded = RoundParticipant(player: profile)
            XCTAssertEqual(PersonalHandicapRoundPrefill.participant(unseeded, player: profile, configuration: config(), isLeagueRound: false, status: status), unseeded)
        }
    }

    func testLeagueRoundAndLegacyStrokesEntryNeverReadPersonalIndex() throws {
        let profile = try player()
        let original = RoundParticipant(player: profile)
        XCTAssertEqual(PersonalHandicapRoundPrefill.participant(original, player: profile, configuration: config(), isLeagueRound: true), original)
        var leagueParticipant = original
        leagueParticipant.seriesMemberID = "league-member"
        XCTAssertEqual(PersonalHandicapRoundPrefill.participant(leagueParticipant, player: profile, configuration: config(), isLeagueRound: false), leagueParticipant)
        var strokesConfig = config()
        strokesConfig.handicapEntryFormat = .strokes
        XCTAssertEqual(PersonalHandicapRoundPrefill.participant(original, player: profile, configuration: strokesConfig, isLeagueRound: false), original)
    }

    func testOtherPlayerIdentityCannotSeedParticipant() throws {
        let original = RoundParticipant(player: try player(id: "p2", index: nil))
        XCTAssertEqual(PersonalHandicapRoundPrefill.participant(original, player: try player(id: "p1"), configuration: config(), isLeagueRound: false), original)
    }

    func testTrendChronologyFiltersPrequalificationAndWrongPlayerAndReconcilesCorrections() {
        func point(_ roundID: String, played: Double, index: Double? = 12.4, asOf: Double = 100, playerID: String = "p1", status: PersonalHandicapCalculation.Status = .qualified) -> PersonalHandicapHistoryPoint {
            .init(playerID: playerID, roundID: roundID, roundTitle: roundID, playedAt: .init(for: Date(timeIntervalSince1970: played)), calculation: calculation(index: index, status: status, asOf: asOf))
        }
        let points = [point("r3", played: 30), point("r1", played: 10), point("r2", played: 20),
                      point("r2", played: 20, index: 11.1, asOf: 101), point("early", played: 5, status: .collecting),
                      point("other", played: 40, playerID: "p2")]
        let trend = PersonalHandicapPresentation.trend(points, playerID: "p1")
        XCTAssertEqual(trend.map(\.roundID), ["r1", "r2", "r3"])
        XCTAssertEqual(trend[1].calculation.qualifiedIndex, 11.1)
        XCTAssertEqual(PersonalHandicapPresentation.trend(points.reversed(), playerID: "p1"), trend)
    }

    func testScoreHistoryDistinguishesCountingPoolExcludedAndOlderScores() {
        func score(_ id: String, reason: String? = nil) -> PersonalHandicapScoreRecord {
            .init(playerID: "p1", roundID: id, roundTitle: id, playedAt: date, holeCount: 9, grossScore: 45, exclusionReason: reason)
        }
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(score("r2"), calculation: calculation()), "Counts")
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(score("r1"), calculation: calculation()), "Pool")
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(score("r2", reason: "Practice"), calculation: calculation()), "Unofficial")
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(score("unknown"), calculation: calculation()), "Unofficial")
        var result = calculation()
        result.poolScoreIDs = ["r2"]
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(score("r1"), calculation: result), "Earlier score")
    }

    func testLaterIneligibleHistoryRevisionRemovesEarlierCalculatedPoint() {
        let first = PersonalHandicapHistoryPoint(playerID: "p1", roundID: "r1", roundTitle: "Round", playedAt: date, calculation: calculation(asOf: 100))
        let corrected = PersonalHandicapHistoryPoint(playerID: "p1", roundID: "r1", roundTitle: "Round", playedAt: date, calculation: calculation(index: nil, status: .collecting, asOf: 101))
        XCTAssertTrue(PersonalHandicapPresentation.trend([first, corrected], playerID: "p1").isEmpty)
    }

    func testAuditPlusProfilePreservesSignedRoundAllowance() throws {
        let round = prefill(try player(index: -2), configuration: config(.full18))
        XCTAssertEqual(round.handicapResolution?.calculation?.courseHandicap, -2)
        XCTAssertEqual(round.adjustedHandicap, -2, "A plus-two Index must not become scratch")
        XCTAssertEqual(ScoringEngine.strokesReceived(handicap: -2, holeHandicap: 18, useHandicaps: true), -1)
    }

    func testUnchangedManualSaveKeepsOriginalDateAndPlayerTimestamp() throws {
        var original = try player(index: 10)
        original.lastUpdatedAt = date
        let later = Time(iso: "", unix: date.unix + 86400)
        let changed = try original.settingManualPersonalHandicap(.init(value: 10, source: .manual, updatedAt: later), as: "u1", at: later)
        XCTAssertEqual(changed.personalHandicap, original.personalHandicap)
        XCTAssertEqual(changed.lastUpdatedAt, original.lastUpdatedAt)
        XCTAssertNil(changed.personalHandicap?.manualHistory)
    }

    func testManualEditsAndRemovalRetainDatedInputsForRegisteredAndOfflinePlayers() throws {
        for owner: String? in ["u1", nil] {
            let original = try player(userID: owner, index: 10)
            let editTime = Time(iso: "", unix: date.unix + 86400)
            let removeTime = Time(iso: "", unix: date.unix + 2 * 86400)
            let edited = try original.settingManualPersonalHandicap(.init(value: 20, source: .external), as: "u1", at: editTime)
            let cleared = try edited.settingManualPersonalHandicap(nil, as: "u1", at: removeTime)
            let profile = try XCTUnwrap(cleared.personalHandicap)
            XCTAssertEqual(profile.manualHistory?.count, 3)
            XCTAssertNil(profile.manualEffective(at: .init(iso: "", unix: date.unix - 1)))
            XCTAssertEqual(profile.manualEffective(at: date)?.value, 10)
            XCTAssertEqual(profile.manualEffective(at: editTime)?.value, 20)
            XCTAssertEqual(profile.manualEffective(at: editTime)?.source, .external)
            XCTAssertNil(profile.manualEffective(at: removeTime))
            XCTAssertNil(profile.manual)
            let again = try cleared.settingManualPersonalHandicap(nil, as: "u1")
            XCTAssertEqual(again.personalHandicap, profile)
            XCTAssertEqual(again.lastUpdatedAt, cleared.lastUpdatedAt)
            XCTAssertEqual(try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(cleared)).personalHandicap, profile)
        }
    }

    func testLegacyManualProfileWithoutHistoryKeepsItsKnownEffectiveDate() throws {
        let original = try player(index: 10)
        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(original))
        XCTAssertNil(decoded.personalHandicap?.manualHistory)
        XCTAssertEqual(decoded.personalHandicap?.manualEffective(at: date)?.value, 10)
        XCTAssertNil(decoded.personalHandicap?.manualEffective(at: .init(iso: "", unix: date.unix - 1)))
    }

    func testSourceOnlyManualEditDoesNotEraseThePriorSource() throws {
        let original = try player(index: 10)
        let later = Time(iso: "", unix: date.unix + 86400)
        let changed = try original.settingManualPersonalHandicap(.init(value: 10, source: .external), as: "u1", at: later)
        XCTAssertEqual(changed.personalHandicap?.manualEffective(at: date)?.source, .manual)
        XCTAssertEqual(changed.personalHandicap?.manualEffective(at: later)?.source, .external)
    }

    func testPlusPrefillUsesSignedSegmentAllowanceAndDoesNotApplyLeaguePolicy() throws {
        let nine = prefill(try player(index: -4), configuration: config(.front9))
        XCTAssertEqual(nine.adjustedHandicap, -2)
        XCTAssertEqual(nine.handicapResolution?.effectiveStrokes, -2)
        XCTAssertEqual(nine.personalHandicapInput?.index, -4)
        let full = prefill(try player(index: -2), configuration: config(.full18))
        let calculation = try XCTUnwrap(full.handicapResolution?.calculation)
        XCTAssertEqual(calculation.allowedStrokes(maximum: 21), 0, "League callers keep their existing nonnegative policy")
        XCTAssertEqual(calculation.allowedStrokes(maximum: 21, allowsPlusHandicap: true), -2)
        let frozen = full
        var changed = try player(index: 25)
        changed.personalHandicap?.calculation = self.calculation(index: 20)
        XCTAssertEqual(PersonalHandicapRoundPrefill.participant(frozen, player: changed, configuration: config(.full18), isLeagueRound: false, status: .complete), frozen)
    }

}

private extension Encodable {
    func toDictionaryValue() throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(self), options: .fragmentsAllowed) }
}
