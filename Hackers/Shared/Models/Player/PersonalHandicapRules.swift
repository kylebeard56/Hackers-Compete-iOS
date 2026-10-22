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

/// Hackers policy, not the USGA's proprietary expected-score formula. The
/// linear estimate agrees, to a tenth, with the USGA 14.0/15.0 examples and
/// representative Swiss Golf 2025 published values from -6.0 through 54.0.
/// Keep both components unrounded until their 18-hole sum is rounded once.
enum PersonalHandicapNineHoleEstimation {
    static let pairedVersion = "hackers-paired-nine-v1"
    static let expectedVersion = "hackers-expected-nine-linear-bounded-v2"
    static let supportedIndexRange = -6.0...54.0

    /// Better-than-+6 players use the published table's +6 boundary, rather
    /// than extrapolating unvalidated expected scores. Preserve their actual
    /// historical Index separately; this never changes that Index or allowance.
    static func modelIndex(index: Double) throws -> Double {
        guard index.isFinite, index <= supportedIndexRange.upperBound else { throw PersonalHandicapRules.InputError.invalidInput }
        return max(supportedIndexRange.lowerBound, index)
    }

    static func expectedDifferential(index: Double) throws -> Double {
        let result = 0.52 * (try modelIndex(index: index)) + 1.2
        guard result.isFinite else { throw PersonalHandicapRules.InputError.invalidInput }
        return result
    }
}

enum PersonalHandicapEngine {
    static let methodVersion = "hackers-whs-inspired-nine-hole-v4"
    static let unavailableMessage = "Some scores need more individual scoring data. Your last valid calculated Index or manual starting Index remains available."

    private struct ReplayInput: Encodable {
        let sources: [String]
        let manual: ManualPersonalHandicap?
        let manualHistory: [PersonalHandicapManualRevision]
        let verified: [PersonalHandicapVerifiedDifferential]
    }

    /// One selection/ESR unit can reference two initial nine-hole source cards.
    private struct Differential {
        let id: String
        let roundIDs: [String]
        let value: Double?
        let pendingReason: String?
    }

    private static func recordDifferential(_ score: inout PersonalHandicapScoreRecord, value: Double,
        id: String, rounds: [String], method: PersonalHandicapDifferentialMethod, version: String) {
        score.differential = PersonalHandicapRules.tenth(value)
        score.differentialID = id
        score.differentialRoundIDs = rounds
        score.differentialMethod = method
        score.differentialMethodVersion = version
        score.pendingReason = nil
    }

