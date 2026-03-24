import XCTest
@testable import Hackers

final class TelemetryServiceTests: XCTestCase {
    func testAddEventMergesBaselineContextAndUserProperties() {
        let sentry = SentrySpy()
        let postHog = PostHogSpy()
        let harness = makeService(sentry: sentry, postHog: postHog)

        harness.service.configure(configuration: testConfiguration(groupsEnabled: false))
        harness.service.setContext(roundID: "round_1", seriesID: "series_1")
        harness.service.captureScreen("dashboard")

        harness.service.addEvent(
            "round.opened",
            eventProps: ["source": "dashboard"],
            userProps: ["plan": "pro"]
        )

        XCTAssertEqual(postHog.capturedEvents.count, 1)
        XCTAssertEqual(postHog.capturedEvents.first?.name, "round.opened")
        XCTAssertEqual(postHog.capturedEvents.first?.properties["round_id"] as? String, "round_1")
        XCTAssertEqual(postHog.capturedEvents.first?.properties["series_id"] as? String, "series_1")
        XCTAssertEqual(postHog.capturedEvents.first?.properties["screen_name"] as? String, "dashboard")
        XCTAssertEqual(postHog.capturedEvents.first?.properties["source"] as? String, "dashboard")
        XCTAssertEqual(postHog.capturedEvents.first?.properties["app_environment"] as? String, "sandbox")
        XCTAssertEqual(postHog.capturedEvents.first?.userProperties?["plan"] as? String, "pro")
        XCTAssertEqual(sentry.breadcrumbs.last?.message, "round.opened")
    }

    func testSetContextAndClearContextRegisterExpectedProperties() {
        let harness = makeService()
        let postHog = harness.postHogSpy

        harness.service.configure(configuration: testConfiguration(groupsEnabled: false))
        harness.service.setContext(roundID: "round_1", seriesID: "series_1", teamID: "team_1")

        XCTAssertEqual(postHog.registerCalls.last?["round_id"] as? String, "round_1")
        XCTAssertEqual(postHog.registerCalls.last?["series_id"] as? String, "series_1")
        XCTAssertEqual(postHog.registerCalls.last?["team_id"] as? String, "team_1")

        harness.service.clearContext()

        XCTAssertTrue(postHog.unregisterCalls.contains("round_id"))
        XCTAssertTrue(postHog.unregisterCalls.contains("series_id"))
        XCTAssertTrue(postHog.unregisterCalls.contains("team_id"))
    }

    func testGroupFallbackUsesGroupsOnlyWhenEnabled() {
        let groupsEnabledService = makeService()
        groupsEnabledService.service.configure(configuration: testConfiguration(groupsEnabled: true))
        groupsEnabledService.service.setContext(roundID: "round_1", seriesID: "series_1", teamID: "team_1")

        XCTAssertEqual(groupsEnabledService.postHogSpy.groupCalls.count, 3)
        XCTAssertNotNil(groupsEnabledService.postHogSpy.registerCalls.last?["$groups"])

        let groupsDisabledService = makeService()
        groupsDisabledService.service.configure(configuration: testConfiguration(groupsEnabled: false))
        groupsDisabledService.service.setContext(roundID: "round_1", seriesID: "series_1", teamID: "team_1")

        XCTAssertEqual(groupsDisabledService.postHogSpy.groupCalls.count, 0)
        XCTAssertNil(groupsDisabledService.postHogSpy.registerCalls.last?["$groups"])
    }

    func testFeatureFlagWrappersProxyPostHogValues() {
        let service = makeService()
        service.postHogSpy.featureFlags["new_ui"] = "variant_a"
        service.postHogSpy.featurePayloads["new_ui"] = ["copy": "hello"]

        service.service.configure(configuration: testConfiguration(groupsEnabled: false))

        XCTAssertTrue(service.service.isFeatureEnabled("new_ui"))
        XCTAssertEqual(service.service.featureVariant("new_ui"), "variant_a")
        XCTAssertEqual(service.service.featurePayload("new_ui") as? [String: String], ["copy": "hello"])
    }

