//
//  RoundService+Listeners.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundService {
    enum RoundRegistrationType: String, CaseIterable {
        case round
        case participants
        case segments
        case scoring
        case teams
        case teeGroups
        
        var name: String {
            switch self {
            case .round:            return "round"
            case .participants:     return "participants"
            case .segments:         return "segments"
            case .scoring:          return "scoring"
            case .teams:            return "teams"
            case .teeGroups:        return "tee groups"
            }
        }
        
        var subcollectionName: String? {
            switch self {
            case .round:            return nil
            case .participants:     return RoundSubcollection.participants.rawValue
            case .segments:         return RoundSubcollection.segments.rawValue
            case .scoring:          return RoundSubcollection.scores.rawValue
            case .teams:            return RoundSubcollection.teams.rawValue
            case .teeGroups:        return RoundSubcollection.teeGroups.rawValue
            }
        }
    }
}

extension RoundService {
    func startListeners() async {
        for type in RoundRegistrationType.allCases {
            await startListening(to: type)
        }
    }
    
    func stopListeners() {
        for type in RoundRegistrationType.allCases {
            stopListening(to: type)
        }
    }
    
    private func startListening(to type: RoundRegistrationType) async {
        addBreadcrumb("\(#function), \(type)")
        
        switch type {
        case .round:
            await startRoundListener()
        case .participants:
            await startParticipantListener()
        case .segments:
            await startSegmentListener()
        case .scoring:
            await startScoringListener()
        case .teams:
            await startTeamListener()
        case .teeGroups:
            await startTeeGroupListener()
        }
    }
    
    private func stopListening(to type: RoundRegistrationType) {
        addBreadcrumb(#function)
        
        switch type {
        case .round:
            roundListener?.remove()
            roundListener = nil
            addBreadcrumb("Round listener stopped")
        case .participants:
            participantListener?.remove()
            participantListener = nil
            addBreadcrumb("Participants listener stopped")
        case .segments:
            segmentListener?.remove()
            segmentListener = nil
            addBreadcrumb("Segments listener stopped")
        case .scoring:
            scoringListener?.remove()
            scoringListener = nil
            addBreadcrumb("Scoring listener stopped")
        case .teams:
            teamListener?.remove()
            teamListener = nil
            addBreadcrumb("Teams listener stopped")
        case .teeGroups:
            teeGroupListener?.remove()
            teeGroupListener = nil
            addBreadcrumb("Tee groups listener stopped")
        }
    }
}

extension RoundService {
    private func startRoundListener() async {
        if roundListener.exists { return }
        addBreadcrumb(#function)
        
        guard let roundID else {
            addBreadcrumb(.error, .roundService, "Failed to listen to round: missing roundID")
            return
        }
        
        roundListener = reference
            .document(roundID)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get round snapshot", error)
                    return
                }
                
                do {
                    let round = try snapshot.data(as: Round.self)
                    self?.snapshot.round = round
                    self?.addBreadcrumb("Snapshot round updated from listener")
                } catch {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get decode round snapshot", error)
                }
            })
    }
    
    private func startParticipantListener() async {
        if participantListener.exists { return }
        addBreadcrumb(#function)
        
        guard let roundID else {
            addBreadcrumb(.error, .roundService, "Failed to listen to participants: missing roundID")
            return
        }
        
        participantListener = reference
            .document(roundID)
            .collection(RoundSubcollection.participants.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get participants snapshot", error)
                    return
                }
                
                do {
                    let participants = try snapshot.documents.compactMap({ try $0.data(as: RoundParticipant.self) })
                    self?.snapshot.participants = participants
                    self?.addBreadcrumb("Snapshot participants updated from listener")
                } catch {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get decode participants snapshot", error)
                }
            })
    }
    
    private func startSegmentListener() async {
        if segmentListener.exists { return }
        addBreadcrumb(#function)
        
        guard let roundID else {
            addBreadcrumb(.error, .roundService, "Failed to listen to segments: missing roundID")
            return
        }
        
        segmentListener = reference
            .document(roundID)
            .collection(RoundSubcollection.segments.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get segments snapshot", error)
                    return
                }
                
                do {
                    let segments = try snapshot.documents.compactMap({ try $0.data(as: RoundSegment.self) })
                    self?.snapshot.segments = segments
                    self?.addBreadcrumb("Snapshot segments updated from listener")
                } catch {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get decode segments snapshot", error)
                }
            })
    }
    
    private func startScoringListener() async {
        if scoringListener.exists { return }
        addBreadcrumb(#function)
        
        guard let roundID else {
            addBreadcrumb(.error, .roundService, "Failed to listen to scoring: missing roundID")
            return
        }
        
        scoringListener = reference
            .document(roundID)
            .collection(RoundSubcollection.scores.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get scoring snapshot", error)
                    return
                }
                
                do {
                    let scoring = try snapshot.documents.compactMap({ try $0.data(as: ScoreEntry.self) })
                    self?.snapshot.scoring = scoring
                    self?.addBreadcrumb("Snapshot scoring updated from listener")
                } catch {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get decode scoring snapshot", error)
                }
            })
    }
    
    private func startTeamListener() async {
        if teamListener.exists { return }
        addBreadcrumb(#function)
        
        guard let roundID else {
            addBreadcrumb(.error, .roundService, "Failed to listen to teams: missing roundID")
            return
        }
        
        teamListener = reference
            .document(roundID)
            .collection(RoundSubcollection.teams.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get teams snapshot", error)
                    return
                }
                
                do {
                    let teams = try snapshot.documents.compactMap({ try $0.data(as: RoundTeam.self) })
                    self?.snapshot.teams = teams
                    self?.addBreadcrumb("Snapshot teams updated from listener")
                } catch {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get decode teams snapshot", error)
                }
            })
    }
    
    private func startTeeGroupListener() async {
        if teeGroupListener.exists { return }
        addBreadcrumb(#function)
        
        guard let roundID else {
            addBreadcrumb(.error, .roundService, "Failed to listen to tee groups: missing roundID")
            return
        }
        
        teeGroupListener = reference
            .document(roundID)
            .collection(RoundSubcollection.teeGroups.rawValue)
            .addSnapshotListener({ [weak self] snapshot, error in
                guard let snapshot else {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get tee groups snapshot", error)
                    return
                }
                
                do {
                    let groups = try snapshot.documents.compactMap({ try $0.data(as: TeeTimeGroup.self) })
                    self?.snapshot.teeGroups = groups
                    self?.addBreadcrumb("Snapshot tee groups updated from listener")
                } catch {
                    self?.addBreadcrumb(.error, .roundService, "Failed to get decode tee groups snapshot", error)
                }
            })
    }
}
