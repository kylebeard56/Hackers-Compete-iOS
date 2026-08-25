//
//  MockLiveRoundFourTeams.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/26.
//

import SwiftUI

enum MockLiveRoundFourTeams {
    static let roundID = "mock_round_four_teams"
    private static let defaultTeeID = defaultCourseSegment.courseInfo.tees.first?.id ?? "the_hound_male"
    
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
        shareCode: "4TEAM16",
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
        .init(id: "team_blue", name: "Blue Team", color: "blue", index: 1, createdAt: .init(), parentID: roundID),
        .init(id: "team_green", name: "Green Team", color: "green", index: 2, createdAt: .init(), parentID: roundID),
        .init(id: "team_purple", name: "Purple Team", color: "purple", index: 3, createdAt: .init(), parentID: roundID)
    ]
    
    static let teeGroups: [TeeTimeGroup] = [
        .init(id: "group_1", index: 0, teeTime: "2026-02-01T08:00:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_2", index: 1, teeTime: "2026-02-01T08:10:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_3", index: 2, teeTime: "2026-02-01T08:20:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_4", index: 3, teeTime: "2026-02-01T08:30:00Z", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID)
    ]
    
    static let participants: [RoundParticipant] = [
        // Group 1 (Red team)
        makeParticipant(id: "participant_1", first: "Evan", last: "Cole", teamID: "team_red", groupID: "group_1", teeOrder: 1, handicap: 3, isHost: true),
        makeParticipant(id: "participant_2", first: "Noah", last: "Bishop", teamID: "team_red", groupID: "group_1", teeOrder: 2, handicap: 12),
        makeParticipant(id: "participant_3", first: "Avery", last: "Grant", teamID: "team_red", groupID: "group_1", teeOrder: 3, handicap: 22),
        makeParticipant(id: "participant_4", first: "Hayden", last: "Knight", teamID: "team_red", groupID: "group_1", teeOrder: 4, handicap: 31),
        
        // Group 2 (Blue team)
        makeParticipant(id: "participant_5", first: "Luca", last: "Mason", teamID: "team_blue", groupID: "group_2", teeOrder: 1, handicap: 8),
        makeParticipant(id: "participant_6", first: "Peyton", last: "Reed", teamID: "team_blue", groupID: "group_2", teeOrder: 2, handicap: 27),
        makeParticipant(id: "participant_7", first: "Sawyer", last: "Hale", teamID: "team_blue", groupID: "group_2", teeOrder: 3, handicap: 14),
        makeParticipant(id: "participant_8", first: "Sydney", last: "Flores", teamID: "team_blue", groupID: "group_2", teeOrder: 4, handicap: 35),
        
        // Group 3 (Green team)
        makeParticipant(id: "participant_9", first: "Rowan", last: "Park", teamID: "team_green", groupID: "group_3", teeOrder: 1, handicap: 6),
        makeParticipant(id: "participant_10", first: "Dakota", last: "Hayes", teamID: "team_green", groupID: "group_3", teeOrder: 2, handicap: 19),
        makeParticipant(id: "participant_11", first: "Emery", last: "Lane", teamID: "team_green", groupID: "group_3", teeOrder: 3, handicap: 29),
        makeParticipant(id: "participant_12", first: "Reese", last: "Murray", teamID: "team_green", groupID: "group_3", teeOrder: 4, handicap: 10),
        
        // Group 4 (Purple team)
        makeParticipant(id: "participant_13", first: "Quincy", last: "Holt", teamID: "team_purple", groupID: "group_4", teeOrder: 1, handicap: 1),
        makeParticipant(id: "participant_14", first: "Kai", last: "Summers", teamID: "team_purple", groupID: "group_4", teeOrder: 2, handicap: 17),
        makeParticipant(id: "participant_15", first: "Sloane", last: "Miller", teamID: "team_purple", groupID: "group_4", teeOrder: 3, handicap: 25),
        makeParticipant(id: "participant_16", first: "Blair", last: "Hughes", teamID: "team_purple", groupID: "group_4", teeOrder: 4, handicap: 34)
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
            defaultTee: courseInfo.tees.first?.id ?? "the_hound_male"
        )
    }
}
