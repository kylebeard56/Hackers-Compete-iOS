//
//  RoundSession.swift
//  Hackers
//
//  Created by Kyle Beard on 9/3/25.
//

import Combine
import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

enum RoundRegistrationType: String, CaseIterable {
    case round, participant, segment, scoring, team, teeGroup
    case scoringGroup
}

enum RoundSubscriptionProfile: String, CaseIterable {
    case lobby
    case liveRound
    case roundOutcome
    case oneShot

    var listenerTypes: Set<RoundRegistrationType> {
        switch self {
        case .lobby:
            return [.round, .participant, .segment, .team, .teeGroup, .scoringGroup]
        case .liveRound:
            return Set(RoundRegistrationType.allCases)
        case .roundOutcome, .oneShot:
            return []
        }
    }

    var usesLiveListeners: Bool {
        !listenerTypes.isEmpty
    }
}

enum RoundSessionRebuildReason: String {
    case none
    case newRound = "new_round"
    case coldStart = "cold_start"
    case staleBackground = "stale_background"
    case staleInactive = "stale_inactive"
}

enum RoundSessionStaleReason: String {
    case backgroundTimeout = "background_timeout"
    case inactiveTimeout = "inactive_timeout"
}

@MainActor
final class RoundSession: ObservableObject, Loggable {
    static let staleSessionInterval: TimeInterval = 30 * 60
    static let listenerErrorThrottleInterval: TimeInterval = 5 * 60

    @Published var roundID: String?
    @Published var snapshot: RoundSnapshot = .init()
    /// When we last received data from any Firebase listener (round, scoring, etc.).
    @Published var lastSnapshotReceivedAt: Date?
    @Published private(set) var currentProfile: RoundSubscriptionProfile = .oneShot
    @Published private(set) var lastActiveAt: Date?
    @Published private(set) var lastForegroundAt: Date?
    @Published private(set) var lastBackgroundAt: Date?
    
    @Published var roundListener: ListenerRegistration?
    @Published var participantListener: ListenerRegistration?
    @Published var segmentListener: ListenerRegistration?
    @Published var scoringListener: ListenerRegistration?
    @Published var teamListener: ListenerRegistration?
    @Published var teeGroupListener: ListenerRegistration?
    @Published var scoringGroupListener: ListenerRegistration?
    
    @Published var isLoadingLobbyListeners = false
    @Published var isLoadingActiveListeners = false
    
    @Published var isAddingPlayers = false
    
    @Published var isStartingLiveRound = false
    @Published var roundActivationErrors: Set<RoundActivationError> = .init()
    @Published var showRoundActivationErrors = false
    @Published var showUnbalancedTeamsWarning = false
    
    var suppressParticipantListener = false
    private var needsRefreshAfterLongBackground = false
    private var initialLoadStartedAt: Date?
    private var initialLoadExpectedTypes: Set<RoundRegistrationType> = []
    private var initialLoadReadyTypes: Set<RoundRegistrationType> = []
    private var didEmitInitialSnapshotLoaded = false
    private var initialLoadSource: String?
    private var listenerErrorThrottle: [String: Date] = [:]
    
    var activeListeners: [RoundRegistrationType] {
        var result: [RoundRegistrationType] = []

        if roundListener != nil { result.append(.round) }
        if participantListener != nil { result.append(.participant) }
        if segmentListener != nil { result.append(.segment) }
        if scoringListener != nil { result.append(.scoring) }
        if teamListener != nil { result.append(.team) }
        if teeGroupListener != nil { result.append(.teeGroup) }
        if scoringGroupListener != nil { result.append(.scoringGroup) }

        return result
    }
    
    var inactiveListeners: [RoundRegistrationType] {
        let active = Set(activeListeners)
        return RoundRegistrationType.allCases.filter { !active.contains($0) }
    }
    
    var isRunning: Bool {
        activeListeners.count > 0
    }
    
    let reference: CollectionReference = Firestore.firestore().collection(Collections.rounds.rawValue)
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        observeSceneLifecycle()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
    
    func fetchSingleInstance(for roundID: String) async throws -> RoundSnapshot {
        addBreadcrumb()
        
        do {
            return .init(
                round:          try await FirebaseService.shared.getRoundDocument(byID: roundID).get(),
                participants:   try await FirebaseService.shared.getParticipants(for: roundID).get(),
                teams:          try await FirebaseService.shared.getTeams(for: roundID).get(),
                teeGroups:      try await FirebaseService.shared.getTeeGroups(for: roundID).get(),
                scoringGroups:  try await FirebaseService.shared.getScoringGroups(for: roundID).get(),
                segments:       try await FirebaseService.shared.getSegments(for: roundID).get(),
                scoring:        try await FirebaseService.shared.getScores(for: roundID).get()
            )
        } catch {
            throw error
        }
    }
    
