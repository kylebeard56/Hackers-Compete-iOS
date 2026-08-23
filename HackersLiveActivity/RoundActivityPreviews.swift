#if DEBUG
import SwiftUI

private let previewState = RoundLiveActivityAttributes.ContentState(
    phase: .live,
    roundTitle: "The Preserve at Verdae",
    participantName: "Sarah Beard",
    formatLabel: "Stroke Play · Net",
    holeLabel: "Hole 8 of 9",
    holeProgress: 7.0 / 9.0,
    hole: .init(
        number: 8,
        total: 9,
        completed: 7,
        remaining: 2,
        par: 4,
        yardage: 385,
        handicapStrokes: 1,
        currentScoreLabel: "TBD"
    ),
    personalScore: .init(title: "You · Net", value: "+3", thru: "Thru 7"),
    grossScore: .init(title: "You · Gross", value: "+3", thru: "Thru 7"),
    teamScore: .init(title: "Red Team", value: "+3", thru: "Thru 7"),
    matchup: .init(
        opponent: "Blue Team",
        standingLabel: "DOWN 5",
        differentialLabel: "5-stroke differential",
        winPercentage: 5,
        tiePercentage: 3,
        isEarlyEstimate: true,
        left: .init(
            title: "Red Team",
            score: "+3",
            winPercentage: 5,
            isCurrentUserSide: true,
            countingPlayers: ["Kyle", "Sam"]
        ),
        right: .init(
            title: "Blue Team",
            score: "-2",
            winPercentage: 92,
            isCurrentUserSide: false,
            countingPlayers: ["Alex", "Jordan"]
        )
    ),
    competition: .init(
        kind: .individual,
        title: "Field position",
            position: "T5",
        score: nil,
        detail: "2 strokes back",
        participantCount: 8
    ),
    isPersonalScoreCounting: true,
    deepLinkURL: URL(string: "hackersgolf:///live-round?round_id=preview&hole=7")!,
    updatedAt: Date(timeIntervalSince1970: 1)
)

#Preview("Matchup · Light") {
    RoundActivityContentView(state: previewState)
        .frame(width: 390)
        .preferredColorScheme(.light)
}

#Preview("Matchup · Dark") {
    RoundActivityContentView(state: previewState)
        .frame(width: 390)
        .preferredColorScheme(.dark)
}

#Preview("Team Competition Activity") {
    RoundActivityContentView(
        state: .init(
            phase: .live,
            roundTitle: "Saturday at Pine Valley",
            participantName: "Kyle Beard",
            formatLabel: "Best Ball · Net",
            holeLabel: "Hole 14 of 18",
            holeProgress: 13.0 / 18.0,
            hole: .init(
                number: 14,
                total: 18,
                completed: 13,
                remaining: 5,
                par: 4,
                yardage: 418,
                handicapStrokes: 1,
                currentScoreLabel: "Par"
            ),
            personalScore: .init(title: "You · Net", value: "+3", thru: "Thru 13"),
            grossScore: .init(title: "You · Gross", value: "+6", thru: "Thru 13"),
            teamScore: .init(title: "Red Team", value: "+5", thru: "Thru 13"),
            matchup: nil,
            competition: .init(
                kind: .team,
                title: "Red Team",
                position: "2",
                score: "+5",
                detail: "2 strokes back",
                participantCount: 8
            ),
            deepLinkURL: URL(string: "hackersgolf:///live-round?round_id=preview&hole=14")!,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    )
    .frame(width: 390)
}

#Preview("Individual Field Activity") {
    RoundActivityContentView(
        state: .init(
            phase: .live,
            roundTitle: "The Preserve at Verdae",
            participantName: "Kyle Beard",
            formatLabel: "Stroke Play · Net",
            holeLabel: "Hole 9 of 9",
            holeProgress: 8.0 / 9.0,
            hole: .init(
                number: 9,
                total: 9,
                completed: 8,
                remaining: 1,
                par: 5,
                yardage: 385,
                currentScoreLabel: "TBD"
            ),
            personalScore: .init(title: "You · Net", value: "+3", thru: "Thru 8"),
            grossScore: .init(title: "You · Gross", value: "+5", thru: "Thru 8"),
            teamScore: nil,
            matchup: nil,
            competition: .init(
                kind: .individual,
                title: "Field position",
                position: "T3",
                score: nil,
                detail: "2 strokes back",
                participantCount: 24
            ),
            deepLinkURL: URL(string: "hackersgolf:///live-round?round_id=preview&hole=9")!,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    )
    .frame(width: 390)
}

#Preview("Stale Round Activity") {
    RoundActivityContentView(
        state: .init(
            phase: .stale,
            roundTitle: previewState.roundTitle,
            participantName: previewState.participantName,
            formatLabel: previewState.formatLabel,
            holeLabel: previewState.holeLabel,
            holeProgress: previewState.holeProgress,
            hole: previewState.hole,
            personalScore: previewState.personalScore,
            grossScore: previewState.grossScore,
            teamScore: previewState.teamScore,
            matchup: previewState.matchup,
            competition: previewState.competition,
            isPersonalScoreCounting: previewState.isPersonalScoreCounting,
            deepLinkURL: previewState.deepLinkURL,
            updatedAt: previewState.updatedAt
        ),
        isStale: true
    )
    .frame(width: 390)
}
#endif
