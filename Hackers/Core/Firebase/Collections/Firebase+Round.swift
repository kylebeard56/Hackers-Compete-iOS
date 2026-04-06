//
//  Firebase+Round.swift
//  Hackers
//
//  Created by Kyle Beard on 8/22/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection: String = Collections.rounds.rawValue

// MARK: - Round
extension FirebaseService {
    func getRoundByShareCode(_ value: String) async -> Result<Round, Error> {
        addBreadcrumb(message: "\(#function), \(value)")
        return await fetch(where: "share_code", isEqualTo: value, in: collection)
    }

    /// Resolves by Firestore document id first, then by `share_code`.
    func resolveRound(byToken token: String) async -> Result<Round, Error> {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated else { return .failure(HackersError.documentNotFound) }
        switch await getRoundByID(trimmed) {
        case .success(let round):
            return .success(round)
        case .failure:
            return await getRoundByShareCode(trimmed.uppercased())
        }
    }
    
    func getRoundByID(_ value: String) async -> Result<Round, Error> {
        addBreadcrumb(message: "\(#function), \(value)")
        return await fetch(where: "id", isEqualTo: value, in: collection)
    }

    func getRoundsByIDs(_ values: [String]) async -> [Round] {
        let ids = Array(Set(values.filter(\.isPopulated)))
        guard ids.isPopulated else { return [] }

        let fetched: Result<[Round], Error> = await fetchByIDs(ids, in: collection)
        switch fetched {
        case .success(let rounds):
            let foundIDs = Set(rounds.map(\.id))
            let missingIDs = ids.filter { !foundIDs.contains($0) }
            guard missingIDs.isPopulated else { return rounds }

            var resolved = rounds
            for roundID in missingIDs {
                if case .success(let round) = await getRoundByID(roundID) {
                    resolved.append(round)
                }
            }
            return resolved
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Cannot batch fetch rounds by IDs", error: error)

            var resolved: [Round] = []
            for roundID in ids {
                if case .success(let round) = await getRoundByID(roundID) {
                    resolved.append(round)
                }
            }
            return resolved
        }
    }
    
    func fetchRounds(playerID: String) async -> [Round] {
        addBreadcrumb(message: "\(#function), \(playerID)")
        
        do {
            let query = Firestore.firestore()
                .collection(Collections.rounds.name)
                .whereField("players", arrayContains: playerID)
            return try await fetchDocuments(query: query).get()
        } catch {
            addBreadcrumb(
                level: .error,
                message: "Cannot fetch rounds for player: \(playerID)",
                error: error
            )
            return []
        }
    }
}

// MARK: - Round Completion

extension FirebaseService {
    /// Appends `CompletedPlayer` entries to the `completed_players` array on the round document in one write.
    /// Uses Firestore `arrayUnion` so concurrent writes from multiple clients merge safely.
    func markPlayersComplete(roundID: String, completedPlayers: [CompletedPlayer]) async throws {
        guard completedPlayers.isPopulated else { return }
        addBreadcrumb(message: "\(#function), round: \(roundID), count: \(completedPlayers.count)")

        let encoder = Firestore.Encoder()
        let encoded: [Any] = try completedPlayers.map { try encoder.encode($0) }

        try await Firestore.firestore()
            .collection(collection)
            .document(roundID)
            .updateData(["completed_players": FieldValue.arrayUnion(encoded)])

        await finalizeRoundCompletionIfNeeded(roundID: roundID, newlyWritten: completedPlayers)
    }

    /// Appends a single `CompletedPlayer` entry; delegates to `markPlayersComplete`.
    func markPlayerComplete(roundID: String, completedPlayer: CompletedPlayer) async throws {
        addBreadcrumb(message: "\(#function), round: \(roundID), player: \(completedPlayer.playerID)")
        try await markPlayersComplete(roundID: roundID, completedPlayers: [completedPlayer])
    }