    func start(for roundID: String) async {
        await activate(roundID: roundID, profile: .lobby)
    }

    func refreshOneShotSnapshot(for requestedRoundID: String? = nil) async {
        let targetRoundID = requestedRoundID ?? roundID
        guard let targetRoundID, targetRoundID.isPopulated else { return }
        await loadSingleSnapshotIfNeeded(for: targetRoundID, forceRefresh: true)
    }

    func activate(roundID requestedRoundID: String, profile: RoundSubscriptionProfile) async {
        addBreadcrumb(message: "Activate round session: round=\(requestedRoundID), profile=\(profile.rawValue)")

        let now = Date()
        let sameRound = roundID == requestedRoundID
        let shouldRebuild = shouldRebuildSession(for: requestedRoundID, asOf: now)
        let rebuildReason = rebuildReason(for: requestedRoundID, asOf: now)
        let existingListenerTypes = Set(activeListeners)
        let targetListenerTypes = profile.listenerTypes
        recordSessionActivity(at: now)

        emitRoundSessionActivated(
            roundID: requestedRoundID,
            profile: profile,
            rebuildReason: rebuildReason,
            sameRoundReuse: sameRound && !shouldRebuild,
            existingListenerTypes: existingListenerTypes,
            targetListenerTypes: targetListenerTypes
        )

        if sameRound, !shouldRebuild {
            if currentProfile != profile {
                await transitionProfile(to: profile)
            } else {
                addBreadcrumb(message: "Reuse warm round session without restarting listeners")
            }
            currentProfile = profile
            return
        }

        if shouldRebuild, sameRound {
            addBreadcrumb(message: "Rebuild stale round session for same round")
        } else if let previousRoundID = roundID, previousRoundID != requestedRoundID {
            addBreadcrumb(message: "Switch round session from \(previousRoundID) to \(requestedRoundID)")
        }

        if shouldRebuild, sameRound, let staleReason = staleReasonForCurrentSession(asOf: now) {
            emitStaleRefreshTriggered(
                roundID: requestedRoundID,
                profile: profile,
                staleReason: staleReason,
                asOf: now
            )
        }

        stopListeners()
        if !sameRound {
            snapshot = .init()
        }

        roundID = requestedRoundID
        currentProfile = profile
        needsRefreshAfterLongBackground = false
        TelemetryService.shared.setContext(roundID: requestedRoundID)

        if profile.usesLiveListeners {
            beginInitialLoadTracking(for: profile, startedAt: now, source: "live_listeners")
            await startListeners(for: profile)
        } else {
            await loadSingleSnapshotIfNeeded(for: requestedRoundID, forceRefresh: shouldRebuild || snapshot.round.id != requestedRoundID)
        }
    }

    func transitionProfile(to profile: RoundSubscriptionProfile) async {
        addBreadcrumb(message: "Transition round session profile to \(profile.rawValue)")

        let previousProfile = currentProfile
        currentProfile = profile
        recordSessionActivity()

        guard roundID.exists else { return }

        let previousListenerTypes = previousProfile.listenerTypes
        let nextListenerTypes = profile.listenerTypes
        let listenersAdded = nextListenerTypes.subtracting(previousListenerTypes)
        let listenersRemoved = previousListenerTypes.subtracting(nextListenerTypes)

        emitRoundSessionProfileTransition(
            roundID: roundID ?? "",
            from: previousProfile,
            to: profile,
            listenersAdded: listenersAdded,
            listenersRemoved: listenersRemoved
        )

        if profile.usesLiveListeners {
            beginInitialLoadTracking(for: profile, startedAt: Date(), source: "live_listeners")
            await startListeners(for: profile)
            stopListeners(excluding: profile.listenerTypes)
        } else {
            stopListeners()
            if let roundID, snapshot.round.id != roundID {
                await loadSingleSnapshotIfNeeded(for: roundID, forceRefresh: true)
            }
        }
    }

    func teardownIfDifferent(roundID requestedRoundID: String) {
        guard let currentRoundID = roundID, currentRoundID != requestedRoundID else { return }
        stop()
    }
    
    func stop() {
        addBreadcrumb()
        stopListeners()
        self.roundID = nil
        snapshot = .init()
        currentProfile = .oneShot
        lastActiveAt = nil
        lastSnapshotReceivedAt = nil
        lastForegroundAt = nil
        lastBackgroundAt = nil
        needsRefreshAfterLongBackground = false
        initialLoadStartedAt = nil
        initialLoadExpectedTypes = []
        initialLoadReadyTypes = []
        didEmitInitialSnapshotLoaded = false
        initialLoadSource = nil
    }

