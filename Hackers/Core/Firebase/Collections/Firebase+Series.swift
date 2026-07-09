//
//  Firebase+Series.swift
//  Hackers
//
//  Firebase operations for Series and its subcollections.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection = Collections.series.rawValue

enum SeriesDerivedBatchWriteError: Error, LocalizedError {
    case operationLimitExceeded(entity: String, count: Int)

    var errorDescription: String? {
        switch self {
        case .operationLimitExceeded(let entity, let count):
            return "Atomic \(entity) publication supports at most 500 operations; received \(count)."
        }
    }
}

// MARK: - Series CRUD

extension FirebaseService {

    func createSeries(_ series: Series) async -> Result<Series, Error> {
        addBreadcrumb(message: "\(#function), name: \(series.name)")
        return await series.post()
    }

    func fetchSeries(id: String) async -> Result<Series, Error> {
        addBreadcrumb(message: "\(#function), id: \(id)")
        return await fetch(where: "id", isEqualTo: id, in: collection)
    }

    func getSeriesByShareCode(_ value: String) async -> Result<Series, Error> {
        addBreadcrumb(message: "\(#function), \(value)")
        return await fetch(where: "share_code", isEqualTo: value, in: collection)
    }

    /// Resolves by Firestore document id first, then by `share_code`.
    func resolveSeries(byToken token: String) async -> Result<Series, Error> {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated else { return .failure(HackersError.documentNotFound) }
        switch await fetchSeries(id: trimmed) {
        case .success(let series):
            return .success(series)
        case .failure:
            return await getSeriesByShareCode(trimmed.uppercased())
        }
    }

    func fetchUserSeries(playerID: String) async -> [Series] {
        addBreadcrumb(message: "\(#function), playerID: \(playerID)")
        do {
            let query = Firestore.firestore()
                .collection(collection)
                .whereField("member_player_ids", arrayContains: playerID)
            return try await fetchDocuments(query: query).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series for player: \(playerID)", error: error)
            return []
        }
    }

    func updateSeries(_ series: Series) async -> Result<Series, Error> {
        addBreadcrumb(message: "\(#function), id: \(series.id)")
        return await series.put()
    }
}

// MARK: - Members

extension FirebaseService {

    func addSeriesMember(_ member: SeriesMember) async -> Result<SeriesMember, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(member.parentID), name: \(member.name.fullName)")
        return await member.post()
    }

    func updateSeriesMember(_ member: SeriesMember) async -> Result<SeriesMember, Error> {
        addBreadcrumb(message: "\(#function), id: \(member.id)")
        return await member.put()
    }

    func deleteSeriesMember(_ member: SeriesMember) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), id: \(member.id)")
        return await member.delete()
    }

    func fetchSeriesMembers(seriesID: String) async -> [SeriesMember] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series members", error: error)
            return []
        }
    }

    func fetchSeriesMember(memberID: String) async -> Result<SeriesMember, Error> {
        addBreadcrumb(message: "\(#function), memberID: \(memberID)")

        do {
            // Collection-group `documentID == memberID` requires a full path (even segment count).
            // `SeriesMember.id` matches the document id and is indexed for this query shape.
            let query = Firestore.firestore()
                .collectionGroup(SeriesSubcollection.members.rawValue)
                .whereField("id", isEqualTo: memberID)
                .limit(to: 1)

            let members: [SeriesMember] = try await fetchDocuments(query: query).get()
            guard let member = members.first else {
                addBreadcrumb(level: .warning, message: "Series member not found for memberID: \(memberID)")
                return .failure(HackersError.documentNotFound)
            }
            return .success(member)
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series member by id \(memberID)", error: error)
            return .failure(error)
        }
    }

    func syncSeriesMemberAfterParticipantClaim(
        seriesMemberID: String,
        userID: String,
        playerID: String,
        name: Name
    ) async throws {
        addBreadcrumb(message: "\(#function), memberID: \(seriesMemberID), playerID: \(playerID)")

        var member = try await fetchSeriesMember(memberID: seriesMemberID).get()
        let previousPlayerID = member.playerID

        member.userID = userID
        member.playerID = playerID
        member.name = name
        member.lastUpdatedAt = .init()
        member = try await updateSeriesMember(member).get()

        if let previousPlayerID, previousPlayerID.isPopulated, previousPlayerID != playerID {
            try await removePlayerFromSeries(seriesID: member.parentID, playerID: previousPlayerID)
        }

        if playerID.isPopulated, previousPlayerID != playerID {
            try await addPlayerToSeries(seriesID: member.parentID, playerID: playerID)
        } else if playerID.isPopulated, previousPlayerID == playerID {
            try await addPlayerToSeries(seriesID: member.parentID, playerID: playerID)
        }
    }
}

