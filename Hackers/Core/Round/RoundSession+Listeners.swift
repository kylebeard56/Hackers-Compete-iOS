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
    private func shouldApplyListenerSnapshot(_ metadata: SnapshotMetadata, listenerType: RoundRegistrationType) -> Bool {
        guard metadata.hasPendingWrites == false else { return false }
        guard metadata.isFromCache == false else {
            addBreadcrumb(message: "Skip cached \(listenerType.name) listener snapshot")
            return false
        }
        return true
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .round,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get round snapshot", error: error)
                    return
                }
                
                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .round) == true else { return }
                
                do {
                    let round = try snapshot.data(as: Round.self)
                    self?.snapshot.round = round
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message: "Snapshot round updated from listener")
                    if self?.recordInitialSnapshotReady(for: .round) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(level: .error, message: "Failed to get decode round snapshot", error: error)
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .participant,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get participants snapshot", error: error)
                    return
                }
                
                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .participant) == true else { return }
                guard self?.suppressParticipantListener != true else { return }
                
                do {
                    let participants = try snapshot.documents.compactMap({ try $0.data(as: RoundParticipant.self) })
                    self?.snapshot.participants = participants
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message: "Snapshot participants updated from listener")
                    if self?.recordInitialSnapshotReady(for: .participant) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(
                        level: .error,
                        message: "Failed to get decode participants snapshot",
                        error: error
                    )
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .segment,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get segments snapshot", error: error)
                    return
                }
                
                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .segment) == true else { return }
                
                do {
                    let segments = try snapshot.documents.compactMap({ try $0.data(as: RoundSegment.self) })
                    self?.snapshot.segments = segments
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message: "Snapshot segments updated from listener")
                    if self?.recordInitialSnapshotReady(for: .segment) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(level: .error, message: "Failed to get decode segments snapshot", error: error)
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .scoring,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get scoring snapshot", error: error)
                    return
                }
                
                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .scoring) == true else { return }
                
                do {
                    let scoring = try snapshot.documents.compactMap({ try $0.data(as: ScoreEntry.self) })
                    self?.snapshot.scoring = scoring
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message: "Snapshot scoring updated from listener")
                    if self?.recordInitialSnapshotReady(for: .scoring) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(level: .error, message: "Failed to get decode scoring snapshot", error: error)
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .scoringGroup,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get scoring groups snapshot", error: error)
                    return
                }

                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .scoringGroup) == true else { return }

                do {
                    let groups = try snapshot.documents.compactMap({ try $0.data(as: RoundScoringGroup.self) })
                    self?.snapshot.scoringGroups = groups
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message: "Snapshot scoring groups updated from listener")
                    if self?.recordInitialSnapshotReady(for: .scoringGroup) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(level: .error, message: "Failed to get decode scoring groups snapshot", error: error)
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .team,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get teams snapshot", error: error)
                    return
                }
                
                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .team) == true else { return }
                
                do {
                    let teams = try snapshot.documents.compactMap({ try $0.data(as: RoundTeam.self) })
                    self?.snapshot.teams = teams
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message: "Snapshot teams updated from listener")
                    if self?.recordInitialSnapshotReady(for: .team) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(level: .error, message: "Failed to get decode teams snapshot", error: error)
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
                    if let self, let error {
                        Task { @MainActor in
                            self.emitListenerError(
                                roundID: roundID,
                                profile: self.currentProfile,
                                listenerType: .teeGroup,
                                error: error
                            )
                        }
                    }
                    self?.addBreadcrumb(level: .error, message: "Failed to get tee groups snapshot", error: error)
                    return
                }
                
                guard self?.shouldApplyListenerSnapshot(snapshot.metadata, listenerType: .teeGroup) == true else { return }
                
                do {
                    let groups = try snapshot.documents.compactMap({ try $0.data(as: TeeTimeGroup.self) })
                    self?.snapshot.teeGroups = groups
                    Task { @MainActor in self?.lastSnapshotReceivedAt = Date() }
                    self?.addBreadcrumb(message:"Snapshot tee groups updated from listener")
                    if self?.recordInitialSnapshotReady(for: .teeGroup) == true {
                        self?.emitInitialSnapshotLoaded(loadSource: "live_listeners")
                    }
                } catch {
                    self?.addBreadcrumb(level: .error, message: "Failed to get decode tee groups snapshot", error: error)
                }
            })
    }
}
