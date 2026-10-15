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
                let profile = updated.personalHandicap ?? .init()
                var fields: [String: Any] = [
                    "personal_handicap.manual": try manual.map { try $0.toDictionary() as Any } ?? FieldValue.delete(),
                    "personal_handicap.effective_index": profile.effectiveIndex.map { $0 as Any } ?? FieldValue.delete(),
                    "personal_handicap.effective_source": profile.effectiveSource.map { $0.rawValue as Any } ?? FieldValue.delete(),
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

    func fetchPersonalHandicapHistory(playerID: String) async throws -> PersonalHandicapHistory {
        guard !playerID.isEmpty, !playerID.contains("/") else { throw HackersError.invalidDocumentID }
        // Use canonical source rounds for ordinary AND league play, never the
        // league's handicap-score pool (which has different eligibility/rules).
        // Propagate read failures: a partial history must not look like zero scores.
        let query = Firestore.firestore().collection(Collections.rounds.name)
            .whereField("players", arrayContains: playerID)
        let rounds: [Round] = try await fetchDocuments(query: query).get()
        var reviews: [PersonalHandicapRoundReview] = []
        for round in rounds where round.status != .archived {
            try Task.checkCancellation()
            async let participants = getParticipants(for: round.id)
            async let segments = getSegments(for: round.id)
            async let scores = getScores(for: round.id)
            let (p, s, g) = try await (participants.get(), segments.get(), scores.get())
            let snapshot = RoundSnapshot(round: round, participants: p, segments: s, scoring: g)
            // Existing rounds do not certify acceptability or provide official PCC /
            // expected-score data. Explicitly pending; never infer an official input.
            reviews.append(PersonalHandicapEligibility.review(snapshot, playerID: playerID))
        }
        let rebuilt = PersonalHandicapEngine.rebuild(playerID: playerID, reviews: reviews)
        return .init(points: rebuilt.history, scores: rebuilt.scores.reversed(), calculation: rebuilt.calculation)
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
