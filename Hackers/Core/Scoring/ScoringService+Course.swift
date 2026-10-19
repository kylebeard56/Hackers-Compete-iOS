//
//  ScoringService+Course.swift
//  Hackers
//
//  Created by Kyle Beard on 8/9/25.
//

import Foundation
import UIKit

extension ScoringService {
    /// Scale a handicap inputted based on slope course ratings
    static func scaleHandicap() { }
    
    /// Provide a 0-100 difficulty score for a tee box from slope and course ratings
    static func courseDifficulty() { }
}

enum HandicapCalculator {
    static func isValidDraft(_ text: String, format: HandicapEntryFormat) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return format == .courseHandicap }
        return Double(trimmed)?.isFinite == true
    }

    /// Personal entry always uses the standard 18-hole Index. League inputs retain
    /// their configured basis and continue through the existing conversion rules.
    static func entryIndexBasis(for participant: RoundParticipant, configured: SeriesHandicapStrokeBasis?) -> SeriesHandicapStrokeBasis? {
        if participant.seriesMemberID != nil || participant.handicapSnapshot != nil || participant.leagueHandicapStrokesAtCreation != nil {
            return participant.handicapSnapshot?.calculation?.indexBasis ?? configured
        }
        return .eighteenHole
    }

    static func personalConfiguration(_ configuration: RoundConfiguration, playedHoleCount: Int) -> RoundConfiguration {
        var result = configuration
        result.handicapIndexBasis = .eighteenHole
        result.handicapStrokeBasis = .defaultBasis(holeCount: playedHoleCount)
        return result
    }

    static func configuration(_ configuration: RoundConfiguration, settingHandicapBasis basis: SeriesHandicapStrokeBasis?, playedHoleCount: Int) -> RoundConfiguration {
        var result = configuration
        if configuration.handicapEntryFormat == .courseHandicap {
            result.handicapIndexBasis = .eighteenHole
            // Course Handicap is already on the played segment's scale.
            result.handicapStrokeBasis = .defaultBasis(holeCount: playedHoleCount)
        } else { result.handicapStrokeBasis = basis }
        return result
    }


    static func calculation(
        index: Double?,
        tee: Tee?,
        segment: HoleSegment?,
        indexBasis: SeriesHandicapStrokeBasis?
    ) -> CourseHandicapCalculation {
        var result = CourseHandicapCalculation(handicapIndex: index, indexBasis: indexBasis, teeID: tee?.id, segment: segment)
        if index == nil || index?.isFinite != true { result.missingFields.append("handicap index") }
        if indexBasis == nil { result.missingFields.append("index basis") }
        guard let tee, let segment else {
            result.missingFields.append("selected tee or segment")
            return result
        }
        let numbers = segment.holeRange.holeNumbers
        let holes = tee.holes.filter { numbers.contains($0.number) }
        let validPar = holes.count == numbers.count && Set(holes.map(\.number)) == Set(numbers)
            && holes.allSatisfy { $0.par > 0 }
        result.par = validPar ? tee.par(for: segment) : nil
        result.parProvenance = validPar ? .segment : nil
        if !validPar { result.missingFields.append("par") }

        // Tee's existing deterministic fallbacks are the only estimation source.
        // Full data on a native nine-hole course describes that nine, not 18 holes.
        let teeHoleCount = max(tee.totalHoles, tee.holes.count)
        let nativeNine = teeHoleCount == 9
        let validFullData = teeHoleCount >= 18 && tee.ratingFull.isFinite && tee.ratingFull > 0 && tee.slopeFull > 0
        switch segment {
        case .full18:
            if teeHoleCount >= 18 {
                result.rating = tee.ratingFull
                result.slope = tee.slopeFull
                result.ratingProvenance = .fullCourse
                result.slopeProvenance = .fullCourse
            }
        case .front9, .back9:
            let exactRating = segment == .front9 ? tee.ratingFront : tee.ratingBack
            let exactSlope = segment == .front9 ? tee.slopeFront : tee.slopeBack
            let nativeSegment = segment == .front9 && nativeNine
            result.rating = exactRating
            result.slope = exactSlope
            result.ratingProvenance = exactRating == nil ? nil : .segment
            result.slopeProvenance = exactSlope == nil ? nil : .segment
            if exactRating == nil, nativeSegment || validFullData {
                result.rating = tee.rating(for: segment)
                result.ratingProvenance = nativeSegment ? .fullCourse : .estimatedFromFullCourse
            }
            if exactSlope == nil, nativeSegment || validFullData {
                result.slope = tee.slope(for: segment)
                result.slopeProvenance = nativeSegment ? .fullCourse : .estimatedFromFullCourse
            }
        case .custom:
            result.missingFields.append("supported segment")
        }
        if result.rating?.isFinite != true || (result.rating ?? 0) <= 0 { result.missingFields.append("course rating") }
        if (result.slope ?? 0) <= 0 { result.missingFields.append("slope rating") }
        guard result.missingFields.isEmpty, let index, let indexBasis,
              let rating = result.rating, let slope = result.slope, let par = result.par else { return result }
        let calculationIndex = courseHandicapIndexBasis(index, inputBasis: indexBasis, segment: segment)
        let raw = calculationIndex * (Double(slope) / 113.0) + rating - Double(par)
        guard raw.isFinite, raw > Double(Int.min), raw < Double(Int.max) else {
            result.missingFields.append("valid calculation")
            return result
        }
        result.calculationIndex = calculationIndex
        result.rawValue = raw
        result.courseHandicap = Int(raw.rounded())
        result.status = result.ratingProvenance == .estimatedFromFullCourse || result.slopeProvenance == .estimatedFromFullCourse
            ? .estimated : .exact
        return result
    }

    static func calculation(
        index: Double?,
        participant: RoundParticipant,
        courseSegment: CourseSegment?,
        indexBasis: SeriesHandicapStrokeBasis?
    ) -> CourseHandicapCalculation {
        calculation(index: index, tee: courseSegment.flatMap { tee(for: participant, in: $0) },
                    segment: courseSegment?.holeSegment, indexBasis: indexBasis)
    }

    // Compatibility preview APIs. Applying a value must go through allowedStrokes,
    // which requires confirmation for estimates and rejects unavailable results.
    static func rawCourseHandicap(index: Double, tee: Tee, segment: HoleSegment,
                                  handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole) -> Double? {
        calculation(index: index, tee: tee, segment: segment, indexBasis: handicapStrokeBasis).rawValue
    }

    static func courseHandicap(index: Double, tee: Tee, segment: HoleSegment,
                               handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole) -> Int? {
        calculation(index: index, tee: tee, segment: segment, indexBasis: handicapStrokeBasis).courseHandicap
    }

    static func rawCourseHandicap(index: Double, participant: RoundParticipant, courseSegment: CourseSegment?,
                                  handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole) -> Double? {
        calculation(index: index, participant: participant, courseSegment: courseSegment, indexBasis: handicapStrokeBasis).rawValue
    }

    static func courseHandicap(index: Double, participant: RoundParticipant, courseSegment: CourseSegment?,
                               handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole) -> Int? {
        calculation(index: index, participant: participant, courseSegment: courseSegment, indexBasis: handicapStrokeBasis).courseHandicap
    }

    static func hasCourseHandicapData(for participant: RoundParticipant? = nil, courseSegment: CourseSegment?) -> Bool {
        calculation(index: 0, participant: participant ?? RoundParticipant(), courseSegment: courseSegment,
                    indexBasis: .eighteenHole).status != .unavailable
    }

    static func strokes(
        for input: Double, format: HandicapEntryFormat, participant: RoundParticipant,
        courseSegment: CourseSegment?, maximumHandicap: Int? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole,
        estimateApproved: Bool = false
    ) -> Int? {
        switch format {
        case .strokes:
            guard input.isFinite, input > Double(Int.min), input < Double(Int.max) else { return nil }
            return capped(Int(input.rounded()), maximumHandicap: maximumHandicap)
        case .courseHandicap:
            return calculation(index: input, participant: participant, courseSegment: courseSegment,
                               indexBasis: handicapStrokeBasis)
                .allowedStrokes(maximum: maximumHandicap, estimateApproved: estimateApproved)
        }
    }

    static func participant(
        _ participant: RoundParticipant, applying input: Double?, format: HandicapEntryFormat,
        courseSegment: CourseSegment?, maximumHandicap: Int? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole,
        approveEstimate: Bool = false, approvedBy: String? = nil
    ) -> RoundParticipant {
        // League allowances are frozen. Commissioner overrides use the dedicated
        // round-only override API and never rewrite the original calculation.
        guard participant.leagueHandicapStrokesAtCreation == nil, participant.handicapSnapshot == nil else { return participant }
        var updated = participant
        let handicapStrokeBasis = entryIndexBasis(for: participant, configured: handicapStrokeBasis)
        let calculation = format == .courseHandicap
            ? self.calculation(index: input, participant: participant, courseSegment: courseSegment, indexBasis: handicapStrokeBasis)
            : participant.handicapResolution?.calculation
        let priorApproval = participant.handicapResolution
        let keepApproval = calculation == priorApproval?.calculation && priorApproval?.estimateApprovedAt != nil
        let approved = format == .courseHandicap && calculation?.status == .estimated && (approveEstimate || keepApproval)
        let allowance = input.flatMap { strokes(for: $0, format: format, participant: participant, courseSegment: courseSegment,
                                maximumHandicap: maximumHandicap, handicapStrokeBasis: handicapStrokeBasis,
                                estimateApproved: approved) }
        if format == .courseHandicap {
            updated.handicapIndex = input
        } else if let allowance {
            // Manual strokes do not erase an Index saved for this round.
            updated.originalHandicap = allowance
        }
        if let allowance { updated.adjustedHandicap = allowance }
        updated.handicapResolution = RoundHandicapResolution(
            entryFormat: format, calculation: calculation, effectiveStrokes: allowance,
            estimateApprovedAt: approved ? (keepApproval ? priorApproval?.estimateApprovedAt : Time()) : nil,
            approvedBy: approved ? (keepApproval ? priorApproval?.approvedBy : approvedBy) : nil,
            manualStrokes: input.flatMap { value in
                format == .strokes && value.isFinite && value >= 0 && value < Double(Int.max)
                    ? Int(value.rounded()) : nil
            } ?? priorApproval?.manualStrokeInput
        )
        return updated
    }

    static func recomputedParticipants(
        _ participants: [RoundParticipant], format: HandicapEntryFormat, courseSegment: CourseSegment?,
        maximumHandicap: Int? = nil, handicapStrokeBasis: SeriesHandicapStrokeBasis? = nil,
        changingEntryFormat: Bool = false
    ) -> [RoundParticipant] {
        participants.map { participant in
            guard participant.leagueHandicapStrokesAtCreation == nil, participant.handicapSnapshot == nil else { return participant }
            if changingEntryFormat, format == .strokes {
                var pending = participant
                let manual = participant.handicapResolution?.manualStrokeInput
                pending.handicapResolution = RoundHandicapResolution(entryFormat: .strokes,
                    calculation: participant.handicapResolution?.calculation,
                    effectiveStrokes: manual.map { capped($0, maximumHandicap: maximumHandicap) }, manualStrokes: manual)
                if let strokes = pending.handicapResolution?.effectiveStrokes { pending.adjustedHandicap = strokes }
                return pending
            }
            // A manual allowance is independent of changes to the selected tee.
            guard (changingEntryFormat || participant.handicapResolution?.entryFormat != .strokes),
                  format == .courseHandicap else { return participant }
            guard let index = participant.handicapIndex else {
                var unresolved = participant
                unresolved.handicapResolution = RoundHandicapResolution(
                    entryFormat: .courseHandicap,
                    calculation: calculation(index: nil, participant: participant, courseSegment: courseSegment, indexBasis: handicapStrokeBasis),
                    effectiveStrokes: nil, manualStrokes: participant.handicapResolution?.manualStrokeInput
                )
                return unresolved
            }
            return self.participant(participant, applying: index, format: format, courseSegment: courseSegment,
                                    maximumHandicap: maximumHandicap, handicapStrokeBasis: handicapStrokeBasis ?? participant.handicapResolution?.calculation?.indexBasis)
        }
    }

    static func isReady(_ participant: RoundParticipant, format: HandicapEntryFormat,
                        courseSegment: CourseSegment?, indexBasis: SeriesHandicapStrokeBasis?) -> Bool {
        if participant.leagueHandicapStrokesAtCreation != nil || participant.handicapSnapshot != nil { return true }
        if let resolution = participant.handicapResolution {
            if resolution.entryFormat == .strokes { return resolution.effectiveStrokes != nil }
            let current = calculation(index: participant.handicapIndex, participant: participant, courseSegment: courseSegment, indexBasis: indexBasis ?? resolution.calculation?.indexBasis)
            return current == resolution.calculation && resolution.effectiveStrokes != nil
                && (current.status == .exact || (current.status == .estimated && resolution.estimateApprovedAt != nil))
        }
        return format == .strokes
    }

    static func courseHandicapIndexBasis(_ index: Double, inputBasis: SeriesHandicapStrokeBasis, segment: HoleSegment) -> Double {
        let targetBasis: SeriesHandicapStrokeBasis = segment.holeCount <= 9 ? .nineHole : .eighteenHole
        switch (inputBasis, targetBasis) {
        case (.eighteenHole, .nineHole): return (index / 2.0 * 10).rounded() / 10
        case (.nineHole, .eighteenHole): return index * 2.0
        case (.nineHole, .nineHole), (.eighteenHole, .eighteenHole): return index
        }
    }

    static func normalizedParticipantsForField(_ participants: [RoundParticipant]) -> [RoundParticipant] {
        let active = participants.filter(\.isPresenceActive)
        let baseline = active.map(\.adjustedHandicap).min() ?? 0
        return participants.map { normalized($0, subtracting: baseline) }
    }

    static func normalizedParticipants(
        _ participants: [RoundParticipant],
        for matchup: TeamMatchup,
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup]
    ) -> [RoundParticipant] {
        let participantIDs = participantIDs(in: matchup, participants: participants, teams: teams, scoringGroups: scoringGroups)
        let baseline = participants
            .filter { participantIDs.contains($0.id) && $0.isPresenceActive }
            .map(\.adjustedHandicap)
            .min() ?? 0

        return participants.map { participant in
            guard participantIDs.contains(participant.id) else { return participant }
            return normalized(participant, subtracting: baseline)
        }
    }

    static func participantIDs(
        in matchup: TeamMatchup,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup]
    ) -> Set<String> {
        switch matchup.effectiveMode {
        case .individual:
            return Set(matchup.participantIDs ?? [])
        case .team:
            let teamIDs = Set(matchup.teamIDs)
            return Set(participants.filter { $0.teamID.map(teamIDs.contains) == true }.map(\.id))
        case .partnership, .teeGroup, .scoreOwner:
            let groupByID = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })
            return Set(matchup.pairingIDs().flatMap { groupByID[$0]?.memberIDs ?? [] })
        }
    }

    private static func normalized(_ participant: RoundParticipant, subtracting baseline: Int) -> RoundParticipant {
        var updated = participant
        updated.adjustedHandicap = max(0, participant.adjustedHandicap - baseline)
        return updated
    }

    private static func tee(for participant: RoundParticipant, in courseSegment: CourseSegment) -> Tee? {
        if participant.teeBoxID.isPopulated {
            return courseSegment.tee(from: participant.teeBoxID)
        }
        if let defaultTeeID = courseSegment.defaultTee, let tee = courseSegment.tee(from: defaultTeeID) {
            return tee
        }
        return nil
    }

    private static func capped(_ value: Int, maximumHandicap: Int?) -> Int {
        let nonNegative = max(0, value)
        guard let maximumHandicap else { return nonNegative }
        return min(nonNegative, maximumHandicap)
    }
}