    /// Chronological replay pairs initial nines only once. After a calculated
    /// Index exists, each new nine uses that prior Index, never a manual value or
    /// a future result. Source scorecards and scoring snapshots are immutable.
    static func rebuild(
        playerID: String, reviews: [PersonalHandicapRoundReview],
        verified: [PersonalHandicapVerifiedDifferential] = [], manual: ManualPersonalHandicap? = nil, manualHistory: [PersonalHandicapManualRevision] = [], asOf: Time = .init()
    ) -> PersonalHandicapRebuild {
        let manualProfile = PersonalHandicapProfile(manual: manual, manualHistory: manualHistory)
        let reviews = PersonalHandicapEligibility.unique(reviews, playerID: playerID)
        let verified = verified.filter { $0.playerID == playerID }
        let supplied = Dictionary(grouping: verified, by: \.roundID)
        let fingerprint = PersonalHandicapFingerprint.hash(ReplayInput(
            sources: reviews.map { $0.fingerprint.isEmpty ? PersonalHandicapFingerprint.hash($0.score) + String($0.revision) : $0.fingerprint },
            manual: manual, manualHistory: manualHistory, verified: verified.sorted { $0.roundID == $1.roundID ? $0.postingID < $1.postingID : $0.roundID < $1.roundID }))
        var scores: [PersonalHandicapScoreRecord] = []
        var history: [PersonalHandicapHistoryPoint] = []
        var differentials: [Differential] = []
        var initialNine: (scoreIndex: Int, played: Double)?
        var reductions: [String: Double] = [:]
        var postingIDs = Set<String>()
        var totalHoles = 0
        var qualifyingIDs: [String] = []
        var lowIndex: Double?
        var qualifiedHistory: [(date: Double, index: Double)] = []
        var calculation = PersonalHandicapCalculation(
            index: nil, status: .collecting, asOf: asOf, methodVersion: methodVersion,
            qualifyingScoreIDs: [], qualifyingHoles: 0, requiredHoles: 54, poolScoreIDs: [], countingScoreIDs: []
        )
        calculation.poolDifferentialIDs = []; calculation.countingDifferentialIDs = []
        for review in reviews {
            var score = review.score
            var holes = review.qualifyingHoles
            if score.exclusionReason != nil || holes == 0 { scores.append(score); continue }
            let previousIndex = calculation.effectiveCalculatedIndex
            let matches = (supplied[score.roundID] ?? []).filter { $0.revision == review.revision }
            var value: Double?
            var indexInEffect: Double?
            var postingID = score.roundID
            var method = PersonalHandicapDifferentialMethod.eighteenHole
            var version = "whs-eighteen-hole-v1"
            var pairInitialNine = false
            if let card = review.card {
                let historicalManual = manualProfile.manualInput(at: score.playedAt)
                indexInEffect = card.frozenPersonalIndex ?? previousIndex ?? historicalManual?.value
                score.personalIndexAtPlay = indexInEffect
                score.personalIndexProvenance = card.frozenPersonalIndex != nil ? "frozen_personal_input"
                    : previousIndex != nil ? "replayed_personal_history"
                    : indexInEffect != nil ? "\(historicalManual?.source.rawValue ?? "manual")_as_of_recorded_play" : "initial_par_plus_five"
                score.pcc = card.pcc
                do {
                    let assessed = try card.assessed(index: indexInEffect)
                    score.adjustedGrossScore = assessed.gross
                    score.playedDifferential = assessed.played
                    score.pendingReason = assessed.pending
                    holes = assessed.qualifyingHoles
                    value = assessed.differential
                    if card.intendedHoles == 9, card.holes.count == 9, let played = assessed.played {
                        if let previousIndex {
                            let expected = try PersonalHandicapNineHoleEstimation.expectedDifferential(index: previousIndex)
                            value = played + expected
                            score.expectedNineDifferential = expected
                            score.expectedScoreIndex = previousIndex
                            score.expectedScoreModelIndex = try PersonalHandicapNineHoleEstimation.modelIndex(index: previousIndex)
                            method = .expectedNineEstimate
                            version = PersonalHandicapNineHoleEstimation.expectedVersion
                            indexInEffect = previousIndex // ESR compares against the same pre-round personal Index.
                        } else {
                            pairInitialNine = true
                            score.pendingReason = "Unpaired initial nine · qualifying holes retained"
                            score.differentialMethod = .pairedNineEstimate
                            score.differentialMethodVersion = PersonalHandicapNineHoleEstimation.pairedVersion
                        }
                    }
                } catch {
                    score.pendingReason = "Personal hole limits need valid unrestricted Course Handicap and stroke-index data"
                }
            }
            if matches.count == 1, let input = matches.first,
               input.unroundedValue.isFinite, input.indexInEffect?.isFinite != false, !input.postingID.isEmpty {
                value = input.unroundedValue
                indexInEffect = input.indexInEffect
                postingID = input.postingID
                pairInitialNine = false
                method = .verifiedExternal; version = "verified-eighteen-hole-v1"
                score.expectedNineDifferential = nil; score.expectedScoreIndex = nil
                score.expectedScoreModelIndex = nil
            } else if review.card == nil {
                score.pendingReason = "Differential inputs unavailable or do not match this score revision"
            }
            guard postingIDs.insert(postingID).inserted else {
                score.exclusionReason = "Duplicate handicap posting"
                score.qualifyingHoles = 0
                score.pendingReason = nil
                scores.append(score); continue
            }
            score.qualifyingHoles = holes
            totalHoles += holes
            qualifyingIDs.append(score.roundID)
            let current = scores.count
            scores.append(score)
            var added: Differential?
            var allowExceptionalReduction = true
            if pairInitialNine, let played = score.playedDifferential {
                if let earlier = initialNine {
                    let rounds = [scores[earlier.scoreIndex].roundID, score.roundID]
                    let id = "paired-nine-" + PersonalHandicapFingerprint.hash(rounds)
                    let combined = earlier.played + played
                    recordDifferential(&scores[earlier.scoreIndex], value: combined, id: id, rounds: rounds,
                        method: .pairedNineEstimate, version: PersonalHandicapNineHoleEstimation.pairedVersion)
                    recordDifferential(&scores[current], value: combined, id: id, rounds: rounds,
                        method: .pairedNineEstimate, version: PersonalHandicapNineHoleEstimation.pairedVersion)
                    added = .init(id: id, roundIDs: rounds, value: PersonalHandicapRules.tenth(combined), pendingReason: nil)
                    initialNine = nil
                    // No single pre-round established Index exists for this synthetic pair.
                    allowExceptionalReduction = false
                } else { initialNine = (current, played) }
            } else {
                if let value {
                    recordDifferential(&scores[current], value: value, id: score.roundID, rounds: [score.roundID], method: method, version: version)
                }
                added = .init(id: score.roundID, roundIDs: [score.roundID], value: value.map(PersonalHandicapRules.tenth), pendingReason: scores[current].pendingReason)
            }
            if let added {
                differentials.append(added)
                if let value, allowExceptionalReduction {
                    let reduction = PersonalHandicapRules.exceptionalReduction(unroundedDifferential: value, indexInEffect: indexInEffect)
                    if reduction != 0 {
                        for entry in differentials.suffix(20) { reductions[entry.id, default: 0] += reduction }
                    }
                }
            }
            // Select differential equivalents, not source-card count. An unpaired
            // initial nine advances actual holes but never occupies a fabricated slot.
            let scope = Array(differentials.suffix(20))
            let pool = scope.filter { $0.value != nil }
            let activeBlockers = scope.filter { $0.value == nil }.map { $0.pendingReason ?? unavailableMessage }
            var index: Double?
            var counting: [Differential] = []
            if totalHoles >= 54, activeBlockers.isEmpty, let selection = PersonalHandicapRules.selection(count: pool.count) {
                counting = Array(pool.sorted {
                    let l = $0.value! + reductions[$0.id, default: 0], r = $1.value! + reductions[$1.id, default: 0]
                    return l == r ? $0.id < $1.id : l < r
                }.prefix(selection.count))
                let mean = counting.reduce(0) { $0 + $1.value! + reductions[$1.id, default: 0] } / Double(selection.count) + selection.adjustment
                index = PersonalHandicapRules.tenth(PersonalHandicapRules.capped(PersonalHandicapRules.tenth(mean), lowIndex: lowIndex))
                if pool.count == 20, let index {
                    qualifiedHistory.append((score.playedAt.unix, index))
                    let cutoff = score.playedAt.unix - 365 * 86400
                    lowIndex = qualifiedHistory.filter { $0.date >= cutoff }.map(\.index).min()
                }
            }
            calculation = .init(index: index, status: activeBlockers.isEmpty ? (index == nil ? .collecting : .qualified) : .blocked,
                asOf: asOf, methodVersion: methodVersion, qualifyingScoreIDs: qualifyingIDs, qualifyingHoles: totalHoles,
                requiredHoles: 54, poolScoreIDs: pool.flatMap(\.roundIDs), countingScoreIDs: counting.flatMap(\.roundIDs))
            calculation.poolDifferentialIDs = pool.map(\.id)
            calculation.countingDifferentialIDs = counting.map(\.id)
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
        }
        calculation.inputFingerprint = fingerprint
        return .init(calculation: calculation, history: history, scores: scores)
    }
}
