//
//  Round+Participant.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

/// The uncapped calculation for one Index, tee and segment. None of these values
/// are playing allowances; normalization and game allowances happen downstream.
struct CourseHandicapCalculation: Hashable, Codable {
    enum Status: String, Codable {
        case exact = "EXACT"
        case estimated = "ESTIMATED"
        case unavailable = "UNAVAILABLE"
    }

    enum Provenance: String, Codable {
        case segment
        case fullCourse = "full_course"
        case estimatedFromFullCourse = "estimated_from_full_course"
    }

    var status: Status = .unavailable
    var handicapIndex: Double?
    var indexBasis: SeriesHandicapStrokeBasis?
    var calculationIndex: Double?
    var teeID: String?
    var segment: HoleSegment?
    var rating: Double?
    var slope: Int?
    var par: Int?
    var ratingProvenance: Provenance?
    var slopeProvenance: Provenance?
    var parProvenance: Provenance?
    var rawValue: Double?
    var courseHandicap: Int?
    var missingFields: [String] = []

    enum CodingKeys: String, CodingKey {
        case status, segment, rating, slope, par
        case handicapIndex = "handicap_index"
        case indexBasis = "index_basis"
        case calculationIndex = "calculation_index"
        case teeID = "tee_id"
        case ratingProvenance = "rating_provenance"
        case slopeProvenance = "slope_provenance"
        case parProvenance = "par_provenance"
        case rawValue = "raw_value"
        case courseHandicap = "course_handicap"
        case missingFields = "missing_fields"
    }

    func allowedStrokes(maximum: Int?, estimateApproved: Bool = false) -> Int? {
        guard status == .exact || (status == .estimated && estimateApproved),
              let courseHandicap else { return nil }
        let nonNegative = max(0, courseHandicap)
        return maximum.map { min(nonNegative, max(0, $0)) } ?? nonNegative
    }
}

/// Round-local resolution, including unresolved drafts. Optional on old records:
/// absence never asserts that a historical allowance was an exact calculation.
struct RoundHandicapResolution: Hashable, Codable {
    var entryFormat: HandicapEntryFormat
    var calculation: CourseHandicapCalculation?
    var effectiveStrokes: Int?
    var estimateApprovedAt: Time?
    var approvedBy: String?
    /// Explicit manual input, retained independently when switching back to Index entry.
    var manualStrokes: Int? = nil

    /// Existing explicit strokes remain reusable without treating a calculated allowance as manual input.
    var manualStrokeInput: Int? {
        manualStrokes ?? (entryFormat == .strokes ? effectiveStrokes : nil)
    }

    enum CodingKeys: String, CodingKey {
        case calculation
        case entryFormat = "entry_format"
        case effectiveStrokes = "effective_strokes"
        case estimateApprovedAt = "estimate_approved_at"
        case approvedBy = "approved_by"
        case manualStrokes = "manual_strokes"
    }
}

enum RoundParticipantPresenceStatus: String, Codable, CaseIterable {
    case active
    case unconfirmed
    case noShow = "no_show"
}

enum RoundParticipantHandicapSnapshotSource: String, Codable {
    case league
    case commissionerRepair = "commissioner_repair"
}

/// Immutable inputs used to seed a participant's handicap for one round.
/// Later score ingestion may change the member's projected handicap, but never this snapshot.
struct RoundParticipantHandicapSnapshot: Hashable, Codable {
    var authoritativeCourseHandicap: Int
    var handicapIndex: Double?
    var effectiveStrokes: Int
    var courseID: String
    var courseName: String
    var teeBoxID: String
    var teeName: String
    var teeGender: String
    var holeSegment: HoleSegment
    var courseRating: Double?
    var courseSlope: Int?
    var par: Int
    var handicapStrokeBasis: SeriesHandicapStrokeBasis
    var maximumHandicap: Int?
    var entryFormat: HandicapEntryFormat
    var calculatorFingerprint: String
    var selectedHandicapScoreIDs: [String]
    var calculatedAt: Time
    var source: RoundParticipantHandicapSnapshotSource
    var calculation: CourseHandicapCalculation? = nil

    enum CodingKeys: String, CodingKey {
        case par, source, calculation
        case authoritativeCourseHandicap = "authoritative_course_handicap"
        case handicapIndex = "handicap_index"
        case effectiveStrokes = "effective_strokes"
        case courseID = "course_id"
        case courseName = "course_name"
        case teeBoxID = "tee_box_id"
        case teeName = "tee_name"
        case teeGender = "tee_gender"
        case holeSegment = "hole_segment"
        case courseRating = "course_rating"
        case courseSlope = "course_slope"
        case handicapStrokeBasis = "handicap_stroke_basis"
        case maximumHandicap = "maximum_handicap"
        case entryFormat = "entry_format"
        case calculatorFingerprint = "calculator_fingerprint"
        case selectedHandicapScoreIDs = "selected_handicap_score_ids"
        case calculatedAt = "calculated_at"
    }
}

