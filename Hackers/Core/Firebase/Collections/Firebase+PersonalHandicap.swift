import FirebaseAuth
import FirebaseFirestore
import Foundation

struct ProfileLeagueHandicap: Identifiable {
    let id: String
    let name: String
    let index: Double?
    let basis: SeriesHandicapStrokeBasis
}

struct PersonalHandicapHistory {
    var points: [PersonalHandicapHistoryPoint] = []
    var scores: [PersonalHandicapScoreRecord] = []
    var calculation: PersonalHandicapCalculation?
    var player: Player?
}

extension FirebaseService {
    /// Read the latest player inside the transaction, then patch only the manual
    /// input and effective projection. Concurrent score/name/history edits survive.
    func saveManualPersonalHandicap(playerID: String, manual: ManualPersonalHandicap?) async throws -> Player {
        guard !playerID.isEmpty, !playerID.contains("/") else { throw HackersError.invalidDocumentID }
        guard Auth.auth().currentUser != nil else { throw PersonalHandicapError.notAuthorized }
        // Player.userID references the resolved Hackers user record, which can
        // predate the current authentication provider's UID (existing email linkage).
        let userID = await AppData.shared.user?.id
        let reference = Firestore.firestore().collection(Collections.players.rawValue).document(playerID)
        let time = Time()
        let result = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
            do {
                let player = try transaction.getDocument(reference).data(as: Player.self)
                let updated = try player.settingManualPersonalHandicap(manual, as: userID, at: time)
                if updated == player { return try JSONEncoder().encode(player) }
                let profile = updated.personalHandicap ?? .init()
                var fields: [String: Any] = [
                    "personal_handicap.manual_history": try profile.manualHistory.map { try $0.toDictionary() },
                    "personal_handicap.manual": try profile.manual.map { try $0.toDictionary() as Any } ?? FieldValue.delete(),
                    "personal_handicap.effective_index": profile.effectiveIndex.map { $0 as Any } ?? FieldValue.delete(),
                    "personal_handicap.effective_source": profile.effectiveSource.map { $0.rawValue as Any } ?? FieldValue.delete(),
                    "personal_handicap.refresh_token": FieldValue.delete(),
                    "last_updated_at": try time.toDictionary()
                ]
                // Dot-path updates preserve calculation and future profile fields.
                if player.personalHandicap == nil {
                    fields = ["personal_handicap": try profile.toDictionary(), "last_updated_at": try time.toDictionary()]
                }
                transaction.updateData(fields, forDocument: reference)
                return try JSONEncoder().encode(updated)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        guard let data = result as? Data else { throw HackersError.failedToEncodeDocument }
        let updated = try JSONDecoder().decode(Player.self, from: data)
        await AppData.shared.updateCachedPrimaryPlayer(updated)
        return updated
    }

    /// Refresh on profile load and immediately before a new ordinary participant
    /// is created. Canonical source rounds remain the authority after corrections.
    func fetchPersonalHandicapHistory(playerID: String) async throws -> PersonalHandicapHistory {
        for attempt in 0...1 {
            do { return try await rebuildPersonalHandicap(playerID: playerID) }
            catch PersonalHandicapRefreshError.superseded where attempt == 0 { continue }
        }
        throw PersonalHandicapRefreshError.superseded
    }

    private func rebuildPersonalHandicap(playerID: String) async throws -> PersonalHandicapHistory {
        guard !playerID.isEmpty, !playerID.contains("/") else { throw HackersError.invalidDocumentID }
        let playerRef = Firestore.firestore().collection(Collections.players.rawValue).document(playerID)
        var player = try await playerRef.getDocument(source: .server).data(as: Player.self)
        let userID = await AppData.shared.user?.id
        let mayPersist = Auth.auth().currentUser != nil && player.canEditPersonalHandicap(as: userID)
        let token = UUID().uuidString
        // Claim BEFORE reading inputs. A newer refresh invalidates every older
        // page/final summary, and a concurrent manual edit invalidates this token.
        if mayPersist {
            let data = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
                do {
                    let current = try transaction.getDocument(playerRef).data(as: Player.self)
                    guard current.canEditPersonalHandicap(as: userID) else { throw PersonalHandicapError.notAuthorized }
                    transaction.updateData(["personal_handicap.refresh_token": token], forDocument: playerRef)
                    return try JSONEncoder().encode(current)
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }
            guard let data = data as? Data else { throw HackersError.failedToEncodeDocument }
            player = try JSONDecoder().decode(Player.self, from: data)
        }
        let asOf = Time()
        let root = Firestore.firestore().collection(Collections.rounds.name)
        let roundDocuments = try await root.whereField("players", arrayContains: playerID).getDocuments(source: .server)
        let v2Documents = try await Firestore.firestore().collection(V2Collection.rounds)
            .whereField("participant_player_ids", arrayContains: playerID).getDocuments(source: .server)
        var candidatesV2 = Dictionary(uniqueKeysWithValues: v2Documents.documents.map { ($0.documentID, $0 as DocumentSnapshot) })
        // A migrated copy may no longer include this player. Inspect by stable ID
        // as well, so an active V2 removal never falls back to stale V1 scores.
        for document in roundDocuments.documents where candidatesV2[document.documentID] == nil {
            let copy = try await Firestore.firestore().collection(V2Collection.rounds).document(document.documentID).getDocument(source: .server)
            if copy.exists { candidatesV2[copy.documentID] = copy }
        }
        var activeV2: [String: DocumentSnapshot] = [:]
        var routes: [String: Bool] = [:]
        for (id, document) in candidatesV2 {
            let round = try document.data(as: RoundV2.self)
            var useV2 = true
            if let seriesID = round.seriesContext?.seriesID {
                if let cached = routes[seriesID] { useV2 = cached }
                else {
                    let series = try await Firestore.firestore().collection(V2Collection.series).document(seriesID).getDocument(source: .server).data(as: SeriesV2.self)
                    if let migration = series.migration {
                        let routing = try await Firestore.firestore().collection(V2Collection.routing)
                            .document(migration.sourceSeriesID ?? seriesID).getDocument(source: .server)
                        let phase = routing.exists ? try routing.data(as: SeriesRoutingV2.self).phase : migration.phase
                        useV2 = phase.prefersV2
                    }
                    routes[seriesID] = useV2
                }
            }
            if useV2 { activeV2[id] = document }
        }
        var reviews: [PersonalHandicapRoundReview] = []
        for document in roundDocuments.documents where activeV2[document.documentID] == nil {
            try Task.checkCancellation()
            var round = try document.data(as: Round.self)
            round.id = document.documentID
            guard round.status != .archived else { continue }
            async let participants = RoundParticipant.query(parentID: round.id).getDocuments(source: .server)
            async let segments = RoundSegment.query(parentID: round.id).getDocuments(source: .server)
            async let scores = ScoreEntry.query(parentID: round.id).getDocuments(source: .server)
            let (p, s, g) = try await (participants, segments, scores)
            let snapshot = RoundSnapshot(round: round,
                participants: try p.documents.map { try $0.data(as: RoundParticipant.self) },
                segments: try s.documents.map { try $0.data(as: RoundSegment.self) },
                scoring: try g.documents.map { try $0.data(as: ScoreEntry.self) })
            var review = PersonalHandicapEligibility.review(snapshot, playerID: playerID)
            review.score.sourceCollection = Collections.rounds.name
            reviews.append(review)
        }
        for document in activeV2.values {
            try Task.checkCancellation()
            let round = try document.data(as: RoundV2.self)
            guard round.status != .archived, !round.isCanceled, round.participantPlayerIDs.contains(playerID) else { continue }
            async let participants = RoundParticipantV2.query(parentID: round.id).getDocuments(source: .server)
            async let segments = RoundSegmentV2.query(parentID: round.id).getDocuments(source: .server)
            async let scores = ScoreEntryV2.query(parentID: round.id).getDocuments(source: .server)
            let (p, s, g) = try await (participants, segments, scores)
            let v2 = RoundSnapshotV2(round: round,
                participants: try p.documents.map { try $0.data(as: RoundParticipantV2.self) }, teams: [], teeGroups: [], scoringGroups: [],
                segments: try s.documents.map { try $0.data(as: RoundSegmentV2.self) }, scores: try g.documents.map { try $0.data(as: ScoreEntryV2.self) })
            reviews.append(PersonalHandicapEligibility.reviewV2(v2, playerID: playerID))
        }
        var rebuilt = PersonalHandicapEngine.rebuild(playerID: playerID, reviews: reviews, manual: player.personalHandicap?.manual, manualHistory: player.personalHandicap?.manualHistory ?? [], asOf: asOf)
        if mayPersist {
            try await persistPersonalHandicap(&rebuilt, playerRef: playerRef, token: token)
        }
        player = PersonalHandicapPersistence.applying(rebuilt.calculation, to: player)
        if mayPersist { await AppData.shared.updateCachedPrimaryPlayer(player) }
        return .init(points: rebuilt.history, scores: rebuilt.scores.reversed(), calculation: rebuilt.calculation, player: player)
    }

    private func persistPersonalHandicap(_ rebuilt: inout PersonalHandicapRebuild, playerRef: DocumentReference, token: String) async throws {
        let scoreCollection = playerRef.collection("personal-handicap-scores")
        let historyCollection = playerRef.collection("personal-handicap-history")
        async let oldScores = scoreCollection.getDocuments(source: .server)
        async let oldHistory = historyCollection.getDocuments(source: .server)
        let (scoreDocuments, historyDocuments) = try await (oldScores, oldHistory)
        let previousScores = Dictionary(uniqueKeysWithValues: scoreDocuments.documents.compactMap { document in
            (try? document.data(as: PersonalHandicapScoreRecord.self)).map { (document.documentID, $0) }
        })
        let previousHistory = Dictionary(uniqueKeysWithValues: historyDocuments.documents.compactMap { document in
            (try? document.data(as: PersonalHandicapHistoryPoint.self)).map { (document.documentID, $0) }
        })
        // Preserve the date of unchanged historical calculations. A correction
        // updates only affected outputs; source scorecards are never rewritten.
        rebuilt.history = rebuilt.history.map { point in
            if let old = previousHistory[point.id], PersonalHandicapPersistence.sameHistory(old, point) { return old }
            return point
        }
        if rebuilt.calculation.retainedIndex != nil {
            rebuilt.calculation.retainedAsOf = rebuilt.history.last?.calculation.asOf
        }
        var writes: [(DocumentReference, [String: Any]?)] = []
        for score in rebuilt.scores where previousScores[score.id] != score {
            writes.append((scoreCollection.document(score.id), try score.toDictionary()))
        }
        for point in rebuilt.history where previousHistory[point.id] != point {
            writes.append((historyCollection.document(point.id), try point.toDictionary()))
        }
        let scoreIDs = Set(rebuilt.scores.map(\.id)), pointIDs = Set(rebuilt.history.map(\.id))
        for document in scoreDocuments.documents where !scoreIDs.contains(document.documentID) { writes.append((document.reference, nil)) }
        for document in historyDocuments.documents where !pointIDs.contains(document.documentID) { writes.append((document.reference, nil)) }
        // Small refreshes are one transaction; large histories are paged below
        // Firestore's write limit. A generation token guards every page and summary.
        for start in stride(from: 0, to: max(1, writes.count), by: 200) {
            let page = Array(writes.dropFirst(start).prefix(200))
            let isLast = start + 200 >= writes.count
            let calculation = rebuilt.calculation
            _ = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
                do {
                    let document = try transaction.getDocument(playerRef)
                    guard let profile = document.data()?["personal_handicap"] as? [String: Any], profile["refresh_token"] as? String == token else {
                        throw PersonalHandicapRefreshError.superseded
                    }
                    let player = try document.data(as: Player.self)
                    for (reference, data) in page {
                        if let data { transaction.setData(data, forDocument: reference) }
                        else { transaction.deleteDocument(reference) }
                    }
                    if isLast {
                        let updated = PersonalHandicapPersistence.applying(calculation, to: player)
                        transaction.updateData([
                            "personal_handicap.calculation": try calculation.toDictionary(),
                            "personal_handicap.effective_index": updated.personalHandicap?.effectiveIndex.map { $0 as Any } ?? FieldValue.delete(),
                            "personal_handicap.effective_source": updated.personalHandicap?.effectiveSource.map { $0.rawValue as Any } ?? FieldValue.delete()
                        ], forDocument: playerRef)
                    }
                    return true
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }
        }
    }

    /// Changes handicap-posting metadata only, including on completed cards.
    func setPersonalHandicapPurpose(playerID: String, roundID: String, sourceCollection: String = Collections.rounds.name, purpose: PersonalHandicapRoundPurpose, partialReason: String?) async throws -> PersonalHandicapHistory {
        guard !playerID.isEmpty, !roundID.isEmpty, !playerID.contains("/"), !roundID.contains("/") else { throw HackersError.invalidDocumentID }
        let player = try await getPlayerByID(playerID).get()
        let userID = await AppData.shared.user?.id
        guard Auth.auth().currentUser != nil, player.canEditPersonalHandicap(as: userID) else { throw PersonalHandicapError.notAuthorized }
        guard [Collections.rounds.name, V2Collection.rounds].contains(sourceCollection) else { throw HackersError.invalidDocumentID }
        let participants = try await Firestore.firestore().collection(sourceCollection).document(roundID)
            .collection(RoundSubcollection.participants.rawValue).whereField("player_id", isEqualTo: playerID).getDocuments(source: .server)
        guard participants.documents.count == 1, let participant = participants.documents.first else { throw PersonalHandicapError.notAuthorized }
        let reference = participant.reference
        try await reference.updateData([
            "personal_handicap_purpose": purpose.rawValue,
            "personal_handicap_partial_reason": partialReason.map { $0 as Any } ?? FieldValue.delete(),
            "last_updated_at": try Time().toDictionary()
        ])
        return try await fetchPersonalHandicapHistory(playerID: playerID)
    }

    /// Read-only projection using each league's existing algorithm and overrides.
    /// Routing selects the canonical V1/V2 root before any subcollection reads.
    func fetchProfileLeagueHandicaps(playerID: String) async throws -> [ProfileLeagueHandicap] {
        let records = await fetchUserSeriesRecords(playerID: playerID)
        var result: [ProfileLeagueHandicap] = []
        for record in records.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let collection: String
            let config: SeriesHandicapConfig
            switch record {
            case .v1(let series): collection = Collections.series.rawValue; config = series.handicapConfig
            case .v2(let series): collection = V2Collection.series; config = series.settings.handicapConfig
            }
            let root = Firestore.firestore().collection(collection).document(record.id)
            let memberDocuments = try await root.collection("members").whereField("player_id", isEqualTo: playerID).getDocuments()
            let members = try memberDocuments.documents.map { try $0.data(as: SeriesMember.self) }.filter(\.isActive)
            guard !members.isEmpty else { continue }
            var scores: [SeriesHandicapScore] = []
            var overrides: [SeriesHandicapOverride] = []
            for member in members {
                async let memberScores = root.collection("handicap-scores").whereField("member_id", isEqualTo: member.id).getDocuments()
                async let memberOverrides = root.collection("handicap-overrides").whereField("member_id", isEqualTo: member.id).getDocuments()
                let (scoreDocuments, overrideDocuments) = try await (memberScores, memberOverrides)
                scores += try scoreDocuments.documents.map { try $0.data(as: SeriesHandicapScore.self) }
                overrides += try overrideDocuments.documents.map { try $0.data(as: SeriesHandicapOverride.self) }
            }
            let projection = SeriesHandicapProjectionService.project(members: members, scores: scores, overrides: overrides, handicapConfig: config)
            let member = members.sorted { $0.id < $1.id }.first!
            result.append(.init(id: record.id, name: record.name, index: projection.handicapsByMemberID[member.id]?.effectiveIndex, basis: config.strokeBasis))
        }
        return result
    }
}
