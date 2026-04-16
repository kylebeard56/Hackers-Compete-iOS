@testable import Hackers
import XCTest

final class GameLobbyFormatSelectionTests: XCTestCase {

    func testVegasAppearsInSoloLobbyWithPlayerAndTeamRequirements() {
        var snapshot = MockLobbyDuo.snapshot
        snapshot.participants = [MockLobbyDuo.participants[0]]

        let availability = FormatSelectionView.availability(for: FormatTemplateRegistry.vegas, in: snapshot)

        XCTAssertFalse(availability.isSelectable)
        XCTAssertEqual(availability.unmetRequirements, ["Needs 4+ players", "Teams required"])
    }

    func testTeamFormatShowsTeamsRequiredWhenTeamsAreOff() {
        let availability = FormatSelectionView.availability(for: FormatTemplateRegistry.bestBall, in: MockLobbyFoursome.snapshot)

        XCTAssertFalse(availability.isSelectable)
        XCTAssertEqual(availability.unmetRequirements, ["Teams required"])
    }

    func testMatchPlayShowsMatchupsRequiredWhenFieldCannotBePaired() {
        var snapshot = MockLobbyFoursome.snapshot
        snapshot.participants.removeLast()

        let availability = FormatSelectionView.availability(for: FormatTemplateRegistry.matchPlayIndividual, in: snapshot)

        XCTAssertFalse(availability.isSelectable)
        XCTAssertEqual(availability.unmetRequirements, ["Matchups required"])
    }

    func testSelectableFormatRemainsSelectable() {
        let availability = FormatSelectionView.availability(for: FormatTemplateRegistry.strokePlay, in: MockLobbyDuo.snapshot)

        XCTAssertTrue(availability.isSelectable)
        XCTAssertTrue(availability.unmetRequirements.isEmpty)
    }

    func testTeamSizeRequirementAppearsWhenCurrentTeamsAreInvalid() {
        var snapshot = MockLobbyMatchups.snapshot
        snapshot.participants[0].teamID = nil

        let availability = FormatSelectionView.availability(for: FormatTemplateRegistry.alternateShot, in: snapshot)

        XCTAssertFalse(availability.isSelectable)
        XCTAssertEqual(availability.unmetRequirements, ["2 per team"])
    }

    func testSeriesTemplatesStillExcludeVegas() {
        XCTAssertFalse(FormatTemplateRegistry.seriesTemplates.contains { $0.id == FormatTemplateRegistry.vegas.id })
    }
}