enum ParticipantScoreCompleteness: Equatable {
    case complete(scored: Int)
    case incomplete(scored: Int, required: Int)
    case noScores(required: Int)

    var isComplete: Bool {
        if case .complete = self { return true }
        return false
    }

    var scoredCount: Int {
        switch self {
        case .complete(let scored), .incomplete(let scored, _):
            return scored
        case .noScores:
            return 0
        }
    }

    var requiredCount: Int {
        switch self {
        case .complete(let scored):
            return scored
        case .incomplete(_, let required), .noScores(let required):
            return required
        }
    }

    var reviewChipTitle: String? {
        switch self {
        case .complete:
            return nil
        case .incomplete:
            return "Incomplete scores"
        case .noScores:
            return "No scores"
        }
    }

    var outcomeStatusTitle: String? {
        switch self {
        case .complete:
            return nil
        case .incomplete:
            return "Incomplete"
        case .noScores:
            return "No scores"
        }
    }
}

enum RoundScoreCompleteness {
    static func classify(participantID: String, snapshot: RoundSnapshot) -> ParticipantScoreCompleteness {
        let holeNumbers = snapshot.roundSegment?.holeRange.holeNumbers ?? snapshot.holeSegment.holeRange.holeNumbers
        return classify(
            participantID: participantID,
            scores: snapshot.scoring,
            holeNumbers: holeNumbers,
            holes: snapshot.defaultTee?.holes ?? [],
            scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs
        )
    }

