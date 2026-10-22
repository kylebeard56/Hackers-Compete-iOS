@testable import Hackers
import Combine
import SwiftUI
import XCTest

@MainActor
final class UserCompanionPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "UserCompanionPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMissingPreferencesDefaultOffEvenWithLegacyRoundSelection() {
        defaults.set("old-round", forKey: "selected_live_round_for_watch_v1")
        defaults.set(true, forKey: "live_round_activity_enabled_v1")
        let preferences = UserCompanionPreferences(defaults: defaults)
        preferences.selectUser("user-a")
        XCTAssertFalse(preferences.state.appleWatch)
        XCTAssertFalse(preferences.state.liveActivities)
    }

    func testSwitchesAreIndependentAndBothOffValuesPersistAfterRelaunch() {
        let preferences = UserCompanionPreferences(defaults: defaults)
        preferences.selectUser("user-a")
        preferences.setAppleWatch(true)
        XCTAssertTrue(preferences.state.appleWatch)
        XCTAssertFalse(preferences.state.liveActivities)
        preferences.setLiveActivities(true)
        preferences.setAppleWatch(false)
        XCTAssertFalse(preferences.state.appleWatch)
        XCTAssertTrue(preferences.state.liveActivities)

        let relaunched = UserCompanionPreferences(defaults: defaults)
        relaunched.selectUser("user-a")
        XCTAssertEqual(relaunched.state, preferences.state)
        relaunched.setLiveActivities(false)
        let restoredOff = UserCompanionPreferences(defaults: defaults)
        restoredOff.selectUser("user-a")
        XCTAssertFalse(restoredOff.state.appleWatch)
        XCTAssertFalse(restoredOff.state.liveActivities)
    }

    func testSignOutPreservesPreferencesAndAccountsStayIsolated() {
        let preferences = UserCompanionPreferences(defaults: defaults)
        preferences.selectUser("user-a")
        preferences.setAppleWatch(true)
        preferences.setLiveActivities(true)
        preferences.selectUser(nil)
        XCTAssertFalse(preferences.state.appleWatch)
        XCTAssertFalse(preferences.state.liveActivities)
        preferences.setAppleWatch(true)
        XCTAssertFalse(preferences.state.appleWatch)
        preferences.selectUser("user-b")
        XCTAssertFalse(preferences.state.appleWatch)
        XCTAssertFalse(preferences.state.liveActivities)
        preferences.selectUser("user-a")
        XCTAssertTrue(preferences.state.appleWatch)
        XCTAssertTrue(preferences.state.liveActivities)
    }

    func testSameAccountRestorationPreservesSelectionBeforeAndAfterPreferenceHydration() {
        for hydrateFirst in [false, true] {
            let store = SelectedLiveRoundStore(defaults: defaults)
            store.selectUser("user-a")
            store.select("selected-round")
            let preferences = UserCompanionPreferences(defaults: defaults)
            if hydrateFirst { preferences.selectUser("user-a") }
            let coordinator = LiveRoundCompanionCoordinator(
                selectionStore: SelectedLiveRoundStore(defaults: defaults), preferences: preferences
            )
            preferences.selectUser("user-a")
            XCTAssertEqual(coordinator.selectedRoundID, "selected-round")
            XCTAssertEqual(coordinator.liveActivityRoundID, "selected-round")
            XCTAssertEqual(SelectedLiveRoundStore(defaults: defaults).roundID, "selected-round")
        }
    }

    func testDifferentAccountRestorationAndSignOutClearSelection() {
        let store = SelectedLiveRoundStore(defaults: defaults)
        store.selectUser("user-a")
        store.select("round-a")
        let preferences = UserCompanionPreferences(defaults: defaults)
        let coordinator = LiveRoundCompanionCoordinator(
            selectionStore: SelectedLiveRoundStore(defaults: defaults), preferences: preferences
        )
        preferences.selectUser("user-b")
        XCTAssertNil(coordinator.selectedRoundID)
        XCTAssertNil(coordinator.liveActivityRoundID)
        coordinator.select(roundID: "round-b")
        preferences.selectUser("user-a")
        XCTAssertNil(coordinator.selectedRoundID)
        coordinator.select(roundID: "round-a")
        coordinator.resetSelections()
        XCTAssertNil(coordinator.selectedRoundID)
        XCTAssertNil(SelectedLiveRoundStore(defaults: defaults).roundID)
        preferences.selectUser("user-a")
        XCTAssertNil(coordinator.selectedRoundID)
    }

    func testLegacySelectionWithoutOwnerIsNotAdoptedBySignedInAccount() {
        defaults.set("unknown-owner-round", forKey: "selected_live_round_for_watch_v1")
        let preferences = UserCompanionPreferences(defaults: defaults)
        let coordinator = LiveRoundCompanionCoordinator(
            selectionStore: SelectedLiveRoundStore(defaults: defaults), preferences: preferences
        )
        preferences.selectUser("user-a")
        XCTAssertNil(coordinator.selectedRoundID)
        XCTAssertNil(coordinator.liveActivityRoundID)
    }

    func testMissingPlayerDuringRestorationDoesNotEraseSavedSelection() {
        let preferences = UserCompanionPreferences(defaults: defaults)
        preferences.selectUser("user-a")
        let coordinator = LiveRoundCompanionCoordinator(
            selectionStore: SelectedLiveRoundStore(defaults: defaults), preferences: preferences
        )
        coordinator.select(roundID: "selected-round")
        coordinator.reconcileEligibleRounds([], currentPlayerID: nil)
        XCTAssertEqual(coordinator.selectedRoundID, "selected-round")
        coordinator.reconcileEligibleRounds([], currentPlayerID: "player-a")
        XCTAssertNil(coordinator.selectedRoundID)
    }

    func testCoordinatorRejectsWatchMutationsWhileDisabled() async throws {
        let preferences = UserCompanionPreferences(defaults: defaults)
        preferences.selectUser("user-a")
        let watch = PhoneWatchConnectivityService()
        let coordinator = LiveRoundCompanionCoordinator(
            watchConnectivity: watch, preferences: preferences
        )
        let mutation = WatchScoreMutation(
            deviceSequence: 1, roundID: "round", holeNumber: 1,
            scoringUnitID: "unit", participantIDs: ["participant"],
            anchorParticipantID: "participant", operation: .set(4),
            observedScoreRevision: nil
        )
        let reply = try XCTUnwrap(watch.mutationHandler)
        let acknowledgement = await reply(mutation)
        XCTAssertEqual(acknowledgement.status, .rejected)
        XCTAssertEqual(acknowledgement.errorCategory, .unauthorized)
        XCTAssertNil(coordinator.lastProjection)
    }

    func testCoordinatorActivatesWatchAndDisablesItWithoutChangingRoundSelection() async throws {
        let preferences = UserCompanionPreferences(defaults: defaults)
        let watchSession = RoundSession()
        let coordinator = LiveRoundCompanionCoordinator(
            selectionStore: SelectedLiveRoundStore(defaults: defaults),
            companionRoundSession: watchSession,
            preferences: preferences
        )
        let app = AppSession(restoresAuthentication: false)
        app.ephemeralParticipantID = "participant_1"
        await coordinator.start(appSession: app)
        preferences.selectUser("user-a")
        // Let identity cleanup finish before preparing a warm in-memory round.
        for _ in 0..<20 { await Task.yield() }
        preferences.setAppleWatch(true)
        await prepareWarmSession(watchSession)
        let published = expectation(description: "Watch receives live round data")
        let subscription = coordinator.$lastProjection.compactMap { $0 }.prefix(1).sink { _ in
            published.fulfill()
        }
        coordinator.select(roundID: MockLiveRound2v2.roundID)
        await fulfillment(of: [published], timeout: 3)
        XCTAssertEqual(coordinator.lastProjection?.roundID, MockLiveRound2v2.roundID)

        preferences.setAppleWatch(false)
        XCTAssertNil(coordinator.lastProjection)
        XCTAssertNil(watchSession.roundID)
        XCTAssertEqual(coordinator.selectedRoundID, MockLiveRound2v2.roundID)
        XCTAssertFalse(preferences.state.liveActivities)
        subscription.cancel()
    }

    func testCoordinatorStartsAndEndsLiveActivityIndependentlyOfWatch() async {
        let preferences = UserCompanionPreferences(defaults: defaults)
        let activity = ActivitySpy()
        let activitySession = RoundSession()
        let coordinator = LiveRoundCompanionCoordinator(
            selectionStore: SelectedLiveRoundStore(defaults: defaults),
            activityRoundSession: activitySession,
            activityManager: activity, preferences: preferences
        )
        let app = AppSession(restoresAuthentication: false)
        app.ephemeralParticipantID = "participant_1"
        await coordinator.start(appSession: app)
        preferences.selectUser("user-a")
        for _ in 0..<20 { await Task.yield() }
        preferences.setLiveActivities(true)
        await prepareWarmSession(activitySession)
        let started = expectation(description: "Activity receives live round data")
        activity.onSynchronize = { started.fulfill() }
        coordinator.select(roundID: MockLiveRound2v2.roundID)
        await fulfillment(of: [started], timeout: 3)
        activity.onSynchronize = nil
        XCTAssertTrue(activity.isEnabled)
        XCTAssertTrue(activity.mayStart)
        XCTAssertFalse(preferences.state.appleWatch)
        XCTAssertNil(coordinator.lastProjection)

        let ended = expectation(description: "Turning off immediately ends the activity")
        activity.onEnd = { ended.fulfill() }
        preferences.setLiveActivities(false)
        XCTAssertFalse(activity.isEnabled)
        await fulfillment(of: [ended], timeout: 3)
        XCTAssertNil(activitySession.roundID)
        XCTAssertEqual(coordinator.liveActivityRoundID, MockLiveRound2v2.roundID)
        activity.onEnd = nil

        // A quick OFF/ON must finish the native end before a replacement starts.
        preferences.setLiveActivities(true)
        preferences.setLiveActivities(false)
        preferences.setLiveActivities(true)
        await prepareWarmSession(activitySession)
        let restarted = expectation(description: "Activity restarts after rapid preference changes")
        activity.onSynchronize = { restarted.fulfill() }
        let endCount = activity.endCount
        await fulfillment(of: [restarted], timeout: 3)
        XCTAssertGreaterThan(activity.endCount, endCount)
        activity.onSynchronize = nil
        preferences.setLiveActivities(false)
    }

    func testDefaultOffStartupEndsAnyActivityFromAnEarlierLaunch() async {
        let activity = ActivitySpy()
        let coordinator = LiveRoundCompanionCoordinator(
            selectionStore: SelectedLiveRoundStore(defaults: defaults),
            activityManager: activity,
            preferences: UserCompanionPreferences(defaults: defaults)
        )
        await coordinator.start(appSession: AppSession(restoresAuthentication: false))
        XCTAssertFalse(activity.isEnabled)
        XCTAssertGreaterThan(activity.endCount, 0)
    }

    func testNativeManagerDoesNotPublishWhenDisabled() async throws {
        let manager = RoundLiveActivityManager()
        let state = RoundLiveActivityAttributes.ContentState(
            phase: .live, roundTitle: "Round", holeLabel: "Hole 1 of 18",
            holeProgress: 0, hole: nil, personalScore: .init(title: "You", value: "E", thru: "Thru 0"),
            teamScore: nil, matchup: nil,
            deepLinkURL: try XCTUnwrap(URL(string: "hackersgolf:///live-round?round_id=round")),
            updatedAt: Date()
        )
        await manager.synchronize(
            attributes: .init(roundID: "round", participantID: "participant"),
            state: state, mayStartNewActivity: true
        )
        XCTAssertNil(manager.latestState)
        manager.isEnabled = true
        manager.isEnabled = false
        await manager.synchronize(
            attributes: .init(roundID: "round", participantID: "participant"),
            state: state, mayStartNewActivity: true
        )
        XCTAssertNil(manager.latestState)
    }

    func testSettingsRendersInLightDarkAndLargeText() async throws {
        let preferences = UserCompanionPreferences(defaults: defaults)
        preferences.selectUser("preview-user")
        let companion = LiveRoundCompanionCoordinator(preferences: preferences)
        for scheme in [ColorScheme.light, .dark] {
            let host = UIHostingController(rootView: NavigationStack {
                UserSettingsView(
                    palette: .init(theme: .glass, scheme: scheme),
                    preferences: preferences, companion: companion
                )
            }
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, scheme == .dark ? .accessibility3 : .large))
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true
                previousKeyWindow?.makeKeyAndVisible()
            }
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(300))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Settings-\(scheme == .dark ? "dark-large-text" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func prepareWarmSession(_ session: RoundSession) async {
        await session.transitionProfile(to: .liveRound)
        session.roundID = MockLiveRound2v2.roundID
        session.snapshot = MockLiveRound2v2.snapshot
        session.recordSessionActivity()
    }
}

@MainActor
private final class ActivitySpy: RoundLiveActivityManaging {
    var isEnabled = false
    var mayStart = false
    var endCount = 0
    var onSynchronize: (() -> Void)?
    var onEnd: (() -> Void)?

    func synchronize(
        attributes: RoundLiveActivityAttributes,
        state: RoundLiveActivityAttributes.ContentState,
        mayStartNewActivity: Bool
    ) async {
        guard isEnabled else { return }
        mayStart = mayStartNewActivity
        onSynchronize?()
    }

    func end() async {
        endCount += 1
        onEnd?()
    }
}
