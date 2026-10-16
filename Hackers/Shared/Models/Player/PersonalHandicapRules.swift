import Foundation

/// Published USGA Rules 3.1, 5.1–5.3, 5.7–5.9. Pure personal calculations:
/// no dependency on league projections, scoring allowances, or league multipliers.
/// Official PCC may be absent; the caller records the explicitly assumed zero.
/// Expected-score inputs are never estimated.
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
        let played = try playedDifferential(adjustedGross: adjustedGross, rating: rating, slope: slope, holes: holes, pcc: pcc ?? 0)
        if holes == 18 { return played }
        guard let expected = expectedNineHoleDifferential else { throw InputError.missingExpectedScore }
        guard expected.isFinite else { throw InputError.invalidInput }
        return played + expected
    }

    /// Actual played portion only. A nine-hole value is not an 18-hole Index input.
    static func playedDifferential(adjustedGross: Int, rating: Double, slope: Int, holes: Int, pcc: Double) throws -> Double {
        guard holes == 9 || holes == 18 else { throw InputError.partialRoundRequiresProvider }
        guard adjustedGross > 0, rating.isFinite, rating > 0, (55...155).contains(slope),
              [-1.0, 0, 1, 2, 3].contains(pcc) else { throw InputError.invalidInput }
        return 113 / Double(slope) * (Double(adjustedGross) - rating - (holes == 9 ? 0.5 : 1) * pcc)
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
struct PersonalHandicapVerifiedDifferential: Codable {
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
    static let methodVersion = "hackers-whs-inspired-assumed-pcc-v2"
    static let unavailableMessage = "Eligible nine-hole and partial scores stay in your history and progress. Their 18-hole conversion needs an expected-score input; your manual starting Index remains available."

    private struct ReplayInput: Encodable {
        let sources: [String]
        let manual: ManualPersonalHandicap?
        let verified: [PersonalHandicapVerifiedDifferential]
    }

    /// Uses canonical individual gross cards, independently of league allowances.
    /// Nines remain pending until supplied expected-score processing is possible.
    static func rebuild(
        playerID: String, reviews: [PersonalHandicapRoundReview],
        verified: [PersonalHandicapVerifiedDifferential] = [], manual: ManualPersonalHandicap? = nil, asOf: Time = .init()
    ) -> PersonalHandicapRebuild {
        let reviews = PersonalHandicapEligibility.unique(reviews, playerID: playerID)
        let verified = verified.filter { $0.playerID == playerID }
        let supplied = Dictionary(grouping: verified, by: \.roundID)
        let fingerprint = PersonalHandicapFingerprint.hash(ReplayInput(
            sources: reviews.map { $0.fingerprint.isEmpty ? PersonalHandicapFingerprint.hash($0.score) + String($0.revision) : $0.fingerprint },
            manual: manual, verified: verified.sorted { $0.roundID == $1.roundID ? $0.postingID < $1.postingID : $0.roundID < $1.roundID }))
        var scores: [PersonalHandicapScoreRecord] = []
        var history: [PersonalHandicapHistoryPoint] = []
        var values: [String: Double] = [:]
        var reductions: [String: Double] = [:]
        var postingIDs = Set<String>()
        var unresolved: [String: String] = [:]
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
            var holes = review.qualifyingHoles
            if score.exclusionReason != nil || holes == 0 { scores.append(score); continue }
            let matches = (supplied[score.roundID] ?? []).filter { $0.revision == review.revision }
            var value: Double?
            var indexInEffect: Double?
            var postingID = score.roundID
            if let card = review.card {
                indexInEffect = card.frozenPersonalIndex ?? calculation.effectiveCalculatedIndex
                    ?? manual.flatMap { $0.updatedAt.unix <= score.playedAt.unix ? $0.value : nil }
                score.personalIndexAtPlay = indexInEffect
                score.personalIndexProvenance = card.frozenPersonalIndex != nil ? "frozen_personal_input"
                    : calculation.effectiveCalculatedIndex != nil ? "replayed_personal_history"
                    : indexInEffect != nil ? "manual_as_of_recorded_play" : "initial_par_plus_five"
                score.pcc = card.pcc
                do {
                    let assessed = try card.assessed(index: indexInEffect)
                    score.adjustedGrossScore = assessed.gross
                    score.playedDifferential = assessed.played
                    score.pendingReason = assessed.pending
                    holes = assessed.qualifyingHoles
                    value = assessed.differential
                } catch {
                    score.pendingReason = "Personal hole limits need valid unrestricted Course Handicap and stroke-index data"
                }
            }
            // Future verified normalization can resolve nines without changing
            // gross scores, assumed/verified PCC provenance or round allowances.
            if matches.count == 1, let input = matches.first,
               input.unroundedValue.isFinite, input.indexInEffect?.isFinite != false, !input.postingID.isEmpty {
                value = input.unroundedValue
                indexInEffect = input.indexInEffect
                postingID = input.postingID
                score.pendingReason = nil
            } else if review.card == nil {
                score.pendingReason = "Differential inputs unavailable or do not match this score revision"
            }
            guard postingIDs.insert(postingID).inserted else {
                score = .init(playerID: score.playerID, roundID: score.roundID, roundTitle: score.roundTitle,
                              playedAt: score.playedAt, holeCount: score.holeCount, grossScore: score.grossScore,
                              exclusionReason: "Duplicate handicap posting")
                scores.append(score); continue
            }
            score.qualifyingHoles = holes
            totalHoles += holes
            qualifyingIDs.append(score.roundID)
            score.differential = value.map(PersonalHandicapRules.tenth)
            if let value {
                values[score.roundID] = PersonalHandicapRules.tenth(value)
                let reduction = PersonalHandicapRules.exceptionalReduction(unroundedDifferential: value, indexInEffect: indexInEffect)
                if reduction != 0 {
                    for id in qualifyingIDs.suffix(20) { reductions[id, default: 0] += reduction }
                }
            } else { unresolved[score.roundID] = score.pendingReason ?? unavailableMessage }
            let scope = Array(qualifyingIDs.suffix(20))
            let poolIDs = scope.filter { values[$0] != nil }
            let activeBlockers = scope.compactMap { unresolved[$0] }
            var index: Double?
            var counting: [String] = []
            if totalHoles >= 54, activeBlockers.isEmpty, let selection = PersonalHandicapRules.selection(count: poolIDs.count) {
                counting = Array(poolIDs.sorted {
                    let l = values[$0]! + reductions[$0, default: 0], r = values[$1]! + reductions[$1, default: 0]
                    return l == r ? $0 < $1 : l < r
                }.prefix(selection.count))
                let mean = counting.reduce(0) { $0 + values[$1]! + reductions[$1, default: 0] } / Double(selection.count) + selection.adjustment
                index = PersonalHandicapRules.tenth(PersonalHandicapRules.capped(PersonalHandicapRules.tenth(mean), lowIndex: lowIndex))
                if poolIDs.count == 20, let index {
                    qualifiedHistory.append((score.playedAt.unix, index))
                    let cutoff = score.playedAt.unix - 365 * 86400
                    lowIndex = qualifiedHistory.filter { $0.date >= cutoff }.map(\.index).min()
                }
            }
            calculation = .init(index: index, status: activeBlockers.isEmpty ? (index == nil ? .collecting : .qualified) : .blocked,
                asOf: asOf, methodVersion: methodVersion, qualifyingScoreIDs: qualifyingIDs, qualifyingHoles: totalHoles,
                requiredHoles: 54, poolScoreIDs: poolIDs, countingScoreIDs: counting)
            calculation.blockers = activeBlockers.isEmpty ? nil : Array(Set(activeBlockers)).sorted()
            calculation.lowHandicapIndex = lowIndex
            calculation.inputFingerprint = fingerprint
            if index == nil, !activeBlockers.isEmpty, let previous = history.last {
                calculation.retainedIndex = previous.calculation.qualifiedIndex
                calculation.retainedAsOf = previous.calculation.asOf
            }
            if index != nil {
                history.append(.init(playerID: playerID, roundID: score.roundID, roundTitle: score.roundTitle,
                                     playedAt: score.playedAt, calculation: calculation))
            }
            scores.append(score)
        }
        calculation.inputFingerprint = fingerprint
        return .init(calculation: calculation, history: history, scores: scores)
    }
}