// MARK: - Invites

extension FirebaseService {

    func addSeriesInvite(_ invite: SeriesInvite) async -> Result<SeriesInvite, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(invite.parentID), inviteID: \(invite.id)")
        return await invite.post()
    }

    func updateSeriesInvite(_ invite: SeriesInvite) async -> Result<SeriesInvite, Error> {
        addBreadcrumb(message: "\(#function), inviteID: \(invite.id)")
        return await invite.put()
    }

    func fetchSeriesInvites(seriesID: String) async -> [SeriesInvite] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series invites", error: error)
            return []
        }
    }
}

// MARK: - Teams

extension FirebaseService {

    func addSeriesTeam(_ team: SeriesTeam) async -> Result<SeriesTeam, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(team.parentID)")
        return await team.post()
    }

    func updateSeriesTeam(_ team: SeriesTeam) async -> Result<SeriesTeam, Error> {
        addBreadcrumb(message: "\(#function), id: \(team.id)")
        return await team.put()
    }

    func deleteSeriesTeam(_ team: SeriesTeam) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), id: \(team.id)")
        return await team.delete()
    }

    func fetchSeriesTeams(seriesID: String) async -> [SeriesTeam] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series teams", error: error)
            return []
        }
    }
}

// MARK: - Pods

extension FirebaseService {

    func addSeriesPod(_ pod: SeriesTeamPod) async -> Result<SeriesTeamPod, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(pod.parentID), teamID: \(pod.teamID)")
        return await pod.post()
    }

    func updateSeriesPod(_ pod: SeriesTeamPod) async -> Result<SeriesTeamPod, Error> {
        addBreadcrumb(message: "\(#function), podID: \(pod.id)")
        return await pod.put()
    }

    func deleteSeriesPod(_ pod: SeriesTeamPod) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), podID: \(pod.id)")
        return await pod.delete()
    }

    func fetchSeriesPods(seriesID: String) async -> [SeriesTeamPod] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series pods", error: error)
            return []
        }
    }
}

// MARK: - Rounds

extension FirebaseService {

    func addSeriesRound(_ round: SeriesRound) async -> Result<SeriesRound, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(round.parentID)")
        return await round.post()
    }

    func updateSeriesRound(_ round: SeriesRound) async -> Result<SeriesRound, Error> {
        addBreadcrumb(message: "\(#function), roundID: \(round.id)")
        return await round.put()
    }

    func deleteSeriesRound(_ round: SeriesRound) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), roundID: \(round.id)")
        return await round.delete()
    }

    func fetchSeriesRounds(seriesID: String) async -> [SeriesRound] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series rounds", error: error)
            return []
        }
    }
}

// MARK: - Attendance

extension FirebaseService {

    func upsertSeriesRoundAttendance(_ attendance: SeriesRoundAttendance) async -> Result<SeriesRoundAttendance, Error> {
        addBreadcrumb(message: "\(#function), round: \(attendance.seriesRoundID), member: \(attendance.memberID)")
        return await attendance.put()
    }

    func deleteSeriesRoundAttendance(_ attendance: SeriesRoundAttendance) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), id: \(attendance.id)")
        return await attendance.delete()
    }

    func fetchSeriesRoundAttendance(seriesID: String, seriesRoundID: String) async -> [SeriesRoundAttendance] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID), roundID: \(seriesRoundID)")
        do {
            let query = SeriesRoundAttendance.query(parentID: seriesID)
                .whereField("series_round_id", isEqualTo: seriesRoundID)
            return try await fetchDocuments(query: query).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch round attendance", error: error)
            return []
        }
    }
}