    static func classify(
        participantID: String,
        scores: [ScoreEntry],
        holeNumbers: [Int],
        holes: [Hole],
        scoreLookupSegmentIDs: [String] = []
    ) -> ParticipantScoreCompleteness {
        let required = holeNumbers.count
        guard required > 0 else { return .noScores(required: 0) }

        let holeMap = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        let segmentIDs = Set(scoreLookupSegmentIDs.filter(\.isPopulated))
        var validScoreCount = 0
        var hasAnyScoreEntry = false

        for holeNumber in holeNumbers {
            let entry = scores.first { entry in
                entry.scoringUnitID == participantID
                    && entry.holeNumber == holeNumber
                    && (segmentIDs.isEmpty || segmentIDs.contains(entry.segmentID))
            }
            guard let entry else { continue }

            if entry.hasRecordedScore {
                hasAnyScoreEntry = true
            }
            if validGrossStrokes(entry: entry, par: holeMap[holeNumber]?.par) != nil {
                validScoreCount += 1
            }
        }

        if validScoreCount == required {
            return .complete(scored: validScoreCount)
        }
        if hasAnyScoreEntry {
            return .incomplete(scored: validScoreCount, required: required)
        }
        return .noScores(required: required)
    }

    static func validGrossStrokes(entry: ScoreEntry, par: Int?) -> Int? {
        if let strokes = entry.strokes, strokes > 0 {
            return strokes
        }
        if let relativeToPar = entry.relativeToPar,
           let par,
           par > 0 {
            let strokes = par + relativeToPar
            return strokes > 0 ? strokes : nil
        }
        return nil
    }
}

