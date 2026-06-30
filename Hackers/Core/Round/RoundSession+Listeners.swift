//
//  RoundSession+Listeners.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundRegistrationType {
    var name: String {
        switch self {
        case .round:            return "round"
        case .participant:      return "participants"
        case .segment:          return "segments"
        case .scoring:          return "scoring"
        case .team:             return "teams"
        case .teeGroup:         return "tee groups"
        case .scoringGroup:     return "scoring groups"
        }
    }

    var subcollectionName: String? {
        switch self {
        case .round:            return nil
        case .participant:      return RoundSubcollection.participants.rawValue
        case .segment:          return RoundSubcollection.segments.rawValue
        case .scoring:          return RoundSubcollection.scores.rawValue
        case .team:             return RoundSubcollection.teams.rawValue
        case .teeGroup:         return RoundSubcollection.teeGroups.rawValue
        case .scoringGroup:     return RoundSubcollection.scoringGroups.rawValue
        }
    }
}

extension RoundSession {
    private nonisolated static func shouldApplyListenerSnapshot(_ metadata: SnapshotMetadata) -> Bool {
        metadata.hasPendingWrites == false && metadata.isFromCache == false
    }

    private func applyListenerSnapshot(
        listenerType: RoundRegistrationType,
        message: String,
        update: (inout RoundSnapshot) -> Void
    ) {
        update(&snapshot)
        lastSnapshotReceivedAt = Date()
        addBreadcrumb(message: message)
        if recordInitialSnapshotReady(for: listenerType) {
            emitInitialSnapshotLoaded(loadSource: "live_listeners")
        }
    }

    private func emitMissingSnapshotError(
        roundID: String,
        listenerType: RoundRegistrationType,
        message: String,
        error: Error?
    ) {
        if let error {
            emitListenerError(
                roundID: roundID,
                profile: currentProfile,
                listenerType: listenerType,
                error: error
            )
        }
        addBreadcrumb(level: .error, message: message, error: error)
    }

    func startListeners(for profile: RoundSubscriptionProfile) async {
        for type in RoundRegistrationType.allCases where profile.listenerTypes.contains(type) {
            await startListening(to: type)
        }
    }
    
    func stopListeners(excluding retainedTypes: Set<RoundRegistrationType> = []) {
        for type in RoundRegistrationType.allCases where !retainedTypes.contains(type) {
            stopListening(to: type)
        }
    }
    
    private func startListening(to type: RoundRegistrationType) async {
        addBreadcrumb(message: "Start listener for \(type.name)")
        
        switch type {
        case .round:
            await startRoundListener()
        case .participant:
            await startParticipantListener()
        case .segment:
            await startSegmentListener()
        case .scoring:
            await startScoringListener()
        case .team:
            await startTeamListener()
        case .teeGroup:
            await startTeeGroupListener()
        case .scoringGroup:
            await startScoringGroupListener()
        }
    }
    
    private func stopListening(to type: RoundRegistrationType) {
        addBreadcrumb()
        
        switch type {
        case .round:
            roundListener?.remove()
            roundListener = nil
            addBreadcrumb(message: "Round listener stopped")
        case .participant:
            participantListener?.remove()
            participantListener = nil
            addBreadcrumb(message: "Participants listener stopped")
        case .segment:
            segmentListener?.remove()
            segmentListener = nil
            addBreadcrumb(message: "Segments listener stopped")
        case .scoring:
            scoringListener?.remove()
            scoringListener = nil
            addBreadcrumb(message: "Scoring listener stopped")
        case .team:
            teamListener?.remove()
            teamListener = nil
            addBreadcrumb(message: "Teams listener stopped")
        case .teeGroup:
            teeGroupListener?.remove()
            teeGroupListener = nil
            addBreadcrumb(message: "Tee groups listener stopped")
        case .scoringGroup:
            scoringGroupListener?.remove()
            scoringGroupListener = nil
            addBreadcrumb(message: "Scoring groups listener stopped")
        }
    }
}

extension RoundSession {
    private func startRoundListener() async {
        if roundListener.exists { return }
        addBreadcrumb()
        
        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to round: missing roundID")
            return
        }
        