// MARK: - RoundParticipant
struct RoundParticipant: FirebaseSubcollectable, Playable {
    var id: String              // unique participant ID for subcollection
    var userID: String?         // the id of the authenticated user (upstream of player profiles)
    var playerID: String?       // the id of the specific user's player profile
    
    var name: Name              // Name or value to dislay in UI
    var teeBoxID: String
    var originalHandicap: Int   // Starting, inputted handicap from user
    var adjustedHandicap: Int   // Handicap adjustment based on course and slope adjustment
    var handicapIndex: Double?  // Optional decimal index used to compute adjustedHandicap
    var personalHandicapInput: RoundPersonalHandicapInput? = nil
    /// Handicap review metadata only; changes never modify this round's strokes.
    var personalHandicapPurpose: PersonalHandicapRoundPurpose? = nil
    var personalHandicapPartialReason: String? = nil
    /// Frozen scoring allowance for this historical round. Commissioner repair
    /// may replace it together with an auditable handicap snapshot.
    var leagueHandicapStrokesAtCreation: Int?
    var handicapResolution: RoundHandicapResolution?
    var handicapSnapshot: RoundParticipantHandicapSnapshot?

    var seriesMemberID: String?
    var teamID: String?
    var groupID: String?
    var teeOrder: Int?
    var isHost: Bool
    var presenceStatus: RoundParticipantPresenceStatus?
    var isSubstitute: Bool
    var substituteForSeriesMemberID: String?
    var substituteForName: String?
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.participants.rawValue }
    
    init(
        id: String = "",
        userID: String? = nil,
        playerID: String? = nil,
        name: Name = .init(),
        teeBoxID: String = "",
        originalHandicap: Int = 0,
        adjustedHandicap: Int = 0,
        handicapIndex: Double? = nil,
        leagueHandicapStrokesAtCreation: Int? = nil,
        handicapSnapshot: RoundParticipantHandicapSnapshot? = nil,
        handicapResolution: RoundHandicapResolution? = nil,
        seriesMemberID: String? = nil,
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        presenceStatus: RoundParticipantPresenceStatus? = nil,
        isSubstitute: Bool = false,
        substituteForSeriesMemberID: String? = nil,
        substituteForName: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.userID = userID
        self.playerID = playerID
        self.name = name
        self.teeBoxID = teeBoxID
        self.originalHandicap = originalHandicap
        self.adjustedHandicap = adjustedHandicap
        self.handicapIndex = handicapIndex
        self.leagueHandicapStrokesAtCreation = leagueHandicapStrokesAtCreation
        self.handicapSnapshot = handicapSnapshot
        self.handicapResolution = handicapResolution
        self.seriesMemberID = seriesMemberID
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.presenceStatus = presenceStatus
        self.isSubstitute = isSubstitute
        self.substituteForSeriesMemberID = substituteForSeriesMemberID
        self.substituteForName = substituteForName
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    init(
        player: Player,
        teeBoxID: String = "",
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        presenceStatus: RoundParticipantPresenceStatus? = nil,
        isSubstitute: Bool = false,
        substituteForSeriesMemberID: String? = nil,
        substituteForName: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        let handicap = player.handicaps.first?.value ?? 0
        
        self.id = HackersID.string()
        self.userID = player.userID
        self.playerID = player.id
        self.name = player.name
        
        self.teeBoxID = teeBoxID
        self.originalHandicap = handicap
        self.adjustedHandicap = handicap
        self.handicapIndex = nil
        self.leagueHandicapStrokesAtCreation = nil
        self.handicapSnapshot = nil
        self.handicapResolution = nil
        self.seriesMemberID = nil
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.presenceStatus = presenceStatus
        self.isSubstitute = isSubstitute
        self.substituteForSeriesMemberID = substituteForSeriesMemberID
        self.substituteForName = substituteForName
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case playerID = "player_id"
        
        case name
        case teeBoxID = "tee_box_id"
        case originalHandicap = "original_handicap"
        case adjustedHandicap = "adjusted_handicap"
        case handicapIndex = "handicap_index"
        case personalHandicapInput = "personal_handicap_input"
        case personalHandicapPurpose = "personal_handicap_purpose"
        case personalHandicapPartialReason = "personal_handicap_partial_reason"
        case leagueHandicapStrokesAtCreation = "league_handicap_strokes_at_creation"
        case handicapSnapshot = "handicap_snapshot"
        case handicapResolution = "handicap_resolution"

        case seriesMemberID = "series_member_id"
        case teamID = "team_id"
        case groupID = "group_id"
        case teeOrder = "tee_order"
        case isHost = "is_host"
        case presenceStatus = "presence_status"
        case isSubstitute = "is_substitute"
        case substituteForSeriesMemberID = "substitute_for_series_member_id"
        case substituteForName = "substitute_for_name"
        
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
        case schema
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        userID = try c.decodeIfPresent(String.self, forKey: .userID)
        playerID = try c.decodeIfPresent(String.self, forKey: .playerID)

        name = try c.decodeIfPresent(Name.self, forKey: .name) ?? .init()
        teeBoxID = try c.decodeIfPresent(String.self, forKey: .teeBoxID) ?? ""
        originalHandicap = try c.decodeIfPresent(Int.self, forKey: .originalHandicap) ?? 0
        adjustedHandicap = try c.decodeIfPresent(Int.self, forKey: .adjustedHandicap) ?? 0
        handicapIndex = try c.decodeIfPresent(Double.self, forKey: .handicapIndex)
        personalHandicapInput = try c.decodeIfPresent(RoundPersonalHandicapInput.self, forKey: .personalHandicapInput)
        personalHandicapPurpose = try c.decodeIfPresent(PersonalHandicapRoundPurpose.self, forKey: .personalHandicapPurpose)
        personalHandicapPartialReason = try c.decodeIfPresent(String.self, forKey: .personalHandicapPartialReason)
        leagueHandicapStrokesAtCreation = try c.decodeIfPresent(Int.self, forKey: .leagueHandicapStrokesAtCreation)
        handicapResolution = try c.decodeIfPresent(RoundHandicapResolution.self, forKey: .handicapResolution)
        handicapSnapshot = try c.decodeIfPresent(RoundParticipantHandicapSnapshot.self, forKey: .handicapSnapshot)

        seriesMemberID = try c.decodeIfPresent(String.self, forKey: .seriesMemberID)
        teamID = try c.decodeIfPresent(String.self, forKey: .teamID)
        groupID = try c.decodeIfPresent(String.self, forKey: .groupID)
        teeOrder = try c.decodeIfPresent(Int.self, forKey: .teeOrder)
        isHost = try c.decodeIfPresent(Bool.self, forKey: .isHost) ?? false
        presenceStatus = try c.decodeIfPresent(RoundParticipantPresenceStatus.self, forKey: .presenceStatus)
        isSubstitute = try c.decodeIfPresent(Bool.self, forKey: .isSubstitute) ?? false
        substituteForSeriesMemberID = try c.decodeIfPresent(String.self, forKey: .substituteForSeriesMemberID)
        substituteForName = try c.decodeIfPresent(String.self, forKey: .substituteForName)

        createdAt = try c.decodeIfPresent(Time.self, forKey: .createdAt) ?? .init()
        lastUpdatedAt = try c.decodeIfPresent(Time.self, forKey: .lastUpdatedAt) ?? .init()
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID) ?? ""
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
    }
}

