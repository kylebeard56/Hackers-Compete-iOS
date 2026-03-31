//
//  Session+Series.swift
//  Hackers
//

import SwiftUI

extension AppSession {

    func loadSeries() async {
        addBreadcrumb()
        isLoadingSeries = true
        defer { isLoadingSeries = false }

        guard let player = await AppData.shared.getPrimaryPlayer() else {
            seriesList = []
            seriesRoundsBySeriesID = [:]
            return
        }
        let fetched = await FirebaseService.shared.fetchUserSeries(playerID: player.id)
        let sorted = fetched
            .filter { $0.status != .archived }
            .sorted { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix }

        var roundsBySeriesID: [String: [SeriesRound]] = [:]
        await withTaskGroup(of: (String, [SeriesRound]).self) { group in
            for series in sorted {
                let seriesID = series.id
                group.addTask {
                    let rounds = await FirebaseService.shared.fetchSeriesRounds(seriesID: seriesID)
                    return (seriesID, rounds)
                }
            }
            for await (seriesID, rounds) in group {
                roundsBySeriesID[seriesID] = rounds
            }
        }

        self.seriesRoundsBySeriesID = roundsBySeriesID
        self.seriesList = sorted
    }

    func createSeries(name: String) async -> String? {
        addBreadcrumb(message: "Create series: \(name)")

        guard let user = await AppData.shared.user,
              let player = await AppData.shared.getPrimaryPlayer() else { return nil }

        let shareCode = await FirebaseService.shared.getUniqueShareCode()

        var series = Series(
            id: HackersID.string(),
            name: name,
            shareCode: shareCode,
            commissionerUserID: user.id,
            commissionerPlayerID: player.id,
            memberPlayerIDs: [player.id],
            status: .draft
        )
        series.createdAt = Time()
        series.lastUpdatedAt = Time()

        switch await FirebaseService.shared.createSeries(series) {
        case .success(let created):
            let commissioner = SeriesMember(
                id: HackersID.string(),
                userID: user.id,
                playerID: player.id,
                name: player.name,
                role: .commissioner,
                isActive: true,
                joinedAt: Time(),
                createdAt: Time(),
                lastUpdatedAt: Time(),
                parentID: created.id
            )
            _ = await FirebaseService.shared.addSeriesMember(commissioner)
            seriesRoundsBySeriesID[created.id] = []
            seriesList.insert(created, at: 0)
            addEvent(
                "series.created",
                eventProps: [
                    "series_id": created.id,
                    "series_name": created.name
                ]
            )
            return created.id
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create series", error: error)
            addEvent(
                "series.creation_failed",
                eventProps: [
                    "series_name": name,
                    "error": "\(error)"
                ]
            )
            return nil
        }
    }
}
