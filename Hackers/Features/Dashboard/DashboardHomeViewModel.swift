//
//  DashboardHomeViewModel.swift
//  Hackers
//
//  Reads playerHistory and courseHistory from primary player for home display.
//

import Foundation

@MainActor
final class DashboardHomeViewModel: ObservableObject {
    @Published private(set) var recentPlayers: [PlayerHistoryEntry] = []
    @Published private(set) var topPlayers: [PlayerHistoryEntry] = []
    @Published private(set) var recentCourses: [CourseHistoryEntry] = []
    @Published private(set) var topCourses: [CourseHistoryEntry] = []
    @Published private(set) var isLoading = false

    private var primaryPlayerID: String?

    func load(primaryPlayerID: String?) async {
        guard let playerID = primaryPlayerID else {
            recentPlayers = []
            topPlayers = []
            recentCourses = []
            topCourses = []
            return
        }
        self.primaryPlayerID = playerID
        isLoading = true
        defer { isLoading = false }

        switch await FirebaseService.shared.getPlayerByID(playerID) {
        case .success(let player):
            let entries = Array(player.playerHistory.values)
            recentPlayers = entries.sorted { a, b in
                let aLast = a.lastPlayedAt?.unix ?? 0
                let bLast = b.lastPlayedAt?.unix ?? 0
                return aLast > bLast
            }
            topPlayers = entries.sorted { $0.roundsPlayed > $1.roundsPlayed }

            let courseEntries = Array(player.courseHistory.values)
            recentCourses = courseEntries.sorted { $0.lastPlayedAt.unix > $1.lastPlayedAt.unix }
            topCourses = courseEntries.sorted { $0.roundsPlayed > $1.roundsPlayed }

        case .failure:
            recentPlayers = []
            topPlayers = []
            recentCourses = []
            topCourses = []
        }
    }

    func refresh() async {
        await load(primaryPlayerID: primaryPlayerID)
    }
}