    /// After updating `completed_players`, marks the round complete when all participants (or host-only flow) have finished.
    private func finalizeRoundCompletionIfNeeded(roundID: String, newlyWritten: [CompletedPlayer]) async {
        guard case .success(var round) = await getRoundByID(roundID),
              case .success(let participants) = await getParticipants(for: roundID) else { return }

        let participantPlayerIDs = Set(participants.compactMap(\.playerID).filter(\.isPopulated))
        let completedPlayerIDs = Set(
            (round.completedPlayers + newlyWritten).map(\.playerID).filter(\.isPopulated)
        )
        let hostPlayerID = participants.first(where: \.isHost)?.playerID

        let shouldCompleteRound = participantPlayerIDs.isPopulated
            ? participantPlayerIDs.isSubset(of: completedPlayerIDs)
            : hostPlayerID.map { hid in newlyWritten.contains(where: { $0.playerID == hid }) } ?? false

        guard shouldCompleteRound, round.status != .complete else { return }
        round.status = .complete
        round.lastUpdatedAt = .init()
        _ = await round.put()
    }
}

// MARK: - Subcollections

extension FirebaseService {
    func getSubcollectionItem<T: FirebaseSubcollectable>(
        by id: String,
        parentID: String
    ) async -> Result<T, Error> {
        addBreadcrumb(message: "\(#function), id: \(id), parent: \(parentID)")
        return await fetchDocument(with: T.documentReference(id: id, parentID: parentID))
    }
    
    func getSubcollectionItems<T: FirebaseSubcollectable>(parentID: String) async -> Result<[T], Error> {
        addBreadcrumb(message: "\(#function), parent: \(parentID), type: \(T.self)")
        return await fetchDocuments(query: T.query(parentID: parentID))
    }
}

// MARK: - Participants
extension FirebaseService {
    func getParticipant(by id: String, for roundID: String) async -> Result<RoundParticipant, Error> {
        return await getSubcollectionItem(by: id, parentID: roundID)
    }
    
    func getParticipants(for roundID: String) async -> Result<[RoundParticipant], Error> {
        return await getSubcollectionItems(parentID: roundID)
    }
}

// MARK: - Scoring
extension FirebaseService {
    func getScore(by id: String, for roundID: String) async -> Result<ScoreEntry, Error> {
        return await getSubcollectionItem(by: id, parentID: roundID)
    }
    
    func getScores(for roundID: String) async -> Result<[ScoreEntry], Error> {
        return await getSubcollectionItems(parentID: roundID)
    }
}

// MARK: - Scoring Groups
extension FirebaseService {
    func getScoringGroup(by id: String, for roundID: String) async -> Result<RoundScoringGroup, Error> {
        return await getSubcollectionItem(by: id, parentID: roundID)
    }

    func getScoringGroups(for roundID: String) async -> Result<[RoundScoringGroup], Error> {
        return await getSubcollectionItems(parentID: roundID)
    }
}

// MARK: - Teams
extension FirebaseService {
    func getTeam(by id: String, for roundID: String) async -> Result<RoundTeam, Error> {
        return await getSubcollectionItem(by: id, parentID: roundID)
    }
    
    func getTeams(for roundID: String) async -> Result<[RoundTeam], Error> {
        return await getSubcollectionItems(parentID: roundID)
    }
}

// MARK: - Tee Groups
extension FirebaseService {
    func getTeeGroup(by id: String, for roundID: String) async -> Result<TeeTimeGroup, Error> {
        return await getSubcollectionItem(by: id, parentID: roundID)
    }
    
    func getTeeGroups(for roundID: String) async -> Result<[TeeTimeGroup], Error> {
        return await getSubcollectionItems(parentID: roundID)
    }
}

// MARK: - Segments
extension FirebaseService {
    func getSegment(by id: String, for roundID: String) async -> Result<RoundSegment, Error> {
        return await getSubcollectionItem(by: id, parentID: roundID)
    }
    
    func getSegments(for roundID: String) async -> Result<[RoundSegment], Error> {
        return await getSubcollectionItems(parentID: roundID)
    }
}
