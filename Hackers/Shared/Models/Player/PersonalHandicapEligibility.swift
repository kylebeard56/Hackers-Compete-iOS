import Foundation

/// Acceptability requires facts that a completed scorecard alone cannot establish
/// (Rules 2.1–2.2: purpose, Rules of Golf, company, season, rated tees, etc.).
/// Hackers treats completed individual cards as personal postings unless marked
/// otherwise. This is an unofficial app policy, not certification by the USGA.
enum PersonalHandicapRoundPurpose: String, Codable { case unverified, acceptable, practice, unofficial }

enum PersonalHandicapPartialReason: String, CaseIterable {
    case weather, darkness, injury, matchFinished = "match_finished", committeeClosure = "committee_closure"
    var title: String {
        switch self {
        case .weather: return "Weather prevented play"
        case .darkness: return "Fading light prevented play"
        case .injury: return "Injury or illness"
        case .matchFinished: return "Match finished before the final hole"
        case .committeeClosure: return "Committee closed or shortened the course"
        }
    }
}

struct PersonalHandicapRoundReview {
    var score: PersonalHandicapScoreRecord
    var qualifyingHoles: Int
    var revision: Double
    var card: PersonalHandicapCard? = nil
    var fingerprint: String = ""
}

enum PersonalHandicapEligibility {
    static let requiredHoles = 54

