//
//  AppSessionResumeTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

@MainActor
final class AppSessionResumeTests: XCTestCase {
    private func makeStore() -> UserDefaultsRoundResumeStore {
        UserDefaultsRoundResumeStore(
            defaults: UserDefaults(suiteName: "AppSessionResumeTests.\(UUID().uuidString)")!
        )
    }

    func testExitLiveRoundMarksWasExplicitlyExitedAndPersists() {
        let store = makeStore()
        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
        app.activeRoundID = "round-abc"
        app.updateLiveRoundResume(selectedHole: 5, selectedTab: .scoring)

        app.exitLiveRound()

        let persisted = store.load()
        XCTAssertEqual(persisted?.selectedHole, 5)
        XCTAssertEqual(persisted?.wasExplicitlyExited, true)
    }

    func testPerRoundResumeIsolation() {
        let store = makeStore()
        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)

        app.activeRoundID = "first"
        app.updateLiveRoundResume(selectedHole: 5, selectedTab: .scoring)
        app.exitLiveRound()

        app.activeRoundID = "second"
        app.updateLiveRoundResume(selectedHole: 10, selectedTab: .scoring)
        app.exitLiveRound()

        XCTAssertEqual(store.load(roundID: "first")?.selectedHole, 5)
        XCTAssertEqual(store.load(roundID: "second")?.selectedHole, 10)
    }
}
