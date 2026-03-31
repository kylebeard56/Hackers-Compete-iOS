//
//  TeamColorSwatchTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class TeamColorSwatchTests: XCTestCase {

    func testRoundTeam_displaySwatchColor_noneIsNil() {
        let t = RoundTeam(
            id: "1",
            name: "Team 1",
            color: TeamColor.none.rawValue,
            index: 0,
            createdAt: .init()
        )
        XCTAssertNil(t.displaySwatchColor)
    }

    func testRoundTeam_displaySwatchColor_emptyIsNil() {
        let t = RoundTeam(
            id: "1",
            name: "Team 1",
            color: "",
            index: 0,
            createdAt: .init()
        )
        XCTAssertNil(t.displaySwatchColor)
    }

    func testRoundTeam_displaySwatchColor_redIsNonNil() {
        let t = RoundTeam(
            id: "1",
            name: "Red Team",
            color: "red",
            index: 0,
            createdAt: .init()
        )
        XCTAssertNotNil(t.displaySwatchColor)
    }

    func testSeriesTeam_roundColorToken_nonePersists() {
        let team = SeriesTeam(
            id: "s1",
            name: "Squad",
            color: TeamColor.none.rawValue,
            index: 0,
            parentID: "series1"
        )
        XCTAssertEqual(team.roundColorToken, TeamColor.none.rawValue)
        XCTAssertNil(team.displaySwatchColor)
    }

    func testSeriesTeam_displaySwatchColor_customHexWinsOverNoneColorKey() {
        let team = SeriesTeam(
            id: "s1",
            name: "Squad",
            color: TeamColor.none.rawValue,
            customColorHex: "#FF0000",
            index: 0,
            parentID: "series1"
        )
        XCTAssertEqual(team.roundColorToken, "#FF0000")
        XCTAssertNotNil(team.displaySwatchColor)
    }
}