        roundListener = reference
            .document(roundID)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .round,
                            message: "Failed to get round snapshot",
                            error: error
                        )
                    }
                    return
                }
                
                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }
                
                do {
                    let round = try snapshot.data(as: Round.self)
                    Task { @MainActor [weak self] in
                        self?.applyListenerSnapshot(
                            listenerType: .round,
                            message: "Snapshot round updated from listener"
                        ) { snapshot in
                            snapshot.round = round
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(level: .error, message: "Failed to get decode round snapshot", error: error)
                    }
                }
            })
    }
    
    private func startParticipantListener() async {
        if participantListener.exists { return }
        addBreadcrumb()
        
        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to participants: missing roundID")
            return
        }
        
        participantListener = reference
            .document(roundID)
            .collection(RoundSubcollection.participants.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .participant,
                            message: "Failed to get participants snapshot",
                            error: error
                        )
                    }
                    return
                }
                
                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }
                
                do {
                    let participants = try snapshot.documents.compactMap({ try $0.data(as: RoundParticipant.self) })
                    Task { @MainActor [weak self] in
                        guard let self, !self.suppressParticipantListener else { return }
                        self.applyListenerSnapshot(
                            listenerType: .participant,
                            message: "Snapshot participants updated from listener"
                        ) { snapshot in
                            snapshot.participants = participants
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(
                            level: .error,
                            message: "Failed to get decode participants snapshot",
                            error: error
                        )
                    }
                }
            })
    }
    
    private func startSegmentListener() async {
        if segmentListener.exists { return }
        addBreadcrumb()
        
        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to segments: missing roundID")
            return
        }
        
        segmentListener = reference
            .document(roundID)
            .collection(RoundSubcollection.segments.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .segment,
                            message: "Failed to get segments snapshot",
                            error: error
                        )
                    }
                    return
                }
                
                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }
                
                do {
                    let segments = try snapshot.documents.compactMap({ try $0.data(as: RoundSegment.self) })
                    Task { @MainActor [weak self] in
                        self?.applyListenerSnapshot(
                            listenerType: .segment,
                            message: "Snapshot segments updated from listener"
                        ) { snapshot in
                            snapshot.segments = segments
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(level: .error, message: "Failed to get decode segments snapshot", error: error)
                    }
                }
            })
    }
    
    private func startScoringListener() async {
        if scoringListener.exists { return }
        addBreadcrumb()
        
        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to scoring: missing roundID")
            return
        }
        
        scoringListener = reference
            .document(roundID)
            .collection(RoundSubcollection.scores.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .scoring,
                            message: "Failed to get scoring snapshot",
                            error: error
                        )
                    }
                    return
                }
                
                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }
                
                do {
                    let scoring = try snapshot.documents.compactMap({ try $0.data(as: ScoreEntry.self) })
                    Task { @MainActor [weak self] in
                        self?.applyListenerSnapshot(
                            listenerType: .scoring,
                            message: "Snapshot scoring updated from listener"
                        ) { snapshot in
                            snapshot.scoring = scoring
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(level: .error, message: "Failed to get decode scoring snapshot", error: error)
                    }
                }
            })
    }

    private func startScoringGroupListener() async {
        if scoringGroupListener.exists { return }
        addBreadcrumb()

        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to scoring groups: missing roundID")
            return
        }

        scoringGroupListener = reference
            .document(roundID)
            .collection(RoundSubcollection.scoringGroups.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .scoringGroup,
                            message: "Failed to get scoring groups snapshot",
                            error: error
                        )
                    }
                    return
                }

                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }

                do {
                    let groups = try snapshot.documents.compactMap({ try $0.data(as: RoundScoringGroup.self) })
                    Task { @MainActor [weak self] in
                        self?.applyListenerSnapshot(
                            listenerType: .scoringGroup,
                            message: "Snapshot scoring groups updated from listener"
                        ) { snapshot in
                            snapshot.scoringGroups = groups
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(level: .error, message: "Failed to get decode scoring groups snapshot", error: error)
                    }
                }
            })
    }
    
    private func startTeamListener() async {
        if teamListener.exists { return }
        addBreadcrumb()
        
        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to teams: missing roundID")
            return
        }
        
        teamListener = reference
            .document(roundID)
            .collection(RoundSubcollection.teams.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .team,
                            message: "Failed to get teams snapshot",
                            error: error
                        )
                    }
                    return
                }
                
                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }
                
                do {
                    let teams = try snapshot.documents.compactMap({ try $0.data(as: RoundTeam.self) })
                    Task { @MainActor [weak self] in
                        self?.applyListenerSnapshot(
                            listenerType: .team,
                            message: "Snapshot teams updated from listener"
                        ) { snapshot in
                            snapshot.teams = teams
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(level: .error, message: "Failed to get decode teams snapshot", error: error)
                    }
                }
            })
    }
    
    private func startTeeGroupListener() async {
        if teeGroupListener.exists { return }
        addBreadcrumb()
        
        guard let roundID else {
            addBreadcrumb(level: .error, message: "Failed to listen to tee groups: missing roundID")
            return
        }
        
        teeGroupListener = reference
            .document(roundID)
            .collection(RoundSubcollection.teeGroups.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    Task { @MainActor [weak self] in
                        self?.emitMissingSnapshotError(
                            roundID: roundID,
                            listenerType: .teeGroup,
                            message: "Failed to get tee groups snapshot",
                            error: error
                        )
                    }
                    return
                }
                
                guard Self.shouldApplyListenerSnapshot(snapshot.metadata) else { return }
                
                do {
                    let groups = try snapshot.documents.compactMap({ try $0.data(as: TeeTimeGroup.self) })
                    Task { @MainActor [weak self] in
                        self?.applyListenerSnapshot(
                            listenerType: .teeGroup,
                            message: "Snapshot tee groups updated from listener"
                        ) { snapshot in
                            snapshot.teeGroups = groups
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.addBreadcrumb(level: .error, message: "Failed to get decode tee groups snapshot", error: error)
                    }
                }
            })
    }
}
