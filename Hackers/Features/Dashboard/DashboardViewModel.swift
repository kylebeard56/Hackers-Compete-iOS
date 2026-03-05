//
//  DashboardViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

// MARK: - Stale Completion Info

struct StalledCompletionInfo: Identifiable {
    var id: String { round.id }
    let round: Round
    /// Players in the round who already marked themselves complete.
    let completedPlayers: [CompletedPlayer]
}

// MARK: - DashboardViewModel

@MainActor
final class DashboardViewModel: ObservableObject, Loggable {
    @Published var scrollOffset: CGFloat = 0
    @Published var roundsSearchText: String = ""

    /// Non-nil when a live round has tee group members who finished 2+ hours ago
    /// but the current player has not yet responded.
    /// Must be writable so `.sheet(item:)` can set to nil when dismissed.
    @Published var stalledCompletionInfo: StalledCompletionInfo?

    @Published private(set) var currentPlayerID: String?
    private static let staleThreshold: TimeInterval = 2 * 60 * 60  // 2 hours

    init() {
        Task { await resolveCurrentPlayerID() }
    }

    deinit { }
    
    func filteredRounds(from rounds: [Round]) -> [Round] {
        let query = roundsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isPopulated else { return rounds }
        
        return rounds.filter { round in
            if let course = round.configuration.courses.first {
                if course.courseInfo.name.lowercased().contains(query) { return true }
            }
            if round.shareCode.lowercased().contains(query) { return true }
            return false
        }
    }
    
    // MARK: - Stale Completion Detection

    private func resolveCurrentPlayerID() async {
        currentPlayerID = await AppData.shared.getPrimaryPlayer()?.id
    }

    /// Call whenever the rounds list refreshes. Finds the first qualifying stalled round.
    func checkForStalledCompletions(in rounds: [Round]) {
        guard let playerID = currentPlayerID else { return }

        let now = Date().timeIntervalSince1970
        let threshold = Self.staleThreshold

        let match = rounds.first { round in
            guard round.status == .live else { return false }
            guard round.players.contains(playerID) else { return false }
            let alreadyResponded = round.completedPlayers.contains { $0.playerID == playerID }
            guard !alreadyResponded else { return false }
            let staleCompleters = round.completedPlayers.filter { entry in
                (now - entry.completedAt.unix) >= threshold
            }
            return staleCompleters.isPopulated
        }

        if let match {
            let staleCompleters = match.completedPlayers.filter { entry in
                (now - entry.completedAt.unix) >= threshold
            }
            stalledCompletionInfo = StalledCompletionInfo(
                round: match,
                completedPlayers: staleCompleters
            )
        } else {
            stalledCompletionInfo = nil
        }
    }

    func clearStalledCompletionInfo() {
        stalledCompletionInfo = nil
    }
}