    func testResetUserClearsTelemetryState() {
        let service = makeService()
        service.service.configure(configuration: testConfiguration(groupsEnabled: true))
        service.service.setContext(roundID: "round_1", seriesID: "series_1")
        service.service.captureScreen("live_round")

        service.service.resetUser()

        XCTAssertEqual(service.sentrySpy.clearUserCount, 1)
        XCTAssertEqual(service.postHogSpy.resetCount, 1)
        XCTAssertEqual(service.service.currentContext, .init())
        XCTAssertNil(service.service.currentScreenName)
    }

    func testRoundEventPropsIncludeCourseFormatAndParticipantContext() {
        let snapshot = MockLiveRound2v2.snapshot
        let participant = snapshot.participants[0]

        let props = TelemetryEventProps.round(
            snapshot: snapshot,
            participant: participant,
            teeID: participant.teeBoxID,
            seriesID: "series_42"
        )

        XCTAssertEqual(props["round_id"] as? String, MockLiveRound2v2.roundID)
        XCTAssertEqual(props["series_id"] as? String, "series_42")
        XCTAssertEqual(props["participant_id"] as? String, participant.id)
        XCTAssertEqual(props["group_id"] as? String, participant.groupID)
        XCTAssertEqual(props["team_id"] as? String, participant.teamID)
        XCTAssertEqual(props["tee_id"] as? String, participant.teeBoxID)
        XCTAssertEqual(props["hole_segment"] as? String, "full_18")
        XCTAssertEqual(props["participant_count"] as? Int, snapshot.participants.count)
        XCTAssertEqual(props["team_count"] as? Int, snapshot.teams.count)
        XCTAssertEqual(props["tee_group_count"] as? Int, snapshot.teeGroups.count)
        XCTAssertEqual(props["uses_handicaps"] as? Bool, true)
        XCTAssertEqual(props["requires_teams"] as? Bool, true)
        XCTAssertNotNil(props["course_id"])
        XCTAssertNotNil(props["format_template_id"])
    }

    func testCourseContextIncludesSelectionMetadata() {
        let snapshot = MockLiveRound2v2.snapshot
        let course = snapshot.course ?? Course()
        let tee = snapshot.defaultTee

        let props = TelemetryEventProps.courseContext(
            course: course,
            holeSegment: .front9,
            selectedTee: tee,
            selectionSource: .scorecardScan,
            isModifying: true
        )

        XCTAssertEqual(props["course_id"] as? String, course.id)
        XCTAssertEqual(props["selection_source"] as? String, CourseSelectionSource.scorecardScan.rawValue)
        XCTAssertEqual(props["hole_segment"] as? String, "front_9")
        XCTAssertEqual(props["hole_count"] as? Int, 9)
        XCTAssertEqual(props["tee_id"] as? String, tee?.id)
        XCTAssertEqual(props["tee_name"] as? String, tee?.name)
        XCTAssertEqual(props["is_existing_round_change"] as? Bool, true)
    }

    func testScoringPropsIncludeRelativeScoreAndProgress() {
        let snapshot = MockLiveRound2v2.snapshot
        let participant = snapshot.participants[0]
        let holeNumber = 1
        let par = snapshot.defaultTee?.holes.first(where: { $0.number == holeNumber })?.par ?? 4

        let props = TelemetryEventProps.scoring(
            snapshot: snapshot,
            participant: participant,
            entryParticipantID: "entry_participant_1",
            holeNumber: holeNumber,
            strokes: par + 2,
            entryMethod: .customPrompt,
            participantHolesScoredCount: 5,
            totalHoles: 18,
            participantCompletionPct: 27.8
        )

        XCTAssertEqual(props["participant_id"] as? String, participant.id)
        XCTAssertEqual(props["entry_participant_id"] as? String, "entry_participant_1")
        XCTAssertEqual(props["hole_number"] as? Int, holeNumber)
        XCTAssertEqual(props["par"] as? Int, par)
        XCTAssertEqual(props["strokes"] as? Int, par + 2)
        XCTAssertEqual(props["score_relative_to_par"] as? Int, 2)
        XCTAssertEqual(props["entry_method"] as? String, LiveRoundEntryMethod.customPrompt.rawValue)
        XCTAssertEqual(props["participant_holes_scored_count"] as? Int, 5)
        XCTAssertEqual(props["total_holes"] as? Int, 18)
        XCTAssertEqual(props["participant_completion_pct"] as? Double ?? 0, 27.8, accuracy: 0.0001)
    }

