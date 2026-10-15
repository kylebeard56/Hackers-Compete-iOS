import Foundation

enum HandicapIndexEntry {
    /// Round editors use signed numeric values; negative denotes a plus handicap.
    static func filtered(_ text: String) -> String {
        var output = ""
        var hasDecimal = false
        var decimalPlaces = 0
        for character in text {
            if character.isASCII && character.isNumber {
                if hasDecimal {
                    guard decimalPlaces < 1 else { continue }
                    decimalPlaces += 1
                }
                output.append(character)
            } else if character == "-", output.isEmpty {
                output.append(character)
            } else if (character == "." || character == ","), !hasDecimal {
                hasDecimal = true
                output.append(".")
            }
        }
        return output
    }
}

enum PersonalHandicapSource: String, Codable {
    case manual
    case external
    case calculated

    var title: String {
        switch self {
        case .manual: return "Manual starting"
        case .external: return "GHIN / USGA · entered manually"
        case .calculated: return "Hackers calculated"
        }
    }
}

enum PersonalHandicapError: Error, LocalizedError {
    case invalidIndex, notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidIndex: return "Enter a valid Handicap Index with up to one decimal place."
        case .notAuthorized: return "Only the player can edit a registered profile. Reusable offline players can be managed by signed-in players."
        }
    }
}

struct ManualPersonalHandicap: Hashable, Codable {
    let value: Double
    let source: PersonalHandicapSource
    let updatedAt: Time
    /// A personal Index always describes 18 holes, including when playing nine.
    var basis: SeriesHandicapStrokeBasis { .eighteenHole }

    init(value: Double, source: PersonalHandicapSource, updatedAt: Time = .init()) throws {
        guard value.isFinite, (value * 10).isFinite, source != .calculated else {
            throw PersonalHandicapError.invalidIndex
        }
        self.value = (value * 10).rounded() / 10
        self.source = source
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case value, source, basis; case updatedAt = "updated_at" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let basis = try c.decode(SeriesHandicapStrokeBasis.self, forKey: .basis)
        guard basis == .eighteenHole else { throw PersonalHandicapError.invalidIndex }
        try self.init(value: c.decode(Double.self, forKey: .value),
                      source: c.decode(PersonalHandicapSource.self, forKey: .source),
                      updatedAt: c.decode(Time.self, forKey: .updatedAt))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(value, forKey: .value)
        try c.encode(source, forKey: .source)
        try c.encode(basis, forKey: .basis)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    /// Blank means unavailable. A leading '+' uses golf's plus-handicap notation.
    static func parse(_ text: String, source: PersonalHandicapSource, updatedAt: Time = .init()) throws -> Self? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        let pattern = "^[+-]?[0-9]+(?:\\.[0-9])?$"
        guard normalized.range(of: pattern, options: .regularExpression) != nil,
              let number = Double(normalized) else { throw PersonalHandicapError.invalidIndex }
        return try .init(value: normalized.hasPrefix("+") ? -abs(number) : number, source: source, updatedAt: updatedAt)
    }

    static func display(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return value < 0 ? String(format: "+%.1f", abs(value)) : String(format: "%.1f", value)
    }
}

/// Calculation output contract, independent of the policy that produces it.
/// No producer is enabled until the personal calculation policy is approved.
struct PersonalHandicapCalculation: Hashable, Codable {
    enum Status: String, Codable { case collecting, qualified }
    var index: Double?
    var status: Status
    var asOf: Time
    var methodVersion: String
    var qualifyingScoreIDs: [String]
    var qualifyingHoles: Int
    var requiredHoles: Int?
    var poolScoreIDs: [String]
    var countingScoreIDs: [String]
    var basis: SeriesHandicapStrokeBasis = .eighteenHole

    var qualifiedIndex: Double? {
        guard status == .qualified, basis == .eighteenHole, let index, index.isFinite, !methodVersion.isEmpty else { return nil }
        return index
    }

    enum CodingKeys: String, CodingKey {
        case index, status, basis
        case asOf = "as_of", methodVersion = "method_version"
        case qualifyingScoreIDs = "qualifying_score_ids", qualifyingHoles = "qualifying_holes"
        case requiredHoles = "required_holes", poolScoreIDs = "pool_score_ids", countingScoreIDs = "counting_score_ids"
    }
}

struct PersonalHandicapProfile: Hashable, Codable {
    var manual: ManualPersonalHandicap?
    var calculation: PersonalHandicapCalculation?

    init(manual: ManualPersonalHandicap? = nil, calculation: PersonalHandicapCalculation? = nil) {
        self.manual = manual
        self.calculation = calculation
    }

    var effectiveIndex: Double? { calculation?.qualifiedIndex ?? manual?.value }
    var effectiveSource: PersonalHandicapSource? {
        calculation?.qualifiedIndex != nil ? .calculated : manual?.source
    }

