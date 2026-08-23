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
            seriesRecords = []
            seriesList = []
            seriesRoundsBySeriesID = [:]
            seriesV2RoundsBySeriesID = [:]
            return
        }
        let records = await FirebaseService.shared.fetchUserSeriesRecords(playerID: player.id)
        let sorted = records.sorted { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix }
        let v1Values = sorted.compactMap { record -> Series? in
            guard case .v1(let value) = record else { return nil }
            return value
        }

        let maxConcurrentRoundLoads = 4
        let queuedRecords = sorted
        var roundsBySeriesID: [String: [SeriesRound]] = [:]
        var roundsV2BySeriesID: [String: [RoundV2]] = [:]
        await withTaskGroup(of: SeriesRoundLoadResult.self) { group in
            var nextIndex = 0

            func enqueueNext() {
                guard nextIndex < queuedRecords.count else { return }
                let record = queuedRecords[nextIndex]
                nextIndex += 1
                group.addTask {
                    switch record {
                    case .v1(let series):
                        return .v1(series.id, await FirebaseService.shared.fetchSeriesRounds(seriesID: series.id))
                    case .v2(let series):
                        let rounds = (try? await FirebaseService.shared.fetchSeriesRoundsV2(seriesID: series.id).get()) ?? []
                        return .v2(series.id, rounds)
                    }
                }
            }

            for _ in 0..<min(maxConcurrentRoundLoads, queuedRecords.count) {
                enqueueNext()
            }

            for await result in group {
                switch result {
                case .v1(let seriesID, let rounds): roundsBySeriesID[seriesID] = rounds
                case .v2(let seriesID, let rounds): roundsV2BySeriesID[seriesID] = rounds
                }
                enqueueNext()
            }
        }

        self.seriesRoundsBySeriesID = roundsBySeriesID
        self.seriesV2RoundsBySeriesID = roundsV2BySeriesID
        self.seriesRecords = sorted
        // Retained for V1-only consumers such as linked live-round context.
        self.seriesList = v1Values
    }

    func createSeries(name: String, preset: SeriesExperiencePreset) async -> String? {
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
            status: .draft,
            settings: .seeded(for: preset)
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
            seriesRecords.insert(.v1(created), at: 0)
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

private enum SeriesRoundLoadResult {
    case v1(String, [SeriesRound])
    case v2(String, [RoundV2])
}
