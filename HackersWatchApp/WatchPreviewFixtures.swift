#if DEBUG || targetEnvironment(simulator)
import Foundation

enum WatchPreviewFixtures {
    private static let fieldRows: [WatchRoundSnapshot.Competition.Row] = [
        .init(id: "p4", position: "1", title: "Jordan M.", subtitle: nil, score: "+1", thru: "Thru 7", winPercentage: nil, isCurrentUser: false, grossScore: "+3", netScore: "+1", handicapLabel: "HCP 4"),
        .init(id: "p2", position: "2", title: "Alex R.", subtitle: nil, score: "+3", thru: "Thru 7", winPercentage: nil, isCurrentUser: false, grossScore: "+6", netScore: "+3", handicapLabel: "HCP 9"),
        .init(id: "p1", position: "T3", title: "Kyle B.", subtitle: nil, score: "+5", thru: "Thru 7", winPercentage: nil, isCurrentUser: true, grossScore: "+9", netScore: "+5", handicapLabel: "HCP 12"),
        .init(id: "p3", position: "T3", title: "Morgan S.", subtitle: nil, score: "+5", thru: "Thru 6", winPercentage: nil, isCurrentUser: false, grossScore: "+11", netScore: "+5", handicapLabel: "HCP 18")
    ]

    static let fieldCompetition = WatchRoundSnapshot.Competition(
        kind: .field,
        title: "Leaderboard",
        formatLabel: "Stroke Play · Net",
        summary: .init(
            label: "Kyle",
            primary: "T3",
            secondary: "+5",
            detail: "4 strokes back · Thru 7"
        ),
        sections: [
            .init(
                id: "field",
                title: "Standings",
                detail: nil,
                isCurrentUserSection: false,
                rows: fieldRows
            )
        ],
        leaderboardVariants: [
            .init(
                id: "individual",
                label: "Solo",
                sections: [.init(id: "individual", title: "Standings", detail: nil, isCurrentUserSection: false, rows: fieldRows)]
            ),
            .init(
                id: "team",
                label: "Team",
                sections: [
                    .init(id: "red", title: "Red Team", detail: nil, isCurrentUserSection: true, rows: [fieldRows[1], fieldRows[2]]),
                    .init(id: "blue", title: "Blue Team", detail: nil, isCurrentUserSection: false, rows: [fieldRows[0], fieldRows[3]])
                ]
            ),
            .init(
                id: "teeGroup",
                label: "Group",
                sections: [
                    .init(id: "group-1", title: "Group 1", detail: nil, isCurrentUserSection: true, rows: Array(fieldRows.prefix(2))),
                    .init(id: "group-2", title: "Group 2", detail: nil, isCurrentUserSection: false, rows: Array(fieldRows.suffix(2)))
                ]
            )
        ]
    )

    static let matchupCompetition = WatchRoundSnapshot.Competition(
        kind: .matchup,
        title: "Matchups",
        formatLabel: "Best Ball · Net",
        summary: .init(
            label: "vs Blue Team",
            primary: "UP 2",
            secondary: "73% win",
            detail: "2-stroke differential"
        ),
        sections: [
            .init(
                id: "match_1",
                title: "Red Team vs Blue Team",
                detail: "Red Team leads by 2 strokes",
                isCurrentUserSection: true,
                rows: [
                    .init(id: "match_1:red", position: nil, title: "Red Team", subtitle: "Kyle, Alex", score: "+5", thru: "Thru 7", winPercentage: 73, isCurrentUser: true),
                    .init(id: "match_1:blue", position: nil, title: "Blue Team", subtitle: "Jordan, Morgan", score: "+7", thru: "Thru 7", winPercentage: 24, isCurrentUser: false)
                ]
            ),
            .init(
                id: "match_2",
                title: "Gold Team vs Green Team",
                detail: "All square",
                isCurrentUserSection: false,
                rows: [
                    .init(id: "match_2:gold", position: nil, title: "Gold Team", subtitle: nil, score: "+4", thru: "Thru 6", winPercentage: 46, isCurrentUser: false),
                    .init(id: "match_2:green", position: nil, title: "Green Team", subtitle: nil, score: "+4", thru: "Thru 6", winPercentage: 45, isCurrentUser: false)
                ]
            )
        ]
    )

    static let snapshot = WatchRoundSnapshot(
        revision: 12,
        roundID: "preview_round",
        title: "Pine Valley",
        phase: .live,
        inputMode: .strokes,
        selectedHole: 7,
        holes: [
            .init(number: 6, par: 3, inputMinimum: 1, inputMaximum: 7),
            .init(number: 7, par: 4, inputMinimum: 1, inputMaximum: 8),
            .init(number: 8, par: 5, inputMinimum: 3, inputMaximum: 9)
        ],
        subjects: [
            subject(id: "p1", title: "Kyle Beard", compactTitle: "Kyle B.", subtitle: "You"),
            subject(id: "p2", title: "Alexandria Rodriguez", compactTitle: "Alexandria R.", subtitle: "Tee group"),
            subject(id: "p3", title: "Jordan Montgomery", compactTitle: "Jordan M.", subtitle: "Tee group")
        ],
        scores: [
            .init(holeNumber: 6, scoringUnitID: "p1", value: 3, revision: "p1:3"),
            .init(holeNumber: 6, scoringUnitID: "p2", value: 4, revision: "p2:4"),
            .init(holeNumber: 6, scoringUnitID: "p3", value: 3, revision: "p3:3"),
            .init(holeNumber: 7, scoringUnitID: "p1", value: 4, revision: "p1:4"),
            .init(holeNumber: 7, scoringUnitID: "p2", value: 5, revision: "p2:5")
        ],
        competition: fieldCompetition,
        additionalCompetitions: [matchupCompetition],
        generatedAt: Date(timeIntervalSince1970: 1)
    )

    static let fieldSnapshot = snapshot

    static let matchupSnapshot = WatchRoundSnapshot(
        revision: 12,
        roundID: "preview_matchup_round",
        title: "Pine Valley",
        phase: .live,
        inputMode: .strokes,
        selectedHole: 7,
        holes: snapshot.holes,
        subjects: snapshot.subjects,
        scores: snapshot.scores,
        competition: matchupCompetition,
        generatedAt: Date(timeIntervalSince1970: 1)
    )

    private static func subject(
        id: String,
        title: String,
        compactTitle: String,
        subtitle: String
    ) -> WatchRoundSnapshot.Subject {
        .init(
            id: id,
            title: title,
            compactTitle: compactTitle,
            subtitle: subtitle,
            anchorParticipantID: id,
            teeGroupID: "group_1",
            holeUnits: [6, 7, 8].map {
                .init(holeNumber: $0, scoringUnitID: id, participantIDs: [id], strokesReceived: 1)
            }
        )
    }
}
#endif
