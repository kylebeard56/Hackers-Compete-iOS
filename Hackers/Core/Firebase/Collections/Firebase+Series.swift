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

    func fetchUserSeries(playerID: String) async -> [Series] {
        addBreadcrumb(message: "\(#function), playerID: \(playerID)")
        do {
            let query = Firestore.firestore()
                .collection(collection)
                .whereField("players", arrayContains: playerID)
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

    func fetchSeriesMembers(seriesID: String) async -> [SeriesMember] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch series members", error: error)
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

// MARK: - Rounds

extension FirebaseService {

    func addSeriesRound(_ round: SeriesRound) async -> Result<SeriesRound, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(round.parentID)")
        return await round.post()
    }

    func updateSeriesRound(_ round: SeriesRound) async -> Result<SeriesRound, Error> {
        addBreadcrumb(message: "\(#function), id: \(round.id)")
        return await round.put()
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

// MARK: - Round Attendance

extension FirebaseService {

    func upsertSeriesRoundAttendance(_ attendance: SeriesRoundAttendance) async -> Result<SeriesRoundAttendance, Error> {
        addBreadcrumb(message: "\(#function), round: \(attendance.seriesRoundID), member: \(attendance.memberID)")
        return await attendance.put()
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

// MARK: - Handicap Scores

extension FirebaseService {

    func addHandicapScore(_ score: SeriesHandicapScore) async -> Result<SeriesHandicapScore, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(score.parentID), member: \(score.memberID)")
        return await score.post()
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
}

// MARK: - Point Awards

extension FirebaseService {

    func addPointAward(_ award: SeriesPointAward) async -> Result<SeriesPointAward, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(award.parentID)")
        return await award.post()
    }

    func fetchPointAwards(seriesID: String) async -> [SeriesPointAward] {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch point awards", error: error)
            return []
        }
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
        do {
            return try await getSubcollectionItems(parentID: seriesID).get()
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch standings", error: error)
            return []
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
            .updateData(["players": FieldValue.arrayUnion([playerID])])
    }

    func removePlayerFromSeries(seriesID: String, playerID: String) async throws {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID), playerID: \(playerID)")
        try await Firestore.firestore()
            .collection(collection)
            .document(seriesID)
            .updateData(["players": FieldValue.arrayRemove([playerID])])
    }
}
