@testable import Hackers
import Foundation
import SwiftUI
import XCTest

@MainActor
final class RoundResumeRobustnessTests: XCTestCase {
    private let storageKey = "RoundResumeRobustnessTests.resume"

    func testLegacyActiveOnlyRecordGetsPerRoundStorageWhenResumed() async throws {
        let (store, defaults) = try makeStore()
        let saved = state(roundID: "legacy-round", selectedHole: 14, selectedTab: .table)
        defaults.set(try JSONEncoder().encode(saved), forKey: storageKey)
        XCTAssertEqual(store.load(roundID: saved.roundID), saved)
        XCTAssertNil(store.load(roundID: "different-round"))

        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
        await app.restoreRoundOrRouteToDashboard()

        XCTAssertEqual(app.activeRoundID, saved.roundID)
        XCTAssertEqual(app.activeSeriesID, saved.seriesID)
        XCTAssertEqual(app.path, NavigationPath([Destination.liveRound]))
        // Older installs only wrote the active key. Resuming must also create
        // the per-round record so switching rounds cannot lose this selection.
        defaults.removeObject(forKey: storageKey)
        let migrated = try XCTUnwrap(store.load(roundID: saved.roundID))
        XCTAssertEqual(migrated.roundID, saved.roundID)
        XCTAssertEqual(migrated.seriesID, saved.seriesID)
        XCTAssertEqual(migrated.selectedHole, saved.selectedHole)
        XCTAssertEqual(migrated.selectedTab, saved.selectedTab)
    }

    func testUnreadableActiveRecordDoesNotPreventManualRecoveryOfStoredRound() throws {
        let (store, defaults) = try makeStore()
        let saved = state(roundID: "recoverable-round", selectedHole: 16, selectedTab: .matchups)
        store.save(saved)
        defaults.set(Data("{truncated".utf8), forKey: storageKey)

        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
        XCTAssertNil(app.roundResumeState)
        app.activeRoundID = saved.roundID
        app.activeSeriesID = saved.seriesID
        app.routeTo(.liveRound)

        let recovered = try XCTUnwrap(store.load())
        XCTAssertEqual(recovered.roundID, saved.roundID)
        XCTAssertEqual(recovered.seriesID, saved.seriesID)
        XCTAssertEqual(recovered.selectedHole, saved.selectedHole)
        XCTAssertEqual(recovered.selectedTab, saved.selectedTab)
        XCTAssertEqual(store.load(roundID: saved.roundID), recovered)
        XCTAssertEqual(app.roundResumeState, recovered)
    }

