import CryptoKit
import Foundation

struct PersonalHandicapPCC: Hashable, Codable {
    enum Verification: String, Codable { case assumed, verified }
    let value: Double
    let verification: Verification
    let source: String

    static let assumedZero = Self(value: 0, verification: .assumed, source: "Hackers assumption: official PCC unavailable")
    var isValid: Bool {
        [-1.0, 0, 1, 2, 3].contains(value) && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (verification == .verified || value == 0)
    }
    var title: String { "PCC \(String(format: "%g", value)) · \(verification.rawValue)" }
}

struct PersonalHandicapHole {
    let number: Int
    let par: Int
    let strokeIndex: Int
    let gross: Int
}

struct PersonalHandicapCard {
    let holes: [PersonalHandicapHole]
    let intendedHoles: Int
    let rating: Double
    let slope: Int
    let par: Int
    let pcc: PersonalHandicapPCC
    let frozenPersonalIndex: Double?
    let partialReason: String?
    /// A complete rated nine from an otherwise partial 18-hole card.
    let initialNine: PersonalHandicapCardNine?
}

struct PersonalHandicapCardNine {
    let holes: [PersonalHandicapHole]
    let rating: Double
    let slope: Int
}

extension PersonalHandicapCard {
    func assessed(index: Double?) throws -> (gross: Int, played: Double?, differential: Double?, qualifyingHoles: Int, pending: String?) {
        guard pcc.isValid else { throw PersonalHandicapRules.InputError.invalidInput }
        let isPartial = holes.count != intendedHoles
        if isPartial, index == nil {
            guard let nine = initialNine else { throw PersonalHandicapRules.InputError.invalidInput }
            let adjusted = nine.holes.reduce(0) { $0 + min($1.gross, $1.par + 5) }
            let played = try PersonalHandicapRules.playedDifferential(adjustedGross: adjusted, rating: nine.rating, slope: nine.slope, holes: 9, pcc: pcc.value)
            return (adjusted, played, nil, 9, "Initial partial round: rated nine retained; expected-score conversion unavailable")
        }
        if index != nil {
            guard holes.allSatisfy({ (1...18).contains($0.strokeIndex) }),
                  Set(holes.map(\.strokeIndex)).count == holes.count else { throw PersonalHandicapRules.InputError.invalidInput }
        }
        // Use the unrestricted PERSONAL Course Handicap, never the league's
        // playing allowance, competition cap, normalized strokes, or integer legacy value.
        let basisIndex = intendedHoles == 9 ? index.map { PersonalHandicapRules.tenth($0 / 2) } : index
        var courseHandicap = 0
        if let basisIndex {
            let scaledIndex: Double = basisIndex * (Double(slope) / 113.0)
            let raw: Double = scaledIndex + rating - Double(par)
            guard raw.isFinite, raw > Double(Int.min), raw < Double(Int.max) else { throw PersonalHandicapRules.InputError.invalidInput }
            courseHandicap = Int(floor(raw + 0.5))
        }
        let ordered = holes.sorted { $0.strokeIndex < $1.strokeIndex }
        let ranks: [Int: Int]
        if intendedHoles == 9 {
            ranks = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.number, $0.offset + 1) })
        } else { ranks = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0.strokeIndex) }) }
        var adjusted = 0
        for hole in holes {
            let rank = ranks[hole.number]!
            let magnitude = abs(courseHandicap)
            let quotient = magnitude / intendedHoles
            let remainder = magnitude % intendedHoles
            let strokes = courseHandicap >= 0
                ? quotient + (rank <= remainder ? 1 : 0)
                : -(quotient + (rank > intendedHoles - remainder ? 1 : 0))
            // The helper only needs the >54 threshold. Avoid multiplying an
            // untrusted legacy numeric input while retaining nine-hole equivalence.
            let limitBasis = intendedHoles == 9 && courseHandicap > 27 ? 55 : courseHandicap
            let maximum = PersonalHandicapRules.maximumHoleScore(par: hole.par, establishedIndex: index != nil,
                unrestrictedCourseHandicap: limitBasis, strokes: strokes)
            guard maximum > 0 else { throw PersonalHandicapRules.InputError.invalidInput }
            adjusted += min(hole.gross, maximum)
        }
        if isPartial {
            return (adjusted, nil, nil, holes.count, "Partial round: expected-score normalization for unplayed holes unavailable")
        }
        let played = try PersonalHandicapRules.playedDifferential(adjustedGross: adjusted, rating: rating, slope: slope, holes: intendedHoles, pcc: pcc.value)
        if intendedHoles == 9 {
            return (adjusted, played, nil, 9, "Nine-hole score retained; USGA expected-score input unavailable")
        }
        return (adjusted, played, played, 18, nil)
    }
}

enum PersonalHandicapFingerprint {
    static func hash(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct SnapshotInput: Encodable {
        let round: Round
        let participants: [RoundParticipant]
        let segments: [RoundSegment]
        let scores: [ScoreEntry]
    }

    static func snapshot(_ snapshot: RoundSnapshot) -> String {
        hash(SnapshotInput(round: snapshot.round, participants: snapshot.participants.sorted { $0.id < $1.id },
            segments: snapshot.segments.sorted { $0.id < $1.id }, scores: snapshot.scoring.sorted { $0.id < $1.id }))
    }
}


enum PersonalHandicapRefreshError: Error { case superseded }

enum PersonalHandicapPersistence {
    static func applying(_ calculation: PersonalHandicapCalculation, to player: Player) -> Player {
        var updated = player
        var profile = player.personalHandicap ?? .init()
        profile.calculation = calculation
        updated.personalHandicap = profile
        return updated
    }

    static func sameHistory(_ lhs: PersonalHandicapHistoryPoint, _ rhs: PersonalHandicapHistoryPoint) -> Bool {
        var l = lhs.calculation, r = rhs.calculation
        l.asOf = .init(iso: "", unix: 0); r.asOf = l.asOf
        l.inputFingerprint = nil; r.inputFingerprint = nil
        return lhs.playerID == rhs.playerID && lhs.roundID == rhs.roundID && lhs.playedAt == rhs.playedAt
            && lhs.roundTitle == rhs.roundTitle && l == r
    }
}
