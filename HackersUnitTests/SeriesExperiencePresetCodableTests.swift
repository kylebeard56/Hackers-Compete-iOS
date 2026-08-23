//
//  SeriesExperiencePresetCodableTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesExperiencePresetCodableTests: XCTestCase {

    func testLegacyOtherStringDecodesAsTournament() throws {
        let data = Data("\"other\"".utf8)
        let preset = try JSONDecoder().decode(SeriesExperiencePreset.self, from: data)
        XCTAssertEqual(preset, .tournament)
    }

    func testTournamentEncodesAsTournamentString() throws {
        let data = try JSONEncoder().encode(SeriesExperiencePreset.tournament)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"tournament\"")
    }

    func testTournamentRoundTrip() throws {
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        let data = try enc.encode(SeriesExperiencePreset.tournament)
        let out = try dec.decode(SeriesExperiencePreset.self, from: data)
        XCTAssertEqual(out, .tournament)
    }
}