    func testMalformedOrUnsupportedPayloadCanBeReplacedByValidState() throws {
        let (store, defaults) = try makeStore()
        let saved = state(roundID: "recoverable-round")
        let invalidPayloads = [
            Data("{truncated".utf8),
            Data("null".utf8),
            Data("[]".utf8),
            Data(#"{"roundID":"recoverable-round"}"#.utf8),
            Data(#"{"roundID":"recoverable-round","destination":"future_destination","selectedTab":"scoring","timestamp":1000}"#.utf8),
            Data(#"{"roundID":"recoverable-round","destination":"live_round","selectedTab":"future_tab","timestamp":1000}"#.utf8),
        ]

        for payload in invalidPayloads {
            defaults.set(payload, forKey: storageKey)
            defaults.set(payload, forKey: "\(storageKey).round.\(saved.roundID)")
            XCTAssertNil(store.load(), "Unexpectedly decoded \(String(decoding: payload, as: UTF8.self))")
            XCTAssertNil(store.load(roundID: saved.roundID))

            store.save(saved)

            XCTAssertEqual(store.load(), saved)
            XCTAssertEqual(store.load(roundID: saved.roundID), saved)
        }
    }

    func testClearRemovesCurrentResumeWithoutDeletingOtherRecoverableRounds() throws {
        let (store, _) = try makeStore()
        var earlier = state(roundID: "earlier-round", selectedHole: 11, selectedTab: .table)
        earlier.wasExplicitlyExited = true
        let current = state(roundID: "current-round", selectedHole: 4, selectedTab: .matchups)
        store.save(earlier)
        store.save(current)
        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)

        app.clearRoundResume()

        XCTAssertNil(app.roundResumeState)
        XCTAssertNil(store.load())
        XCTAssertNil(store.load(roundID: current.roundID))
        XCTAssertEqual(store.load(roundID: earlier.roundID), earlier)
        // Repeating completion cleanup must not delete an unrelated saved round.
        app.clearRoundResume()
        XCTAssertEqual(store.load(roundID: earlier.roundID), earlier)
    }

    func testClearAllPurgesOnlyTheExactResumeNamespace() throws {
        let (store, defaults) = try makeStore()
        let first = state(roundID: "first")
        let second = state(roundID: "second")
        let otherStore = UserDefaultsRoundResumeStore(defaults: defaults, key: "\(storageKey)-other")
        let unrelatedKeys = [
            "unrelated.preference",
            "\(storageKey).round",
            "\(storageKey).roundtrip",
            "\(storageKey).roundish.first",
        ]
        for key in unrelatedKeys {
            defaults.set("keep", forKey: key)
        }
        store.save(first)
        store.save(second)
        otherStore.save(first)

        store.clearAll()
        store.clearAll()

        XCTAssertNil(store.load())
        XCTAssertNil(store.load(roundID: first.roundID))
        XCTAssertNil(store.load(roundID: second.roundID))
        XCTAssertEqual(otherStore.load(), first)
        XCTAssertEqual(otherStore.load(roundID: first.roundID), first)
        for key in unrelatedKeys {
            XCTAssertEqual(defaults.string(forKey: key), "keep", "Removed unrelated key \(key)")
        }
    }

    func testClearAllPurgesOrphanedRecordsEvenWhenActiveRecordIsCorruptOrMissing() throws {
        for hasCorruptActiveRecord in [false, true] {
            let (store, defaults) = try makeStore()
            store.save(state(roundID: "first"))
            store.save(state(roundID: "second"))
            defaults.set(Data("{bad-index".utf8), forKey: "\(storageKey).round.corrupt")
            if hasCorruptActiveRecord {
                defaults.set(Data("{bad-active".utf8), forKey: storageKey)
            } else {
                defaults.removeObject(forKey: storageKey)
            }

            store.clearAll()

            XCTAssertNil(defaults.object(forKey: storageKey))
            for roundID in ["first", "second", "corrupt"] {
                XCTAssertNil(defaults.object(forKey: "\(storageKey).round.\(roundID)"))
                XCTAssertNil(store.load(roundID: roundID))
            }
        }
    }

    func testPendingJoinLinkTakesPriorityWithoutErasingSavedResume() async throws {
        let links: [PendingJoinLink] = [
            .round(token: "new-round"),
            .series(token: "new-series"),
            .freeform(token: "join-code"),
        ]
        for link in links {
            let (store, _) = try makeStore()
            let saved = state(roundID: "saved-round", selectedHole: 9, selectedTab: .matchups)
            store.save(saved)
            let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
            app.pendingJoinLink = link

            await app.restoreRoundOrRouteToDashboard()

            XCTAssertEqual(app.path, NavigationPath([Destination.dashboard]))
            XCTAssertNil(app.activeRoundID)
            XCTAssertNil(app.activeSeriesID)
            XCTAssertEqual(app.pendingJoinLink, link)
            XCTAssertEqual(app.roundResumeState, saved)
            XCTAssertEqual(store.load(), saved)
            XCTAssertEqual(store.load(roundID: saved.roundID), saved)
        }
    }

    func testInvalidSavedRoundIDsAreDiscardedBeforeRouting() async throws {
        for roundID in ["", " \n\t", "/", "rounds/another-round"] {
            let (store, _) = try makeStore()
            store.save(state(roundID: roundID))
            let app = AppSession(roundResumeStore: store, restoresAuthentication: false)

            await app.restoreRoundOrRouteToDashboard()

            XCTAssertEqual(app.path, NavigationPath([Destination.dashboard]), "Invalid ID: \(roundID)")
            XCTAssertNil(app.activeRoundID)
            XCTAssertNil(app.activeSeriesID)
            XCTAssertNil(app.roundResumeState)
            XCTAssertNil(store.load())
            XCTAssertNil(store.load(roundID: roundID))
        }
    }

    func testLobbyToLiveTransitionPreservesSelectionAndReplacesLobbyInBackStack() throws {
        let (store, _) = try makeStore()
        let saved = state(roundID: "round", selectedHole: 13, selectedTab: .table)
        store.save(saved)
        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
        app.activeRoundID = saved.roundID
        app.activeSeriesID = saved.seriesID
        app.routeTo(.dashboard)
        app.routeTo(.lobby)
        XCTAssertEqual(store.load()?.destination, .lobby)

        app.routeTo(.liveRound, replacingCurrent: true)

        XCTAssertEqual(app.path, NavigationPath([Destination.dashboard, .liveRound]))
        let resumed = try XCTUnwrap(store.load())
        XCTAssertEqual(resumed.destination, .liveRound)
        XCTAssertEqual(resumed.selectedHole, saved.selectedHole)
        XCTAssertEqual(resumed.selectedTab, saved.selectedTab)
        XCTAssertEqual(resumed.seriesID, saved.seriesID)
        XCTAssertEqual(store.load(roundID: saved.roundID), resumed)
    }

    func testTabOnlyUpdatePreservesHoleAndRefreshesSeriesContext() throws {
        let (store, _) = try makeStore()
        let saved = state(roundID: "round", selectedHole: 8, selectedTab: .scoring)
        store.save(saved)
        let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
        app.activeRoundID = saved.roundID
        app.activeSeriesID = "updated-series"

        app.updateLiveRoundResume(selectedHole: nil, selectedTab: .matchups)

        let updated = try XCTUnwrap(store.load())
        XCTAssertEqual(updated.roundID, saved.roundID)
        XCTAssertEqual(updated.selectedHole, 8)
        XCTAssertEqual(updated.selectedTab, .matchups)
        XCTAssertEqual(updated.seriesID, "updated-series")
        XCTAssertEqual(store.load(roundID: saved.roundID), updated)

        app.activeSeriesID = nil
        app.persistRoundResume(destination: .liveRound)
        XCTAssertNil(store.load()?.seriesID)
        XCTAssertEqual(store.load()?.selectedHole, 8)
        XCTAssertEqual(store.load()?.selectedTab, .matchups)
    }

    func testPersistWithoutAnActiveRoundCannotOverwriteSavedProgress() throws {
        for roundID: String? in [nil, ""] {
            let (store, _) = try makeStore()
            let saved = state(roundID: "saved-round", selectedHole: 17, selectedTab: .table)
            store.save(saved)
            let app = AppSession(roundResumeStore: store, restoresAuthentication: false)
            app.activeRoundID = roundID

            app.updateLiveRoundResume(selectedHole: 1, selectedTab: .scoring)

            XCTAssertEqual(app.roundResumeState, saved)
            XCTAssertEqual(store.load(), saved)
            XCTAssertEqual(store.load(roundID: saved.roundID), saved)
        }
    }

    private func makeStore() throws -> (UserDefaultsRoundResumeStore, UserDefaults) {
        let suiteName = "RoundResumeRobustnessTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return (UserDefaultsRoundResumeStore(defaults: defaults, key: storageKey), defaults)
    }

    private func state(
        roundID: String,
        selectedHole: Int = 6,
        selectedTab: RoundResumeTab = .scoring
    ) -> RoundResumeState {
        RoundResumeState(
            roundID: roundID,
            seriesID: "series",
            destination: .liveRound,
            selectedHole: selectedHole,
            selectedTab: selectedTab,
            timestamp: Date(timeIntervalSince1970: 1_725_000_000)
        )
    }
}
