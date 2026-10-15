import Foundation

/// Published USGA Rules 3.1, 5.1–5.3, 5.7–5.9. Pure personal calculations:
/// no dependency on league projections, scoring allowances, or league multipliers.
/// Missing external inputs are errors, never assumed zero/estimated.
enum PersonalHandicapRules {
    enum InputError: Error, Equatable {
        case missingPCC, missingExpectedScore, partialRoundRequiresProvider, invalidInput
    }

    /// Ties round toward +infinity, including minus Score Differentials (Rule 5.1c).
    static func tenth(_ value: Double) -> Double { floor(value * 10 + 0.5 + 1e-9) / 10 }

    static func differential(
        adjustedGross: Int, rating: Double, slope: Int, holes: Int,
        pcc: Double?, expectedNineHoleDifferential: Double? = nil
    ) throws -> Double {
        guard holes == 9 || holes == 18 else { throw InputError.partialRoundRequiresProvider }
        guard adjustedGross > 0, rating.isFinite, rating > 0, (55...155).contains(slope) else { throw InputError.invalidInput }
        guard let pcc else { throw InputError.missingPCC }
        guard [-1.0, 0, 1, 2, 3].contains(pcc) else { throw InputError.invalidInput }
        let played = 113 / Double(slope) * (Double(adjustedGross) - rating - (holes == 9 ? 0.5 : 1) * pcc)
        if holes == 18 { return played } // retain unrounded for exceptional-score comparison
        guard let expected = expectedNineHoleDifferential else { throw InputError.missingExpectedScore }
        guard expected.isFinite else { throw InputError.invalidInput }
        return played + expected // do not round the played nine before combining
    }

    /// `strokes` must come from the full unrestricted Course Handicap, including
    /// strokes given back by plus players. Never pass capped/normalized league strokes.
    static func maximumHoleScore(par: Int, establishedIndex: Bool, unrestrictedCourseHandicap: Int, strokes: Int) -> Int {
        if !establishedIndex || (unrestrictedCourseHandicap > 54 && strokes >= 4) { return par + 5 }
        return par + 2 + strokes
    }

    static func selection(count: Int) -> (count: Int, adjustment: Double)? {
        switch count {
        case 3: return (1, -2)
        case 4: return (1, -1)
        case 5: return (1, 0)
        case 6: return (2, -1)
        case 7...8: return (2, 0)
        case 9...11: return (3, 0)
        case 12...14: return (4, 0)
        case 15...16: return (5, 0)
        case 17...18: return (6, 0)
        case 19: return (7, 0)
        case 20: return (8, 0)
        default: return nil
        }
    }

    static func exceptionalReduction(unroundedDifferential: Double, indexInEffect: Double?) -> Double {
        guard let indexInEffect else { return 0 }
        let improvement = indexInEffect - unroundedDifferential
        return improvement >= 10 ? -2 : improvement >= 7 ? -1 : 0
    }

    static func capped(_ value: Double, lowIndex: Double?) -> Double {
        guard let lowIndex, value > lowIndex + 3 else { return min(54, value) }
        return min(54, lowIndex + 5, lowIndex + 3 + (value - lowIndex - 3) * 0.5)
    }
}

/// Boundary for a future verified posting/calculation provider. This is not a
/// user-editable Firestore field. The provider must bind its response to the exact
/// player, round and reviewed revision, and supply an unrounded, 18-hole-scale
/// differential AFTER official PCC, expected score and Rule 3 adjustments.
struct PersonalHandicapVerifiedDifferential {
    let playerID: String
    let roundID: String
    let revision: Double
    let unroundedValue: Double
    let indexInEffect: Double?
    /// Stable external posting identity deduplicates multiple imported copies.
    let postingID: String
}

struct PersonalHandicapRebuild {
    var calculation: PersonalHandicapCalculation
    var history: [PersonalHandicapHistoryPoint]
    var scores: [PersonalHandicapScoreRecord]
}

enum PersonalHandicapEngine {
    static let methodVersion = "usga-published-rules-2024-v1"
    static let unavailableMessage = "Calculation needs verified handicap postings, official PCC and expected-score data. A manual starting Index can be used until these are available."