    func shouldRebuildSession(for requestedRoundID: String, asOf date: Date = Date()) -> Bool {
        guard roundID == requestedRoundID else { return true }
        return isSessionStale(asOf: date)
    }

    func rebuildReason(for requestedRoundID: String, asOf date: Date = Date()) -> RoundSessionRebuildReason {
        guard roundID == requestedRoundID else {
            return roundID == nil ? .coldStart : .newRound
        }

        guard isSessionStale(asOf: date) else { return .none }
        return needsRefreshAfterLongBackground ? .staleBackground : .staleInactive
    }

    func isSessionStale(asOf date: Date = Date()) -> Bool {
        if needsRefreshAfterLongBackground {
            return true
        }

        guard let lastActiveAt else { return false }
        return date.timeIntervalSince(lastActiveAt) >= Self.staleSessionInterval
    }

    func recordSessionActivity(at date: Date = Date()) {
        lastActiveAt = date
    }

    func markNeedsRefreshAfterLongBackground() {
        needsRefreshAfterLongBackground = true
    }

    func shouldEmitListenerError(
        roundID: String,
        profile: RoundSubscriptionProfile,
        listenerType: RoundRegistrationType,
        error: Error,
        at date: Date = Date()
    ) -> Bool {
        let nsError = error as NSError
        let key = [
            roundID,
            profile.rawValue,
            listenerType.rawValue,
            nsError.domain,
            "\(nsError.code)"
        ].joined(separator: "|")

        if let lastEventAt = listenerErrorThrottle[key],
           date.timeIntervalSince(lastEventAt) < Self.listenerErrorThrottleInterval {
            return false
        }

        listenerErrorThrottle[key] = date
        return true
    }

    func beginInitialLoadTracking(
        for profile: RoundSubscriptionProfile,
        startedAt: Date = Date(),
        source: String
    ) {
        initialLoadStartedAt = startedAt
        initialLoadExpectedTypes = profile.listenerTypes
        initialLoadReadyTypes = []
        didEmitInitialSnapshotLoaded = false
        initialLoadSource = source
    }

    func recordInitialSnapshotReady(for type: RoundRegistrationType) -> Bool {
        guard initialLoadExpectedTypes.contains(type) else { return false }
        guard !didEmitInitialSnapshotLoaded else { return false }

        initialLoadReadyTypes.insert(type)

        guard initialLoadReadyTypes.isSuperset(of: initialLoadExpectedTypes) else { return false }
        didEmitInitialSnapshotLoaded = true
        return true
    }

    private func loadSingleSnapshotIfNeeded(for roundID: String, forceRefresh: Bool) async {
        guard forceRefresh || snapshot.round.id != roundID else { return }

        beginInitialLoadTracking(for: currentProfile, source: "one_shot")

        do {
            snapshot = try await fetchSingleInstance(for: roundID)
            lastSnapshotReceivedAt = Date()
            emitInitialSnapshotLoaded(loadSource: "one_shot")
        } catch {
            addBreadcrumb(level: .error, message: "Failed to load single round snapshot for \(roundID)", error: error)
        }
    }

    private func observeSceneLifecycle() {
        HackersNotification.appSceneDidEnterBackground.publisher()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleBackgroundEntry()
            }
            .store(in: &subscriptions)