extension RoundParticipant {
    var isOnline: Bool { userID != nil }
    var isOffline: Bool { userID == nil }
    var resolvedPresenceStatus: RoundParticipantPresenceStatus { presenceStatus ?? .active }
    var isPresenceActive: Bool { resolvedPresenceStatus != .noShow }

    /// Computed Series allowance that can be restored after a round-local override.
    var leagueHandicapComputedBaseline: Int? {
        leagueHandicapStrokesAtCreation ?? handicapSnapshot?.effectiveStrokes
    }

    /// True when commissioner changed strokes vs series seed (commissioner-only orange hint).
    var isLeagueHandicapModifiedFromCreation: Bool {
        guard let baseline = leagueHandicapComputedBaseline else { return false }
        return adjustedHandicap != baseline
    }

    /// Returns a round-local strokes override without mutating the league calculation inputs.
    func applyingLeagueHandicapOverride(_ strokes: Int, maximum: Int) -> RoundParticipant {
        var participant = self
        participant.adjustedHandicap = min(max(strokes, 0), max(maximum, 0))
        return participant
    }

    /// Returns a participant restored to the immutable Series-computed baseline, when available.
    func restoringLeagueHandicapComputedBaseline() -> RoundParticipant? {
        guard let baseline = leagueHandicapComputedBaseline else { return nil }
        var participant = self
        participant.adjustedHandicap = baseline
        return participant
    }