    /// Rebuild from canonical score revisions, never mutate round participants.
    /// All initial nine-hole scores require provider normalization after 54 holes;
    /// neither chronological pairing nor doubling is a supported fallback.
    static func rebuild(
        playerID: String, reviews: [PersonalHandicapRoundReview],
        verified: [PersonalHandicapVerifiedDifferential] = [], asOf: Time = .init()
    ) -> PersonalHandicapRebuild {
        let reviews = PersonalHandicapEligibility.unique(reviews, playerID: playerID)
        let supplied = Dictionary(grouping: verified.filter { $0.playerID == playerID }, by: \.roundID)
        var scores: [PersonalHandicapScoreRecord] = []
        var history: [PersonalHandicapHistoryPoint] = []
        var accepted: [(review: PersonalHandicapRoundReview, value: Double, reduction: Double)] = []
        var postingIDs = Set<String>()
        var blockers = Set<String>()
        var totalHoles = 0
        var qualifyingIDs: [String] = []
        var lowIndex: Double?
        var qualifiedHistory: [(date: Double, index: Double)] = []
        var calculation = PersonalHandicapCalculation(
            index: nil, status: .collecting, asOf: asOf, methodVersion: methodVersion,
            qualifyingScoreIDs: [], qualifyingHoles: 0, requiredHoles: 54, poolScoreIDs: [], countingScoreIDs: []
        )
        for review in reviews {
            var score = review.score
            if score.exclusionReason != nil { scores.append(score); continue }
            guard review.qualifyingHoles == 9 || review.qualifyingHoles == 18,
                  score.pendingReason == nil else {
                blockers.insert(score.pendingReason ?? "Score eligibility requires verification")
                scores.append(score); continue
            }
            let matches = (supplied[score.roundID] ?? []).filter { $0.revision == review.revision }
            guard matches.count == 1, let input = matches.first,
                  input.unroundedValue.isFinite, input.indexInEffect?.isFinite != false,
                  !input.postingID.isEmpty else {
                score.pendingReason = "Official differential inputs unavailable or do not match this score revision"
                totalHoles += review.qualifyingHoles
                qualifyingIDs.append(score.roundID)
                blockers.insert(unavailableMessage)
                scores.append(score); continue
            }
            guard postingIDs.insert(input.postingID).inserted else {
                score = .init(playerID: score.playerID, roundID: score.roundID, roundTitle: score.roundTitle,
                              playedAt: score.playedAt, holeCount: score.holeCount, grossScore: score.grossScore,
                              exclusionReason: "Duplicate handicap posting")
                scores.append(score); continue
            }
            totalHoles += review.qualifyingHoles
            qualifyingIDs.append(score.roundID)
            let reduction = PersonalHandicapRules.exceptionalReduction(unroundedDifferential: input.unroundedValue, indexInEffect: input.indexInEffect)
            accepted.append((review, PersonalHandicapRules.tenth(input.unroundedValue), 0))
            // ESR applies cumulatively to the most recent 20 differentials at posting,
            // including the new score; later scores do not inherit the adjustment.
            if reduction != 0 {
                for i in max(0, accepted.count - 20)..<accepted.count { accepted[i].reduction += reduction }
            }
            let pool = Array(accepted.suffix(20))
            let selection = PersonalHandicapRules.selection(count: pool.count)
            var counting: [String] = []
            var index: Double?
            if totalHoles >= 54, blockers.isEmpty, let selection {
                let lowest = pool.sorted {
                    let l = $0.value + $0.reduction, r = $1.value + $1.reduction
                    return l == r ? $0.review.score.roundID < $1.review.score.roundID : l < r
                }.prefix(selection.count)
                counting = lowest.map { $0.review.score.roundID }
                let mean = lowest.reduce(0) { $0 + $1.value + $1.reduction } / Double(selection.count) + selection.adjustment
                // Existing Low Index is used first, even after a break >365 days.
                index = PersonalHandicapRules.tenth(PersonalHandicapRules.capped(PersonalHandicapRules.tenth(mean), lowIndex: lowIndex))
                if accepted.count >= 20, let index {
                    qualifiedHistory.append((score.playedAt.unix, index))
                    let cutoff = score.playedAt.unix - 365 * 86400
                    lowIndex = qualifiedHistory.filter { $0.date >= cutoff }.map(\.index).min()
                }
            }
            calculation = .init(index: index, status: blockers.isEmpty ? (index == nil ? .collecting : .qualified) : .blocked,
                asOf: asOf, methodVersion: methodVersion, qualifyingScoreIDs: accepted.map { $0.review.score.roundID },
                qualifyingHoles: totalHoles, requiredHoles: 54, poolScoreIDs: pool.map { $0.review.score.roundID }, countingScoreIDs: counting)
            calculation.lowHandicapIndex = lowIndex
            if index != nil {
                history.append(.init(playerID: playerID, roundID: score.roundID, roundTitle: score.roundTitle,
                                     playedAt: score.playedAt, calculation: calculation))
            }
            scores.append(score)
        }
        if !blockers.isEmpty {
            calculation.index = nil
            calculation.status = .blocked
            calculation.countingScoreIDs = []
            calculation.poolScoreIDs = [] // an incomplete pool must not appear authoritative
            calculation.blockers = blockers.sorted()
        }
        calculation.qualifyingScoreIDs = qualifyingIDs
        calculation.qualifyingHoles = totalHoles
        return .init(calculation: calculation, history: history, scores: scores)
    }
}
