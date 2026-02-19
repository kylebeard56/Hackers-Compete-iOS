//
//  MockLiveRoundRyderCup.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/26.
//

import SwiftUI

enum MockLiveRoundRyderCup {
    static let roundID = "mock_round_ryder_cup"
    private static let defaultTeeID = defaultCourseSegment.courseInfo.tees.first?.id ?? "default_tee_1"
    
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
        shareCode: "RYDER16",
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
        .init(id: "group_1", index: 0, teeTime: "2026-02-01T08:00:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_2", index: 1, teeTime: "2026-02-01T08:10:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_3", index: 2, teeTime: "2026-02-01T08:20:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_4", index: 3, teeTime: "2026-02-01T08:30:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID)
    ]
    
    static let participants: [RoundParticipant] = [
        // Group 1 (mixed red/blue)
        makeParticipant(id: "participant_1", first: "Alex", last: "Carter", teamID: "team_red", groupID: "group_1", teeOrder: 1, handicap: 4, isHost: true),
        makeParticipant(id: "participant_2", first: "Jordan", last: "Lee", teamID: "team_red", groupID: "group_1", teeOrder: 2, handicap: 16),
        makeParticipant(id: "participant_3", first: "Casey", last: "Morgan", teamID: "team_blue", groupID: "group_1", teeOrder: 3, handicap: 9),
        makeParticipant(id: "participant_4", first: "Taylor", last: "Brooks", teamID: "team_blue", groupID: "group_1", teeOrder: 4, handicap: 28),
        
        // Group 2 (mixed red/blue)
        makeParticipant(id: "participant_5", first: "Sam", last: "Reed", teamID: "team_red", groupID: "group_2", teeOrder: 1, handicap: 7),
        makeParticipant(id: "participant_6", first: "Riley", last: "Stone", teamID: "team_red", groupID: "group_2", teeOrder: 2, handicap: 23),
        makeParticipant(id: "participant_7", first: "Morgan", last: "Price", teamID: "team_blue", groupID: "group_2", teeOrder: 3, handicap: 2),
        makeParticipant(id: "participant_8", first: "Jamie", last: "Ross", teamID: "team_blue", groupID: "group_2", teeOrder: 4, handicap: 19),
        
        // Group 3 (mixed red/blue)
        makeParticipant(id: "participant_9", first: "Drew", last: "Ellis", teamID: "team_red", groupID: "group_3", teeOrder: 1, handicap: 11),
        makeParticipant(id: "participant_10", first: "Logan", last: "Pierce", teamID: "team_red", groupID: "group_3", teeOrder: 2, handicap: 30),
        makeParticipant(id: "participant_11", first: "Parker", last: "Shaw", teamID: "team_blue", groupID: "group_3", teeOrder: 3, handicap: 6),
        makeParticipant(id: "participant_12", first: "Reese", last: "Nolan", teamID: "team_blue", groupID: "group_3", teeOrder: 4, handicap: 25),
        
        // Group 4 (mixed red/blue)
        makeParticipant(id: "participant_13", first: "Quinn", last: "Avery", teamID: "team_red", groupID: "group_4", teeOrder: 1, handicap: 14),
        makeParticipant(id: "participant_14", first: "Charlie", last: "Miles", teamID: "team_red", groupID: "group_4", teeOrder: 2, handicap: 33),
        makeParticipant(id: "participant_15", first: "Rowan", last: "Hart", teamID: "team_blue", groupID: "group_4", teeOrder: 3, handicap: 1),
        makeParticipant(id: "participant_16", first: "Blake", last: "Turner", teamID: "team_blue", groupID: "group_4", teeOrder: 4, handicap: 21)
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
            teeBoxID: defaultTeeID,
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
