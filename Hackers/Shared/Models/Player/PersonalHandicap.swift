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
        case .calculated: return "Hackers Calculated Index"
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

/// Unofficial personal calculation output; never an issued GHIN Index.
struct PersonalHandicapCalculation: Hashable, Codable {
    enum Status: String, Codable { case collecting, qualified, blocked }
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

    var blockers: [String]? = nil
    var lowHandicapIndex: Double? = nil
    var inputFingerprint: String? = nil
    var retainedIndex: Double? = nil
    var retainedAsOf: Time? = nil
    /// Differential IDs count paired nines once; score IDs retain both source cards.
    var poolDifferentialIDs: [String]? = nil
    var countingDifferentialIDs: [String]? = nil
    var poolCount: Int { Set(poolDifferentialIDs ?? poolScoreIDs).count }
    var countingCount: Int { Set(countingDifferentialIDs ?? countingScoreIDs).count }

    var qualifiedIndex: Double? {
        guard status == .qualified, basis == .eighteenHole, qualifyingHoles >= 54,
              Set(qualifyingScoreIDs).count >= 3, let index, index.isFinite, index <= 54,
              !methodVersion.isEmpty, poolDifferentialIDs.map({ Set($0).count >= 3 }) != false else { return nil }
        return index
    }

    /// A newly pending conversion does not invent an update or erase a valid
    /// previously established Index. Rebuild removes this fallback on correction
    /// if no valid historical prefix remains.
    var effectiveCalculatedIndex: Double? {
        if let qualifiedIndex { return qualifiedIndex }
        guard status == .blocked, basis == .eighteenHole, !methodVersion.isEmpty, qualifyingHoles >= 54, Set(qualifyingScoreIDs).count >= 3,
              let retainedIndex, retainedIndex.isFinite, retainedIndex <= 54, retainedAsOf != nil else { return nil }
        return retainedIndex
    }
    var effectiveCalculatedAt: Time { qualifiedIndex != nil ? asOf : retainedAsOf ?? asOf }

    enum CodingKeys: String, CodingKey {
        case index, status, basis, blockers
        case calculationPending = "calculation_pending"
        case lowHandicapIndex = "low_handicap_index"
        case inputFingerprint = "input_fingerprint"
        case retainedIndex = "retained_index", retainedAsOf = "retained_as_of"
        case asOf = "as_of", methodVersion = "method_version"
        case qualifyingScoreIDs = "qualifying_score_ids", qualifyingHoles = "qualifying_holes"
        case requiredHoles = "required_holes", poolScoreIDs = "pool_score_ids", countingScoreIDs = "counting_score_ids"
        case poolDifferentialIDs = "pool_differential_ids", countingDifferentialIDs = "counting_differential_ids"
    }
}

/// A nil manual is an explicit removal, not an absent historical record.
struct PersonalHandicapManualRevision: Hashable, Codable {
    let manual: ManualPersonalHandicap?
    let effectiveAt: Time

    enum CodingKeys: String, CodingKey { case manual; case effectiveAt = "effective_at" }
}

struct PersonalHandicapProfile: Hashable, Codable {
    var manual: ManualPersonalHandicap?
    var calculation: PersonalHandicapCalculation?
    var manualHistory: [PersonalHandicapManualRevision]?

    init(manual: ManualPersonalHandicap? = nil, calculation: PersonalHandicapCalculation? = nil,
         manualHistory: [PersonalHandicapManualRevision]? = nil) {
        self.manual = manual
        self.calculation = calculation
        self.manualHistory = manualHistory
    }

    func manualEffective(at date: Time) -> ManualPersonalHandicap? {
        // Last event wins at equal timestamps, including an explicit removal.
        let event = (manualHistory ?? []).enumerated().filter { $0.element.effectiveAt.unix <= date.unix }.max {
            $0.element.effectiveAt.unix == $1.element.effectiveAt.unix
                ? $0.offset < $1.offset : $0.element.effectiveAt.unix < $1.element.effectiveAt.unix
        }?.element
        if let event { return event.manual }
        return manual.flatMap { $0.updatedAt.unix <= date.unix ? $0 : nil }
    }