enum CourseHandicapRosterDisplay {
    static func entryFormat(for participant: RoundParticipant, defaultFormat: HandicapEntryFormat) -> HandicapEntryFormat {
        participant.handicapSnapshot?.entryFormat ?? participant.handicapResolution?.entryFormat ?? defaultFormat
    }

    static func label(
        participant: RoundParticipant, courseSegment: CourseSegment?,
        handicapStrokeBasis: SeriesHandicapStrokeBasis?, defaultTee: Tee?, tees: [Tee],
        maximumHandicap: Int?, allowOriginalHandicapFallback: Bool = false,
        previewCurrentSelection: Bool = false
    ) -> String? {
        if let snapshot = participant.handicapSnapshot {
            guard let calculation = snapshot.calculation, snapshot.entryFormat == .courseHandicap else {
                return "Strokes Received: \(participant.lockedHandicapAllowance) (saved allowance)"
            }
            return description(calculation, strokes: participant.lockedHandicapAllowance)
        }
        if let resolution = participant.handicapResolution {
            if resolution.entryFormat == .strokes {
                return resolution.effectiveStrokes.map { "Strokes Received: \($0) (manual)" } ?? "Enter strokes for this round"
            }
            // Lobby course changes arrive before asynchronous participant writes.
            // Preview that selection without changing saved scoring allowances.
            // Other callers retain the stored calculation for historical rounds.
            if previewCurrentSelection, participant.leagueHandicapStrokesAtCreation == nil {
                guard let index = participant.handicapIndex else { return "Course HCP: Unavailable" }
                let basis = HandicapCalculator.entryIndexBasis(
                    for: participant, configured: handicapStrokeBasis ?? resolution.calculation?.indexBasis
                )
                let current = HandicapCalculator.calculation(
                    index: index, participant: participant, courseSegment: courseSegment, indexBasis: basis
                )
                let strokes = current == resolution.calculation
                    ? resolution.effectiveStrokes
                    : current.allowedStrokes(maximum: maximumHandicap)
                return description(current, strokes: strokes)
            }
            if let calculation = resolution.calculation { return description(calculation, strokes: resolution.effectiveStrokes) }
        }
        // Integer legacy handicaps have no verified Index meaning or basis.
        guard let index = participant.handicapIndex else { return nil }
        return label(index: index, participant: participant, courseSegment: courseSegment,
                     handicapStrokeBasis: handicapStrokeBasis, defaultTee: defaultTee, tees: tees, maximumHandicap: maximumHandicap)
    }

    static func label(
        index: Double, participant: RoundParticipant, courseSegment: CourseSegment?,
        handicapStrokeBasis: SeriesHandicapStrokeBasis?, defaultTee: Tee?, tees: [Tee], maximumHandicap: Int?
    ) -> String? {
        let calculation = HandicapCalculator.calculation(index: index, participant: participant,
            courseSegment: courseSegment, indexBasis: handicapStrokeBasis)
        var label = description(calculation, strokes: calculation.allowedStrokes(maximum: maximumHandicap))
        if let defaultTee, participant.teeBoxID != defaultTee.id,
           let participantTee = tees.first(where: { $0.id == participant.teeBoxID }) {
            label += " (\(participantTee.name) tees)"
        }
        return label
    }

    static func description(_ calculation: CourseHandicapCalculation, strokes: Int?) -> String {
        guard let raw = calculation.courseHandicap else { return "Course HCP: Unavailable" }
        let title = calculation.status == .estimated ? "Estimated Course HCP" : "Course HCP"
        let allowance = strokes.map { " · Strokes Received: \($0)" } ?? " · Confirmation required"
        return "\(title): \(raw)\(allowance)"
    }
}