// MARK: - Announcements

extension FirebaseService {

    func addSeriesAnnouncement(_ announcement: SeriesAnnouncement) async -> Result<SeriesAnnouncement, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(announcement.parentID)")
        return await announcement.post()
    }

    func updateSeriesAnnouncement(_ announcement: SeriesAnnouncement) async -> Result<SeriesAnnouncement, Error> {
        addBreadcrumb(message: "\(#function), announcementID: \(announcement.id)")
        return await announcement.put()
    }

    func deleteSeriesAnnouncement(_ announcement: SeriesAnnouncement) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), announcementID: \(announcement.id)")
        return await announcement.delete()
    }

    func fetchSeriesAnnouncements(seriesID: String) async -> [SeriesAnnouncement] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series announcements", error: error)
            return []
        }
    }
}

// MARK: - Scoring Profiles

extension FirebaseService {

    func addScoringProfile(_ profile: SeriesScoringProfile) async -> Result<SeriesScoringProfile, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(profile.parentID)")
        return await profile.post()
    }

    func updateScoringProfile(_ profile: SeriesScoringProfile) async -> Result<SeriesScoringProfile, Error> {
        addBreadcrumb(message: "\(#function), id: \(profile.id)")
        return await profile.put()
    }

    func fetchScoringProfiles(seriesID: String) async -> [SeriesScoringProfile] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch scoring profiles", error: error)
            return []
        }
    }
}

// MARK: - Round Mappings

extension FirebaseService {

    func addSeriesRoundMapping(_ mapping: SeriesRoundMapping) async -> Result<SeriesRoundMapping, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(mapping.parentID), roundID: \(mapping.seriesRoundID)")
        return await mapping.post()
    }

    func fetchSeriesRoundMappings(seriesID: String, seriesRoundID: String? = nil) async -> [SeriesRoundMapping] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        switch await fetchSeriesRoundMappingsResult(seriesID: seriesID, seriesRoundID: seriesRoundID) {
        case .success(let mappings):
            return mappings
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Cannot fetch series mappings", error: error)
            return []
        }
    }

    func fetchSeriesRoundMappingsResult(
        seriesID: String,
        seriesRoundID: String? = nil
    ) async -> Result<[SeriesRoundMapping], Error> {
        let query = SeriesRoundMapping.query(parentID: seriesID)
            .whereField(useCondition: seriesRoundID != nil, "series_round_id", isEqualTo: seriesRoundID ?? "")
        return await fetchDocuments(query: query)
    }
}

// MARK: - Handicap Scores

extension FirebaseService {

    func addHandicapScore(_ score: SeriesHandicapScore) async -> Result<SeriesHandicapScore, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(score.parentID), member: \(score.memberID)")
        return await score.post()
    }

    func updateHandicapScore(_ score: SeriesHandicapScore) async -> Result<SeriesHandicapScore, Error> {
        addBreadcrumb(message: "\(#function), scoreID: \(score.id)")
        return await score.put()
    }

    func fetchHandicapScores(seriesID: String) async -> [SeriesHandicapScore] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch handicap scores", error: error)
            return []
        }
    }

    func fetchHandicapScores(seriesID: String, memberID: String) async -> [SeriesHandicapScore] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID), memberID: \(memberID)")
        do {
            let query = SeriesHandicapScore.query(parentID: seriesID)
                .whereField("member_id", isEqualTo: memberID)
            return try await fetchDocuments(query: query).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch handicap scores for member", error: error)
            return []
        }
    }

    func fetchHandicapScores(seriesID: String, sourceRoundID: String) async -> [SeriesHandicapScore] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID), sourceRoundID: \(sourceRoundID)")
        do {
            let query = SeriesHandicapScore.query(parentID: seriesID)
                .whereField("source_round_id", isEqualTo: sourceRoundID)
            return try await fetchDocuments(query: query).get()
                .filter { $0.source == .round }
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch handicap scores for source round", error: error)
            return []
        }
    }

    func deleteHandicapScore(_ score: SeriesHandicapScore) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), scoreID: \(score.id)")
        return await score.delete()
    }
}

