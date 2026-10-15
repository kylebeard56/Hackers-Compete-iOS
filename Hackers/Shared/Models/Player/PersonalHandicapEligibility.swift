import Foundation

/// Acceptability requires facts that a completed scorecard alone cannot establish
/// (Rules 2.1–2.2: purpose, Rules of Golf, company, season, rated tees, etc.).
/// No existing round is silently certified by this review.
enum PersonalHandicapRoundPurpose { case unverified, acceptable, practice, unofficial }

struct PersonalHandicapRoundReview {
    var score: PersonalHandicapScoreRecord
    var qualifyingHoles: Int
    var revision: Double
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
        purpose: PersonalHandicapRoundPurpose = .unverified
    ) -> PersonalHandicapRoundReview {
        let round = snapshot.round
        let course = snapshot.courseSegment
        let matches = snapshot.participants.filter { $0.playerID == playerID }
        let participant = matches.count == 1 ? matches.first : nil
        let tee = participant.flatMap { course?.tee(from: $0.teeBoxID) }
        let range = course?.holeRange
        // Reuse PR #14's provenance-aware metadata resolver; Tee.rating(for:)
        // alone can silently estimate a nine-hole rating from full-course data.
        let metadata = HandicapCalculator.calculation(index: 0, tee: tee, segment: range.flatMap {
            (1...18).contains($0.startHole) && ($0.startHole...18).contains($0.endHole) ? $0.segment : nil
        }, indexBasis: .eighteenHole)
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
        let gross = grossByHole.isEmpty ? nil : grossByHole.values.reduce(0, +)
        let playedAt = round.firstScoredAt ?? round.createdAt // corrections must not move the play date
        var record = PersonalHandicapScoreRecord(
            playerID: playerID, roundID: round.id,
            roundTitle: round.displayTitle(courseName: course?.courseInfo.name), playedAt: playedAt,
            holeCount: grossByHole.count, grossScore: gross, exclusionReason: nil
        )
        func result(excluded: String? = nil, pending: String? = nil, holes: Int = 0) -> PersonalHandicapRoundReview {
            record = .init(playerID: record.playerID, roundID: record.roundID, roundTitle: record.roundTitle,
                           playedAt: record.playedAt, holeCount: record.holeCount, grossScore: record.grossScore,
                           exclusionReason: excluded, pendingReason: pending)
            return .init(score: record, qualifyingHoles: holes, revision: revision)
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
        guard let range, (1...18).contains(range.startHole), (range.startHole...18).contains(range.endHole), [9, 18].contains(range.count),
              metadata.status == .exact, let rating = metadata.rating, rating.isFinite, rating > 0,
              let slope = metadata.slope, (55...155).contains(slope) else {
            return result(pending: "Exact rated tee and nine- or eighteen-hole course data required")
        }
        guard grouped.values.allSatisfy({ $0.count == 1 }) else { return result(excluded: "Duplicate or ambiguous individual hole scores") }
        guard grossByHole.count == range.count else {
            if grossByHole.count >= 9 {
                return result(pending: "Partial round requires verified reason, rated holes and official expected-score processing")
            }
            return result(excluded: "Incomplete individual gross scorecard")
        }
        guard round.firstScoredAt != nil else { return result(pending: "Actual play date is not recorded") }
        guard purpose == .acceptable else {
            return result(pending: "Handicap acceptability not verified (including practice status, season and Rules of Golf)")
        }
        return result(holes: range.count)
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
