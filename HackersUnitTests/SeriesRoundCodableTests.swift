//
//  SeriesRoundCodableTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundCodableTests: XCTestCase {

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
}