    func settingManual(_ input: ManualPersonalHandicap?, at time: Time) throws -> Self {
        guard manual?.value != input?.value || manual?.source != input?.source else { return self }
        var result = self
        var revisions = manualHistory ?? []
        // Seed the known legacy input before its first edit. Never guess an older one.
        if revisions.isEmpty, let manual { revisions.append(.init(manual: manual, effectiveAt: manual.updatedAt)) }
        result.manual = try input.map { try .init(value: $0.value, source: $0.source, updatedAt: time) }
        revisions.append(.init(manual: result.manual, effectiveAt: time))
        result.manualHistory = revisions
        return result
    }

    var effectiveIndex: Double? { calculation?.effectiveCalculatedIndex ?? manual?.value }
    var effectiveSource: PersonalHandicapSource? {
        calculation?.effectiveCalculatedIndex != nil ? .calculated : manual?.source
    }

    enum CodingKeys: String, CodingKey {
        case manual, calculation
        case manualHistory = "manual_history"
        case effectiveIndex = "effective_index", effectiveSource = "effective_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        manual = try c.decodeIfPresent(ManualPersonalHandicap.self, forKey: .manual)
        calculation = try c.decodeIfPresent(PersonalHandicapCalculation.self, forKey: .calculation)
        manualHistory = try c.decodeIfPresent([PersonalHandicapManualRevision].self, forKey: .manualHistory)
        // Effective fields are a persisted projection, never a competing authority.
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(manual, forKey: .manual)
        try c.encodeIfPresent(calculation, forKey: .calculation)
        try c.encodeIfPresent(manualHistory, forKey: .manualHistory)
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
                sourceUpdatedAt: source == .calculated ? profile!.calculation!.effectiveCalculatedAt : profile!.manual!.updatedAt,
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

enum PersonalHandicapDifferentialMethod: String, Codable {
    case eighteenHole = "eighteen_hole"
    case pairedNineEstimate = "hackers_paired_nine_estimate"
    case expectedNineEstimate = "hackers_expected_nine_estimate"
    case verifiedExternal = "verified_external"

