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
    static func rawCourseHandicap(
        index: Double,
        tee: Tee,
        segment: HoleSegment,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> Double? {
        guard let rating = tee.rating(for: segment),
              let slope = tee.slope(for: segment),
              slope > 0 else {
            return nil
        }

        let par = tee.par(for: segment)
        guard par > 0 else { return nil }

        let indexBasis = courseHandicapIndexBasis(
            index,
            inputBasis: handicapStrokeBasis,
            segment: segment
        )

        return max(0, indexBasis * (Double(slope) / 113.0) + (rating - Double(par)))
    }

    static func courseHandicap(
        index: Double,
        tee: Tee,
        segment: HoleSegment,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> Int? {
        rawCourseHandicap(
            index: index,
            tee: tee,
            segment: segment,
            handicapStrokeBasis: handicapStrokeBasis
        ).map { Int($0.rounded()) }
    }

    static func rawCourseHandicap(
        index: Double,
        participant: RoundParticipant,
        courseSegment: CourseSegment?,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> Double? {
        guard let courseSegment,
              let tee = tee(for: participant, in: courseSegment) else {
            return nil
        }
        return rawCourseHandicap(
            index: index,
            tee: tee,
            segment: courseSegment.holeSegment,
            handicapStrokeBasis: handicapStrokeBasis
        )
    }

    static func courseHandicap(
        index: Double,
        participant: RoundParticipant,
        courseSegment: CourseSegment?,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> Int? {
        rawCourseHandicap(
            index: index,
            participant: participant,
            courseSegment: courseSegment,
            handicapStrokeBasis: handicapStrokeBasis
        ).map { Int($0.rounded()) }
    }

    static func hasCourseHandicapData(for participant: RoundParticipant? = nil, courseSegment: CourseSegment?) -> Bool {
        guard let courseSegment else { return false }
        let tee: Tee?
        if let participant {
            tee = self.tee(for: participant, in: courseSegment)
        } else if let defaultTeeID = courseSegment.defaultTee {
            tee = courseSegment.tee(from: defaultTeeID)
        } else {
            tee = nil
        }
        guard let tee else { return false }
        return courseHandicap(index: 0, tee: tee, segment: courseSegment.holeSegment) != nil
    }

    static func strokes(
        for input: Double,
        format: HandicapEntryFormat,
        participant: RoundParticipant,
        courseSegment: CourseSegment?,
        maximumHandicap: Int? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> Int {
        let raw: Int
        switch format {
        case .strokes:
            raw = Int(input.rounded())
        case .courseHandicap:
            raw = courseHandicap(
                index: input,
                participant: participant,
                courseSegment: courseSegment,
                handicapStrokeBasis: handicapStrokeBasis
            )
                ?? Int(input.rounded())
        }
        return capped(raw, maximumHandicap: maximumHandicap)
    }

    static func participant(
        _ participant: RoundParticipant,
        applying input: Double,
        format: HandicapEntryFormat,
        courseSegment: CourseSegment?,
        maximumHandicap: Int? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> RoundParticipant {
        var updated = participant
        updated.handicapIndex = format == .courseHandicap ? input : nil
        updated.originalHandicap = capped(Int(input.rounded()), maximumHandicap: format == .strokes ? maximumHandicap : nil)
        updated.adjustedHandicap = strokes(
            for: input,
            format: format,
            participant: updated,
            courseSegment: courseSegment,
            maximumHandicap: maximumHandicap,
            handicapStrokeBasis: handicapStrokeBasis
        )
        return updated
    }

    static func recomputedParticipants(
        _ participants: [RoundParticipant],
        format: HandicapEntryFormat,
        courseSegment: CourseSegment?,
        maximumHandicap: Int? = nil,
        handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    ) -> [RoundParticipant] {
        participants.map { participant in
            let input = participant.handicapIndex ?? Double(participant.originalHandicap)
            return self.participant(
                participant,
                applying: input,
                format: format,
                courseSegment: courseSegment,
                maximumHandicap: maximumHandicap,
                handicapStrokeBasis: handicapStrokeBasis
            )
        }
    }

    private static func courseHandicapIndexBasis(
        _ index: Double,
        inputBasis: SeriesHandicapStrokeBasis,
        segment: HoleSegment
    ) -> Double {
        let targetBasis: SeriesHandicapStrokeBasis = segment.holeCount <= 9 ? .nineHole : .eighteenHole
        switch (inputBasis, targetBasis) {
        case (.eighteenHole, .nineHole):
            return (index / 2.0 * 10).rounded() / 10
        case (.nineHole, .eighteenHole):
            return index * 2.0
        case (.nineHole, .nineHole), (.eighteenHole, .eighteenHole):
            return index
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
        updated.adjustedHandicap = max(0, participant.adjustedHandicap - max(0, baseline))
        return updated
    }

    private static func tee(for participant: RoundParticipant, in courseSegment: CourseSegment) -> Tee? {
        if participant.teeBoxID.isPopulated, let tee = courseSegment.tee(from: participant.teeBoxID) {
            return tee
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
    static func label(
        participant: RoundParticipant,
        courseSegment: CourseSegment?,
        handicapStrokeBasis: SeriesHandicapStrokeBasis,
        defaultTee: Tee?,
        tees: [Tee],
        maximumHandicap: Int?,
        allowOriginalHandicapFallback: Bool = true
    ) -> String? {
        guard let index = participant.handicapIndex ?? (allowOriginalHandicapFallback ? Double(participant.originalHandicap) : nil) else {
            return nil
        }
        return label(
            index: index,
            participant: participant,
            courseSegment: courseSegment,
            handicapStrokeBasis: handicapStrokeBasis,
            defaultTee: defaultTee,
            tees: tees,
            maximumHandicap: maximumHandicap
        )
    }

    static func label(
        index: Double,
        participant: RoundParticipant,
        courseSegment: CourseSegment?,
        handicapStrokeBasis: SeriesHandicapStrokeBasis,
        defaultTee: Tee?,
        tees: [Tee],
        maximumHandicap: Int?
    ) -> String? {
        guard let rawCourseHandicap = HandicapCalculator.rawCourseHandicap(
            index: index,
            participant: participant,
            courseSegment: courseSegment,
            handicapStrokeBasis: handicapStrokeBasis
        ) else {
            return nil
        }

        let displayedCourseHandicap = maximumHandicap
            .map { min(rawCourseHandicap, Double($0)) }
            ?? rawCourseHandicap
        let capSuffix = displayedCourseHandicap < rawCourseHandicap ? "*" : ""
        let roundedCourseHandicap = Int(displayedCourseHandicap.rounded(.toNearestOrAwayFromZero))
        var label = "Course HCP: \(roundedCourseHandicap)\(capSuffix)"

        if let defaultTee,
           participant.teeBoxID != defaultTee.id,
           let participantTee = tees.first(where: { $0.id == participant.teeBoxID }) {
            label += " (\(participantTee.name) tees)"
        }

        return label
    }
}
