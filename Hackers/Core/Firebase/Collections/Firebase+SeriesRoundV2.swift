//
//  Firebase+SeriesRoundV2.swift
//  Hackers
//
//  Version-routed reads and direct score writes for canonical V2 aggregates.
//  Lifecycle and structural writes intentionally live in callable functions.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

extension FirebaseService {
    func fetchSeriesV2(id: String) async -> Result<SeriesV2, Error> {
        addBreadcrumb(message: "\(#function), id: \(id)")
        return await fetchDocument(
            with: Firestore.firestore().collection(V2Collection.series).document(id)
        )
    }

    func fetchRoundV2(id: String) async -> Result<RoundV2, Error> {
        addBreadcrumb(message: "\(#function), id: \(id)")
        return await fetchDocument(
            with: Firestore.firestore().collection(V2Collection.rounds).document(id)
        )
    }

    func fetchSeriesRoutingV2(seriesID: String) async -> Result<SeriesRoutingV2, Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        return await fetchDocument(
            with: Firestore.firestore().collection(V2Collection.routing).document(seriesID)
        )
    }

    private func lookupSeriesRoutingV2(seriesID: String) async -> SeriesRoutingV2? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection(V2Collection.routing)
                .document(seriesID)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: SeriesRoutingV2.self)
        } catch {
            addBreadcrumb(level: .warning, message: "Cannot inspect V2 Series routing: \(seriesID)", error: error)
            return nil
        }
    }

    func fetchSeriesRoundsV2(seriesID: String) async -> Result<[RoundV2], Error> {
        addBreadcrumb(message: "\(#function), seriesID: \(seriesID)")
        let query = Firestore.firestore()
            .collection(V2Collection.rounds)
            .whereField("series_context.series_id", isEqualTo: seriesID)
        return await fetchDocuments(query: query)
    }

    func fetchSeriesMembersV2(seriesID: String) async -> Result<[SeriesMemberV2], Error> {
        await fetchDocuments(query: SeriesMemberV2.query(parentID: seriesID))
    }

    func fetchSeriesTeamsV2(seriesID: String) async -> Result<[SeriesTeamV2], Error> {
        await fetchDocuments(query: SeriesTeamV2.query(parentID: seriesID))
    }

    func fetchSeriesRoundResultStatesV2(seriesID: String) async -> Result<[SeriesRoundResultStateV2], Error> {
        await fetchDocuments(query: SeriesRoundResultStateV2.query(parentID: seriesID))
    }

    /// V1 and V2 persist the same additive historical projection wire shape. The
    /// explicit V2 path avoids teaching the V1 model a second collection authority.
    func fetchSeriesRoundResultsV2(seriesID: String) async -> Result<[SeriesRoundResult], Error> {
        let query = Firestore.firestore()
            .collection(V2Collection.series)
            .document(seriesID)
            .collection(SeriesV2Subcollection.roundResults.rawValue)
        return await fetchDocuments(query: query)
    }

    func fetchRoundSnapshotV2(roundID: String) async -> Result<RoundSnapshotV2, Error> {
        do {
            let round: RoundV2 = try await fetchRoundV2(id: roundID).get()
            let participants: [RoundParticipantV2] = try await fetchDocuments(
                query: RoundParticipantV2.query(parentID: roundID)
            ).get()
            let teams: [RoundTeamV2] = try await fetchDocuments(
                query: RoundTeamV2.query(parentID: roundID)
            ).get()
            let teeGroups: [RoundTeeGroupV2] = try await fetchDocuments(
                query: RoundTeeGroupV2.query(parentID: roundID)
            ).get()
            let scoringGroups: [RoundScoringGroupV2] = try await fetchDocuments(
                query: RoundScoringGroupV2.query(parentID: roundID)
            ).get()
            let segments: [RoundSegmentV2] = try await fetchDocuments(
                query: RoundSegmentV2.query(parentID: roundID)
            ).get()
            let scores: [ScoreEntryV2] = try await fetchDocuments(
                query: ScoreEntryV2.query(parentID: roundID)
            ).get()
            return .success(.init(
                round: round,
                participants: participants,
                teams: teams,
                teeGroups: teeGroups,
                scoringGroups: scoringGroups,
                segments: segments,
                scores: scores
            ))
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch V2 round snapshot: \(roundID)", error: error)
            return .failure(error)
        }
    }

    /// Uses the V2 membership index so Series roots do not grow an unbounded member-id array.
    func fetchUserSeriesV2(playerID: String) async -> [SeriesV2] {
        guard playerID.isPopulated else { return [] }
        do {
            let query = Firestore.firestore()
                .collection(V2Collection.memberships)
                .whereField("player_id", isEqualTo: playerID)
                .whereField("is_active", isEqualTo: true)
            let memberships: [SeriesMembershipIndexV2] = try await fetchDocuments(query: query).get()
            var result: [SeriesV2] = []
            for seriesID in Array(Set(memberships.map(\.seriesID))).sorted() {
                if case .success(let series) = await fetchSeriesV2(id: seriesID) {
                    result.append(series)
                }
            }
            return result
        } catch {
            addBreadcrumb(level: .error, message: "Cannot fetch V2 series memberships", error: error)
            return []
        }
    }

    /// Returns one record per logical league. Staged V2 copies remain hidden until
    /// the commissioner activates their server-owned routing document.
    func fetchUserSeriesRecords(playerID: String) async -> [SeriesRecord] {
        guard playerID.isPopulated else { return [] }

        let v1Values = await fetchUserSeries(playerID: playerID)
        var v2Values = await fetchUserSeriesV2(playerID: playerID)
        let knownV2IDs = Set(v2Values.map(\.id))

        // Membership indexes are migrated before activation, but resolving V2 by the
        // known V1 id makes selection fail-safe if an index read is temporarily incomplete.
        for seriesID in v1Values.map(\.id) where !knownV2IDs.contains(seriesID) {
            if case .success(let value) = await fetchSeriesV2(id: seriesID) {
                v2Values.append(value)
            }
        }

        let v1ByID = Dictionary(uniqueKeysWithValues: v1Values.map { ($0.id, $0) })
        var v2ByLogicalID: [String: SeriesV2] = [:]
        for value in v2Values {
            v2ByLogicalID[value.migration?.sourceSeriesID ?? value.id] = value
        }

        let logicalIDs = Set(v1ByID.keys).union(v2ByLogicalID.keys)
        var records: [SeriesRecord] = []
        for logicalID in logicalIDs.sorted() {
            let v2 = v2ByLogicalID[logicalID]
            let routing: SeriesRoutingV2?
            if v1ByID[logicalID] != nil || v2?.migration != nil {
                routing = await lookupSeriesRoutingV2(seriesID: logicalID)
            } else {
                routing = nil
            }
            if let selected = SeriesVersionSelectorV2.select(
                v1: v1ByID[logicalID],
                v2: v2,
                routing: routing
            ), selected.status != .archived {
                records.append(selected)
            }
        }
        return records.sorted { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix }
    }

    /// Resolves both versions and applies the same cutover rule used by dashboard lists.
    func resolveSeriesRecord(byToken token: String) async -> Result<SeriesRecord, Error> {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isPopulated else { return .failure(SeriesRoundV2Error.unresolvedToken) }

        let v1 = try? await resolveSeries(byToken: value).get()
        var v2 = try? await fetchSeriesV2(id: value).get()
        if v2 == nil {
            let query = Firestore.firestore()
                .collection(V2Collection.series)
                .whereField("share_code", isEqualTo: value.uppercased())
                .limit(to: 1)
            let result: Result<SeriesV2, Error> = await fetchDocument(query: query)
            v2 = try? result.get()
        }

        let logicalID = v2?.migration?.sourceSeriesID ?? v1?.id ?? v2?.id
        let routing: SeriesRoutingV2?
        if let logicalID, v1 != nil || v2?.migration != nil {
            routing = await lookupSeriesRoutingV2(seriesID: logicalID)
        } else {
            routing = nil
        }
        if let selected = SeriesVersionSelectorV2.select(v1: v1, v2: v2, routing: routing) {
            return .success(selected)
        }
        return .failure(SeriesRoundV2Error.unresolvedToken)
    }

    func resolveRoundRecord(byToken token: String) async -> Result<RoundRecord, Error> {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isPopulated else { return .failure(SeriesRoundV2Error.unresolvedToken) }

        let v1 = try? await resolveRound(byToken: value).get()
        var v2 = try? await fetchRoundV2(id: value).get()
        if v2 == nil {
            let query = Firestore.firestore()
                .collection(V2Collection.rounds)
                .whereField("share_code", isEqualTo: value.uppercased())
                .limit(to: 1)
            let result: Result<RoundV2, Error> = await fetchDocument(query: query)
            v2 = try? result.get()
        }

        if let v2 {
            if let seriesID = v2.seriesContext?.seriesID,
               case .success(let series) = await fetchSeriesV2(id: seriesID) {
                let routing: SeriesRoutingV2?
                if let migration = series.migration {
                    routing = try? await fetchSeriesRoutingV2(
                        seriesID: migration.sourceSeriesID ?? seriesID
                    ).get()
                } else {
                    routing = nil
                }
                let phase = routing?.phase ?? series.migration?.phase
                if series.migration == nil || phase?.prefersV2 == true {
                    return .success(.v2(v2))
                }
            } else if v2.seriesContext == nil {
                return .success(.v2(v2))
            }
        }
        if let v1 { return .success(.v1(v1)) }
        return .failure(SeriesRoundV2Error.unresolvedToken)
    }

    /// Score documents use deterministic ids and remain direct Firestore writes for live-round latency.
    func saveScoreV2(_ score: ScoreEntryV2) async -> Result<ScoreEntryV2, Error> {
        guard score.parentID.isPopulated, score.id.isPopulated else {
            return .failure(HackersError.failedToEncodeDocument)
        }
        addBreadcrumb(message: "\(#function), roundID: \(score.parentID), scoreID: \(score.id)")
        return await score.put()
    }
}