    var isEstimated: Bool { self == .pairedNineEstimate || self == .expectedNineEstimate }
    var title: String {
        switch self {
        case .eighteenHole: return "Exact 18-hole differential"
        case .pairedNineEstimate: return "Estimated · paired nines"
        case .expectedNineEstimate: return "Estimated · expected nine"
        case .verifiedExternal: return "Externally supplied differential"
        }
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
    var exclusionReason: String?
    var pendingReason: String? = nil
    var qualifyingHoles: Int? = nil
    var adjustedGrossScore: Int? = nil
    var pcc: PersonalHandicapPCC? = nil
    var playedDifferential: Double? = nil
    var differential: Double? = nil
    var personalIndexAtPlay: Double? = nil
    var personalIndexProvenance: String? = nil
    var sourceFingerprint: String? = nil
    var postingPurpose: PersonalHandicapRoundPurpose? = nil
    var partialReason: String? = nil
    var sourceCollection: String? = nil
    var playedAtSource: String? = nil
    var courseID: String? = nil
    var courseName: String? = nil
    var teeID: String? = nil
    var teeName: String? = nil
    var courseRating: Double? = nil
    var slopeRating: Int? = nil
    var coursePar: Int? = nil
    var differentialID: String? = nil
    var differentialRoundIDs: [String]? = nil
    var differentialMethod: PersonalHandicapDifferentialMethod? = nil
    var differentialMethodVersion: String? = nil
    /// Unrounded estimate and chronological calculated Index used, never a manual Index.
    var expectedNineDifferential: Double? = nil
    var expectedScoreIndex: Double? = nil
    /// Bounded model input; expectedScoreIndex retains the actual pre-round Index.
    var expectedScoreModelIndex: Double? = nil

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id", roundID = "round_id", roundTitle = "round_title", playedAt = "played_at"
        case holeCount = "hole_count", grossScore = "gross_score", exclusionReason = "exclusion_reason"
        case pendingReason = "pending_reason"
        case qualifyingHoles = "qualifying_holes", adjustedGrossScore = "adjusted_gross_score", pcc
        case playedDifferential = "played_differential", differential
        case personalIndexProvenance = "personal_index_provenance"
        case personalIndexAtPlay = "personal_index_at_play", sourceFingerprint = "source_fingerprint"
        case postingPurpose = "posting_purpose", partialReason = "partial_reason", sourceCollection = "source_collection"
        case playedAtSource = "played_at_source"
        case courseID = "course_id", courseName = "course_name", teeID = "tee_id", teeName = "tee_name"
        case courseRating = "course_rating", slopeRating = "slope_rating", coursePar = "course_par"
        case differentialID = "differential_id", differentialRoundIDs = "differential_round_ids"
        case differentialMethod = "differential_method", differentialMethodVersion = "differential_method_version"
        case expectedNineDifferential = "expected_nine_differential", expectedScoreIndex = "expected_score_index"
        case expectedScoreModelIndex = "expected_score_model_index"
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
        if score.exclusionReason != nil { return "Unofficial" }
        if score.pendingReason != nil { return "Pending" }
        guard let calculation,
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
        let previous = personalHandicap ?? .init()
        let profile = try previous.settingManual(manual, at: time)
        guard previous != profile else { return self }
        updated.personalHandicap = profile
        updated.lastUpdatedAt = time
        return updated
    }
}

extension PersonalHandicapCalculation {
    /// The first Sandbox PR #15 build only knows collecting/qualified. Keep the
    /// wire status readable by that client while preserving pending state here.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index = try c.decodeIfPresent(Double.self, forKey: .index)
        let raw = try c.decode(String.self, forKey: .status)
        let pending = try c.decodeIfPresent(Bool.self, forKey: .calculationPending) ?? false
        status = pending ? .blocked : Status(rawValue: raw) ?? .collecting
        asOf = try c.decode(Time.self, forKey: .asOf)
        methodVersion = try c.decode(String.self, forKey: .methodVersion)
        qualifyingScoreIDs = try c.decode([String].self, forKey: .qualifyingScoreIDs)
        qualifyingHoles = try c.decode(Int.self, forKey: .qualifyingHoles)
        requiredHoles = try c.decodeIfPresent(Int.self, forKey: .requiredHoles)
        poolScoreIDs = try c.decode([String].self, forKey: .poolScoreIDs)
        countingScoreIDs = try c.decode([String].self, forKey: .countingScoreIDs)
        poolDifferentialIDs = try c.decodeIfPresent([String].self, forKey: .poolDifferentialIDs)
        countingDifferentialIDs = try c.decodeIfPresent([String].self, forKey: .countingDifferentialIDs)
        basis = try c.decode(SeriesHandicapStrokeBasis.self, forKey: .basis)
        blockers = try c.decodeIfPresent([String].self, forKey: .blockers)
        lowHandicapIndex = try c.decodeIfPresent(Double.self, forKey: .lowHandicapIndex)
        inputFingerprint = try c.decodeIfPresent(String.self, forKey: .inputFingerprint)
        retainedIndex = try c.decodeIfPresent(Double.self, forKey: .retainedIndex)
        retainedAsOf = try c.decodeIfPresent(Time.self, forKey: .retainedAsOf)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(index, forKey: .index)
        try c.encode(status == .blocked ? Status.collecting : status, forKey: .status)
        if status == .blocked { try c.encode(true, forKey: .calculationPending) }
        try c.encode(asOf, forKey: .asOf)
        try c.encode(methodVersion, forKey: .methodVersion)
        try c.encode(qualifyingScoreIDs, forKey: .qualifyingScoreIDs)
        try c.encode(qualifyingHoles, forKey: .qualifyingHoles)
        try c.encodeIfPresent(requiredHoles, forKey: .requiredHoles)
        try c.encode(poolScoreIDs, forKey: .poolScoreIDs)
        try c.encode(countingScoreIDs, forKey: .countingScoreIDs)
        try c.encodeIfPresent(poolDifferentialIDs, forKey: .poolDifferentialIDs)
        try c.encodeIfPresent(countingDifferentialIDs, forKey: .countingDifferentialIDs)
        try c.encode(basis, forKey: .basis)
        try c.encodeIfPresent(blockers, forKey: .blockers)
        try c.encodeIfPresent(lowHandicapIndex, forKey: .lowHandicapIndex)
        try c.encodeIfPresent(inputFingerprint, forKey: .inputFingerprint)
        try c.encodeIfPresent(retainedIndex, forKey: .retainedIndex)
        try c.encodeIfPresent(retainedAsOf, forKey: .retainedAsOf)
    }
}
