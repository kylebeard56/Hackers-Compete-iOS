//
//  TelemetryService.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import PostHog
import Sentry

/// Shared logging surface for app-wide diagnostics and telemetry.
protocol Loggable { }
typealias TelemetryLevel = SentryLevel

// https://posthog.com/docs/libraries/ios/usage

struct TelemetryConfiguration: Hashable {
    let sentryDSN: String
    let sentryEnvironment: String
    let sentryTracesSampleRate: Double
    let postHogAPIKey: String
    let postHogHost: String
    let postHogGroupsEnabled: Bool
    let postHogSessionReplayEnabled: Bool

    var hasSentryConfiguration: Bool {
        sentryDSN.isPopulated
    }

    var hasPostHogConfiguration: Bool {
        postHogAPIKey.isPopulated && postHogHost.isPopulated
    }

    static func load(bundle: Bundle = .main) -> TelemetryConfiguration {
        TelemetryConfiguration(
            sentryDSN: bundle.telemetryString(
                forKey: "SENTRY_DSN",
                defaultValue: "https://06c09f6fc6ec44949250d33033d1255e@o1318782.ingest.sentry.io/4504035028303872"
            ),
            sentryEnvironment: bundle.telemetryString(
                forKey: "SENTRY_ENVIRONMENT",
                defaultValue: TelemetryBuildEnvironment.name
            ),
            sentryTracesSampleRate: bundle.telemetryDouble(forKey: "SENTRY_TRACES_SAMPLE_RATE", defaultValue: 0.69),
            postHogAPIKey: bundle.telemetryString(forKey: "POSTHOG_API_KEY", defaultValue: ""),
            postHogHost: bundle.telemetryString(forKey: "POSTHOG_HOST", defaultValue: "https://us.i.posthog.com"),
            postHogGroupsEnabled: bundle.telemetryBool(forKey: "POSTHOG_GROUPS_ENABLED", defaultValue: false),
            postHogSessionReplayEnabled: bundle.telemetryBool(
                forKey: "POSTHOG_SESSION_REPLAY_ENABLED",
                defaultValue: true
            )
        )
    }
}

struct TelemetryContext: Hashable {
    var roundID: String?
    var seriesID: String?
    var teamID: String?
    var groupID: String?
    var participantID: String?

    var eventProperties: [String: Any] {
        var props: [String: Any] = [:]
        if let roundID { props["round_id"] = roundID }
        if let seriesID { props["series_id"] = seriesID }
        if let teamID { props["team_id"] = teamID }
        if let groupID { props["group_id"] = groupID }
        if let participantID { props["participant_id"] = participantID }
        return props
    }

    var postHogGroups: [String: String] {
        var groups: [String: String] = [:]
        if let roundID { groups["round"] = roundID }
        if let seriesID { groups["series"] = seriesID }
        if let teamID { groups["team"] = teamID }
        return groups
    }
}

enum CourseSelectionSource: String {
    case search
    case recent
    case nearby
    case manual
    case scorecardScan = "scorecard_scan"
    case existingRoundChange = "existing_round_change"
    case seriesRoundDefault = "series_round_default"
}

enum LiveRoundEntryMethod: String {
    case quickPicker = "quick_picker"
    case customPrompt = "custom_prompt"
    case clear
    case maxScoreFill = "max_score_fill"
}

enum TelemetryHoleTransition: Equatable {
    case none
    case completed
    case reopened
}

