@testable import Hackers
import Foundation

enum SeriesBehaviorFixtures {
    static let seriesID = "series_phase_0"
    static let fixedTime = Time(iso: "2026-07-09T12:00:00Z", unix: 1_783_598_400)

    static var bestTwoNineHoleSettings: SeriesSettings {
        SeriesSettings(
            experiencePreset: .league,
            defaultCourse: SeriesCourseSelection(
                courseID: "course_phase_0",
                cachedName: "Phase Zero Golf Club",
                defaultTeeBoxID: "tee_blue",
                holeSegment: .front9
            ),
            defaultCourseRotationMode: .alternateFrontBack,
            defaultRoundConfig: bestTwoNineHoleConfiguration,
            defaultTeamScoringProfileID: "team_placement",
            defaultIndividualScoringProfileID: "individual_placement",
            handicapConfig: SeriesHandicapConfig(
                mode: .dynamic,
                strokeBasis: .nineHole,
                entryFormat: .strokes,
                normalizationMode: .field
            ),
            allowRoundEditsAfterLobbyCreation: false,
            allowManualAwardOverrides: true,
            isAttendanceEnabled: true,
            attendanceDefault: .accepted,
            podGroupingDefault: .alignByIndex,
            useTeams: true,
            useIndividualStandings: true,
            useTeamStandings: true,
            showScoreboardTile: true,
            substitutesScore: true,
            defaultScheduledTeeTimeMinutesFromMidnight: 17 * 60,
            recurringPlayWeekdays: [5]
        )
    }

    static var bestTwoNineHoleConfiguration: SeriesRoundConfiguration {
        SeriesRoundConfiguration(
            formatTemplateID: FormatTemplateRegistry.bestBall.id,
            competitionScope: .field,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: .individual,
            matchupScoringStyle: .aggregateRoundTotal,
            sequentialTeeStartsEnabled: true,
            matchupMode: .field,
            podGroupingStrategy: .alignByIndex,
            teamAssignmentMode: .seriesTeams,
            teeGroupMode: .podAligned,
            notes: "Phase 0 configuration contract",
            allowCourseOverride: false,
            allowFormatOverride: false,
            allowLobbyBackPropagation: false,
            scoreBasisOverride: .gross,
            maxScoreOverPar: .twoTimesParPlusOne,
            handicapStrokeBasis: .nineHole,
            handicapEntryFormat: .strokes,
            handicapNormalizationMode: .field,
            countsTowardHandicapPool: true,
            excludedHandicapMemberIDs: ["member_z"]
        )
    }

    static var configuredRound: SeriesRound {
        SeriesRound(
            id: "series_round_1",
            title: "Week 1",
            index: 0,
            status: .planned,
            scheduledAt: fixedTime,
            courseOverride: bestTwoNineHoleSettings.defaultCourse,
            roundConfig: bestTwoNineHoleConfiguration,
            teamScoringProfileID: "team_placement",
            individualScoringProfileID: "individual_placement",
            notes: "Golden round",
            createdAt: fixedTime,
            lastUpdatedAt: fixedTime,
            parentID: seriesID
        )
    }

    static var goldenAwards: [SeriesPointAward] {
        [
            award(round: 1, track: .team, competitorID: "red", name: "Red", placement: 1, points: 10),
            award(round: 1, track: .team, competitorID: "blue", name: "Blue", placement: 2, points: 8),
            award(round: 1, track: .team, competitorID: "green", name: "Green", placement: 3, points: 6),
            award(round: 2, track: .team, competitorID: "red", name: "Red", placement: 2, points: 8),
            award(round: 2, track: .team, competitorID: "blue", name: "Blue", placement: 1, points: 10),
            award(round: 2, track: .team, competitorID: "green", name: "Green", placement: 3, points: 6),
            award(round: 3, track: .team, competitorID: "red", name: "Red", placement: 1, points: 9),
            award(round: 3, track: .team, competitorID: "blue", name: "Blue", placement: 2, points: 9),
            award(round: 3, track: .team, competitorID: "green", name: "Green", placement: 3, points: 6),
            award(round: 1, track: .individual, competitorID: "alice", name: "Alice", placement: 2, points: 7),
            award(round: 1, track: .individual, competitorID: "bailey", name: "Bailey", placement: 1, points: 8),
            award(round: 2, track: .individual, competitorID: "alice", name: "Alice", placement: 1, points: 8),
            award(round: 2, track: .individual, competitorID: "bailey", name: "Bailey", placement: 3, points: 6),
        ]
    }

    static func largeLeagueAwards(roundCount: Int = 40, teamCount: Int = 16) -> [SeriesPointAward] {
        (0..<roundCount).flatMap { roundIndex in
            (0..<teamCount).map { teamIndex in
                let placement = ((teamIndex + roundIndex) % teamCount) + 1
                return award(
                    round: roundIndex + 1,
                    track: .team,
                    competitorID: "team_\(teamIndex + 1)",
                    name: "Team \(teamIndex + 1)",
                    placement: placement,
                    points: Double(teamCount - placement + 1)
                )
            }
        }
    }

    private static func award(
        round: Int,
        track: SeriesAwardTrack,
        competitorID: String,
        name: String,
        placement: Int,
        points: Double
    ) -> SeriesPointAward {
        SeriesPointAward(
            id: "round_\(round)_\(track.rawValue)_\(competitorID)",
            seriesRoundID: "round_\(round)",
            awardTrack: track,
            competitorType: track.competitorType,
            competitorID: competitorID,
            competitorName: name,
            profileKind: .placement,
            placement: placement,
            basePoints: points,
            totalPoints: points,
            source: .automatic,
            awardedAt: fixedTime,
            createdAt: fixedTime,
            lastUpdatedAt: fixedTime,
            parentID: seriesID
        )
    }
}
