//
//  MockLiveRound2v2.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/26.
//

import SwiftUI

enum MockLiveRound2v2 {
    static let roundID = "mock_round_2v2"
    
    static let snapshot: RoundSnapshot = .init(
        round: round,
        participants: participants,
        teams: teams,
        teeGroups: teeGroups,
        segments: [],
        scoring: []
    )
    
    static let round: Round = .init(
        id: roundID,
        shareCode: "2V2RED",
        createdBy: "player_1",
        status: .live,
        players: participants.compactMap(\.playerID),
        configuration: .init(
            primaryFormat: .init(
                type: .strokePlay,
                configuration: .init(
                    method: .individual,
                    aggregation: nil,
                    basis: .net,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            courses: [defaultCourseSegment]
        ),
        createdAt: .init(),
        lastUpdatedAt: .init()
    )
    
    static let teams: [RoundTeam] = [
        .init(id: "team_red", name: "Red Team", color: "red", index: 0, createdAt: .init(), parentID: roundID),
        .init(id: "team_blue", name: "Blue Team", color: "blue", index: 1, createdAt: .init(), parentID: roundID)
    ]
    
    static let teeGroups: [TeeTimeGroup] = [
        .init(
            id: "group_1",
            index: 0,
            teeTime: "2026-02-01T08:00:00Z",
            startingHole: 1,
            lastCompletedHole: 0,
            createdAt: .init(),
            parentID: roundID
        )
    ]
    
    static let participants: [RoundParticipant] = [
        makeParticipant(
            id: "participant_1",
            first: "John",
            last: "Smith",
            teamID: "team_red",
            groupID: "group_1",
            teeOrder: 1,
            handicap: 5,
            isHost: true
        ),
        makeParticipant(
            id: "participant_2",
            first: "Mike",
            last: "Johnson",
            teamID: "team_red",
            groupID: "group_1",
            teeOrder: 2,
            handicap: 18
        ),
        makeParticipant(
            id: "participant_3",
            first: "Alexandriea",
            last: "Wilson-Smithfield",
            teamID: "team_blue",
            groupID: "group_1",
            teeOrder: 3,
            handicap: 12
        ),
        makeParticipant(
            id: "participant_4",
            first: "Tom",
            last: "Davis",
            teamID: "team_blue",
            groupID: "group_1",
            teeOrder: 4,
            handicap: 30
        )
    ]
    
    private static func makeParticipant(
        id: String,
        first: String,
        last: String,
        teamID: String,
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
            teeBoxID: "default_tee_1",
            originalHandicap: handicap,
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID,
            teeOrder: teeOrder,
            isHost: isHost,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }
    
    private static var defaultCourseSegment: CourseSegment {
        .init(
            courseInfo: CourseInfo(
                course: Course(from: MockCourses.mountainPark, with: "course_id"),
                for: .full18
            ),
            holeRange: HoleSegment.full18.holeRange,
            defaultTee: "default_tee_1"
        )
    }
}
