//
//  MockLobbyFoursome.swift
//  Hackers
//
//  Created by Kyle Beard on 2/16/26.
//

import SwiftUI

/// Foursome lobby: 4 players, no teams, 1 tee group, stroke play with handicaps.
enum MockLobbyFoursome {
    static let roundID = "mock_lobby_foursome"
    private static let defaultTeeID = defaultCourseSegment.courseInfo.tees.first?.id ?? "default_tee_1"
    
    static let snapshot: RoundSnapshot = .init(
        round: round,
        participants: participants,
        teams: [],
        teeGroups: teeGroups,
        segments: [],
        scoring: []
    )
    
    static let round: Round = .init(
        id: roundID,
        shareCode: "FOUR01",
        createdBy: "player_participant_1",
        status: .lobby,
        players: participants.compactMap(\.playerID),
        configuration: .init(
            primaryFormat: .init(
                type: .strokePlay,
                configuration: .init(
                    method: .individual,
                    aggregation: nil,
                    basis: .net,
                    handicap: .individualStrokePlay,
                    requiresTeams: false,
                    teeGroupOnly: false
                )
            ),
            courses: [defaultCourseSegment]
        ),
        createdAt: .init(),
        lastUpdatedAt: .init()
    )
    
    static let teeGroups: [TeeTimeGroup] = [
        .init(
            id: "group_1",
            index: 0,
            teeTime: "8:06 AM",
            startingHole: 1,
            lastCompletedHole: 0,
            createdAt: .init(),
            parentID: roundID
        )
    ]
    
    static let participants: [RoundParticipant] = [
        makeParticipant(id: "participant_1", first: "Kyle", last: "Beard", groupID: "group_1", teeOrder: 1, handicap: 12, isHost: true),
        makeParticipant(id: "participant_2", first: "Jake", last: "Palmer", groupID: "group_1", teeOrder: 2, handicap: 8),
        makeParticipant(id: "participant_3", first: "Drew", last: "Collins", groupID: "group_1", teeOrder: 3, handicap: 22),
        makeParticipant(id: "participant_4", first: "Nick", last: "Rivera", groupID: "group_1", teeOrder: 4, handicap: 15),
    ]
    
    private static func makeParticipant(
        id: String,
        first: String,
        last: String,
        groupID: String,
        teeOrder: Int,
        handicap: Int,
        isHost: Bool = false
    ) -> RoundParticipant {
        .init(
            id: id,
            userID: "user_\(id)",
            playerID: "player_\(id)",
            name: Name(first, last),
            teeBoxID: defaultTeeID,
            originalHandicap: handicap,
            adjustedHandicap: handicap,
            teamID: nil,
            groupID: groupID,
            teeOrder: teeOrder,
            isHost: isHost,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }
    
    private static var defaultCourseSegment: CourseSegment {
        let courseInfo = CourseInfo(
            course: Course(from: MockCourses.mountainPark, with: "course_id", useStableTeeIDs: true),
            for: .full18
        )
        return .init(
            courseInfo: courseInfo,
            holeRange: HoleSegment.full18.holeRange,
            defaultTee: courseInfo.tees.first?.id ?? "default_tee_1"
        )
    }
}