    /// The allowance locked for this round. League handicap updates after activation
    /// must never alter live or historical scoring context.
    var lockedHandicapAllowance: Int {
        if isLeagueHandicapModifiedFromCreation {
            return adjustedHandicap
        }
        return handicapSnapshot?.effectiveStrokes
            ?? leagueHandicapStrokesAtCreation
            ?? adjustedHandicap
    }

    var lockedHandicapProvenance: String {
        let strokes = lockedHandicapAllowance
        if let baseline = leagueHandicapComputedBaseline, strokes != baseline {
            return "Commissioner override: Strokes Received \(strokes) (computed \(baseline))"
        }
        if handicapResolution?.entryFormat == .strokes || handicapSnapshot?.entryFormat == .strokes {
            return "Strokes Received \(strokes) (manual)"
        }
        let index = handicapSnapshot?.handicapIndex ?? handicapIndex
        let prefix = index.map { "Index \(String(format: "%.1f", $0)) · " } ?? ""
        if let calculation = handicapSnapshot?.calculation ?? handicapResolution?.calculation,
           let courseHandicap = calculation.courseHandicap {
            let title = calculation.status == .estimated ? "Estimated Course HCP" : "Course HCP"
            return "\(prefix)\(title) \(courseHandicap) · Strokes Received \(strokes)"
        }
        return "\(prefix)Strokes Received \(strokes)"
    }
}

extension RoundParticipant {
    var alphabeticName: String {
        name.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    func toPlayer() -> Player {
        .init(playable: self)
    }
}

/// Local editor buffers. Switching mode never uses a calculated allowance as input.
struct RoundHandicapEntryDraft {
    var format: HandicapEntryFormat = .strokes
    var indexText = ""
    var strokesText = ""

    init() { }

    init(participant: RoundParticipant, defaultFormat: HandicapEntryFormat) {
        format = participant.handicapResolution?.entryFormat ?? defaultFormat
        indexText = participant.handicapIndex.map { String(format: "%.1f", $0) } ?? ""
        let manual = participant.handicapResolution?.manualStrokeInput
        if let manual {
            strokesText = String(manual)
        } else if participant.handicapResolution == nil, defaultFormat == .strokes {
            strokesText = String(participant.originalHandicap)
        }
    }

    var text: String {
        get { format == .courseHandicap ? indexText : strokesText }
        set {
            if format == .courseHandicap {
                indexText = HandicapIndexEntry.filtered(newValue)
            } else {
                guard newValue.allSatisfy({ $0.isASCII && $0.isNumber }) else { return }
                strokesText = String(newValue.prefix(6))
            }
        }
    }

    var value: Double? {
        guard let value = Double(text), value.isFinite else { return nil }
        return value
    }

    func applying(to participant: RoundParticipant, courseSegment: CourseSegment?,
                  indexBasis: SeriesHandicapStrokeBasis?, maximum: Int?,
                  approveEstimate: Bool = false, approvedBy: String? = nil) -> RoundParticipant {
        guard let value else { return participant }
        var updated = participant
        // Keep an edited Index visible even when the user explicitly chooses manual strokes.
        if format == .strokes, let index = Double(indexText), index.isFinite {
            updated = HandicapCalculator.participant(updated, applying: index, format: .courseHandicap,
                courseSegment: courseSegment, maximumHandicap: maximum, handicapStrokeBasis: indexBasis)
        }
        updated = HandicapCalculator.participant(updated, applying: value, format: format,
            courseSegment: courseSegment, maximumHandicap: maximum, handicapStrokeBasis: indexBasis,
            approveEstimate: approveEstimate, approvedBy: approvedBy)
        if format == .courseHandicap, participant.handicapSnapshot == nil,
           participant.leagueHandicapStrokesAtCreation == nil, let manual = Int(strokesText) {
            updated.handicapResolution?.manualStrokes = manual
        }
        return updated
    }
}

enum RoundHandicapEntryPresentation {
    static func indexLabel(_ participant: RoundParticipant, basis: SeriesHandicapStrokeBasis?) -> String {
        let holes = basis.map { " (\($0.holeCount)-hole)" } ?? ""
        if participant.handicapSnapshot?.source == .commissionerRepair { return "Commissioner Override" + holes }
        if participant.handicapSnapshot != nil || participant.seriesMemberID != nil { return "League Handicap Index" + holes }
        if let input = participant.personalHandicapInput, input.index == participant.handicapIndex {
            return "Personal Handicap Index (18-hole)"
        }
        return "Round Handicap Index" + holes
    }
}