enum TelemetryEventProps {
    static func round(
        snapshot: RoundSnapshot,
        participant: RoundParticipant? = nil,
        teeID: String? = nil,
        seriesID: String? = TelemetryService.shared.currentContext.seriesID,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        let selectedTee = selectedTee(in: snapshot, participant: participant, teeID: teeID)
        let selectedCourse = snapshot.course ?? snapshot.courseInfo.map(Course.init(info:))
        let template = snapshot.resolvedActiveTemplate

        var props: [String: Any] = [
            "round_id": snapshot.round.id,
            "hole_segment": holeSegmentID(snapshot.holeSegment),
            "hole_count": snapshot.holeRange?.count ?? snapshot.holeSegment.holeCount,
            "format_template_id": template.id,
            "format_name": template.name,
            "format_category": template.category.rawValue,
            "competition_scope": snapshot.configuration.resolvedCompetitionScope.rawValue,
            "uses_handicaps": snapshot.configuration.useHandicaps,
            "requires_teams": snapshot.requiresTeams,
            "max_score_over_par": snapshot.gameFormat.configuration.maxScoreOverPar.rawValue,
            "participant_count": snapshot.participants.count,
            "team_count": snapshot.teams.count,
            "tee_group_count": snapshot.teeGroups.count,
            "matchup_count": snapshot.roundSegment?.matchups?.count ?? 0
        ]

        if let seriesID, seriesID.isPopulated {
            props["series_id"] = seriesID
        }

        if let selectedCourse {
            props.merge(
                courseContext(
                    course: selectedCourse,
                    holeSegment: snapshot.holeSegment,
                    selectedTee: selectedTee
                )
            ) { _, new in new }
        } else if let selectedTee {
            props["tee_id"] = selectedTee.id
            props["tee_name"] = selectedTee.name
        }

        if let participant {
            props["participant_id"] = participant.id
            if let groupID = participant.groupID, groupID.isPopulated {
                props["group_id"] = groupID
            }
            if let teamID = participant.teamID, teamID.isPopulated {
                props["team_id"] = teamID
            }
        }

        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    static func courseContext(
        course: Course,
        holeSegment: HoleSegment? = nil,
        selectedTee: Tee? = nil,
        selectionSource: CourseSelectionSource? = nil,
        isModifying: Bool? = nil,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        let courseName = course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName

        var props: [String: Any] = [
            "course_id": course.id,
            "course_origin": course.origin.isPopulated ? course.origin : CourseOrigin.unknown.rawValue
        ]

        if let golfCourseApiID = course.golfCourseApiID {
            props["course_api_id"] = golfCourseApiID
        }

        if courseName.isPopulated {
            props["course_name"] = courseName
        }

        if let holeSegment {
            props["hole_segment"] = holeSegmentID(holeSegment)
            props["hole_count"] = holeSegment.holeCount
        }

        if let selectedTee {
            props["tee_id"] = selectedTee.id
            props["tee_name"] = selectedTee.name
        }

        if let selectionSource {
            props["selection_source"] = selectionSource.rawValue
        }

        if let isModifying {
            props["is_existing_round_change"] = isModifying
        }

        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    static func scoring(
        snapshot: RoundSnapshot,
        participant: RoundParticipant,
        entryParticipantID: String,
        holeNumber: Int,
        strokes: Int? = nil,
        entryMethod: LiveRoundEntryMethod,
        participantHolesScoredCount: Int,
        totalHoles: Int,
        participantCompletionPct: Double,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        var props = round(snapshot: snapshot, participant: participant)
        let participantTee = snapshot.tees.first(where: { $0.id == participant.teeBoxID })
        let hole = participantTee?.holes.first(where: { $0.number == holeNumber })
            ?? snapshot.defaultTee?.holes.first(where: { $0.number == holeNumber })

        props["entry_participant_id"] = entryParticipantID
        props["is_self_scored"] = entryParticipantID == participant.id
        props["hole_number"] = holeNumber
        props["entry_method"] = entryMethod.rawValue
        props["participant_holes_scored_count"] = participantHolesScoredCount
        props["total_holes"] = totalHoles
        props["participant_completion_pct"] = participantCompletionPct

        if let par = hole?.par {
            props["par"] = par
            if let strokes {
                props["score_relative_to_par"] = strokes - par
            }
        }

        if let strokes {
            props["strokes"] = strokes
        }

        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    static func holeCompletionTransition(before: Double, after: Double) -> TelemetryHoleTransition {
        switch (before >= 1, after >= 1) {
        case (false, true):
            return .completed
        case (true, false):
            return .reopened
        default:
            return .none
        }
    }

    static func roundSessionActivation(
        roundID: String,
        profile: RoundSubscriptionProfile,
        rebuildReason: RoundSessionRebuildReason,
        sameRoundReuse: Bool,
        existingListenerTypes: Set<RoundRegistrationType>,
        targetListenerTypes: Set<RoundRegistrationType>,
        seriesID: String? = TelemetryService.shared.currentContext.seriesID
    ) -> [String: Any] {
        var props: [String: Any] = [
            "round_id": roundID,
            "profile": profile.rawValue,
            "same_round_reuse": sameRoundReuse,
            "rebuild_reason": rebuildReason.rawValue,
            "existing_listener_count": existingListenerTypes.count,
            "target_listener_count": targetListenerTypes.count,
            "active_listener_types": listenerTypesString(existingListenerTypes),
            "target_listener_types": listenerTypesString(targetListenerTypes)
        ]

        if let seriesID, seriesID.isPopulated {
            props["series_id"] = seriesID
        }

        return props
    }

    static func roundSessionProfileTransition(
        roundID: String,
        from previousProfile: RoundSubscriptionProfile,
        to nextProfile: RoundSubscriptionProfile,
        listenersAdded: Set<RoundRegistrationType>,
        listenersRemoved: Set<RoundRegistrationType>,
        seriesID: String? = TelemetryService.shared.currentContext.seriesID
    ) -> [String: Any] {
        var props: [String: Any] = [
            "round_id": roundID,
            "from_profile": previousProfile.rawValue,
            "to_profile": nextProfile.rawValue,
            "listeners_added": listenersAdded.count,
            "listeners_removed": listenersRemoved.count,
            "listener_types_added": listenerTypesString(listenersAdded),
            "listener_types_removed": listenerTypesString(listenersRemoved)
        ]

        if let seriesID, seriesID.isPopulated {
            props["series_id"] = seriesID
        }

        return props
    }

    static func roundSessionInitialSnapshotLoaded(
        snapshot: RoundSnapshot,
        profile: RoundSubscriptionProfile,
        listenerTypes: Set<RoundRegistrationType>,
        loadSource: String,
        startedAt: Date?,
        seriesID: String? = TelemetryService.shared.currentContext.seriesID
    ) -> [String: Any] {
        var props: [String: Any] = [
            "round_id": snapshot.round.id,
            "profile": profile.rawValue,
            "listener_count": listenerTypes.count,
            "participant_count": snapshot.participants.count,
            "team_count": snapshot.teams.count,
            "tee_group_count": snapshot.teeGroups.count,
            "scoring_group_count": snapshot.scoringGroups.count,
            "segment_count": snapshot.segments.count,
            "score_count": snapshot.scoring.count,
            "round_status": snapshot.round.status.rawValue,
            "load_source": loadSource,
            "ready_duration_ms": startedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        ]

        if let seriesID, seriesID.isPopulated {
            props["series_id"] = seriesID
        }

        return props
    }

    static func roundSessionStaleRefreshTriggered(
        roundID: String,
        profile: RoundSubscriptionProfile,
        staleReason: RoundSessionStaleReason,
        backgroundDurationSec: Int?,
        hadLiveScoringListener: Bool,
        seriesID: String? = TelemetryService.shared.currentContext.seriesID
    ) -> [String: Any] {
        var props: [String: Any] = [
            "round_id": roundID,
            "profile": profile.rawValue,
            "stale_reason": staleReason.rawValue,
            "had_live_scoring_listener": hadLiveScoringListener
        ]

        if let seriesID, seriesID.isPopulated {
            props["series_id"] = seriesID
        }

        if let backgroundDurationSec {
            props["background_duration_sec"] = backgroundDurationSec
        }

        return props
    }

    static func roundSessionListenerError(
        roundID: String,
        profile: RoundSubscriptionProfile,
        listenerType: RoundRegistrationType,
        error: Error,
        seriesID: String? = TelemetryService.shared.currentContext.seriesID
    ) -> [String: Any] {
        let nsError = error as NSError

        var props: [String: Any] = [
            "round_id": roundID,
            "profile": profile.rawValue,
            "listener_type": listenerType.rawValue,
            "error_domain": nsError.domain,
            "error_code": nsError.code,
            "error_description_short": String(nsError.localizedDescription.prefix(120))
        ]

        if let seriesID, seriesID.isPopulated {
            props["series_id"] = seriesID
        }

        return props
    }

    private static func listenerTypesString(_ types: Set<RoundRegistrationType>) -> String {
        types
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }

    static func completionPercentage(completedCount: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return (Double(completedCount) / Double(totalCount)) * 100
    }

    private static func selectedTee(
        in snapshot: RoundSnapshot,
        participant: RoundParticipant?,
        teeID: String?
    ) -> Tee? {
        if let teeID, teeID.isPopulated {
            return snapshot.tees.first(where: { $0.id == teeID })
        }

        if let participant, participant.teeBoxID.isPopulated {
            return snapshot.tees.first(where: { $0.id == participant.teeBoxID })
        }

        return snapshot.defaultTee
    }

    private static func holeSegmentID(_ segment: HoleSegment) -> String {
        switch segment {
        case .full18:
            return "full_18"
        case .front9:
            return "front_9"
        case .back9:
            return "back_9"
        case .custom(let lower, let upper):
            return "custom_\(lower)_\(upper)"
        }
    }
}

protocol TelemetrySentryClient {
    var crashedLastRun: Bool { get }
    func configure(_ configuration: TelemetryConfiguration)
    func addBreadcrumb(level: TelemetryLevel, category: String?, message: String, data: [String: Any]?)
    func capture(
        level: TelemetryLevel,
        message: String,
        error: Error?,
        file: String,
        line: Int,
        function: String,
        parameters: [String: Any]?,
        category: String?
    )
    func setUser(id: String?, email: String?)
    func clearUser()
}

protocol TelemetryPostHogClient {
    var isConfigured: Bool { get }
    func configure(_ configuration: TelemetryConfiguration)
    func capture(_ name: String, properties: [String: Any], userProperties: [String: Any]?)
    func screen(_ name: String, properties: [String: Any]?)
    func identify(_ distinctId: String, userProperties: [String: Any]?)
    func reset()
    func register(_ properties: [String: Any])
    func unregister(_ key: String)
    func group(type: String, key: String, properties: [String: Any]?)
    func isFeatureEnabled(_ key: String) -> Bool
    func featureFlag(_ key: String) -> Any?
    func featurePayload(_ key: String) -> Any?
    func reloadFeatureFlags(completion: (() -> Void)?)
}

final class TelemetryService {
    static let shared = TelemetryService()

    private let sentryClient: TelemetrySentryClient
    private let postHogClient: TelemetryPostHogClient
    private let bundle: Bundle
    private let notificationCenter: NotificationCenter

    private(set) var configuration: TelemetryConfiguration?
    private(set) var currentContext = TelemetryContext()
    private(set) var currentScreenName: String?

    private var didConfigure = false
    private var registeredContextKeys = Set<String>()
    private var identifiedGroupKeys: [String: String] = [:]
    private var featureFlagsObserver: NSObjectProtocol?

    init(
        sentryClient: TelemetrySentryClient = LiveSentryTelemetryClient(),
        postHogClient: TelemetryPostHogClient = LivePostHogTelemetryClient(),
        bundle: Bundle = .main,
        notificationCenter: NotificationCenter = .default
    ) {
        self.sentryClient = sentryClient
        self.postHogClient = postHogClient
        self.bundle = bundle
        self.notificationCenter = notificationCenter
    }

    func configure() {
        configure(configuration: nil)
    }

    func configure(configuration: TelemetryConfiguration?) {
        guard !didConfigure else { return }

        let config = configuration ?? TelemetryConfiguration.load(bundle: bundle)
        self.configuration = config

        if config.hasSentryConfiguration {
            sentryClient.configure(config)
        }

        if config.hasPostHogConfiguration {
            postHogClient.configure(config)
            observeFeatureFlagsIfNeeded()
            syncRegisteredContextProperties()
        } else {
            addBreadcrumb(
                level: .warning,
                category: "telemetry",
                message: "PostHog API key missing; analytics and replay are disabled"
            )
        }

        didConfigure = true
    }

    func addBreadcrumb(
        level: TelemetryLevel = .info,
        category: String? = nil,
        message: String? = nil,
        error: Error? = nil,
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        parameters: [String: Any]? = nil
    ) {
        let resolvedMessage: String
        if let error {
            resolvedMessage = (message ?? function) + " with error: \(error)"
        } else {
            resolvedMessage = message ?? function
        }

        sentryClient.addBreadcrumb(
            level: level,
            category: category,
            message: resolvedMessage,
            data: parameters
        )

        if [.warning, .error, .fatal].contains(level) {
            sentryClient.capture(
                level: level,
                message: resolvedMessage,
                error: error,
                file: file,
                line: line,
                function: function,
                parameters: parameters,
                category: category
            )
        }

        let label = label(for: level)
        let time = Date().timestamp
        let fileLine = "\(file.fileNameWithoutExtension):\(line)"
        let printedLine = "[\(label)] [\(time)] [\(fileLine)] \(resolvedMessage)"
        print(printedLine)
    }

    func addEvent(
        _ name: String,
        eventProps: [String: Any]? = nil,
        userProps: [String: Any]? = nil
    ) {
        let mergedProps = mergedEventProperties(with: eventProps)
        postHogClient.capture(name, properties: mergedProps, userProperties: userProps)
        addBreadcrumb(category: "telemetry.event", message: name, parameters: mergedProps)
    }

    func identify(user: HackersUser, authUserID: String?) {
        let distinctID = authUserID ?? user.id
        let userProps: [String: Any] = [
            "email": user.email,
            "hackers_user_id": user.id,
            "player_count": user.players.count,
            "status": user.status,
            "last_app_version": user.metadata.latestVersion,
            "device_operating_system": user.metadata.deviceOS
        ]

        sentryClient.setUser(id: distinctID, email: user.email)
        postHogClient.identify(distinctID, userProperties: userProps)
    }

    func resetUser() {
        sentryClient.clearUser()
        postHogClient.reset()
        currentContext = .init()
        currentScreenName = nil
        registeredContextKeys.removeAll()
        identifiedGroupKeys.removeAll()
    }

    func captureScreen(_ name: String, properties: [String: Any]? = nil) {
        currentScreenName = name
        let mergedProps = mergedEventProperties(with: properties)
        postHogClient.screen(name, properties: mergedProps)
        addBreadcrumb(category: "telemetry.screen", message: name, parameters: mergedProps)
    }

    func clearScreen(_ name: String? = nil) {
        guard name == nil || currentScreenName == name else { return }
        currentScreenName = nil
    }

    func setContext(
        roundID: String? = nil,
        seriesID: String? = nil,
        teamID: String? = nil,
        groupID: String? = nil,
        participantID: String? = nil
    ) {
        if let roundID { currentContext.roundID = roundID }
        if let seriesID { currentContext.seriesID = seriesID }
        if let teamID { currentContext.teamID = teamID }
        if let groupID { currentContext.groupID = groupID }
        if let participantID { currentContext.participantID = participantID }

        syncRegisteredContextProperties()
        identifyGroupsIfNeeded()
    }

    func clearContext() {
        currentContext = .init()
        syncRegisteredContextProperties()
        identifiedGroupKeys.removeAll()
    }

    func isFeatureEnabled(_ key: String) -> Bool {
        postHogClient.isFeatureEnabled(key)
    }

    func featureVariant(_ key: String) -> String? {
        postHogClient.featureFlag(key) as? String
    }

    func featurePayload(_ key: String) -> Any? {
        postHogClient.featurePayload(key)
    }

    func reloadFeatureFlags(completion: (() -> Void)? = nil) {
        postHogClient.reloadFeatureFlags(completion: completion)
    }

    func storeLegacySentryUser(with email: String) {
        sentryClient.setUser(id: nil, email: email)
    }

    func mergedEventProperties(with eventProps: [String: Any]? = nil) -> [String: Any] {
        var props: [String: Any] = [
            "app_environment": configuration?.sentryEnvironment.lowercased() ?? TelemetryBuildEnvironment.name,
            "app_version": bundle.appVersion
        ]

        if let currentScreenName {
            props["screen_name"] = currentScreenName
        }

        currentContext.eventProperties.forEach { props[$0.key] = $0.value }

        if let postHogGroups = mergedPostHogGroups, !postHogGroups.isEmpty {
            props["$groups"] = postHogGroups
        }

        eventProps?.forEach { props[$0.key] = $0.value }
        return props
    }

    private var mergedPostHogGroups: [String: String]? {
        guard configuration?.postHogGroupsEnabled == true else { return nil }
        let groups = currentContext.postHogGroups
        return groups.isEmpty ? nil : groups
    }

    private func syncRegisteredContextProperties() {
        guard postHogClient.isConfigured else { return }

        var properties = currentContext.eventProperties
        if let postHogGroups = mergedPostHogGroups {
            properties["$groups"] = postHogGroups
        }

        let newKeys = Set(properties.keys)
        let keysToRemove = registeredContextKeys.subtracting(newKeys)
        for key in keysToRemove {
            postHogClient.unregister(key)
        }

        if properties.isPopulated {
            postHogClient.register(properties)
        }

        registeredContextKeys = newKeys
    }

    private func identifyGroupsIfNeeded() {
        guard configuration?.postHogGroupsEnabled == true, postHogClient.isConfigured else { return }

        for (type, key) in currentContext.postHogGroups where identifiedGroupKeys[type] != key {
            postHogClient.group(type: type, key: key, properties: ["name": key])
            identifiedGroupKeys[type] = key
        }
    }

    private func observeFeatureFlagsIfNeeded() {
        guard featureFlagsObserver == nil else { return }

        featureFlagsObserver = notificationCenter.addObserver(
            forName: PostHogSDK.didReceiveFeatureFlags,
            object: nil,
            queue: .main
        ) { _ in
            HackersNotification.telemetryFeatureFlagsLoaded.send()
        }
    }

    private func label(for level: TelemetryLevel) -> String {
        switch level {
        case .debug:        return "DEBUG"
        case .info:         return "INFO"
        case .warning:      return "WARNING"
        case .error:        return "ERROR"
        case .fatal:        return "FATAL"
        case .none:         return "NONE"
        @unknown default:   return "NONE"
        }
    }
}

extension Loggable {
    func addBreadcrumb(
        level: TelemetryLevel = .info,
        category: String? = nil,
        message: String? = nil,
        error: Error? = nil,
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        parameters: [String: Any]? = nil
    ) {
        TelemetryService.shared.addBreadcrumb(
            level: level,
            category: category,
            message: message,
            error: error,
            file: file,
            line: line,
            function: function,
            parameters: parameters
        )
    }

    func addEvent(
        _ name: String,
        eventProps: [String: Any]? = nil,
        userProps: [String: Any]? = nil
    ) {
        TelemetryService.shared.addEvent(name, eventProps: eventProps, userProps: userProps)
    }

    func storeSentryUser(with email: String) {
        TelemetryService.shared.storeLegacySentryUser(with: email)
    }

    func telemetryRoundProperties(
        snapshot: RoundSnapshot,
        participant: RoundParticipant? = nil,
        teeID: String? = nil,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        TelemetryEventProps.round(
            snapshot: snapshot,
            participant: participant,
            teeID: teeID,
            extra: extra
        )
    }

    func telemetryCourseProperties(
        course: Course,
        holeSegment: HoleSegment? = nil,
        selectedTee: Tee? = nil,
        selectionSource: CourseSelectionSource? = nil,
        isModifying: Bool? = nil,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        TelemetryEventProps.courseContext(
            course: course,
            holeSegment: holeSegment,
            selectedTee: selectedTee,
            selectionSource: selectionSource,
            isModifying: isModifying,
            extra: extra
        )
    }
}

private final class LiveSentryTelemetryClient: TelemetrySentryClient {
    var crashedLastRun: Bool {
        SentrySDK.crashedLastRun
    }

    func configure(_ configuration: TelemetryConfiguration) {
        SentrySDK.start { options in
            options.dsn = configuration.sentryDSN
            options.debug = false
            options.tracesSampleRate = NSNumber(value: configuration.sentryTracesSampleRate)
            options.environment = configuration.sentryEnvironment.lowercased()
            options.attachViewHierarchy = true
            options.enableMetricKit = true
            options.enableTimeToFullDisplayTracing = true
            options.swiftAsyncStacktraces = true
        }

        SentrySDK.configureScope { scope in
            scope.setTag(value: deviceUUID, key: "device_guid")
            scope.setTag(value: Locale.current.identifier, key: "locale")
        }
    }

    func addBreadcrumb(level: TelemetryLevel, category: String?, message: String, data: [String: Any]?) {
        let breadcrumb = Breadcrumb()
        breadcrumb.level = level
        breadcrumb.category = category ?? ""
        breadcrumb.message = message
        breadcrumb.data = data
        SentrySDK.addBreadcrumb(breadcrumb)
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
    ) {
        let event = Event(level: level)
        event.message = SentryMessage(formatted: message)

        SentrySDK.capture(event: event) { scope in
            if let error {
                scope.setContext(value: ["error": "\(error)"], key: "Error")
            }

            scope.setContext(
                value: [
                    "File": file.fileNameWithoutExtension,
                    "Line": "\(line)",
                    "Function": function
                ],
                key: "Source Code"
            )

            if let parameters {
                scope.setContext(value: parameters, key: "Additional Details")
            }

            if let category {
                scope.setTag(value: category, key: "Category")
            }

            scope.setTag(value: self.crashedLastRun ? "TRUE" : "FALSE", key: "Crashed last run")
        }
    }

    func setUser(id: String?, email: String?) {
        let user = User()
        user.userId = id
        user.email = email
        SentrySDK.setUser(user)
    }

    func clearUser() {
        SentrySDK.setUser(nil)
    }
}

private final class LivePostHogTelemetryClient: TelemetryPostHogClient {
    private(set) var isConfigured = false

    func configure(_ configuration: TelemetryConfiguration) {
        guard configuration.hasPostHogConfiguration else {
            isConfigured = false
            return
        }

        let config = PostHogConfig(apiKey: configuration.postHogAPIKey, host: configuration.postHogHost)
        config.personProfiles = .identifiedOnly
        config.captureScreenViews = false
        config.preloadFeatureFlags = true
        config.sendFeatureFlagEvent = true
        config.debug = TelemetryBuildEnvironment.isSandbox
        config.sessionReplay = configuration.postHogSessionReplayEnabled
        config.sessionReplayConfig.screenshotMode = configuration.postHogSessionReplayEnabled
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = true
        config.sessionReplayConfig.captureLogs = false
        config.sessionReplayConfig.captureNetworkTelemetry = true

        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    func capture(_ name: String, properties: [String: Any], userProperties: [String: Any]?) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture(name, properties: properties, userProperties: userProperties)
    }

    func screen(_ name: String, properties: [String: Any]?) {
        guard isConfigured else { return }
        PostHogSDK.shared.screen(name, properties: properties ?? [:])
    }

    func identify(_ distinctId: String, userProperties: [String: Any]?) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(distinctId, userProperties: userProperties ?? [:])
    }

    func reset() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }

    func register(_ properties: [String: Any]) {
        guard isConfigured, properties.isPopulated else { return }
        PostHogSDK.shared.register(properties)
    }

    func unregister(_ key: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.unregister(key)
    }

    func group(type: String, key: String, properties: [String: Any]?) {
        guard isConfigured else { return }
        PostHogSDK.shared.group(type: type, key: key, groupProperties: properties ?? [:])
    }

    func isFeatureEnabled(_ key: String) -> Bool {
        guard isConfigured else { return false }
        return PostHogSDK.shared.isFeatureEnabled(key)
    }

    func featureFlag(_ key: String) -> Any? {
        guard isConfigured else { return nil }
        return PostHogSDK.shared.getFeatureFlag(key)
    }

    func featurePayload(_ key: String) -> Any? {
        guard isConfigured else { return nil }
        return PostHogSDK.shared.getFeatureFlagPayload(key)
    }

    func reloadFeatureFlags(completion: (() -> Void)?) {
        guard isConfigured else {
            completion?()
            return
        }

        if let completion {
            PostHogSDK.shared.reloadFeatureFlags(completion)
        } else {
            PostHogSDK.shared.reloadFeatureFlags()
        }
    }
}

private extension Bundle {
    func telemetryString(forKey key: String, defaultValue: String) -> String {
        guard let value = object(forInfoDictionaryKey: key) else { return defaultValue }
        if let stringValue = value as? String, stringValue.isPopulated {
            return stringValue
        }
        return defaultValue
    }

    func telemetryBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard let value = object(forInfoDictionaryKey: key) else { return defaultValue }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            return NSString(string: stringValue).boolValue
        }

        return defaultValue
    }

    func telemetryDouble(forKey key: String, defaultValue: Double) -> Double {
        guard let value = object(forInfoDictionaryKey: key) else { return defaultValue }

        if let doubleValue = value as? Double {
            return doubleValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.doubleValue
        }

        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return doubleValue
        }

        return defaultValue
    }
}

private enum TelemetryBuildEnvironment {
    #if SANDBOX
    static let name = "sandbox"
    static let isSandbox = true
    #else
    static let name = "production"
    static let isSandbox = false
    #endif
}

private extension Date {
    static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()

    var timestamp: String {
        Date.formatter.string(from: self)
    }
}

private extension String {
    var fileNameWithoutExtension: String {
        URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }
}
