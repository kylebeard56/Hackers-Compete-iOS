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

        guard let player = await AppData.shared.getPrimaryPlayer() else { return }
        let fetched = await FirebaseService.shared.fetchUserSeries(playerID: player.id)
        self.seriesList = fetched
            .filter { $0.status != .archived }
            .sorted { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix }
    }

    func createSeries(name: String) async -> String? {
        addBreadcrumb(message: "Create series: \(name)")

        guard let user = await AppData.shared.user,
              let player = await AppData.shared.getPrimaryPlayer() else { return nil }

        var series = Series(
            id: HackersID.string(),
            name: name,
            commissionerUserID: user.id,
            commissionerPlayerID: player.id,
            players: [player.id],
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
            seriesList.insert(created, at: 0)
            return created.id
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create series", error: error)
            return nil
        }
    }
}
