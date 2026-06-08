//
//  SeriesRoundCodableTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundCodableTests: XCTestCase {

    func testSeriesDescriptionDefaultsToNilWhenMissing() throws {
        let series = Series(
            id: "series1",
            name: "Thursday League",
            description: nil,
            commissionerUserID: "user1",
            status: .active,
            settings: .init()
        )

        let data = try JSONEncoder().encode(series)
        let decoded = try JSONDecoder().decode(Series.self, from: data)

        XCTAssertEqual(decoded.name, "Thursday League")
        XCTAssertNil(decoded.description)
    }

    func testSeriesDescriptionRoundTripsWhenPresent() throws {
        let series = Series(
            id: "series1",
            name: "Thursday League",
            description: "Weekly league notes and expectations.",
            commissionerUserID: "user1",
            status: .active,
            settings: .init()
        )

        let data = try JSONEncoder().encode(series)
        let decoded = try JSONDecoder().decode(Series.self, from: data)
        let dict = try series.toDictionary()

        XCTAssertEqual(decoded.name, "Thursday League")
        XCTAssertEqual(decoded.description, "Weekly league notes and expectations.")
        XCTAssertEqual(dict["description"] as? String, "Weekly league notes and expectations.")
    }

    func testEncodeToDictionaryIncludesSchemaOne() throws {
        var round = SeriesRound(
            id: "round1",
            title: "Week 1",
            index: 0,
            parentID: "series1"
        )
        round.schema = 999

        let dict = try round.toDictionary()
        XCTAssertEqual(dict["schema"] as? Int, 1)
    }

    func testLegacySeriesRoundAwardsEngineVersionDefaultsToRefreshNeeded() throws {
        let legacyJSON = Data(
            #"{"id":"round1","title":"Week 1","index":0,"status":"complete","awards_status":"finalized","parent_id":"series1"}"#.utf8
        )
        let legacyRound = try JSONDecoder().decode(SeriesRound.self, from: legacyJSON)
        let currentRound = SeriesRound(
            id: "round2",
            title: "Week 2",
            index: 1,
            status: .complete,
            awardsStatus: .finalized,
            automaticAwardsEngineVersion: SeriesViewModel.currentAutomaticAwardsEngineVersion,
            parentID: "series1"
        )

        XCTAssertEqual(legacyRound.automaticAwardsEngineVersion, 0)
        XCTAssertTrue(SeriesViewModel.automaticAwardsNeedEngineRefresh(for: legacyRound))
        XCTAssertFalse(SeriesViewModel.automaticAwardsNeedEngineRefresh(for: currentRound))
    }

    func testLegacySeriesHandicapBasisDefaultsFromDefaultPar() throws {
        let decoder = JSONDecoder()

        let nineHole = try decoder.decode(
            SeriesHandicapConfig.self,
            from: Data(#"{"mode":"dynamic","config":{"default_par_for_index":36}}"#.utf8)
        )
        let eighteenHole = try decoder.decode(
            SeriesHandicapConfig.self,
            from: Data(#"{"mode":"dynamic","config":{"default_par_for_index":72}}"#.utf8)
        )

        XCTAssertEqual(nineHole.strokeBasis, .nineHole)
        XCTAssertEqual(eighteenHole.strokeBasis, .eighteenHole)
    }

    func testLegacyRoundHandicapBasisDefaultsFromHoleCount() throws {
        let decoder = JSONDecoder()
        let configuration = try decoder.decode(RoundConfiguration.self, from: Data(#"{}"#.utf8))

        XCTAssertNil(configuration.handicapStrokeBasis)
        XCTAssertEqual(configuration.resolvedHandicapStrokeBasis(holeCount: 9), .nineHole)
        XCTAssertEqual(configuration.resolvedHandicapStrokeBasis(holeCount: 18), .eighteenHole)
    }

    func testRoundHandicapBasisDecodesExplicitValue() throws {
        let decoder = JSONDecoder()
        let configuration = try decoder.decode(
            RoundConfiguration.self,
            from: Data(#"{"handicap_stroke_basis":"eighteen_hole"}"#.utf8)
        )

        XCTAssertEqual(configuration.handicapStrokeBasis, .eighteenHole)
        XCTAssertEqual(configuration.resolvedHandicapStrokeBasis(holeCount: 9), .eighteenHole)
    }

    func testSeriesRoundHandicapBasisDefaultsToAutoAndDecodesExplicitValue() throws {
        let decoder = JSONDecoder()
        let auto = try decoder.decode(SeriesRoundConfiguration.self, from: Data(#"{}"#.utf8))
        let explicit = try decoder.decode(
            SeriesRoundConfiguration.self,
            from: Data(#"{"handicap_stroke_basis":"nine_hole"}"#.utf8)
        )

        XCTAssertNil(auto.handicapStrokeBasis)
        XCTAssertEqual(explicit.handicapStrokeBasis, .nineHole)
    }

    func testRoundSharedScoreHandicapConfigRoundTrips() throws {
        let config = HandicapConfiguration(
            percentage: 1.0,
            isTeamCombined: true,
            positionPercentages: [0.35, 0.15]
        )
        let configuration = RoundConfiguration(sharedScoreHandicapConfig: config)

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(RoundConfiguration.self, from: data)
        let dictionary = try configuration.toDictionary()

        XCTAssertEqual(decoded.sharedScoreHandicapConfig, config)
        XCTAssertNotNil(dictionary["shared_score_handicap_config"])
    }

    func testRoundLeagueHandicapMaximumRoundTripsAndDefaultsToNilWhenMissing() throws {
        let decoder = JSONDecoder()
        let legacyConfiguration = try decoder.decode(RoundConfiguration.self, from: Data(#"{}"#.utf8))
        XCTAssertNil(legacyConfiguration.leagueHandicapMaximum)

        let configuration = RoundConfiguration(leagueHandicapMaximum: 18)
        let data = try JSONEncoder().encode(configuration)
        let decoded = try decoder.decode(RoundConfiguration.self, from: data)
        let dictionary = try configuration.toDictionary()

        XCTAssertEqual(decoded.leagueHandicapMaximum, 18)
        XCTAssertEqual(dictionary["league_handicap_maximum"] as? Int, 18)
    }

    func testRoundExplicitUseHandicapsRoundTripsAndLegacyFallsBackToPrimaryFormat() throws {
        let decoder = JSONDecoder()
        let legacyConfiguration = try decoder.decode(RoundConfiguration.self, from: Data(#"{}"#.utf8))
        XCTAssertNil(legacyConfiguration.handicapsEnabled)
        XCTAssertFalse(legacyConfiguration.useHandicaps)

        let configuration = RoundConfiguration(handicapsEnabled: true)
        let data = try JSONEncoder().encode(configuration)
        let decoded = try decoder.decode(RoundConfiguration.self, from: data)
        let dictionary = try configuration.toDictionary()

        XCTAssertEqual(decoded.handicapsEnabled, true)
        XCTAssertTrue(decoded.useHandicaps)
        XCTAssertEqual(dictionary["use_handicaps"] as? Bool, true)
    }

    func testRoundSelectionDomainRoundTripsAndDefaultsToNilWhenMissing() throws {
        let decoder = JSONDecoder()
        let legacyConfiguration = try decoder.decode(RoundConfiguration.self, from: Data(#"{}"#.utf8))
        XCTAssertNil(legacyConfiguration.selectionDomain)

        let configuration = RoundConfiguration(selectionDomain: .partnership)
        let data = try JSONEncoder().encode(configuration)
        let decoded = try decoder.decode(RoundConfiguration.self, from: data)
        let dictionary = try configuration.toDictionary()

        XCTAssertEqual(decoded.selectionDomain, .partnership)
        XCTAssertEqual(dictionary["selection_domain"] as? String, "partnership")
    }

    func testSeriesRoundSelectionDomainRoundTripsAndDefaultsToNilWhenMissing() throws {
        let decoder = JSONDecoder()
        let legacyConfiguration = try decoder.decode(SeriesRoundConfiguration.self, from: Data(#"{}"#.utf8))
        XCTAssertNil(legacyConfiguration.selectionDomain)

        let configuration = SeriesRoundConfiguration(selectionDomain: .partnership)
        let data = try JSONEncoder().encode(configuration)
        let decoded = try decoder.decode(SeriesRoundConfiguration.self, from: data)
        let dictionary = try configuration.toDictionary()

        XCTAssertEqual(decoded.selectionDomain, .partnership)
        XCTAssertEqual(dictionary["selection_domain"] as? String, "partnership")
    }

    func testSeriesRoundMaxScoreDefaultsToQuadAndRoundTripsWhenPresent() throws {
        let decoder = JSONDecoder()
        let legacyConfiguration = try decoder.decode(SeriesRoundConfiguration.self, from: Data(#"{}"#.utf8))

        XCTAssertNil(legacyConfiguration.maxScoreOverPar)
        XCTAssertEqual(legacyConfiguration.legacyGameFormat.configuration.maxScoreOverPar, .quad)

        let configuration = SeriesRoundConfiguration(maxScoreOverPar: .twoTimesParPlusOne)
        let data = try JSONEncoder().encode(configuration)
        let decoded = try decoder.decode(SeriesRoundConfiguration.self, from: data)
        let dictionary = try configuration.toDictionary()

        XCTAssertEqual(decoded.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertEqual(decoded.legacyGameFormat.configuration.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertEqual(dictionary["max_score_over_par"] as? String, "twoTimesParPlusOne")
    }

    func testSubstituteRoleAndSettingsRoundTripWithLegacyDefaults() throws {
        let decoder = JSONDecoder()
        let legacySettings = try decoder.decode(SeriesSettings.self, from: Data(#"{}"#.utf8))
        let legacyRoundConfiguration = try decoder.decode(RoundConfiguration.self, from: Data(#"{}"#.utf8))

        XCTAssertFalse(legacySettings.substitutesScore)
        XCTAssertFalse(legacyRoundConfiguration.substitutesScore)
        XCTAssertEqual(SeriesMemberRole.substitute.rawValue, "substitute")

        var settings = SeriesSettings()
        settings.substitutesScore = true
        let settingsDictionary = try settings.toDictionary()
        let settingsData = try JSONEncoder().encode(settings)
        let decodedSettings = try decoder.decode(SeriesSettings.self, from: settingsData)

        XCTAssertTrue(decodedSettings.substitutesScore)
        XCTAssertEqual(settingsDictionary["substitutes_score"] as? Bool, true)

        let roundConfiguration = RoundConfiguration(substitutesScore: true)
        let roundData = try JSONEncoder().encode(roundConfiguration)
        let decodedRoundConfiguration = try decoder.decode(RoundConfiguration.self, from: roundData)
        let roundDictionary = try roundConfiguration.toDictionary()

        XCTAssertTrue(decodedRoundConfiguration.substitutesScore)
        XCTAssertEqual(roundDictionary["substitutes_score"] as? Bool, true)
    }

    func testPlannedSeatSubstituteMetadataRoundTrips() throws {
        let seat = SeriesRoundPlannedSeat(
            id: "seat1",
            memberID: "sub1",
            teeOrder: 2,
            source: .manualOverride,
            isSubstitute: true,
            substituteForSeriesMemberID: "member1",
            substituteForName: "Joe Smith",
            representedTeamID: "team1"
        )

        let data = try JSONEncoder().encode(seat)
        let decoded = try JSONDecoder().decode(SeriesRoundPlannedSeat.self, from: data)
        let dictionary = try seat.toDictionary()

        XCTAssertTrue(decoded.isSubstitute)
        XCTAssertEqual(decoded.substituteForSeriesMemberID, "member1")
        XCTAssertEqual(decoded.substituteForName, "Joe Smith")
        XCTAssertEqual(decoded.representedTeamID, "team1")
        XCTAssertEqual(dictionary["is_substitute"] as? Bool, true)
        XCTAssertEqual(dictionary["substitute_for_series_member_id"] as? String, "member1")
        XCTAssertEqual(dictionary["substitute_for_name"] as? String, "Joe Smith")
        XCTAssertEqual(dictionary["represented_team_id"] as? String, "team1")
    }

    func testRoundParticipantSubstituteMetadataRoundTrips() throws {
        let participant = RoundParticipant(
            id: "p_sub",
            name: Name("Sam", "Sub"),
            isSubstitute: true,
            substituteForSeriesMemberID: "member1",
            substituteForName: "Joe Smith",
            parentID: "round1"
        )

        let data = try JSONEncoder().encode(participant)
        let decoded = try JSONDecoder().decode(RoundParticipant.self, from: data)
        let dictionary = try participant.toDictionary()

        XCTAssertTrue(decoded.isSubstitute)
        XCTAssertEqual(decoded.substituteForSeriesMemberID, "member1")
        XCTAssertEqual(decoded.substituteForName, "Joe Smith")
        XCTAssertEqual(dictionary["is_substitute"] as? Bool, true)
        XCTAssertEqual(dictionary["substitute_for_series_member_id"] as? String, "member1")
        XCTAssertEqual(dictionary["substitute_for_name"] as? String, "Joe Smith")
    }
}