    private static func key(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func isScramble(_ templateID: String) -> Bool {
        let template = FormatTemplateRegistry.captainsChoice
        let aliases = [template.id, template.name, "captain choice"] + (template.aliases ?? [])
        let normalized = key(templateID)
        return aliases.contains { key($0) == normalized } || normalized.hasSuffix("scramble")
    }

    /// Never resolve an unknown ID through the registry's stroke-play fallback.
    /// Shamble is deliberately absent even though the registry maps it to best ball.
    private static func isIndividualFormat(_ templateID: String) -> Bool {
        ["strokeplay", "strokeplaygross", "strokeplaynet", "strokeplaymatchup", "individualmatchup",
         "stableford", "matchplay", "matchplayindividual", "bestball", "best2of4", "betterball",
         "bestballmatchup", "best2of4matchup", "fourball", "fourballstrokeplay", "fourballmatchplay"]
            .contains(key(templateID))
    }

    static func review(
        _ snapshot: RoundSnapshot, playerID: String,
        purpose: PersonalHandicapRoundPurpose? = nil
    ) -> PersonalHandicapRoundReview {
        let round = snapshot.round
        let course = snapshot.courseSegment
        let matches = snapshot.participants.filter { $0.playerID == playerID }
        let participant = matches.count == 1 ? matches.first : nil
        let tee = participant.flatMap { course?.tee(from: $0.teeBoxID) }
        let range = course?.holeRange
        let purpose = purpose ?? participant?.personalHandicapPurpose ?? .acceptable
        let partialReason = participant?.personalHandicapPartialReason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fingerprint = PersonalHandicapFingerprint.snapshot(snapshot)
        // Reuse PR #14's provenance-aware metadata resolver; Tee.rating(for:)
        // alone can silently estimate a nine-hole rating from full-course data.
        var metadata = HandicapCalculator.calculation(index: 0, tee: tee, segment: range.flatMap {
            (1...18).contains($0.startHole) && ($0.startHole...18).contains($0.endHole) ? $0.segment : nil
        }, indexBasis: .eighteenHole)
        // A deliberately shortened round can still use the exact full-course
        // metadata, with expected-score processing pending for unplayed holes.
        if let range, (1...18).contains(range.startHole), (range.startHole...18).contains(range.endHole),
           (10...17).contains(range.count), PersonalHandicapPartialReason(rawValue: partialReason ?? "") != nil {
            metadata = HandicapCalculator.calculation(index: 0, tee: tee, segment: .full18, indexBasis: .eighteenHole)
        }
        let entries = snapshot.scoring.filter { entry in
            guard let participant else { return false }
            return entry.participantIDs == [participant.id] && range?.contains(entry.holeNumber) == true
        }
        var revision = max(round.lastUpdatedAt.unix, round.createdAt.unix)
        for value in snapshot.participants { revision = max(revision, value.lastUpdatedAt.unix) }
        for value in snapshot.segments { revision = max(revision, value.lastUpdatedAt.unix) }
        for value in snapshot.scoring { revision = max(revision, value.lastUpdatedAt.unix) }
        let grouped = Dictionary(grouping: entries, by: \.holeNumber)
        // Conflicting/duplicate hole rows require correction. Never add them twice,
        // or guess whether an additional row was a correction versus a side game.
        var grossByHole: [Int: Int] = [:]
        for (number, rows) in grouped where rows.count == 1 {
            guard let entry = rows.first, !entry.pickedUp,
                  let hole = tee?.holes.first(where: { $0.number == number }), hole.par > 0,
                  entry.relativeToPar.map({ hole.par + $0 > 0 }) != false,
                  let gross = ScoringEngine.resolvedGrossStrokes(entry: entry, par: hole.par), gross > 0,
                  entry.strokes == nil || entry.relativeToPar == nil || entry.strokes == hole.par + entry.relativeToPar! else { continue }
            grossByHole[number] = gross
        }
        // Preserve recorded gross strokes in history even when tee/par metadata
        // is insufficient to qualify them. Never infer team scores or missing pars.
        var historyGross = grossByHole
        for (number, rows) in grouped where rows.count == 1 && historyGross[number] == nil {
            if let row = rows.first, !row.pickedUp, let strokes = row.strokes, strokes > 0 { historyGross[number] = strokes }
        }
        let gross = historyGross.isEmpty ? nil : historyGross.values.reduce(0, +)
        // Older cards predate first_scored_at. ScoreEntry.createdAt is a required
        // persisted field, so its earliest recorded time is an available fallback,
        // rather than the last edit time or a fabricated date.
        let firstRecordedScore = entries.map(\.createdAt).min { $0.unix < $1.unix }
        let playedAt = round.firstScoredAt ?? firstRecordedScore ?? round.createdAt
        var record = PersonalHandicapScoreRecord(
            playerID: playerID, roundID: round.id,
            roundTitle: round.displayTitle(courseName: course?.courseInfo.name), playedAt: playedAt,
            holeCount: historyGross.count, grossScore: gross, exclusionReason: nil
        )
        func result(excluded: String? = nil, pending: String? = nil, holes: Int = 0, card: PersonalHandicapCard? = nil) -> PersonalHandicapRoundReview {
            record = .init(playerID: record.playerID, roundID: record.roundID, roundTitle: record.roundTitle,
                           playedAt: record.playedAt, holeCount: record.holeCount, grossScore: record.grossScore,
                           exclusionReason: excluded, pendingReason: pending)
            record.playedAtSource = round.firstScoredAt != nil ? "first_scored_at" : firstRecordedScore != nil ? "earliest_recorded_score" : "round_created_at_unqualified"
            record.postingPurpose = purpose
            record.partialReason = partialReason
            record.qualifyingHoles = holes
            record.sourceFingerprint = fingerprint
            return .init(score: record, qualifyingHoles: holes, revision: revision, card: card, fingerprint: fingerprint)
        }
        let templateIDs = [round.configuration.formatSummary?.templateID].compactMap { $0 }
            + snapshot.segments.compactMap(\.templateID)
        if templateIDs.contains(where: isScramble) {
            return result(excluded: "Captain’s Choice / Scramble: shared shots are not individual handicap scores.")
        }
        if purpose == .practice { return result(excluded: "Practice round") }
        if purpose == .unofficial { return result(excluded: "Unofficial round") }
        guard round.status == .complete else { return result(excluded: "Round is not complete") }
        guard let participant, !participant.id.isEmpty else { return result(excluded: "Individual player identity is missing or ambiguous") }
        guard round.configuration.scoreOwnerScope == .individual,
              !round.configuration.primaryFormat.configuration.handicap.isTeamCombined,
              !snapshot.segments.contains(where: { $0.gameFormat.configuration.handicap.isTeamCombined }),
              !snapshot.segments.contains(where: { segment in
                  segment.scoringUnits.contains { unit in
                      unit.ownerIDs.contains(participant.id) && (unit.owner != .participant || unit.ownerIDs.count != 1)
                  }
              }), !templateIDs.contains(where: { FormatTemplateRegistry.template(for: $0).scoreSource == .shared }) else {
            return result(excluded: "Team-only or shared score")
        }
        guard templateIDs.allSatisfy(isIndividualFormat) else { return result(excluded: "Format is not verified for individual handicap posting") }
        guard let range, (1...18).contains(range.startHole), (range.startHole...18).contains(range.endHole),
              (9...18).contains(range.count), let tee,
              metadata.status == .exact, let rating = metadata.rating, rating.isFinite, rating > 0,
              let slope = metadata.slope, (55...155).contains(slope), let par = metadata.par else {
            return result(pending: "Exact rated tee and course data required")
        }
        guard grouped.values.allSatisfy({ $0.count == 1 }) else { return result(excluded: "Duplicate or ambiguous individual hole scores") }
        guard round.firstScoredAt != nil || firstRecordedScore != nil else { return result(pending: "Recorded score date is unavailable") }
        guard purpose == .acceptable else {
            return result(pending: "Personal handicap posting is marked as needing review")
        }
        let played = grossByHole.keys.sorted().compactMap { number -> PersonalHandicapHole? in
            guard let hole = tee.holes.first(where: { $0.number == number }), let gross = grossByHole[number] else { return nil }
            return .init(number: number, par: hole.par, strokeIndex: hole.handicap ?? 0, gross: gross)
        }
        let intendedHoles = metadata.segment == .full18 ? 18 : 9
        guard !entries.contains(where: \.pickedUp) else {
            return result(pending: "Picked-up holes need a valid individual gross or most-likely score")
        }
        let isPartial = played.count != intendedHoles
        var initialNine: PersonalHandicapCardNine?
        if isPartial {
            guard played.count >= 9 else { return result(excluded: "Incomplete individual gross scorecard") }
            guard PersonalHandicapPartialReason(rawValue: partialReason ?? "") != nil else {
                return result(pending: "Partial round needs a valid reason for unplayed holes")
            }
            for segment in [HoleSegment.front9, .back9] {
                let numbers = Set(segment.holeRange.holeNumbers)
                let nine = played.filter { numbers.contains($0.number) }
                let exact = HandicapCalculator.calculation(index: 0, tee: tee, segment: segment, indexBasis: .eighteenHole)
                if nine.count == 9, exact.status == .exact, let r = exact.rating, let s = exact.slope {
                    initialNine = .init(holes: nine, rating: r, slope: s)
                    break
                }
            }
            guard initialNine != nil else { return result(pending: "Partial round needs a complete, exactly rated nine") }
        }
        let pcc = round.personalHandicapPCC ?? .assumedZero
        guard pcc.isValid else { return result(pending: "PCC provenance or value is invalid") }
        let frozen = participant.personalHandicapInput.flatMap { input -> Double? in
            input.basis == .eighteenHole && input.index.isFinite && input.capturedAt.unix <= playedAt.unix ? input.index : nil
        }
        let card = PersonalHandicapCard(holes: played, intendedHoles: intendedHoles, rating: rating, slope: slope, par: par,
                                       pcc: pcc, frozenPersonalIndex: frozen, partialReason: partialReason, initialNine: initialNine)
        // Before establishment, partial 18-hole cards contribute only a rated nine.
        let holes = isPartial ? (frozen == nil ? 9 : played.count) : intendedHoles
        return result(holes: holes, card: card)
    }

    /// Reuse the established V2 scoring projection, adding only the personal
    /// posting metadata it intentionally omits. No league projection is changed.
    static func reviewV2(_ source: RoundSnapshotV2, playerID: String) -> PersonalHandicapRoundReview {
        var snapshot = source.scoringSnapshot()
        snapshot.round.firstScoredAt = source.scores.filter { $0.strokes != nil || $0.relativeToPar != nil }
            .map(\.createdAt).min { $0.unix < $1.unix }
        snapshot.round.personalHandicapPCC = source.round.personalHandicapPCC
        snapshot.round.configuration.formatSummary?.templateID = source.round.configuration.templateID
        for i in snapshot.participants.indices {
            let personal = source.participants.first { $0.id == snapshot.participants[i].id }
            snapshot.participants[i].personalHandicapPurpose = personal?.personalHandicapPurpose
            snapshot.participants[i].personalHandicapPartialReason = personal?.personalHandicapPartialReason
        }
        var review = review(snapshot, playerID: playerID)
        review.score.sourceCollection = V2Collection.rounds
        return review
    }

    /// Latest revision wins before filtering: a correction can remove eligibility.
    /// This is a separate projection; it never deletes a round from ordinary history/statistics.
    static func unique(_ reviews: [PersonalHandicapRoundReview], playerID: String) -> [PersonalHandicapRoundReview] {
        Dictionary(grouping: reviews.filter { $0.score.playerID == playerID }, by: { $0.score.roundID })
            .compactMap { _, versions in versions.max { $0.revision < $1.revision } }
            .sorted { lhs, rhs in
                lhs.score.playedAt.unix == rhs.score.playedAt.unix
                    ? lhs.score.roundID < rhs.score.roundID : lhs.score.playedAt.unix < rhs.score.playedAt.unix
            }
    }
}
