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

    func testTeeGroupsDisplayInPersistedGroupOrderInsteadOfStartingHoleOrder() {
        let groups = [
            TeeTimeGroup(id: "group_9", index: 8, startingHole: 1, createdAt: .init()),
            TeeTimeGroup(id: "group_1", index: 0, startingHole: 2, createdAt: .init()),
            TeeTimeGroup(id: "group_3", index: 2, startingHole: 4, createdAt: .init()),
            TeeTimeGroup(id: "group_10", index: 9, startingHole: 1, createdAt: .init()),
            TeeTimeGroup(id: "group_2", index: 1, startingHole: 3, createdAt: .init())
        ]

        let sorted = groups.sortedForGameLobbyDisplay()

        XCTAssertEqual(sorted.map(\.id), ["group_1", "group_2", "group_3", "group_9", "group_10"])
        XCTAssertEqual(sorted.map(\.startingHole), [2, 3, 4, 1, 1])
        XCTAssertEqual(sorted[3].startingHoleDisplayLabel(in: groups), "1A")
        XCTAssertEqual(sorted[4].startingHoleDisplayLabel(in: groups), "1B")
    }
}