        HackersNotification.appSceneDidBecomeActive.publisher()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleForegroundEntry()
            }
            .store(in: &subscriptions)
    }

    private func handleBackgroundEntry() {
        lastBackgroundAt = Date()
    }

    private func handleForegroundEntry() {
        let now = Date()
        lastForegroundAt = now

        if let lastBackgroundAt,
           now.timeIntervalSince(lastBackgroundAt) >= Self.staleSessionInterval {
            markNeedsRefreshAfterLongBackground()
            addBreadcrumb(message: "Mark round session stale after extended background")
        }
    }

    private func staleReasonForCurrentSession(asOf date: Date) -> RoundSessionStaleReason? {
        if needsRefreshAfterLongBackground {
            return .backgroundTimeout
        }

        guard let lastActiveAt,
              date.timeIntervalSince(lastActiveAt) >= Self.staleSessionInterval else {
            return nil
        }

        return .inactiveTimeout
    }

    private func emitRoundSessionActivated(
        roundID: String,
        profile: RoundSubscriptionProfile,
        rebuildReason: RoundSessionRebuildReason,
        sameRoundReuse: Bool,
        existingListenerTypes: Set<RoundRegistrationType>,
        targetListenerTypes: Set<RoundRegistrationType>
    ) {
        addEvent(
            "round_session.activated",
            eventProps: TelemetryEventProps.roundSessionActivation(
                roundID: roundID,
                profile: profile,
                rebuildReason: rebuildReason,
                sameRoundReuse: sameRoundReuse,
                existingListenerTypes: existingListenerTypes,
                targetListenerTypes: targetListenerTypes
            )
        )
    }

    private func emitRoundSessionProfileTransition(
        roundID: String,
        from previousProfile: RoundSubscriptionProfile,
        to nextProfile: RoundSubscriptionProfile,
        listenersAdded: Set<RoundRegistrationType>,
        listenersRemoved: Set<RoundRegistrationType>
    ) {
        addEvent(
            "round_session.profile_transitioned",
            eventProps: TelemetryEventProps.roundSessionProfileTransition(
                roundID: roundID,
                from: previousProfile,
                to: nextProfile,
                listenersAdded: listenersAdded,
                listenersRemoved: listenersRemoved
            )
        )
    }

    func emitInitialSnapshotLoaded(loadSource: String? = nil) {
        guard !didEmitInitialSnapshotLoaded else { return }
        didEmitInitialSnapshotLoaded = true

        addEvent(
            "round_session.initial_snapshot_loaded",
            eventProps: TelemetryEventProps.roundSessionInitialSnapshotLoaded(
                snapshot: snapshot,
                profile: currentProfile,
                listenerTypes: currentProfile.listenerTypes,
                loadSource: loadSource ?? initialLoadSource ?? (currentProfile.usesLiveListeners ? "live_listeners" : "one_shot"),
                startedAt: initialLoadStartedAt
            )
        )
    }

    private func emitStaleRefreshTriggered(
        roundID: String,
        profile: RoundSubscriptionProfile,
        staleReason: RoundSessionStaleReason,
        asOf date: Date
    ) {
        addEvent(
            "round_session.stale_refresh_triggered",
            eventProps: TelemetryEventProps.roundSessionStaleRefreshTriggered(
                roundID: roundID,
                profile: profile,
                staleReason: staleReason,
                backgroundDurationSec: lastBackgroundAt.map { Int(date.timeIntervalSince($0)) },
                hadLiveScoringListener: scoringListener != nil
            )
        )
    }

    func emitListenerError(
        roundID: String,
        profile: RoundSubscriptionProfile,
        listenerType: RoundRegistrationType,
        error: Error
    ) {
        guard shouldEmitListenerError(
            roundID: roundID,
            profile: profile,
            listenerType: listenerType,
            error: error
        ) else { return }

        addEvent(
            "round_session.listener_error",
            eventProps: TelemetryEventProps.roundSessionListenerError(
                roundID: roundID,
                profile: profile,
                listenerType: listenerType,
                error: error
            )
        )
    }
}

extension RoundSession {
    func roundSetupEventProps(
        participant: RoundParticipant? = nil,
        teeID: String? = nil,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        telemetryRoundProperties(
            snapshot: snapshot,
            participant: participant,
            teeID: teeID,
            extra: extra
        )
    }

    func emitRoundSetupEvent(
        _ name: String,
        participant: RoundParticipant? = nil,
        teeID: String? = nil,
        extra: [String: Any] = [:]
    ) {
        addEvent(
            name,
            eventProps: roundSetupEventProps(
                participant: participant,
                teeID: teeID,
                extra: extra
            )
        )
    }

    func prefixedTelemetryProps(_ props: [String: Any], prefix: String) -> [String: Any] {
        props.reduce(into: [:]) { result, item in
            result["\(prefix)_\(item.key)"] = item.value
        }
    }

    func teeGroupTelemetryProps(_ group: TeeTimeGroup, extra: [String: Any] = [:]) -> [String: Any] {
        var props: [String: Any] = [
            "group_id": group.id,
            "group_index": group.index,
            "group_name": group.name,
            "starting_hole": group.startingHole,
            "assigned_participant_count": snapshot.participants.filter { $0.groupID == group.id }.count
        ]

        if let teeTime = group.teeTime, teeTime.isPopulated {
            props["tee_time"] = teeTime
        }

        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    func teamTelemetryProps(_ team: RoundTeam, extra: [String: Any] = [:]) -> [String: Any] {
        var props: [String: Any] = [
            "team_id": team.id,
            "team_name": team.name,
            "team_color": team.color,
            "team_index": team.index,
            "assigned_participant_count": snapshot.participants.filter { $0.teamID == team.id }.count
        ]

        extra.forEach { props[$0.key] = $0.value }
        return props
    }
}
