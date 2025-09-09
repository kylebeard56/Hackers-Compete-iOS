//
//  RoundManager.swift
//  Hackers
//
//  Created by Kyle Beard on 9/3/25.
//

import Foundation
import UIKit

@MainActor
@Observable
class RoundManager: Loggable {
    var snapshot: RoundSnapshot = .init()
    
    init() { }
    deinit { }
}

// MARK: - Creating Round

extension RoundManager {
    func createRoundLobby(with course: Course, over segment: HoleSegment) async throws -> RoundSnapshot {
        addBreadcrumb("\(#function), course \(course.id)")
        
        guard let user = await AppData.shared.user else {
            throw HackersError.userNotFound
        }
        
        guard let player = user.players.first(where: \.isPrimary) else {
            throw HackersError.playerNotFound
        }
        
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            courses: [
                CourseSegment(
                    courseInfo: CourseInfo(course: course, for: segment),
                    holeRange: segment.holeRange
                )
            ],
            scoringBasis: .gross
        )
        
        var round = Round(
            id: HackersID.string(),
            shareCode: HackersID.shareCode(),
            createdBy: player.id,
            status: .lobby,
            configuration: configuration,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
        
        var participant = RoundParticipant(
            id: HackersID.string(),
            userID: player.id,
            displayName: player.name.fullName,
            teeBoxID: "",
            originalHandicap: 0,
            adjustedHandicap: 0,
            teamID: nil,
            groupID: nil,
            teeOrder: nil,
            isHost: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: Collections.rounds.rawValue
        )
        
        var segment = RoundSegment(
            id: HackersID.string(),
            roundID: round.id,
            holeRange: segment.holeRange,
            gameFormat: .strokePlay,
            scoringUnits: [],
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: Collections.rounds.rawValue
        )
        
        do {
            participant = try await participant.post().get()
            segment = try await segment.post().get()
            round = try await round.post().get()
            
            return RoundSnapshot(
                round: round,
                participants: [participant],
                teams: [],
                teeGroups: [],
                segments: [segment],
                scoring: []
            )
        } catch let error {
            throw error
        }
    }
    
    func addParticipant(_ player: any Playable) async throws -> RoundParticipant? { return nil }
    
    func deleteParticipant(with id: String) async throws { }
}

