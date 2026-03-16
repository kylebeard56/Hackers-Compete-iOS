//
//  SeriesRoundCreationService.swift
//  Hackers
//
//  Handles creating a round from series data, pre-filling config,
//  roster with handicap strokes, teams, and matchup structure.
//

import Foundation

@MainActor
struct SeriesRoundCreationService: Loggable {

    /// Creates a Round from series configuration, injecting all defaults.
    /// Returns the Round ID on success; nil on failure.
    func createRoundFromSeries(
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        handicaps: [String: SeriesMemberHandicap],
        courseOverride: Course? = nil,
        teeOverride: String? = nil
    ) async -> String? {
        guard let user = await AppData.shared.user,
              let player = await AppData.shared.getPrimaryPlayer() else { return nil }

        let defaultCourse = series.defaults.defaultCourse
        let defaultTeeID = teeOverride ?? defaultCourse?.defaultTeeID ?? ""

        let template = FormatTemplateRegistry.strokePlayGross
        let configuration = RoundConfiguration(
            primaryFormat: seriesRound.format,
            formatSummary: RoundFormatSummary(from: template),
            courses: []
        )

        let shareCode = await FirebaseService.shared.getUniqueShareCode()

        var round = Round(
            id: HackersID.string(),
            shareCode: shareCode,
            createdBy: user.id,
            status: .lobby,
            players: members.compactMap(\.playerID),
            configuration: configuration,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )

        var teeGroup = TeeTimeGroup(
            id: HackersID.string(),
            index: 0,
            startingHole: 1,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )

        var segment = RoundSegment(
            id: HackersID.string(),
            roundID: round.id,
            holeRange: HoleRange(startHole: 1, endHole: 9),
            gameFormat: seriesRound.format,
            templateID: template.id,
            scoringUnits: [],
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )

        do {
            teeGroup = try await teeGroup.post().get()
            segment = try await segment.post().get()

            // Create round teams from series teams
            var roundTeamMap: [String: String] = [:]
            for (idx, seriesTeam) in teams.sorted(by: { $0.index < $1.index }).enumerated() {
                var roundTeam = RoundTeam(
                    id: HackersID.string(),
                    name: seriesTeam.name,
                    color: seriesTeam.color.isEmpty ? TeamColor.teamValue(for: idx).0.rawValue : seriesTeam.color,
                    index: idx,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: round.id
                )
                roundTeam = try await roundTeam.post().get()
                roundTeamMap[seriesTeam.id] = roundTeam.id
            }

            // If no teams, create default pair
            if teams.isEmpty {
                let redTeam = RoundTeam(
                    id: HackersID.string(),
                    name: TeamColor.teamValue(for: 0).1,
                    color: TeamColor.teamValue(for: 0).0.rawValue,
                    index: 0,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: round.id
                )
                let blueTeam = RoundTeam(
                    id: HackersID.string(),
                    name: TeamColor.teamValue(for: 1).1,
                    color: TeamColor.teamValue(for: 1).0.rawValue,
                    index: 1,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: round.id
                )
                _ = try await redTeam.post().get()
                _ = try await blueTeam.post().get()
            }

            // Create participants from series members
            for member in members where member.isActive {
                let teeBoxID = member.defaultTeeBoxID ?? defaultTeeID
                let handicap = handicaps[member.id]?.effectiveIndex ?? 0
                let intHandicap = Int(handicap.rounded())

                let isHost = member.playerID == player.id
                var participant = RoundParticipant(
                    id: HackersID.string(),
                    userID: member.userID,
                    playerID: member.playerID,
                    name: member.name,
                    teeBoxID: teeBoxID,
                    originalHandicap: intHandicap,
                    adjustedHandicap: intHandicap,
                    seriesMemberID: member.id,
                    teamID: member.teamID.flatMap { roundTeamMap[$0] },
                    groupID: teeGroup.id,
                    isHost: isHost,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: round.id
                )
                participant = try await participant.post().get()
            }

            round = try await round.post().get()
            return round.id
        } catch {
            addBreadcrumb(level: .error, message: "Failed to create series round", error: error)
            return nil
        }
    }
}
