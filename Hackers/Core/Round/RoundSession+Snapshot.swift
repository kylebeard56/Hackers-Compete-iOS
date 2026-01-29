//
//  RoundSession+Snapshot.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import Foundation
import UIKit

extension RoundSession {
    
    /// Gets a round by ID
    /// - Parameter roundID: ID of the round to retrieve
    /// - Returns: Round object
    func getRound(_ roundID: String) async throws -> Round {
        let result = await FirebaseService.shared.getRoundByID(roundID)
        return try result.get()
    }
    
    /// Gets a participant by ID within a round
    /// - Parameters:
    ///   - participantID: ID of the participant
    ///   - roundID: ID of the round
    /// - Returns: RoundParticipant object
    func getParticipant(_ participantID: String, in roundID: String) async throws -> RoundParticipant {
        let result = await FirebaseService.shared.getParticipant(by: participantID, for: roundID)
        return try result.get()
    }
    
    /// Gets all participants in a round
    /// - Parameter roundID: ID of the round
    /// - Returns: Array of RoundParticipant objects
    func getParticipants(for roundID: String) async throws -> [RoundParticipant] {
        let result = await FirebaseService.shared.getParticipants(for: roundID)
        return try result.get()
    }
    
    /// Gets all teams in a round
    /// - Parameter roundID: ID of the round
    /// - Returns: Array of RoundTeam objects
    func getTeams(for roundID: String) async throws -> [RoundTeam] {
        let result = await FirebaseService.shared.getTeams(for: roundID)
        return try result.get()
    }
    
    /// Gets all tee groups in a round
    /// - Parameter roundID: ID of the round
    /// - Returns: Array of TeeTimeGroup objects
    func getTeeGroups(for roundID: String) async throws -> [TeeTimeGroup] {
        let result = await FirebaseService.shared.getTeeGroups(for: roundID)
        return try result.get()
    }
    
    /// Gets all segments in a round
    /// - Parameter roundID: ID of the round
    /// - Returns: Array of RoundSegment objects
    func getSegments(for roundID: String) async throws -> [RoundSegment] {
        let result = await FirebaseService.shared.getSegments(for: roundID)
        return try result.get()
    }
    
    /// Gets all score entries in a round
    /// - Parameter roundID: ID of the round
    /// - Returns: Array of ScoreEntry objects
    func getScoring(for roundID: String) async throws -> [ScoreEntry] {
        let result = await FirebaseService.shared.getScores(for: roundID)
        return try result.get()
    }
    
    /// Gets a complete round snapshot with all subcollections
    /// - Parameter roundID: ID of the round
    /// - Returns: RoundSnapshot containing all round data
    func getRoundSnapshot(_ roundID: String) async throws -> RoundSnapshot {
        addBreadcrumb()
        
        async let roundTask = getRound(roundID)
        async let participantsTask = getParticipants(for: roundID)
        async let teamsTask = getTeams(for: roundID)
        async let teeGroupsTask = getTeeGroups(for: roundID)
        async let segmentsTask = getSegments(for: roundID)
        async let scoringTask = getScoring(for: roundID)
        
        let (round, participants, teams, teeGroups, segments, scoring) = try await (
            roundTask, participantsTask, teamsTask, teeGroupsTask, segmentsTask, scoringTask
        )
        
        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: teams,
            teeGroups: teeGroups,
            segments: segments,
            scoring: scoring
        )
    }
}
