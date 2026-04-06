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

enum RoundListener: CaseIterable {
    case round, participant, segment, scoring, team, teeGroup
    case scoringGroup
}

@MainActor
final class RoundSession: ObservableObject, Loggable {
    @Published var roundID: String?
    @Published var snapshot: RoundSnapshot = .init()
    /// When we last received data from any Firebase listener (round, scoring, etc.).
    @Published var lastSnapshotReceivedAt: Date?
    
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
    
    var activeListeners: [RoundListener] {
        var result: [RoundListener] = []

        if roundListener != nil { result.append(.round) }
        if participantListener != nil { result.append(.participant) }
        if segmentListener != nil { result.append(.segment) }
        if scoringListener != nil { result.append(.scoring) }
        if teamListener != nil { result.append(.team) }
        if teeGroupListener != nil { result.append(.teeGroup) }
        if scoringGroupListener != nil { result.append(.scoringGroup) }

        return result
    }
    
    var inactiveListeners: [RoundListener] {
        let active = Set(activeListeners)
        return RoundListener.allCases.filter { !active.contains($0) }
    }
    
    var isRunning: Bool {
        activeListeners.count > 0
    }
    
    let reference: CollectionReference = Firestore.firestore().collection(Collections.rounds.rawValue)
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() { }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
    
    func fetchSingleInstance(for roundID: String) async throws -> RoundSnapshot {
        addBreadcrumb()
        
        do {
            return .init(
                round:          try await FirebaseService.shared.getRoundByID(roundID).get(),
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
        addBreadcrumb()
        stopListeners()
        self.roundID = roundID
        TelemetryService.shared.setContext(roundID: roundID)

//        if roundID.hasPrefix("mock_") {
//            print("loading mock snapshot...")
//            snapshot = MockCompletedRound.completedSnapshot(roundID: roundID)
//            lastSnapshotReceivedAt = Date()
//            return
//        }

        await startListeners()
    }
    
    func stop() {
        addBreadcrumb()
        stopListeners()
        self.roundID = nil
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