    func testHoleCompletionTransitionHelperDetectsCompletedAndReopened() {
        XCTAssertEqual(TelemetryEventProps.holeCompletionTransition(before: 0.75, after: 1.0), .completed)
        XCTAssertEqual(TelemetryEventProps.holeCompletionTransition(before: 1.0, after: 0.5), .reopened)
        XCTAssertEqual(TelemetryEventProps.holeCompletionTransition(before: 0.25, after: 0.5), .none)
        XCTAssertEqual(TelemetryEventProps.completionPercentage(completedCount: 3, totalCount: 9), 33.33333333333333, accuracy: 0.0001)
    }

    private func makeService(
        sentry: SentrySpy = .init(),
        postHog: PostHogSpy = .init()
    ) -> (service: TelemetryService, sentrySpy: SentrySpy, postHogSpy: PostHogSpy) {
        (
            TelemetryService(
                sentryClient: sentry,
                postHogClient: postHog,
                bundle: Bundle(for: TelemetryServiceTests.self),
                notificationCenter: .default
            ),
            sentry,
            postHog
        )
    }

    private func testConfiguration(groupsEnabled: Bool) -> TelemetryConfiguration {
        TelemetryConfiguration(
            sentryDSN: "https://example@sentry.io/123",
            sentryEnvironment: "Sandbox",
            sentryTracesSampleRate: 1.0,
            postHogAPIKey: "phc_test",
            postHogHost: "https://us.i.posthog.com",
            postHogGroupsEnabled: groupsEnabled,
            postHogSessionReplayEnabled: true
        )
    }
}

private final class SentrySpy: TelemetrySentryClient {
    struct BreadcrumbRecord {
        let level: TelemetryLevel
        let category: String?
        let message: String
        let data: [String: Any]?
    }

    var crashedLastRun = false
    var breadcrumbs: [BreadcrumbRecord] = []
    var clearUserCount = 0

    func configure(_ configuration: TelemetryConfiguration) { }

    func addBreadcrumb(level: TelemetryLevel, category: String?, message: String, data: [String: Any]?) {
        breadcrumbs.append(.init(level: level, category: category, message: message, data: data))
    }

    func capture(
        level: TelemetryLevel,
        message: String,
        error: Error?,
        file: String,
        line: Int,
        function: String,
        parameters: [String: Any]?,
        category: String?
    ) { }

    func setUser(id: String?, email: String?) { }

    func clearUser() {
        clearUserCount += 1
    }
}

private final class PostHogSpy: TelemetryPostHogClient {
    struct CapturedEvent {
        let name: String
        let properties: [String: Any]
        let userProperties: [String: Any]?
    }

    struct GroupCall {
        let type: String
        let key: String
        let properties: [String: Any]?
    }

    var isConfigured = false
    var capturedEvents: [CapturedEvent] = []
    var screenEvents: [CapturedEvent] = []
    var registerCalls: [[String: Any]] = []
    var unregisterCalls: [String] = []
    var groupCalls: [GroupCall] = []
    var featureFlags: [String: Any] = [:]
    var featurePayloads: [String: Any] = [:]
    var resetCount = 0

    func configure(_ configuration: TelemetryConfiguration) {
        isConfigured = true
    }

    func capture(_ name: String, properties: [String: Any], userProperties: [String: Any]?) {
        capturedEvents.append(.init(name: name, properties: properties, userProperties: userProperties))
    }

    func screen(_ name: String, properties: [String: Any]?) {
        screenEvents.append(.init(name: name, properties: properties ?? [:], userProperties: nil))
    }

    func identify(_ distinctId: String, userProperties: [String: Any]?) { }

    func reset() {
        resetCount += 1
    }

    func register(_ properties: [String: Any]) {
        registerCalls.append(properties)
    }

    func unregister(_ key: String) {
        unregisterCalls.append(key)
    }

    func group(type: String, key: String, properties: [String: Any]?) {
        groupCalls.append(.init(type: type, key: key, properties: properties))
    }

    func isFeatureEnabled(_ key: String) -> Bool {
        let result = featureFlags[key]
        return result is String ? true : (result as? Bool) ?? false
    }

    func featureFlag(_ key: String) -> Any? {
        featureFlags[key]
    }

    func featurePayload(_ key: String) -> Any? {
        featurePayloads[key]
    }

    func reloadFeatureFlags(completion: (() -> Void)?) {
        completion?()
    }
}
