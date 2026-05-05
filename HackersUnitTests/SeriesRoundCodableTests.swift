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
}