    enum CodingKeys: String, CodingKey {
        case manual, calculation
        case effectiveIndex = "effective_index", effectiveSource = "effective_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        manual = try c.decodeIfPresent(ManualPersonalHandicap.self, forKey: .manual)
        calculation = try c.decodeIfPresent(PersonalHandicapCalculation.self, forKey: .calculation)
        // Effective fields are a persisted projection, never a competing authority.
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(manual, forKey: .manual)
        try c.encodeIfPresent(calculation, forKey: .calculation)
        try c.encodeIfPresent(effectiveIndex, forKey: .effectiveIndex)
        try c.encodeIfPresent(effectiveSource, forKey: .effectiveSource)
    }
}

/// Frozen provenance of the profile input captured when a regular participant is created.
/// Subsequent profile edits never write to existing round participants.
struct RoundPersonalHandicapInput: Hashable, Codable {
    let index: Double
    let source: PersonalHandicapSource
    let sourceUpdatedAt: Time
    let capturedAt: Time
    let basis: SeriesHandicapStrokeBasis

    enum CodingKeys: String, CodingKey {
        case index, source, basis
        case sourceUpdatedAt = "source_updated_at", capturedAt = "captured_at"
    }
}

enum PersonalHandicapRoundPrefill {
    static func participant(
        _ participant: RoundParticipant, player: Player, configuration: RoundConfiguration,
        isLeagueRound: Bool, status: RoundStatus = .lobby, capturedAt: Time = .init()
    ) -> RoundParticipant {
        guard !isLeagueRound, status == .lobby, participant.seriesMemberID == nil,
              participant.leagueHandicapStrokesAtCreation == nil, participant.handicapSnapshot == nil,
              participant.handicapIndex == nil, participant.handicapResolution == nil,
              participant.personalHandicapInput == nil,
              participant.playerID == player.id,
              configuration.handicapEntryFormat == .courseHandicap,
              configuration.handicapIndexBasis == .eighteenHole else { return participant }
        var updated = participant
        let profile = player.personalHandicap
        if let index = profile?.effectiveIndex, let source = profile?.effectiveSource {
            updated.handicapIndex = index
            updated.personalHandicapInput = .init(
                index: index, source: source,
                sourceUpdatedAt: source == .calculated ? profile!.calculation!.asOf : profile!.manual!.updatedAt,
                capturedAt: capturedAt, basis: .eighteenHole
            )
        }
        // Missing Index remains nil and unresolved, including for legacy integer profiles.
        return HandicapCalculator.recomputedParticipants(
            [updated], format: .courseHandicap, courseSegment: configuration.courses.first,
            maximumHandicap: configuration.leagueHandicapMaximum, handicapStrokeBasis: .eighteenHole
        )[0]
    }
}

struct PersonalHandicapHistoryPoint: Hashable, Codable, Identifiable {
    var id: String { roundID }
    let playerID: String
    let roundID: String
    let roundTitle: String
    let playedAt: Time
    let calculation: PersonalHandicapCalculation

    enum CodingKeys: String, CodingKey {
        case calculation
        case playerID = "player_id", roundID = "round_id", roundTitle = "round_title", playedAt = "played_at"
    }
}

struct PersonalHandicapScoreRecord: Hashable, Codable, Identifiable {
    var id: String { roundID }
    let playerID: String
    let roundID: String
    let roundTitle: String
    let playedAt: Time
    let holeCount: Int
    let grossScore: Int?
    let exclusionReason: String?

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id", roundID = "round_id", roundTitle = "round_title", playedAt = "played_at"
        case holeCount = "hole_count", grossScore = "gross_score", exclusionReason = "exclusion_reason"
    }
}

enum PersonalHandicapPresentation {
    /// Only approved calculation outputs may appear on the trend. Dates tie-break by stable round ID.
    static func trend(_ points: [PersonalHandicapHistoryPoint], playerID: String) -> [PersonalHandicapHistoryPoint] {
        let matching = points.filter { $0.playerID == playerID }
        let latest = Dictionary(grouping: matching, by: \.roundID).compactMap { _, versions in
            versions.max { $0.calculation.asOf.unix < $1.calculation.asOf.unix }
        }
        return latest.filter { $0.calculation.qualifiedIndex != nil }.sorted {
            $0.playedAt.unix == $1.playedAt.unix ? $0.roundID < $1.roundID : $0.playedAt.unix < $1.playedAt.unix
        }
    }

    static func scoreStatus(_ score: PersonalHandicapScoreRecord, calculation: PersonalHandicapCalculation?) -> String {
        guard score.exclusionReason == nil, let calculation,
              calculation.qualifyingScoreIDs.contains(score.id) else { return "Unofficial" }
        if calculation.countingScoreIDs.contains(score.id) { return "Counts" }
        return calculation.poolScoreIDs.contains(score.id) ? "Pool" : "Earlier score"
    }
}

extension Player {
    func canEditPersonalHandicap(as userID: String?) -> Bool {
        guard let userID, !userID.isEmpty, !needsToBeCreated else { return false }
        return isOffline || self.userID == userID
    }

    func settingManualPersonalHandicap(_ manual: ManualPersonalHandicap?, as userID: String?, at time: Time = .init()) throws -> Player {
        guard canEditPersonalHandicap(as: userID) else { throw PersonalHandicapError.notAuthorized }
        var updated = self
        var profile = personalHandicap ?? .init()
        profile.manual = manual
        updated.personalHandicap = profile
        updated.lastUpdatedAt = time
        return updated
    }
}