// MARK: - Handicap Overrides

extension FirebaseService {

    func upsertHandicapOverride(_ override: SeriesHandicapOverride) async -> Result<SeriesHandicapOverride, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(`override`.parentID), memberID: \(`override`.memberID)")
        return await override.put()
    }

    func fetchHandicapOverrides(seriesID: String) async -> [SeriesHandicapOverride] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch handicap overrides", error: error)
            return []
        }
    }
}

// MARK: - Point Awards

extension FirebaseService {

    func upsertPointAward(_ award: SeriesPointAward) async -> Result<SeriesPointAward, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(award.parentID), awardID: \(award.id)")
        return await award.put()
    }

    func deletePointAward(_ award: SeriesPointAward) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), awardID: \(award.id)")
        return await award.delete()
    }

    /// Atomically applies one round's award replacement in a single Firestore batch.
    func batchReplacePointAwards(deleting: [SeriesPointAward], upserting: [SeriesPointAward]) async -> Result<Void, Error> {
        let totalOps = deleting.count + upserting.count
        guard totalOps > 0 else { return .success(()) }
        guard totalOps <= 500 else {
            return .failure(
                SeriesDerivedBatchWriteError.operationLimitExceeded(
                    entity: "point award",
                    count: totalOps
                )
            )
        }

        addBreadcrumb(message: "\(#function), delete: \(deleting.count), upsert: \(upserting.count)")

        let db = Firestore.firestore()
        let batch = db.batch()
        for award in deleting {
            let ref = SeriesPointAward.documentReference(id: award.id, parentID: award.parentID)
            batch.deleteDocument(ref)
        }
        for var award in upserting {
            award.lastUpdatedAt = .init()
            let ref = SeriesPointAward.documentReference(id: award.id, parentID: award.parentID)
            do {
                batch.setData(try award.toDictionary(), forDocument: ref)
            } catch {
                addBreadcrumb(level: .error, message: "\(#function) encode failed", error: error)
                return .failure(error)
            }
        }
        do {
            try await batch.commit()
            return .success(())
        } catch {
            addBreadcrumb(level: .error, message: "\(#function) commit failed", error: error)
            return .failure(error)
        }
    }

    func fetchPointAwards(seriesID: String, seriesRoundID: String? = nil) async -> [SeriesPointAward] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        switch await fetchPointAwardsResult(seriesID: seriesID, seriesRoundID: seriesRoundID) {
        case .success(let awards):
            return awards
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Cannot fetch point awards", error: error)
            return []
        }
    }

    func fetchPointAwardsResult(
        seriesID: String,
        seriesRoundID: String? = nil
    ) async -> Result<[SeriesPointAward], Error> {
        let query = SeriesPointAward.query(parentID: seriesID)
            .whereField(useCondition: seriesRoundID != nil, "series_round_id", isEqualTo: seriesRoundID ?? "")
        return await fetchDocuments(query: query)
    }
}

// MARK: - Canonical Round Results

extension FirebaseService {

    func publishCanonicalRoundResultIfNeeded(
        _ result: SeriesRoundResult
    ) async -> Result<SeriesRoundResultPublicationDecision, Error> {
        let db = Firestore.firestore()
        let resultRef = SeriesRoundResult.documentReference(id: result.id, parentID: result.parentID)
        let stateRef = SeriesRoundProcessingState.documentReference(
            id: result.seriesRoundID,
            parentID: result.parentID
        )
        do {
            let rawDecision = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let stateSnapshot = try transaction.getDocument(stateRef)
                    let resultSnapshot = try transaction.getDocument(resultRef)
                    let currentState = try? stateSnapshot.data(as: SeriesRoundProcessingState.self)
                    let decision = SeriesRoundResultPublicationPlanner.decision(
                        for: result,
                        currentState: currentState,
                        resultAlreadyExists: resultSnapshot.exists
                    )
                    guard decision == .publish else { return decision.rawValue }

                    let state = SeriesRoundCanonicalBuilder.processingState(
                        for: result,
                        previous: currentState
                    )
                    transaction.setData(try result.toDictionary(), forDocument: resultRef)
                    transaction.setData(try state.toDictionary(), forDocument: stateRef)
                    return decision.rawValue
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            guard let value = rawDecision as? String,
                  let decision = SeriesRoundResultPublicationDecision(rawValue: value) else {
                return .failure(HackersError.documentNotFound)
            }
            return .success(decision)
        } catch {
            addBreadcrumb(level: .error, message: "Canonical round result publication failed", error: error)
            return .failure(error)
        }
    }

