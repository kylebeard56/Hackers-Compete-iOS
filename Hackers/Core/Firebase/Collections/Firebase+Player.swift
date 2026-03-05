//
//  Firebase+Player.swift
//  Hackers
//
//  Created by Kyle Beard on 11/5/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection: String = Collections.players.rawValue

extension FirebaseService {
    func getPlayerByID(_ value: String) async -> Result<Player, Error> {
        addBreadcrumb(message: "\(#function), \(value)")
        return await fetch(where: "id", isEqualTo: value, in: collection)
    }
    
    func getPlayersByIDs(_ values: [String]) async -> Result<[Player], Error> {
        addBreadcrumb(message: "\(#function), \(values)")
        return await fetchByIDs(values, in: collection)
    }
    
    func searchPlayersByName(_ prefix: String) async -> Result<[Player], Error> {
        addBreadcrumb(message: "\(#function), \(prefix)")
//        return await fetch(where: "name.search_key", hasPrefix: prefix, in: collection)
        return await fetchByName(prefix: prefix, in: collection)
    }
    
    // MARK: - Helpers
    
    /// Query the `Players` collection to see if email is linked to existing document in Cloud Firestore.
    func doesPlayerExistByID(_ value: String) async -> Bool {
        addBreadcrumb(message: "\(#function), \(value)")
        switch await getPlayerByID(value) {
        case .success(_):   return true
        case .failure(_):   return false
        }
    }

    // MARK: - History

    /// Updates the player's playerHistory and courseHistory when a round goes live.
    /// Call when round.status transitions to .live. Idempotent: skips if roundID already in processedRoundIds.
    func updatePlayerHistoryAndCourseHistory(
        playerID: String,
        roundID: String,
        participants: [RoundParticipant],
        courseInfo: CourseInfo?,
        currentPlayerID: String,
        playedAt: Time = .init()
    ) async {
        addBreadcrumb(message: "\(#function), player: \(playerID), round: \(roundID)")

        var player: Player
        switch await getPlayerByID(playerID) {
        case .success(let p): player = p
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to fetch player for history update", error: error)
            return
        }

        guard !player.processedRoundIds.contains(roundID) else {
            addBreadcrumb(message: "Round \(roundID) already processed for player \(playerID)")
            return
        }

        let roundRef = RoundPlayedRef(roundID: roundID, playedAt: playedAt)

        for participant in participants {
            guard let pid = participant.playerID, pid != currentPlayerID else { continue }
            var entry = player.playerHistory[pid] ?? PlayerHistoryEntry(playerID: pid, name: participant.name, rounds: [])
            entry.name = participant.name
            if !entry.rounds.contains(where: { $0.roundID == roundID }) {
                entry.rounds.append(roundRef)
            }
            player.playerHistory[pid] = entry
        }

        if let course = courseInfo {
            let courseIDType: CourseIDType = course.golfCourseApiID != nil ? .courseAPI : .manual
            let courseID = course.golfCourseApiID.map { String($0) } ?? course.id
            let key = "\(courseIDType.rawValue):\(courseID)"
            var entry = player.courseHistory[key] ?? CourseHistoryEntry(
                courseID: courseID,
                courseIDType: courseIDType,
                name: course.name,
                roundsPlayed: 0,
                lastPlayedAt: playedAt
            )
            entry.name = course.name
            entry.roundsPlayed += 1
            entry.lastPlayedAt = playedAt
            player.courseHistory[key] = entry
        }

        player.processedRoundIds.append(roundID)

        do {
            _ = try await player.put().get()
            addBreadcrumb(message: "Updated player history for \(playerID)")
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update player history", error: error)
        }
    }
}