    func fetchCanonicalRoundResults(
        seriesID: String,
        seriesRoundID: String? = nil
    ) async -> Result<[SeriesRoundResult], Error> {
        let query = SeriesRoundResult.query(parentID: seriesID)
            .whereField(useCondition: seriesRoundID != nil, "series_round_id", isEqualTo: seriesRoundID ?? "")
        return await fetchDocuments(query: query)
    }
}

// MARK: - Standings

extension FirebaseService {

    func updateStanding(_ standing: SeriesStanding) async -> Result<SeriesStanding, Error> {
        addBreadcrumb(message: "\(#function), id: \(standing.id)")
        return await standing.put()
    }

    func fetchStandings(seriesID: String) async -> [SeriesStanding] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        switch await fetchStandingsResult(seriesID: seriesID) {
        case .success(let standings):
            return standings
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Cannot fetch standings", error: error)
            return []
        }
    }

    func fetchStandingsResult(seriesID: String) async -> Result<[SeriesStanding], Error> {
        await getSubcollectionItems(parentID: seriesID)
    }

    func deleteStanding(_ standing: SeriesStanding) async -> Result<Bool, Error> {
        addBreadcrumb(message: "\(#function), id: \(standing.id)")
        return await standing.delete()
    }

    /// Atomically applies the semantic standings diff. Larger publications require a generation-based schema.
    func batchReplaceStandings(
        deleting: [SeriesStanding],
        upserting: [SeriesStanding]
    ) async -> Result<Void, Error> {
        let totalOps = deleting.count + upserting.count
        guard totalOps > 0 else { return .success(()) }
        guard totalOps <= 500 else {
            return .failure(
                SeriesDerivedBatchWriteError.operationLimitExceeded(
                    entity: "standings",
                    count: totalOps
                )
            )
        }

        addBreadcrumb(message: "\(#function), delete: \(deleting.count), upsert: \(upserting.count)")
        let batch = Firestore.firestore().batch()
        for standing in deleting {
            let ref = SeriesStanding.documentReference(id: standing.id, parentID: standing.parentID)
            batch.deleteDocument(ref)
        }
        for standing in upserting {
            let ref = SeriesStanding.documentReference(id: standing.id, parentID: standing.parentID)
            do {
                batch.setData(try standing.toDictionary(), forDocument: ref)
            } catch {
                addBreadcrumb(level: .error, message: "\(#function) encode failed", error: error)
                return .failure(error)
            }
        }
        do {
            try await batch.commit()
            return .success(())
        } catch {
            addBreadcrumb(level: .error, message: "\(#function) commit failed", error: error)
            return .failure(error)
        }
    }
}

// MARK: - Denormalized player array helpers

extension FirebaseService {

    func addPlayerToSeries(seriesID: String, playerID: String) async throws {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID), playerID: \(playerID)")
        try await Firestore.firestore()
            .collection(collection)
            .document(seriesID)
            .updateData(["member_player_ids": FieldValue.arrayUnion([playerID])])
    }

    func removePlayerFromSeries(seriesID: String, playerID: String) async throws {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID), playerID: \(playerID)")
        try await Firestore.firestore()
            .collection(collection)
            .document(seriesID)
            .updateData(["member_player_ids": FieldValue.arrayRemove([playerID])])
    }
}
