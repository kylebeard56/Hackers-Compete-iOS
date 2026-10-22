//
//  SeriesRoundCreationMapping.swift
//  Hackers
//
//  Pure mapping from series round + roster state into round documents used when starting a live round.
//  Covered by SeriesRoundCreationMappingTests.
//

import Foundation

struct SeriesCourseHandicapValidationIssue: Hashable {
    let memberID: String
    let memberName: String
    let teeBoxID: String
    let teeName: String?
    let missingFields: [String]

    var message: String {
        let teeLabel = teeName?.isPopulated == true ? "\(teeName!) (\(teeBoxID))" : teeBoxID
        return "\(memberName): \(teeLabel) is missing \(missingFields.joined(separator: ", "))."
    }
}

struct SeriesCourseHandicapResolution: Hashable {
    let calculation: CourseHandicapCalculation
    var effectiveStrokes: Int?
    var handicapIndex: Double?
    let tee: Tee?
    let courseID: String
    let courseName: String
    let holeSegment: HoleSegment
    let courseRating: Double?
    let courseSlope: Int?
    let par: Int
    let entryFormat: HandicapEntryFormat
    var handicapStrokeBasis: SeriesHandicapStrokeBasis?
    let maximumHandicap: Int?
    var calculatorFingerprint: String
    let validationIssue: SeriesCourseHandicapValidationIssue?

    func snapshot(
        selectedHandicapScoreIDs: Set<String> = [],
        source: RoundParticipantHandicapSnapshotSource = .league,
        calculatedAt: Time = .init()
    ) -> RoundParticipantHandicapSnapshot? {
        guard let effectiveStrokes, let tee, let handicapStrokeBasis else { return nil }
        return RoundParticipantHandicapSnapshot(
            authoritativeCourseHandicap: entryFormat == .courseHandicap ? (calculation.courseHandicap ?? effectiveStrokes) : effectiveStrokes,
            handicapIndex: handicapIndex,
            effectiveStrokes: effectiveStrokes,
            courseID: courseID,
            courseName: courseName,
            teeBoxID: tee.id,
            teeName: tee.name,
            teeGender: tee.gender,
            holeSegment: holeSegment,
            courseRating: courseRating,
            courseSlope: courseSlope,
            par: par,
            handicapStrokeBasis: handicapStrokeBasis,
            maximumHandicap: maximumHandicap,
            entryFormat: entryFormat,
            calculatorFingerprint: calculatorFingerprint,
            selectedHandicapScoreIDs: selectedHandicapScoreIDs.sorted(),
            calculatedAt: calculatedAt,
            source: source,
            calculation: entryFormat == .courseHandicap ? calculation : nil
        )
    }
}

/// Single source of truth for the roster Course HCP display and series-round participant seeding.
enum SeriesCourseHandicapResolver {
    static let calculatorVersion = 3

    static func resolve(
        effectiveIndex: Double?,
        member: SeriesMember,
        courseSegment: CourseSegment,
        entryFormat: HandicapEntryFormat,
        handicapStrokeBasis: SeriesHandicapStrokeBasis?,
        maximumHandicap: Int?,
        roundInput: SeriesRoundHandicapInput? = nil
    ) -> SeriesCourseHandicapResolution {
        var member = member
        if let teeBoxID = roundInput?.teeBoxID { member.defaultTeeBoxID = teeBoxID }
        let requestedTeeID = SeriesRoundCreationMapping.resolvedTeeBoxID(
            for: member,
            courseSegment: courseSegment
        )
        let tee = courseSegment.tee(from: requestedTeeID)
        var resolution = resolve(
            effectiveIndex: roundInput.map { $0.isValid ? $0.value : nil } ?? effectiveIndex,
            memberID: member.id,
            memberName: member.name.fullName,
            requestedTeeID: requestedTeeID,
            tee: tee,
            courseID: courseSegment.courseInfo.id,
            courseName: courseSegment.courseInfo.name,
            holeSegment: courseSegment.holeSegment,
            entryFormat: roundInput.map { $0.method == .personalIndex ? .courseHandicap : .strokes } ?? entryFormat,
            handicapStrokeBasis: roundInput.map { $0.method == .personalIndex ? .eighteenHole : .defaultBasis(holeCount: courseSegment.holeSegment.holeCount) } ?? handicapStrokeBasis,
            maximumHandicap: roundInput?.method == .strokes ? nil : maximumHandicap
        )
        if roundInput?.method == .strokes { resolution.handicapIndex = nil }
        return resolution
    }

    static func resolve(
        effectiveIndex: Double?,
        memberID: String,
        memberName: String,
        requestedTeeID: String,
        tee: Tee?,
        courseID: String,
        courseName: String,
        holeSegment: HoleSegment,
        entryFormat: HandicapEntryFormat,
        handicapStrokeBasis: SeriesHandicapStrokeBasis?,
        maximumHandicap: Int?
    ) -> SeriesCourseHandicapResolution {
        let calculation = HandicapCalculator.calculation(
            index: effectiveIndex, tee: tee, segment: holeSegment, indexBasis: handicapStrokeBasis
        ).limitingIndex(to: entryFormat == .courseHandicap ? maximumHandicap : nil)
        var missingFields = entryFormat == .courseHandicap ? calculation.missingFields : []
        if entryFormat == .strokes {
            if let effectiveIndex, effectiveIndex.isFinite,
               effectiveIndex > Double(Int.min), effectiveIndex < Double(Int.max) {
                // Explicit zero is complete, just like any other valid stroke input.
            } else {
                missingFields.append("handicap index")
            }
        }
        if tee == nil, entryFormat == .strokes { missingFields.append("selected tee") }
        if entryFormat == .strokes, calculation.missingFields.contains("par") { missingFields.append("par") }
        // Series creation keeps its stricter course-data preflight. A casual-round
        // confirmation must never bypass league validation or commissioner authority.
        if entryFormat == .courseHandicap, calculation.status == .estimated {
            missingFields.append("exact segment rating/slope (estimate requires commissioner approval)")
        }
        let rating = calculation.rating
        let slope = calculation.slope
        let par = calculation.par ?? 0
        let issue = missingFields.isEmpty ? nil : SeriesCourseHandicapValidationIssue(
            memberID: memberID, memberName: memberName, teeBoxID: requestedTeeID,
            teeName: tee?.name, missingFields: missingFields
        )
        let effectiveStrokes: Int? = {
            guard let effectiveIndex, effectiveIndex.isFinite,
                  effectiveIndex > Double(Int.min), effectiveIndex < Double(Int.max) else { return nil }
            switch entryFormat {
            case .strokes: return capped(Int(effectiveIndex.rounded()), maximumHandicap: maximumHandicap)
            case .courseHandicap: return calculation.allowedStrokes(maximum: nil)
            }
        }()

        let formattedIndex = effectiveIndex.map { String(format: "%.4f", $0) } ?? "nil"
        let formattedRating = rating.map { String(format: "%.4f", $0) } ?? "nil"
        let formattedSlope = slope.map { String($0) } ?? "nil"
        let formattedMaximum = maximumHandicap.map { String($0) } ?? "nil"
        let fingerprintParts: [String] = [
            "series-course-hcp-v\(calculatorVersion)",
            entryFormat.rawValue,
            handicapStrokeBasis?.rawValue ?? "unknown",
            holeSegment.title,
            formattedIndex,
            requestedTeeID,
            formattedRating,
            formattedSlope,
            "\(par)",
            formattedMaximum
        ]

        return SeriesCourseHandicapResolution(
            calculation: calculation,
            effectiveStrokes: effectiveStrokes,
            handicapIndex: effectiveIndex,
            tee: tee,
            courseID: courseID,
            courseName: courseName,
            holeSegment: holeSegment,
            courseRating: rating,
            courseSlope: slope,
            par: par,
            entryFormat: entryFormat,
            handicapStrokeBasis: handicapStrokeBasis,
            maximumHandicap: maximumHandicap,
            calculatorFingerprint: fingerprintParts.joined(separator: "|"),
            validationIssue: issue
        )
    }

    /// New round-only values describe the actual holes played. When mixed with a
    /// legacy strokes-basis series, keep the old allowance calculation/cap and
    /// apply the existing scoring conversion once before storing the frozen total.
    static func onPlayedHoleBasis(_ resolution: SeriesCourseHandicapResolution,
                                  sourceBasis: SeriesHandicapStrokeBasis?, holeCount: Int) -> SeriesCourseHandicapResolution {
        guard let strokes = resolution.effectiveStrokes, let sourceBasis else { return resolution }
        let playedBasis = SeriesHandicapStrokeBasis.defaultBasis(holeCount: holeCount)
        guard sourceBasis != playedBasis else { return resolution }
        var result = resolution
        result.effectiveStrokes = ScoringEngine.handicapStrokesForPlayedHoles(
            handicap: strokes, basis: sourceBasis, holesInPlay: holeCount)
        result.handicapStrokeBasis = playedBasis
        result.calculatorFingerprint += "|played-strokes:\(holeCount)"
        return result
    }

    static func validationIssues(
        members: [SeriesMember],
        handicaps: [String: SeriesMemberHandicap],
        courseSegment: CourseSegment,
        entryFormat: HandicapEntryFormat,
        handicapStrokeBasis: SeriesHandicapStrokeBasis?,
        maximumHandicap: Int?,
        roundInputs: [String: SeriesRoundHandicapInput] = [:]
    ) -> [SeriesCourseHandicapValidationIssue] {
        members.compactMap { member in
            resolve(
                effectiveIndex: handicaps[member.id]?.effectiveIndex,
                member: member,
                courseSegment: courseSegment,
                entryFormat: entryFormat,
                handicapStrokeBasis: handicapStrokeBasis,
                maximumHandicap: maximumHandicap,
                roundInput: roundInputs[member.id]
            ).validationIssue
        }
    }

    private static func capped(_ value: Int, maximumHandicap: Int?) -> Int {
        let nonNegative = max(0, value)
        guard let maximumHandicap else { return nonNegative }
        return min(nonNegative, maximumHandicap)
    }
}

struct SeriesRoundReplacementPlan: Equatable {
    let originalToSubstitute: [String: String]

    var substituteToOriginal: [String: String] {
        Dictionary(uniqueKeysWithValues: originalToSubstitute.map { ($0.value, $0.key) })
    }

    var replacedMemberIDs: Set<String> {
        Set(originalToSubstitute.keys)
    }

    var substituteMemberIDs: Set<String> {
        Set(originalToSubstitute.values)
    }

    func resolvedMemberID(_ memberID: String) -> String {
        originalToSubstitute[memberID] ?? memberID
    }

    func applying(to matchupPlans: [SeriesRoundMatchupPlan]) -> [SeriesRoundMatchupPlan] {
        matchupPlans.map { plan in
            var updated = plan
            updated.memberAID = plan.memberAID.map(resolvedMemberID)
            updated.memberBID = plan.memberBID.map(resolvedMemberID)
            if updated.memberAID != plan.memberAID || updated.memberBID != plan.memberBID {
                updated.lastUpdatedAt = .init()
            }
            return updated
        }
    }

    func applying(to partnershipPlans: [SeriesRoundPartnershipPlan]) -> [SeriesRoundPartnershipPlan] {
        partnershipPlans.map { plan in
            let resolvedMemberIDs = Array(Set(plan.memberIDs.map(resolvedMemberID))).sorted()
            guard resolvedMemberIDs != plan.memberIDs else { return plan }
            var updated = plan
            updated.memberIDs = resolvedMemberIDs
            updated.lastUpdatedAt = .init()
            return updated
        }
    }
}

/// Shared roster policy for Series-authored tee sheets, round creation, and lobby reconciliation.
enum SeriesRoundParticipationPolicy {
    static func isAutomaticPlayer(_ member: SeriesMember) -> Bool {
        guard member.isActive else { return false }
        switch member.role {
        case .commissioner, .captain, .member:
            return true
        case .substitute, .spectator:
            return false
        }
    }

    static func replacementPlan(
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup],
        membersByID: [String: SeriesMember]
    ) -> SeriesRoundReplacementPlan {
        var candidates: [(originalID: String, substituteID: String)] = []

        for seat in orderedSeats(from: plannedTeeGroups) {
            guard seat.isSubstitute,
                  let originalID = seat.substituteForSeriesMemberID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  originalID.isPopulated,
                  originalID != seat.memberID,
                  let substitute = membersByID[seat.memberID],
                  substitute.isActive,
                  substitute.role == .substitute else {
                continue
            }

            if let original = membersByID[originalID], !isAutomaticPlayer(original) {
                continue
            }

            candidates.append((originalID, substitute.id))
        }

        let originalCounts = Dictionary(grouping: candidates) { $0.originalID }.mapValues(\.count)
        let substituteCounts = Dictionary(grouping: candidates) { $0.substituteID }.mapValues(\.count)
        let validMappings: [(String, String)] = candidates.compactMap { candidate -> (String, String)? in
            guard originalCounts[candidate.originalID] == 1,
                  substituteCounts[candidate.substituteID] == 1 else { return nil }
            return (candidate.originalID, candidate.substituteID)
        }
        let originalToSubstitute = Dictionary(uniqueKeysWithValues: validMappings)

        return SeriesRoundReplacementPlan(originalToSubstitute: originalToSubstitute)
    }

    static func effectiveMembers(
        members: [SeriesMember],
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    ) -> [SeriesMember] {
        let membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        let replacements = replacementPlan(
            plannedTeeGroups: plannedTeeGroups,
            membersByID: membersByID
        )
        let plannedMemberIDs = orderedSeats(from: plannedTeeGroups).map(\.memberID)
        let plannedMemberIDSet = Set(plannedMemberIDs)
        let orderedIDs = plannedMemberIDs + members.compactMap { member in
            guard isAutomaticPlayer(member), !plannedMemberIDSet.contains(member.id) else { return nil }
            return member.id
        }
        var seen = Set<String>()

        return orderedIDs.compactMap { memberID in
            guard seen.insert(memberID).inserted,
                  !replacements.replacedMemberIDs.contains(memberID),
                  let member = membersByID[memberID] else { return nil }
            if isAutomaticPlayer(member) { return member }
            guard member.role == .substitute,
                  replacements.substituteMemberIDs.contains(memberID) else { return nil }
            return member
        }
    }

    static func orderedSeats(
        from groups: [SeriesRoundPlannedTeeGroup]
    ) -> [SeriesRoundPlannedSeat] {
        groups
            .sorted { $0.index < $1.index }
            .flatMap { group in
                group.seats.sorted { lhs, rhs in
                    if lhs.teeOrder != rhs.teeOrder { return lhs.teeOrder < rhs.teeOrder }
                    return lhs.memberID < rhs.memberID
                }
            }
    }
}

enum SeriesRoundCreationMapping {

    /// Links a series team id to the corresponding `RoundTeam` document id after create.
    struct SeriesToRoundTeamLink: Equatable {
        let seriesTeamID: String
        let roundTeamID: String
    }

    struct TeeGroupPlan: Identifiable, Equatable {
        let id: String
        let seats: [TeeGroupSeat]

        init(id: String, seats: [TeeGroupSeat]) {
            self.id = id
            self.seats = seats.sorted { lhs, rhs in
                if lhs.teeOrder != rhs.teeOrder { return lhs.teeOrder < rhs.teeOrder }
                return lhs.memberID < rhs.memberID
            }
        }

        init(id: String, memberIDs: [String]) {
            self.init(
                id: id,
                seats: memberIDs.enumerated().map { offset, memberID in
                    TeeGroupSeat(memberID: memberID, teeOrder: offset + 1)
                }
            )
        }

        var memberIDs: [String] {
            seats.map(\.memberID)
        }
    }

    struct TeeGroupSeat: Equatable {
        let memberID: String
        let teeOrder: Int
    }

    struct MemberAssignment: Equatable {
        let groupID: String
        let teeOrder: Int
    }

    // MARK: - Round root + configuration

    static func resolvedCompetitionScope(for seriesRound: SeriesRound) -> CompetitionScope {
        if seriesRound.matchupPlans.isPopulated
            || seriesRound.roundConfig.matchupMode == .teamVsTeam
            || seriesRound.roundConfig.matchupMode == .individualVsIndividual
            || seriesRound.roundConfig.matchupMode == .teeGroupPartnerships {
            return .matchup
        }
        return seriesRound.roundConfig.resolvedCompetitionScope
    }

    /// Root round + segment game format: when league handicaps are enabled and the series round has no explicit gross/net override, default to net so lobby “Handicaps” matches series intent.
    static func primaryGameFormatForRound(series: Series, seriesRound: SeriesRound) -> GameFormat {
        primaryGameFormat(series: series, seriesRound: seriesRound)
    }

    static func primaryGameFormat(series: Series, seriesRound: SeriesRound) -> GameFormat {
        var format = seriesRound.roundConfig.legacyGameFormat
        if series.handicapConfig.isEnabled, seriesRound.roundConfig.scoreBasisOverride == nil {
            format.configuration.basis = .net
        }
        return format
    }

    private static func resolvedSelectionDomain(for seriesRound: SeriesRound) -> ScoringSelectionDomain? {
        if let selectionDomain = seriesRound.roundConfig.selectionDomain {
            return selectionDomain
        }

        switch seriesRound.roundConfig.matchupMode {
        case .teamVsTeam:
            return .team
        case .individualVsIndividual:
            return .participant
        case .teeGroupPartnerships:
            return .partnership
        case .field, .none:
            return nil
        }
    }

    static func roundConfiguration(
        series: Series,
        seriesRound: SeriesRound,
        courseSegment: CourseSegment,
        competitionScope: CompetitionScope
    ) -> RoundConfiguration {
        let template = seriesRound.roundConfig.template
        let primaryFormat = primaryGameFormat(series: series, seriesRound: seriesRound)
        let scoreOwnerScope: RoundScoreOwnerScope = template.scoreSource == .shared
            ? seriesRound.roundConfig.scoreOwnerScope
            : .individual
        return RoundConfiguration(
            primaryFormat: primaryFormat,
            formatSummary: RoundFormatSummary(from: template),
            courses: [courseSegment],
            competitionScope: competitionScope,
            teamScoring: seriesRound.roundConfig.teamScoring,
            matchupResolutionStyle: seriesRound.roundConfig.matchupResolutionStyle,
            scoreOwnerScope: scoreOwnerScope,
            matchupScoringStyle: seriesRound.roundConfig.matchupScoringStyle,
            holeWinPoints: seriesRound.roundConfig.holeWinPoints,
            matchWinnerBonusPoints: seriesRound.roundConfig.matchWinnerBonusPoints,
            matchTiePolicy: seriesRound.roundConfig.matchTiePolicy,
            selectionDomain: resolvedSelectionDomain(for: seriesRound),
            sequentialTeeStartsEnabled: false,
            handicapStrokeBasis: (seriesRound.roundConfig.handicapEntryFormat == .courseHandicap || !seriesRound.handicapInputs.isEmpty)
                ? .defaultBasis(holeCount: courseSegment.holeSegment.holeCount)
                : seriesRound.roundConfig.handicapStrokeBasis,
            handicapIndexBasis: series.handicapConfig.strokeBasis,
            handicapsEnabled: primaryFormat.configuration.basis == .net,
            sharedScoreHandicapConfig: seriesRound.roundConfig.sharedScoreHandicapConfig,
            handicapEntryFormat: seriesRound.roundConfig.handicapEntryFormat,
            handicapNormalizationMode: seriesRound.roundConfig.handicapNormalizationMode,
            leagueHandicapMaximum: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
            attendanceConfirmationEnabled: series.settings.isAttendanceEnabled,
            substitutesScore: seriesRound.policyBinding?.resolvedSubstitutesScore
                ?? series.settings.substitutesScore
        )
    }

    static func participatingMembersAndPresenceStatuses(
        series: Series,
        eligibleMembers: [SeriesMember],
        attendance: [SeriesRoundAttendance],
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup] = []
    ) -> (members: [SeriesMember], presenceStatusByMemberID: [String: RoundParticipantPresenceStatus]) {
        let attendanceByMemberID = Dictionary(uniqueKeysWithValues: attendance.map { ($0.memberID, $0) })
        let membersByID = Dictionary(uniqueKeysWithValues: eligibleMembers.map { ($0.id, $0) })
        let replacements = SeriesRoundParticipationPolicy.replacementPlan(
            plannedTeeGroups: plannedTeeGroups,
            membersByID: membersByID
        )
        let effectiveMembers = SeriesRoundParticipationPolicy.effectiveMembers(
            members: eligibleMembers,
            plannedTeeGroups: plannedTeeGroups
        )

        func attendanceStatus(for memberID: String) -> SeriesRoundAttendanceStatus? {
            guard series.settings.isAttendanceEnabled else { return .accepted }
            if let rawValue = attendanceByMemberID[memberID]?.status,
               let status = SeriesRoundAttendanceStatus(rawValue: rawValue) {
                return status
            }
            return series.settings.attendanceDefault
        }

        let participatingMembers = effectiveMembers.filter { member in
            if replacements.substituteMemberIDs.contains(member.id) {
                return true
            }
            guard series.settings.isAttendanceEnabled else { return true }
            let status = attendanceStatus(for: member.id)
            return status == .accepted || status == .pending
        }

        let presenceStatusByMemberID: [String: RoundParticipantPresenceStatus]
        if series.settings.isAttendanceEnabled {
            presenceStatusByMemberID = Dictionary(uniqueKeysWithValues: participatingMembers.map { member in
                let status: SeriesRoundAttendanceStatus?
                if let originalID = replacements.substituteToOriginal[member.id] {
                    if attendanceByMemberID[member.id] != nil {
                        status = attendanceStatus(for: member.id)
                    } else {
                        let inherited = attendanceStatus(for: originalID)
                        status = inherited == .no ? .accepted : inherited
                    }
                } else {
                    status = attendanceStatus(for: member.id)
                }

                let presence: RoundParticipantPresenceStatus
                switch status {
                case .pending:
                    presence = .unconfirmed
                case .no:
                    presence = .noShow
                case .accepted, .none:
                    presence = .active
                }
                return (member.id, presence)
            })
        } else {
            presenceStatusByMemberID = [:]
        }

        return (participatingMembers, presenceStatusByMemberID)
    }

    /// Values used when creating the root `Round` before Firestore post (share code and timestamps filled by caller).
    static func roundDraft(
        id: String,
        shareCode: String,
        createdBy: String,
        series: Series,
        members: [SeriesMember],
        seriesRound: SeriesRound,
        courseSegment: CourseSegment
    ) -> Round {
        let competitionScope = resolvedCompetitionScope(for: seriesRound)
        return Round(
            id: id,
            name: seriesRound.title,
            shareCode: shareCode,
            createdBy: createdBy,
            status: .lobby,
            players: members.compactMap(\.playerID),
            configuration: roundConfiguration(
                series: series,
                seriesRound: seriesRound,
                courseSegment: courseSegment,
                competitionScope: competitionScope
            ),
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
    }

    // MARK: - Matchups + tee groups

    static func resolvedMatchupPlans(
        seriesRound: SeriesRound,
        teams: [SeriesTeam],
        members: [SeriesMember]
    ) -> [SeriesRoundMatchupPlan] {
        let schedulableMembers = members.filter { $0.role != .substitute && $0.role != .spectator }
        if seriesRound.matchupPlans.isPopulated {
            return seriesRound.matchupPlans.sorted { $0.index < $1.index }
        }

        switch seriesRound.roundConfig.matchupMode {
        case .teamVsTeam:
            let orderedTeams = teams.sorted { $0.index < $1.index }
            var plans: [SeriesRoundMatchupPlan] = []
            var index = 0
            var cursor = 0
            while cursor + 1 < orderedTeams.count {
                plans.append(
                    SeriesRoundMatchupPlan(
                        id: HackersID.string(),
                        teamAID: orderedTeams[cursor].id,
                        teamBID: orderedTeams[cursor + 1].id,
                        index: index,
                        podGroupingStrategy: seriesRound.roundConfig.podGroupingStrategy
                    )
                )
                cursor += 2
                index += 1
            }
            return plans
        case .individualVsIndividual:
            let orderedMembers = schedulableMembers.sorted {
                $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
            }
            var plans: [SeriesRoundMatchupPlan] = []
            var index = 0
            var cursor = 0
            while cursor + 1 < orderedMembers.count {
                plans.append(
                    SeriesRoundMatchupPlan(
                        id: HackersID.string(),
                        memberAID: orderedMembers[cursor].id,
                        memberBID: orderedMembers[cursor + 1].id,
                        index: index
                    )
                )
                cursor += 2
                index += 1
            }
            return plans
        case .teeGroupPartnerships, .none, .field:
            return []
        }
    }

    static func buildTeeGroupPlans(
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan],
        seriesRound: SeriesRound
    ) -> [TeeGroupPlan] {
        let schedulableMembers = members.filter { $0.role != .substitute && $0.role != .spectator }
        if seriesRound.roundConfig.teeGroupMode == .podAligned || seriesRound.roundConfig.podGroupingStrategy.usesPodAlignment {
            let podPlans = buildPodAlignedGroupPlans(
                members: schedulableMembers,
                pods: pods,
                matchupPlans: matchupPlans
            )
            if podPlans.isPopulated {
                let assignedMemberIDs = Set(podPlans.flatMap(\.memberIDs))
                let leftovers = schedulableMembers.filter { !assignedMemberIDs.contains($0.id) }
                return podPlans + sequentialGroupPlans(for: leftovers, teams: teams)
            }
        }

        return sequentialGroupPlans(for: schedulableMembers, teams: teams)
    }

    private static func buildPodAlignedGroupPlans(
        members: [SeriesMember],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan]
    ) -> [TeeGroupPlan] {
        guard matchupPlans.isPopulated else { return [] }
        let participatingMemberIDs = Set(members.map(\.id))
        let podsByTeam = Dictionary(grouping: pods.filter(\.isSchedulable)) { $0.teamID }
        var plans: [TeeGroupPlan] = []

        for plan in matchupPlans.sorted(by: { $0.index < $1.index }) {
            guard plan.podGroupingStrategy.usesPodAlignment else { continue }
            let podsA = (podsByTeam[plan.teamAID] ?? []).sorted { $0.index < $1.index }
            let podsB = (podsByTeam[plan.teamBID] ?? []).sorted { $0.index < $1.index }
            guard podsA.isPopulated, podsB.isPopulated, podsA.count == podsB.count else { continue }

            let matchedPodsB: [SeriesTeamPod]
            switch plan.podGroupingStrategy {
            case .disabled:
                continue
            case .alignByIndex:
                matchedPodsB = podsB
            case .swapPairs:
                matchedPodsB = rotate(podsB, by: 1)
            }

            for index in podsA.indices {
                let seats = groupedSeats(
                    podA: podsA[index],
                    podB: matchedPodsB[index],
                    participatingMemberIDs: participatingMemberIDs
                )
                guard seats.isPopulated else { continue }
                plans.append(TeeGroupPlan(id: "matchup_\(plan.id)_pod_\(index)", seats: seats))
            }
        }

        return plans
    }

    private static func sequentialGroupPlans(for members: [SeriesMember], teams: [SeriesTeam]) -> [TeeGroupPlan] {
        let teamOrder = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.index) })
        let orderedMembers = members.sorted { lhs, rhs in
            let lhsTeam = lhs.teamID.flatMap { teamOrder[$0] } ?? .max
            let rhsTeam = rhs.teamID.flatMap { teamOrder[$0] } ?? .max
            if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
            return lhs.name.fullName < rhs.name.fullName
        }

        return stride(from: 0, to: orderedMembers.count, by: 4).map { start in
            let chunk = Array(orderedMembers[start..<min(start + 4, orderedMembers.count)])
            return TeeGroupPlan(id: "group_\(start / 4)", memberIDs: chunk.map(\.id))
        }
    }

    static func buildMemberAssignments(
        groupPlans: [TeeGroupPlan],
        groupIDsByPlanID: [String: String]
    ) -> [String: MemberAssignment] {
        var assignments: [String: MemberAssignment] = [:]
        for groupPlan in groupPlans {
            guard let groupID = groupIDsByPlanID[groupPlan.id] else { continue }
            for seat in groupPlan.seats {
                assignments[seat.memberID] = MemberAssignment(groupID: groupID, teeOrder: seat.teeOrder)
            }
        }
        return assignments
    }

    static func teeGroupPlansWithAdjacentPartnerships(
        _ groupPlans: [TeeGroupPlan],
        partnershipPlans: [SeriesRoundPartnershipPlan]
    ) -> [TeeGroupPlan] {
        guard groupPlans.isPopulated, partnershipPlans.isPopulated else { return groupPlans }

        let partnerIDsByMemberID: [String: String] = partnershipPlans.reduce(into: [:]) { partial, plan in
            guard plan.memberIDs.count == 2 else { return }
            partial[plan.memberIDs[0]] = plan.memberIDs[1]
            partial[plan.memberIDs[1]] = plan.memberIDs[0]
        }
        guard partnerIDsByMemberID.isPopulated else { return groupPlans }

        return groupPlans.map { plan in
            let seatByMemberID = Dictionary(uniqueKeysWithValues: plan.seats.map { ($0.memberID, $0) })
            var consumed = Set<String>()
            var clusters: [[TeeGroupSeat]] = []

            for seat in plan.seats {
                guard !consumed.contains(seat.memberID) else { continue }
                if let partnerID = partnerIDsByMemberID[seat.memberID],
                   let partnerSeat = seatByMemberID[partnerID] {
                    let pair = [seat, partnerSeat].sorted {
                        if $0.teeOrder != $1.teeOrder { return $0.teeOrder < $1.teeOrder }
                        return $0.memberID < $1.memberID
                    }
                    clusters.append(pair)
                    consumed.insert(seat.memberID)
                    consumed.insert(partnerID)
                } else {
                    clusters.append([seat])
                    consumed.insert(seat.memberID)
                }
            }

            let normalizedSeats = clusters.flatMap { $0 }.enumerated().map { offset, seat in
                TeeGroupSeat(memberID: seat.memberID, teeOrder: offset + 1)
            }
            return TeeGroupPlan(id: plan.id, seats: normalizedSeats)
        }
    }

    static func buildTeeGroupsArray(
        roundID: String,
        groupPlans: [TeeGroupPlan],
        holeRange: HoleRange,
        useSequentialStarts: Bool,
        scheduledTeeTime: Date? = nil
    ) -> [TeeTimeGroup] {
        let plans = groupPlans.isPopulated ? groupPlans : [TeeGroupPlan(id: "group_0", memberIDs: [])]
        let groups = plans.enumerated().map { index, _ in
            TeeTimeGroup(
                id: HackersID.string(),
                index: index,
                teeTime: nil,
                startingHole: useSequentialStarts
                    ? TeeTimeGroup.sequentialStartingHole(forSequenceIndex: index, in: holeRange)
                    : holeRange.startHole,
                lastCompletedHole: nil,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
        }
        return teeGroupsWithSchedule(
            groups,
            holeRange: holeRange,
            useShotgunStart: useSequentialStarts,
            scheduledTeeTime: scheduledTeeTime
        )
    }

    static func teeGroupsWithSchedule(
        _ groups: [TeeTimeGroup],
        holeRange: HoleRange,
        useShotgunStart: Bool,
        scheduledTeeTime: Date? = nil,
        fallbackTeeTime: String? = nil,
        intervalMinutes: Int = 8
    ) -> [TeeTimeGroup] {
        let ordered = groups.sorted { $0.index < $1.index }
        let base = scheduledTeeTime
            ?? fallbackTeeTime.flatMap(Self.dateFromISO8601)
            ?? ordered.compactMap(\.teeTime).first.flatMap(Self.dateFromISO8601)
        let iso = ISO8601DateFormatter()

        return ordered.enumerated().map { index, group in
            var updated = group
            updated.index = index
            updated.startingHole = useShotgunStart
                ? TeeTimeGroup.sequentialStartingHole(forSequenceIndex: index, in: holeRange)
                : holeRange.startHole
            if let base {
                let date = useShotgunStart
                    ? base
                    : base.addingTimeInterval(Double(index * intervalMinutes) * 60)
                updated.teeTime = iso.string(from: date)
            } else {
                updated.teeTime = nil
            }
            return updated
        }
    }

    static func plannedTeeGroupsWithSchedule(
        _ groups: [SeriesRoundPlannedTeeGroup],
        holeRange: HoleRange,
        useShotgunStart: Bool,
        scheduledTeeTime: Date? = nil,
        fallbackTeeTime: String? = nil,
        intervalMinutes: Int = 8,
        preserveStartingHoles: Bool = false
    ) -> [SeriesRoundPlannedTeeGroup] {
        let ordered = groups.sorted { $0.index < $1.index }
        let base = scheduledTeeTime
            ?? fallbackTeeTime.flatMap(Self.dateFromISO8601)
            ?? ordered.compactMap(\.teeTime).first.flatMap(Self.dateFromISO8601)
        let iso = ISO8601DateFormatter()

        return ordered.enumerated().map { index, group in
            var updated = group
            updated.index = index
            updated.startingHole = preserveStartingHoles
                ? group.startingHole
                : (useShotgunStart
                    ? TeeTimeGroup.sequentialStartingHole(forSequenceIndex: index, in: holeRange)
                    : holeRange.startHole)
            if let base {
                let date = useShotgunStart
                    ? base
                    : base.addingTimeInterval(Double(index * intervalMinutes) * 60)
                updated.teeTime = iso.string(from: date)
            } else {
                updated.teeTime = nil
            }
            return updated
        }
    }

    private static func dateFromISO8601(_ value: String?) -> Date? {
        guard let value, value.isPopulated else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func groupedSeats(
        podA: SeriesTeamPod,
        podB: SeriesTeamPod,
        participatingMemberIDs: Set<String>
    ) -> [TeeGroupSeat] {
        let leftSeats = podA.memberIDs.enumerated().compactMap { offset, memberID -> TeeGroupSeat? in
            guard participatingMemberIDs.contains(memberID) else { return nil }
            return TeeGroupSeat(memberID: memberID, teeOrder: offset + 1)
        }
        let rightSeats = podB.memberIDs.enumerated().compactMap { offset, memberID -> TeeGroupSeat? in
            guard participatingMemberIDs.contains(memberID) else { return nil }
            return TeeGroupSeat(memberID: memberID, teeOrder: offset + 3)
        }
        return leftSeats + rightSeats
    }

    private static func rotate<T>(_ values: [T], by offset: Int) -> [T] {
        guard values.count > 1 else { return values }
        let normalizedOffset = ((offset % values.count) + values.count) % values.count
        guard normalizedOffset != 0 else { return values }
        return Array(values[normalizedOffset...]) + Array(values[..<normalizedOffset])
    }

    // MARK: - Teams

    static func buildRoundTeamsArray(
        roundID: String,
        seriesTeams: [SeriesTeam],
        createdAt: Time
    ) -> [RoundTeam] {
        guard seriesTeams.isPopulated else { return [] }

        return seriesTeams.sorted(by: { $0.index < $1.index }).enumerated().map { index, team in
            RoundTeam(
                id: HackersID.string(),
                name: team.name,
                color: team.roundColorToken,
                index: index,
                createdAt: createdAt,
                lastUpdatedAt: createdAt,
                parentID: roundID
            )
        }
    }

    static func teamMappingsFromPosted(seriesTeams: [SeriesTeam], posted: [RoundTeam]) -> [String: SeriesToRoundTeamLink] {
        let sorted = seriesTeams.sorted(by: { $0.index < $1.index })
        guard sorted.count == posted.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(sorted, posted).map { team, roundTeam in
            (team.id, SeriesToRoundTeamLink(seriesTeamID: team.id, roundTeamID: roundTeam.id))
        })
    }

    static func resolvedPartnershipPlans(
        seriesRound: SeriesRound,
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        members: [SeriesMember]
    ) -> [SeriesRoundPartnershipPlan] {
        let replacements = SeriesRoundParticipationPolicy.replacementPlan(
            plannedTeeGroups: seriesRound.plannedTeeGroups,
            membersByID: Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        )
        if seriesRound.partnershipPlans.isPopulated {
            return replacements.applying(to: seriesRound.partnershipPlans)
                .filter(\.isValid)
                .sorted { lhs, rhs in
                    if lhs.teamID != rhs.teamID { return lhs.teamID < rhs.teamID }
                    let lhsLabel = lhs.label ?? lhs.id
                    let rhsLabel = rhs.label ?? rhs.id
                    return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
                }
        }

        guard seriesRound.roundConfig.selectionDomain == .partnership
            || seriesRound.roundConfig.matchupMode == .teeGroupPartnerships
            || seriesRound.roundConfig.scoreOwnerScope == .partnership else { return [] }

        let activeMemberIDs = Set(members.map(\.id))
        let teamOrder = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.index) })
        let generatedPlans = pods
            .filter { $0.isSchedulable && Set($0.memberIDs).isSubset(of: activeMemberIDs) }
            .sorted { lhs, rhs in
                let lhsTeam = teamOrder[lhs.teamID] ?? .max
                let rhsTeam = teamOrder[rhs.teamID] ?? .max
                if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
                return lhs.index < rhs.index
            }
            .map { pod in
                SeriesRoundPartnershipPlan(
                    id: pod.id,
                    teamID: pod.teamID,
                    memberIDs: pod.memberIDs,
                    label: pod.resolvedLabel,
                    seedSeriesPodID: pod.id,
                    createdAt: pod.createdAt,
                    lastUpdatedAt: pod.lastUpdatedAt
                )
            }
        return replacements.applying(to: generatedPlans).filter(\.isValid)
    }

    // MARK: - Participants + segment + Firestore mappings

    static func resolvedTeeBoxID(for member: SeriesMember, courseSegment: CourseSegment) -> String {
        if let teeBoxID = member.defaultTeeBoxID, teeBoxID.isPopulated {
            return teeBoxID
        }
        if let defaultTee = courseSegment.defaultTee, defaultTee.isPopulated {
            return defaultTee
        }
        return courseSegment.courseInfo.tees.first?.id ?? ""
    }

    static func buildParticipantPayloads(
        members: [SeriesMember],
        roundID: String,
        teamMappings: [String: SeriesToRoundTeamLink],
        memberAssignments: [String: MemberAssignment],
        handicaps: [String: SeriesMemberHandicap],
        maximumHandicap: Int? = nil,
        courseSegment: CourseSegment,
        handicapEntryFormat: HandicapEntryFormat = .strokes,
        handicapStrokeBasis: SeriesHandicapStrokeBasis? = nil,
        selectedHandicapScoreIDsByMemberID: [String: Set<String>] = [:],
        roundHandicapInputs: [String: SeriesRoundHandicapInput] = [:],
        roundScoringStrokeBasis: SeriesHandicapStrokeBasis? = nil,
        hostPlayerID: String?,
        presenceStatusByMemberID: [String: RoundParticipantPresenceStatus] = [:],
        plannedSeatsByMemberID: [String: SeriesRoundPlannedSeat] = [:]
    ) -> [RoundParticipant] {
        let resolvedHandicapStrokeBasis = handicapStrokeBasis
        let explicitSubstituteSeats = plannedSeatsByMemberID.values.filter { seat in
            seat.isSubstitute
                && seat.substituteForSeriesMemberID?.isPopulated == true
                && seat.substituteForSeriesMemberID != seat.memberID
        }
        let explicitSubstituteIDs = Set(explicitSubstituteSeats.map(\.memberID))
        let replacedMemberIDs = Set(explicitSubstituteSeats.compactMap(\.substituteForSeriesMemberID))

        return members.compactMap { member in
            guard !replacedMemberIDs.contains(member.id) else { return nil }
            if !SeriesRoundParticipationPolicy.isAutomaticPlayer(member) {
                guard member.isActive,
                      member.role == .substitute,
                      explicitSubstituteIDs.contains(member.id) else { return nil }
            }

            let assignment = memberAssignments[member.id]
            let effectiveIndex = handicaps[member.id]?.effectiveIndex
            let effectiveHandicap = handicaps[member.id]?.effectiveStrokes(maximumHandicap: maximumHandicap) ?? 0
            let plannedSeat = plannedSeatsByMemberID[member.id]
            let representedTeamID = plannedSeat?.representedTeamID?.isPopulated == true
                ? plannedSeat?.representedTeamID
                : member.teamID
            let teamMapping = representedTeamID.flatMap { teamMappings[$0] }
            let roundInput = roundHandicapInputs[member.id]
            let teeBoxID = roundInput?.teeBoxID ?? resolvedTeeBoxID(for: member, courseSegment: courseSegment)
            var resolution = SeriesCourseHandicapResolver.resolve(
                effectiveIndex: effectiveIndex,
                member: member,
                courseSegment: courseSegment,
                entryFormat: handicapEntryFormat,
                handicapStrokeBasis: resolvedHandicapStrokeBasis,
                maximumHandicap: maximumHandicap,
                roundInput: roundInput
            )
            if !roundHandicapInputs.isEmpty, roundInput == nil, handicapEntryFormat == .strokes {
                resolution = SeriesCourseHandicapResolver.onPlayedHoleBasis(resolution,
                    sourceBasis: roundScoringStrokeBasis ?? .defaultBasis(holeCount: courseSegment.holeSegment.holeCount),
                    holeCount: courseSegment.holeSegment.holeCount)
            }
            let computedHandicap = resolution.effectiveStrokes ?? (handicapEntryFormat == .strokes ? effectiveHandicap : 0)
            // Retain the legacy integer field for old clients, but never read it as an Index.
            let originalHandicap = roundInput.flatMap { $0.isValid ? max(0, Int($0.value.rounded())) : nil }
                ?? (handicapEntryFormat == .courseHandicap
                    ? max(0, Int((effectiveIndex ?? 0).rounded())) : effectiveHandicap)
            return RoundParticipant(
                id: HackersID.string(),
                userID: member.userID,
                playerID: member.playerID,
                name: member.name.normalizedForStorage,
                teeBoxID: teeBoxID,
                originalHandicap: originalHandicap,
                adjustedHandicap: computedHandicap,
                handicapIndex: roundInput == nil
                    ? (handicapEntryFormat == .courseHandicap ? effectiveIndex : nil)
                    : resolution.handicapIndex,
                leagueHandicapStrokesAtCreation: resolution.effectiveStrokes,
                handicapSnapshot: resolution.snapshot(
                    selectedHandicapScoreIDs: roundInput == nil ? (selectedHandicapScoreIDsByMemberID[member.id] ?? []) : [],
                    source: roundInput == nil ? .league : .roundSetup
                ),
                handicapResolution: RoundHandicapResolution(
                    entryFormat: resolution.entryFormat,
                    calculation: resolution.entryFormat == .courseHandicap ? resolution.calculation : nil,
                    effectiveStrokes: resolution.effectiveStrokes
                ),
                seriesMemberID: member.id,
                teamID: teamMapping?.roundTeamID,
                groupID: assignment?.groupID,
                teeOrder: assignment?.teeOrder,
                isHost: hostPlayerID != nil && member.playerID == hostPlayerID,
                presenceStatus: presenceStatusByMemberID[member.id] ?? .active,
                isSubstitute: plannedSeat?.isSubstitute == true || member.role == .substitute,
                substituteForSeriesMemberID: plannedSeat?.substituteForSeriesMemberID,
                substituteForName: plannedSeat?.substituteForName,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
        }
    }

    static func membersMissingEffectiveHandicap(
        members: [SeriesMember],
        handicaps: [String: SeriesMemberHandicap]
    ) -> [String] {
        members
            .filter { handicaps[$0.id]?.effectiveIndex == nil }
            .map(\.id)
    }

    static func buildRoundMatchups(
        seriesRound: SeriesRound,
        matchupPlans: [SeriesRoundMatchupPlan],
        teamMappings: [String: SeriesToRoundTeamLink],
        participantIDsBySeriesMemberID: [String: String],
        scoringGroups: [RoundScoringGroup],
        participants: [RoundParticipant]
    ) -> [TeamMatchup] {
        let participantReplacements = SeriesRoundReplacementPlan(
            originalToSubstitute: participants.reduce(into: [:]) { replacements, participant in
                guard let originalID = participant.substituteForSeriesMemberID,
                      originalID.isPopulated,
                      let substituteMemberID = participant.seriesMemberID,
                      substituteMemberID.isPopulated else { return }
                replacements[originalID] = substituteMemberID
            }
        )
        var resolvedParticipantIDs = participantIDsBySeriesMemberID
        for originalID in participantReplacements.replacedMemberIDs {
            let substituteMemberID = participantReplacements.resolvedMemberID(originalID)
            if let participantID = participantIDsBySeriesMemberID[substituteMemberID] {
                resolvedParticipantIDs[originalID] = participantID
            }
        }

        if (seriesRound.roundConfig.selectionDomain == .partnership
            || seriesRound.roundConfig.scoreOwnerScope == .partnership
            || seriesRound.roundConfig.matchupMode == .teeGroupPartnerships),
           scoringGroups.isPopulated {
            if seriesRound.roundConfig.matchupMode == .teeGroupPartnerships {
                let scoringGroupsByID = Dictionary(uniqueKeysWithValues: scoringGroups.map { ($0.id, $0) })
                let participantsBySeriesMemberID: [String: RoundParticipant] = participants.reduce(into: [:]) { partial, participant in
                    guard let seriesMemberID = participant.seriesMemberID, partial[seriesMemberID] == nil else { return }
                    partial[seriesMemberID] = participant
                }
                let partnershipPlansByID: [String: SeriesRoundPartnershipPlan] = seriesRound.partnershipPlans.reduce(into: [:]) { partial, plan in
                    guard plan.isValid, plan.id.isPopulated, partial[plan.id] == nil else { return }
                    partial[plan.id] = plan
                }
                let partnershipGroups = scoringGroups.filter { $0.kind == .partnership }

                func scoringGroupID(forPairID pairID: String) -> String? {
                    if scoringGroupsByID[pairID] != nil {
                        return pairID
                    }

                    guard let partnershipPlan = partnershipPlansByID[pairID] else { return nil }
                    let participantIDs = partnershipPlan.memberIDs.compactMap { seriesMemberID in
                        resolvedParticipantIDs[seriesMemberID] ?? participantsBySeriesMemberID[seriesMemberID]?.id
                    }
                    guard participantIDs.count == partnershipPlan.memberIDs.count else { return nil }

                    let participantIDSet = Set(participantIDs)
                    let matches = partnershipGroups.filter { Set($0.memberIDs) == participantIDSet }
                    guard matches.count == 1 else { return nil }
                    return matches[0].id
                }

                let plannedPairMatchups = matchupPlans.compactMap { plan -> TeamMatchup? in
                    guard let pairAID = plan.pairAID,
                          let pairBID = plan.pairBID,
                          let scoreOwnerAID = scoringGroupID(forPairID: pairAID),
                          let scoreOwnerBID = scoringGroupID(forPairID: pairBID),
                          pairAID != pairBID else {
                        return nil
                    }
                    return TeamMatchup(
                        id: plan.id,
                        teamIDs: [],
                        participantIDs: nil,
                        scoreOwnerIDs: [scoreOwnerAID, scoreOwnerBID],
                        scoreOwnerScope: nil,
                        mode: .partnership
                    )
                }

                if plannedPairMatchups.isPopulated {
                    return plannedPairMatchups
                }
            }

            let groupsByTeeGroup = Dictionary(grouping: scoringGroups.filter { $0.kind == .partnership }) { $0.teeGroupID ?? "" }
            let teamOrder = Dictionary(uniqueKeysWithValues: teamMappings.values.map { ($0.roundTeamID, $0.seriesTeamID) })
            var matchups: [TeamMatchup] = []

            for (_, groups) in groupsByTeeGroup.sorted(by: { $0.key < $1.key }) {
                let sortedGroups = groups.sorted { lhs, rhs in
                    let lhsTeam = lhs.teamID.flatMap { teamOrder[$0] } ?? lhs.teamID ?? ""
                    let rhsTeam = rhs.teamID.flatMap { teamOrder[$0] } ?? rhs.teamID ?? ""
                    if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
                    let lhsLabel = lhs.label ?? lhs.id
                    let rhsLabel = rhs.label ?? rhs.id
                    return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
                }
                guard sortedGroups.count == 2 else { continue }
                if seriesRound.roundConfig.matchupMode == .teeGroupPartnerships {
                    let teamIDs = Set(sortedGroups.compactMap(\.teamID).filter(\.isPopulated))
                    guard teamIDs.count == 2 else { continue }
                }
                matchups.append(
                    TeamMatchup(
                        id: "score_owner_\(sortedGroups[0].id)_\(sortedGroups[1].id)",
                        teamIDs: [],
                        participantIDs: nil,
                        scoreOwnerIDs: [sortedGroups[0].id, sortedGroups[1].id],
                        scoreOwnerScope: nil,
                        mode: .partnership
                    )
                )
            }

            if matchups.isPopulated {
                return matchups
            }
        }

        return matchupPlans.compactMap { plan -> TeamMatchup? in
            switch seriesRound.roundConfig.matchupMode {
            case .teamVsTeam:
                guard let teamA = teamMappings[plan.teamAID]?.roundTeamID,
                      let teamB = teamMappings[plan.teamBID]?.roundTeamID else { return nil }
                return TeamMatchup(id: plan.id, teamIDs: [teamA, teamB], participantIDs: nil, mode: .team)
            case .individualVsIndividual:
                guard let memberAID = plan.memberAID,
                      let memberBID = plan.memberBID,
                      let participantAID = resolvedParticipantIDs[memberAID],
                      let participantBID = resolvedParticipantIDs[memberBID] else {
                    return nil
                }
                return TeamMatchup(
                    id: plan.id,
                    teamIDs: [],
                    participantIDs: [participantAID, participantBID],
                    mode: .individual
                )
            case .teeGroupPartnerships, .none, .field:
                return nil
            }
        }
    }

    static func buildRoundScoringGroups(
        roundID: String,
        seriesRound: SeriesRound,
        participants: [RoundParticipant],
        partnershipPlans: [SeriesRoundPartnershipPlan],
        teeGroups: [TeeTimeGroup]
    ) -> [RoundScoringGroup] {
        let participantEntries: [(String, RoundParticipant)] = participants.compactMap { participant in
            guard let seriesMemberID = participant.seriesMemberID else { return nil }
            return (seriesMemberID, participant)
        }
        let participantByMemberID: [String: RoundParticipant] = Dictionary(uniqueKeysWithValues: participantEntries)

        let partnershipGroups: [RoundScoringGroup] = partnershipPlans.compactMap { plan -> RoundScoringGroup? in
            let resolvedParticipants = plan.memberIDs.compactMap { participantByMemberID[$0] }
            guard resolvedParticipants.count == 2 else { return nil }
            let groupIDs = Set(resolvedParticipants.compactMap(\.groupID).filter(\.isPopulated))
            let teamIDs = Set(resolvedParticipants.compactMap(\.teamID).filter(\.isPopulated))
            guard groupIDs.count == 1, teamIDs.count == 1 else { return nil }
            return RoundScoringGroup(
                id: plan.id.isPopulated ? plan.id : HackersID.string(),
                teamID: teamIDs.first,
                teeGroupID: groupIDs.first,
                kind: .partnership,
                memberIDs: resolvedParticipants.map(\.id),
                label: plan.label,
                seedSeriesPodID: plan.seedSeriesPodID,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
        }

        let participantGroups: [String: [RoundParticipant]] = Dictionary(grouping: participants) { $0.groupID ?? "" }
        let teeGroupScoringGroups: [RoundScoringGroup] = teeGroups.compactMap { teeGroup -> RoundScoringGroup? in
            let members = participantGroups[teeGroup.id] ?? []
            guard members.count >= 2 else { return nil }
            return RoundScoringGroup(
                id: "tee_group_\(teeGroup.id)",
                teamID: nil,
                teeGroupID: teeGroup.id,
                kind: .teeGroup,
                memberIDs: members.map(\.id),
                label: teeGroup.name,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )
        }

        switch seriesRound.roundConfig.scoreOwnerScope {
        case .individual:
            return partnershipGroups
        case .partnership:
            return partnershipGroups
        case .teeGroup:
            return partnershipGroups + teeGroupScoringGroups
        }
    }

    static func buildScoringUnits(
        seriesRound: SeriesRound,
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup],
        teamMappings: [String: SeriesToRoundTeamLink] = [:]
    ) -> [ScoringUnit] {
        let template = seriesRound.roundConfig.template
        let handicapConfig = seriesRound.roundConfig.sharedScoreHandicapConfig ?? template.requirements.defaultHandicapConfig

        switch seriesRound.roundConfig.scoreOwnerScope {
        case .individual:
            if template.scoreSource == .shared,
               seriesRound.roundConfig.legacyGameFormat.configuration.requiresTeams,
               teamMappings.isPopulated {
                return teamMappings.values
                    .sorted { lhs, rhs in
                        if lhs.seriesTeamID != rhs.seriesTeamID { return lhs.seriesTeamID < rhs.seriesTeamID }
                        return lhs.roundTeamID < rhs.roundTeamID
                    }
                    .map { link in
                        let teamParticipants = participants.filter { $0.teamID == link.roundTeamID }
                        let allowance = handicapAllowance(
                            participants: teamParticipants,
                            config: handicapConfig
                        )
                        return ScoringUnit(
                            id: link.roundTeamID,
                            owner: .team,
                            ownerIDs: [link.roundTeamID],
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole),
                            handicapAdjustments: allowance?.memberStrokes,
                            handicapAllowance: allowance
                        )
                    }
            }
            return participants.map { participant in
                ScoringUnit(
                    id: participant.id,
                    owner: .participant,
                    ownerIDs: [participant.id],
                    scoringMethod: .individual,
                    handicapAllowance: handicapAllowance(
                        participants: [participant],
                        config: .individualStrokePlay
                    )
                )
            }
        case .partnership:
            if template.scoreSource == .shared {
                return scoringGroups
                    .filter { $0.kind == .partnership }
                    .map { group in
                        let groupParticipants = participantsForScoringGroup(group, participants: participants)
                        let allowance = handicapAllowance(
                            participants: groupParticipants,
                            config: handicapConfig
                        )
                        return ScoringUnit(
                            id: group.id,
                            owner: .scoreOwner,
                            ownerIDs: group.memberIDs,
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole),
                            handicapAdjustments: allowance?.memberStrokes,
                            handicapAllowance: allowance
                        )
                    }
            }
            return participants.map { participant in
                ScoringUnit(
                    id: participant.id,
                    owner: .participant,
                    ownerIDs: [participant.id],
                    scoringMethod: .individual,
                    handicapAllowance: handicapAllowance(
                        participants: [participant],
                        config: .individualStrokePlay
                    )
                )
            }
        case .teeGroup:
            return scoringGroups
                .filter { $0.kind == .teeGroup }
                .map { group in
                        let groupParticipants = participantsForScoringGroup(group, participants: participants)
                        let allowance = handicapAllowance(
                            participants: groupParticipants,
                            config: handicapConfig
                        )
                        return ScoringUnit(
                            id: group.id,
                            owner: .scoreOwner,
                            ownerIDs: group.memberIDs,
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole),
                            handicapAdjustments: allowance?.memberStrokes,
                            handicapAllowance: allowance
                        )
                    }
        }
    }

    private static func participantsForScoringGroup(
        _ group: RoundScoringGroup,
        participants: [RoundParticipant]
    ) -> [RoundParticipant] {
        let participantsByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        return group.memberIDs.compactMap { participantsByID[$0] }
    }

    private static func handicapAllowance(
        participants: [RoundParticipant],
        config: HandicapConfiguration
    ) -> ScoringUnitHandicapAllowance? {
        let orderedMembers = participants.sorted {
            if $0.adjustedHandicap != $1.adjustedHandicap {
                return $0.adjustedHandicap < $1.adjustedHandicap
            }
            return $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
        }
        guard orderedMembers.isPopulated else { return nil }

        let memberStrokes: [String: Double]
        if let percentages = config.positionPercentages, percentages.isPopulated {
            var strokes: [String: Double] = [:]
            for (index, participant) in orderedMembers.enumerated() {
                guard index < percentages.count else { break }
                strokes[participant.id] = Double(participant.adjustedHandicap) * percentages[index] * config.percentage
            }
            memberStrokes = strokes
        } else if config.isTeamCombined {
            memberStrokes = Dictionary(uniqueKeysWithValues: orderedMembers.map { participant in
                (participant.id, Double(participant.adjustedHandicap) * config.percentage)
            })
        } else {
            let average = Double(orderedMembers.map(\.adjustedHandicap).reduce(0, +)) / Double(orderedMembers.count)
            let unitStrokes = average * config.percentage
            let perMember = unitStrokes / Double(orderedMembers.count)
            memberStrokes = Dictionary(uniqueKeysWithValues: orderedMembers.map { ($0.id, perMember) })
        }

        let unitStrokes = memberStrokes.values.reduce(0.0, +)
        return ScoringUnitHandicapAllowance(
            unitStrokes: unitStrokes,
            memberStrokes: memberStrokes,
            sourceConfig: config
        )
    }

    /// Recalculates only the persisted handicap allowance for existing scoring
    /// units. Ownership and aggregation stay untouched, which makes this safe
    /// for historical commissioner repairs across individual, partnership,
    /// tee-group, and team scoring vectors.
    static func refreshingHandicapAllowances(
        in scoringUnits: [ScoringUnit],
        participants: [RoundParticipant]
    ) -> [ScoringUnit] {
        let participantsByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })

        return scoringUnits.map { unit in
            let participantIDs: [String] = {
                let recordedIDs = Set(
                    (unit.handicapAllowance.map { Array($0.memberStrokes.keys) } ?? [])
                        + (unit.handicapAdjustments.map { Array($0.keys) } ?? [])
                )
                if recordedIDs.isPopulated {
                    return recordedIDs.sorted()
                }
                switch unit.owner {
                case .participant, .scoreOwner:
                    return unit.ownerIDs.filter { participantsByID[$0] != nil }
                case .team:
                    let teamIDs = Set(unit.ownerIDs)
                    return participants
                        .filter { participant in
                            participant.teamID.map(teamIDs.contains) == true
                        }
                        .map(\.id)
                }
            }()

            let members = participantIDs.compactMap { participantsByID[$0] }
            guard members.isPopulated else { return unit }

            let sourceConfig = unit.handicapAllowance?.sourceConfig ?? .individualStrokePlay
            let allowance = handicapAllowance(participants: members, config: sourceConfig)
            var updated = unit
            updated.handicapAllowance = allowance
            if unit.handicapAdjustments != nil {
                updated.handicapAdjustments = allowance?.memberStrokes
            }
            return updated
        }
    }

    static func buildRoundSegment(
        roundID: String,
        series: Series,
        seriesRound: SeriesRound,
        courseSegment: CourseSegment,
        competitionScope: CompetitionScope,
        matchups: [TeamMatchup],
        scoringUnits: [ScoringUnit]
    ) -> RoundSegment {
        RoundSegment(
            id: HackersID.string(),
            roundID: roundID,
            holeRange: courseSegment.holeRange,
            gameFormat: primaryGameFormat(series: series, seriesRound: seriesRound),
            templateID: seriesRound.roundConfig.formatTemplateID,
            scoringUnits: scoringUnits,
            matchups: matchups.isEmpty ? nil : matchups,
            competitionScope: competitionScope,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    static func seriesRoundParticipantMapping(
        seriesRoundID: String,
        seriesID: String,
        memberID: String,
        participantID: String
    ) -> SeriesRoundMapping {
        SeriesRoundMapping(
            id: "\(seriesRoundID)_participant_\(participantID)",
            seriesRoundID: seriesRoundID,
            roundOwnerType: .participant,
            roundOwnerID: participantID,
            competitorType: .member,
            competitorID: memberID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
    }

    static func seriesRoundTeamMapping(
        seriesRoundID: String,
        seriesID: String,
        link: SeriesToRoundTeamLink
    ) -> SeriesRoundMapping {
        SeriesRoundMapping(
            id: "\(seriesRoundID)_team_\(link.roundTeamID)",
            seriesRoundID: seriesRoundID,
            roundOwnerType: .team,
            roundOwnerID: link.roundTeamID,
            competitorType: .team,
            competitorID: link.seriesTeamID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
    }

    static func seriesRoundScoreOwnerMappings(
        seriesRoundID: String,
        seriesID: String,
        scoringGroup: RoundScoringGroup,
        participants: [RoundParticipant],
        teamMappings: [String: SeriesToRoundTeamLink]
    ) -> [SeriesRoundMapping] {
        let participantByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let memberMappings = scoringGroup.memberIDs.compactMap { participantID -> SeriesRoundMapping? in
            guard let participant = participantByID[participantID],
                  let memberID = participant.seriesMemberID else { return nil }
            return SeriesRoundMapping(
                id: "\(seriesRoundID)_score_owner_member_\(scoringGroup.id)_\(memberID)",
                seriesRoundID: seriesRoundID,
                roundOwnerType: .scoreOwner,
                roundOwnerID: scoringGroup.id,
                competitorType: .member,
                competitorID: memberID,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
        }

        let teamMapping: SeriesRoundMapping? = scoringGroup.teamID.flatMap { roundTeamID in
            guard let link = teamMappings.values.first(where: { $0.roundTeamID == roundTeamID }) else { return nil }
            return SeriesRoundMapping(
                id: "\(seriesRoundID)_score_owner_team_\(scoringGroup.id)_\(link.seriesTeamID)",
                seriesRoundID: seriesRoundID,
                roundOwnerType: .scoreOwner,
                roundOwnerID: scoringGroup.id,
                competitorType: .team,
                competitorID: link.seriesTeamID,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
        }

        return memberMappings + (teamMapping.map { [$0] } ?? [])
    }
}

struct SeriesRoundResolvedPlan: Equatable {
    let competitionScope: CompetitionScope
    let roundConfiguration: RoundConfiguration
    let plannedStructure: SeriesRoundPlannedStructure
    let matchupPlans: [SeriesRoundMatchupPlan]
    let partnershipPlans: [SeriesRoundPartnershipPlan]
    let teeGroupPlans: [SeriesRoundCreationMapping.TeeGroupPlan]
    let seriesTeamsForRound: [SeriesTeam]

    init(
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        courseSegment: CourseSegment
    ) {
        competitionScope = SeriesRoundCreationMapping.resolvedCompetitionScope(for: seriesRound)
        roundConfiguration = SeriesRoundCreationMapping.roundConfiguration(
            series: series,
            seriesRound: seriesRound,
            courseSegment: courseSegment,
            competitionScope: competitionScope
        )
        plannedStructure = SeriesRoundPlanningService.resolvedPlannedStructure(
            series: series,
            seriesRound: seriesRound,
            members: members,
            teams: teams,
            pods: pods,
            courseSelection: Self.courseSelection(from: courseSegment)
        )
        matchupPlans = plannedStructure.matchups.map(\.matchupPlan)
        partnershipPlans = SeriesRoundCreationMapping.resolvedPartnershipPlans(
            seriesRound: seriesRound,
            teams: teams,
            pods: pods,
            members: members
        )
        teeGroupPlans = SeriesRoundCreationMapping.teeGroupPlansWithAdjacentPartnerships(
            SeriesRoundPlanningService.teeGroupPlans(from: plannedStructure.teeGroups),
            partnershipPlans: partnershipPlans
        )
        let representedTeamIDs = plannedStructure.teeGroups
            .flatMap(\.seats)
            .compactMap(\.representedTeamID)
            .filter(\.isPopulated)
        let participatingTeamIDs = Set(members.compactMap(\.teamID).filter(\.isPopulated) + representedTeamIDs)
        seriesTeamsForRound = seriesRound.roundConfig.teamAssignmentMode == .seriesTeams
            ? teams.filter { participatingTeamIDs.contains($0.id) }
            : []
    }

    private static func courseSelection(from segment: CourseSegment) -> SeriesCourseSelection {
        let defaultTee = segment.defaultTee.flatMap { segment.tee(from: $0) }
        return SeriesCourseSelection(
            courseID: segment.courseInfo.seriesCourseSelectionID,
            cachedName: segment.courseInfo.name,
            defaultTeeBoxID: segment.defaultTee ?? "",
            defaultTeeName: defaultTee?.name,
            defaultTeeGender: defaultTee?.gender,
            holeSegment: segment.holeSegment
        )
    }
}

enum SeriesRoundPlanningService {

    static func resolvedPlannedStructure(
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        courseSelection: SeriesCourseSelection?
    ) -> SeriesRoundPlannedStructure {
        let activeMembers = members.filter(\.isActive)
        let eligibleMembers = activeMembers.filter { $0.role != .spectator }
        let schedulableMembers = eligibleMembers.filter { $0.role != .substitute }
        let autoMatchupPlans = SeriesRoundCreationMapping.resolvedMatchupPlans(
            seriesRound: seriesRound,
            teams: teams,
            members: schedulableMembers
        )

        let effectiveMatchupPlans: [SeriesRoundMatchupPlan]
        if seriesRound.plannedMatchups.isPopulated {
            effectiveMatchupPlans = normalizePlannedMatchups(
                seriesRound.plannedMatchups,
                fallback: autoMatchupPlans
            ).map(\.matchupPlan)
        } else if seriesRound.matchupPlans.isPopulated {
            effectiveMatchupPlans = seriesRound.matchupPlans.sorted { $0.index < $1.index }
        } else {
            effectiveMatchupPlans = autoMatchupPlans
        }

        let basePlannedMatchups = normalizePlannedMatchups(
            seriesRound.plannedMatchups,
            fallback: effectiveMatchupPlans
        )

        let autoTeeGroups = autoPlannedTeeGroups(
            seriesRound: seriesRound,
            members: schedulableMembers,
            teams: teams,
            pods: pods,
            matchupPlans: effectiveMatchupPlans,
            courseSelection: courseSelection
        )

        let plannedTeeGroups = normalizePlannedTeeGroups(
            seriesRound.plannedTeeGroups,
            fallback: autoTeeGroups,
            allMembers: eligibleMembers,
            holeRange: courseSelection?.holeSegment.holeRange ?? .init(startHole: 1, endHole: 18)
        )

        let replacements = SeriesRoundParticipationPolicy.replacementPlan(
            plannedTeeGroups: plannedTeeGroups,
            membersByID: Dictionary(uniqueKeysWithValues: eligibleMembers.map { ($0.id, $0) })
        )
        let plannedMatchups = replacements.applying(to: basePlannedMatchups.map(\.matchupPlan))
            .enumerated()
            .map { index, matchupPlan in
                var item = basePlannedMatchups[index]
                item.plan = matchupPlan
                item.id = matchupPlan.id
                return item
            }

        return .init(matchups: plannedMatchups, teeGroups: plannedTeeGroups)
    }

    static func normalizePlannedMatchups(
        _ existing: [SeriesRoundPlannedMatchup],
        fallback: [SeriesRoundMatchupPlan]
    ) -> [SeriesRoundPlannedMatchup] {
        if existing.isPopulated {
            return existing
                .sorted { $0.matchupPlan.index < $1.matchupPlan.index }
                .enumerated()
                .map { index, item in
                    var updated = item
                    var plan = updated.matchupPlan
                    plan.index = index
                    updated.plan = plan
                    updated.id = plan.id
                    return updated
                }
        }

        return fallback
            .sorted { $0.index < $1.index }
            .enumerated()
            .map { index, plan in
                var updatedPlan = plan
                updatedPlan.index = index
                return SeriesRoundPlannedMatchup(plan: updatedPlan, source: .autoGenerated)
            }
    }

    static func autoPlannedTeeGroups(
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        matchupPlans: [SeriesRoundMatchupPlan],
        courseSelection: SeriesCourseSelection?
    ) -> [SeriesRoundPlannedTeeGroup] {
        let holeRange = courseSelection?.holeSegment.holeRange ?? .init(startHole: 1, endHole: 18)
        let scheduledTeeTime = seriesRound.scheduledAt.map { Date(timeIntervalSince1970: $0.unix) }
        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: pods,
            matchupPlans: matchupPlans,
            seriesRound: seriesRound
        )
        let payload = SeriesRoundCreationMapping.buildTeeGroupsArray(
            roundID: "planned_round",
            groupPlans: plans,
            holeRange: holeRange,
            useSequentialStarts: seriesRound.roundConfig.usesSequentialTeeStarts,
            scheduledTeeTime: scheduledTeeTime
        )
        let effectivePlans = plans.isPopulated ? plans : [.init(id: "group_0", memberIDs: [])]

        return zip(effectivePlans, payload).enumerated().map { index, item in
            let seats = item.0.seats.map { seat in
                SeriesRoundPlannedSeat(
                    id: seat.memberID,
                    memberID: seat.memberID,
                    teeOrder: seat.teeOrder,
                    source: .autoGenerated
                )
            }
            return SeriesRoundPlannedTeeGroup(
                id: item.0.id,
                index: index,
                teeTime: item.1.teeTime,
                startingHole: item.1.startingHole,
                seats: seats,
                source: .autoGenerated
            )
        }
    }

    static func normalizePlannedTeeGroups(
        _ existing: [SeriesRoundPlannedTeeGroup],
        fallback: [SeriesRoundPlannedTeeGroup],
        allMembers: [SeriesMember],
        holeRange: HoleRange
    ) -> [SeriesRoundPlannedTeeGroup] {
        guard existing.isPopulated else { return fallback }

        let membersByID = Dictionary(uniqueKeysWithValues: allMembers.map { ($0.id, $0) })
        let replacements = SeriesRoundParticipationPolicy.replacementPlan(
            plannedTeeGroups: existing,
            membersByID: membersByID
        )
        let substituteToOriginal = replacements.substituteToOriginal
        var seenMemberIDs = Set<String>()

        var groups = existing
            .sorted { $0.index < $1.index }
            .enumerated()
            .map { index, group -> SeriesRoundPlannedTeeGroup in
                var updated = group
                updated.index = index
                updated.startingHole = holeRange.holeNumbers.contains(group.startingHole)
                    ? group.startingHole
                    : holeRange.startHole
                let seats = group.seats
                    .sorted { lhs, rhs in
                        if lhs.teeOrder != rhs.teeOrder { return lhs.teeOrder < rhs.teeOrder }
                        return lhs.memberID < rhs.memberID
                    }
                    .compactMap { seat -> SeriesRoundPlannedSeat? in
                        guard seat.memberID.isPopulated,
                              let member = membersByID[seat.memberID],
                              !seenMemberIDs.contains(seat.memberID) else { return nil }

                        if SeriesRoundParticipationPolicy.isAutomaticPlayer(member) {
                            guard !replacements.replacedMemberIDs.contains(member.id) else { return nil }
                        } else {
                            guard member.isActive,
                                  member.role == .substitute,
                                  seat.isSubstitute,
                                  let originalID = substituteToOriginal[member.id],
                                  seat.substituteForSeriesMemberID == originalID else {
                                return nil
                            }
                        }

                        seenMemberIDs.insert(seat.memberID)
                        return SeriesRoundPlannedSeat(
                            id: seat.id,
                            memberID: seat.memberID,
                            teeOrder: max(1, seat.teeOrder),
                            source: seat.source,
                            isSubstitute: member.role == .substitute,
                            substituteForSeriesMemberID: member.role == .substitute
                                ? seat.substituteForSeriesMemberID
                                : nil,
                            substituteForName: member.role == .substitute
                                ? seat.substituteForName
                                : nil,
                            representedTeamID: member.role == .substitute
                                ? seat.representedTeamID
                                : nil
                        )
                    }
                updated.seats = seats.enumerated().map { offset, seat in
                    var next = seat
                    next.teeOrder = offset + 1
                    return next
                }
                return updated
            }
            .filter { $0.seats.isPopulated || $0.source == .manualOverride }

        groups = groups.enumerated().map { index, group in
            var updated = group
            updated.index = index
            return updated
        }

        let leftovers = allMembers.filter { member in
            SeriesRoundParticipationPolicy.isAutomaticPlayer(member)
                && !replacements.replacedMemberIDs.contains(member.id)
                && !seenMemberIDs.contains(member.id)
        }
        guard leftovers.isPopulated else { return groups }

        let baseIndex = groups.count
        let appended = stride(from: 0, to: leftovers.count, by: 4).enumerated().map { pair in
            let chunk = Array(leftovers[pair.element..<min(pair.element + 4, leftovers.count)])
            return SeriesRoundPlannedTeeGroup(
                id: "planned_group_\(baseIndex + pair.offset)",
                index: baseIndex + pair.offset,
                teeTime: nil,
                startingHole: TeeTimeGroup.sequentialStartingHole(
                    forSequenceIndex: baseIndex + pair.offset,
                    in: holeRange
                ),
                seats: chunk.enumerated().map { offset, member in
                    SeriesRoundPlannedSeat(
                        id: member.id,
                        memberID: member.id,
                        teeOrder: offset + 1,
                        source: .autoGenerated
                    )
                },
                source: .autoGenerated
            )
        }
        groups.append(contentsOf: appended)
        return groups
    }

    static func teeGroupPlans(
        from plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    ) -> [SeriesRoundCreationMapping.TeeGroupPlan] {
        let groups = plannedTeeGroups
            .sorted { $0.index < $1.index }
            .map { group in
                SeriesRoundCreationMapping.TeeGroupPlan(
                    id: group.id.isPopulated ? group.id : "planned_group_\(group.index)",
                    seats: group.seats.map {
                        SeriesRoundCreationMapping.TeeGroupSeat(
                            memberID: $0.memberID,
                            teeOrder: $0.teeOrder
                        )
                    }
                )
            }
        return groups.isPopulated ? groups : [.init(id: "group_0", memberIDs: [])]
    }

    static func teeGroupsPayload(
        roundID: String,
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup],
        createdAt: Time
    ) -> [TeeTimeGroup] {
        let groups = plannedTeeGroups
            .sorted { $0.index < $1.index }
            .enumerated()
            .map { index, group in
                TeeTimeGroup(
                    id: HackersID.string(),
                    index: index,
                    teeTime: group.teeTime,
                    startingHole: group.startingHole,
                    lastCompletedHole: nil,
                    createdAt: createdAt,
                    lastUpdatedAt: createdAt,
                    parentID: roundID
                )
            }
        return groups.isPopulated
            ? groups
            : [
                TeeTimeGroup(
                    id: HackersID.string(),
                    index: 0,
                    teeTime: nil,
                    startingHole: 1,
                    lastCompletedHole: nil,
                    createdAt: createdAt,
                    lastUpdatedAt: createdAt,
                    parentID: roundID
                )
            ]
    }
}

/// An explicit commissioner input for one planned round. Personal Indexes always use the
/// 18-hole basis; strokes are the final allowance for the holes actually being played.
struct SeriesRoundHandicapInput: Hashable, Codable {
    enum Method: String, Codable, CaseIterable {
        case personalIndex
        case strokes
    }

    var method: Method
    var value: Double
    var teeBoxID: String?

    var isValid: Bool {
        guard value.isFinite else { return false }
        switch method {
        case .personalIndex: return (-10...54).contains(value) && abs(value * 10 - (value * 10).rounded()) < 0.000_001
        case .strokes: return value >= 0 && value <= Double(Int32.max) && value.rounded() == value
        }
    }
}

/// Unsaved editor state survives closing/reopening the setup sheet, including invalid text.
struct SeriesRoundHandicapDraft: Equatable, Codable {
    enum Method: String, CaseIterable, Codable {
        case series = "Series handicap"
        case personalIndex = "Handicap Index"
        case strokes = "Strokes Received"
    }

    var method: Method = .personalIndex
    var text: String = ""
    var teeBoxID: String = ""

    init(input: SeriesRoundHandicapInput? = nil, seriesIndex: Double? = nil, personalIndex: Double? = nil, teeBoxID: String) {
        self.teeBoxID = input?.teeBoxID ?? teeBoxID
        if let input {
            method = input.method == .personalIndex ? .personalIndex : .strokes
            text = SeriesMemberHandicap.formatHandicapIndexForDisplay(input.value)
        } else if seriesIndex != nil {
            method = .series
        } else if let personalIndex {
            text = SeriesMemberHandicap.formatHandicapIndexForDisplay(personalIndex)
        }
    }

    var input: SeriesRoundHandicapInput? {
        guard method != .series,
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) else { return nil }
        let input = SeriesRoundHandicapInput(
            method: method == .personalIndex ? .personalIndex : .strokes,
            value: value, teeBoxID: teeBoxID
        )
        return input.isValid ? input : nil
    }
}

/// Shared preflight for the review screen and the actual round writer. The series
/// computation remains independent from the round-only personal/manual inputs.
enum SeriesRoundHandicapSetup {
    enum DraftError: Error { case invalidInput(String), roundUnavailable }

    static func updating(_ current: SeriesRound, from candidate: SeriesRound) throws -> SeriesRound {
        guard current.id == candidate.id, current.parentID == candidate.parentID,
              current.status == .planned, current.roundID == nil,
              current.lastUpdatedAt == candidate.lastUpdatedAt,
              candidate.handicapInputs.values.allSatisfy(\.isValid) else { throw DraftError.roundUnavailable }
        var updated = current
        updated.handicapInputs = candidate.handicapInputs
        updated.courseOverride = candidate.courseOverride
        updated.roundConfig.scoreBasisOverride = candidate.roundConfig.scoreBasisOverride
        updated.lastUpdatedAt = .init()
        return updated
    }

    static func applying(drafts: [String: SeriesRoundHandicapDraft], to round: SeriesRound) throws -> SeriesRound {
        var result = round
        for (memberID, draft) in drafts {
            if draft.method == .series { result.handicapInputs[memberID] = nil }
            else if let input = draft.input { result.handicapInputs[memberID] = input }
            else if !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || round.handicapInputs[memberID] != nil {
                throw DraftError.invalidInput(memberID)
            }
        }
        return result
    }

    static func requiresHandicaps(series: Series, round: SeriesRound) -> Bool {
        SeriesRoundCreationMapping.primaryGameFormat(series: series, seriesRound: round).configuration.basis == .net
    }

    static func issues(
        series: Series, round: SeriesRound, members: [SeriesMember],
        handicaps: [String: SeriesMemberHandicap], course: CourseSegment
    ) -> [SeriesCourseHandicapValidationIssue] {
        guard requiresHandicaps(series: series, round: round) else { return [] }
        return members.compactMap { member in
            return resolution(series: series, round: round, member: member,
                              handicaps: handicaps, course: course).validationIssue
        }
    }

    static func resolution(
        series: Series, round: SeriesRound, member: SeriesMember,
        handicaps: [String: SeriesMemberHandicap], course: CourseSegment
    ) -> SeriesCourseHandicapResolution {
        let resolution = SeriesCourseHandicapResolver.resolve(
            effectiveIndex: handicaps[member.id]?.effectiveIndex,
            member: member, courseSegment: course,
            entryFormat: round.roundConfig.handicapEntryFormat,
            handicapStrokeBasis: series.handicapConfig.strokeBasis,
            maximumHandicap: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
            roundInput: round.handicapInputs[member.id]
        )
        if !round.handicapInputs.isEmpty, round.handicapInputs[member.id] == nil,
           round.roundConfig.handicapEntryFormat == .strokes {
            return SeriesCourseHandicapResolver.onPlayedHoleBasis(resolution,
                sourceBasis: round.roundConfig.handicapStrokeBasis ?? .defaultBasis(holeCount: course.holeSegment.holeCount),
                holeCount: course.holeSegment.holeCount)
        }
        return resolution
    }
}


/// Presentation-independent readiness for both course-selection paths. All calculations
/// come from the same resolver used by the writer; invalid local edits cannot fall back
/// to an older saved value and incorrectly appear ready.
struct SeriesRoundHandicapReadiness {
    struct Player: Identifiable {
        let member: SeriesMember
        let resolution: SeriesCourseHandicapResolution
        let issue: SeriesCourseHandicapValidationIssue?
        let source: String
        var strokes: Int?
        var allocationContext: String? = nil

        var id: String { member.id }
        var isReady: Bool { issue == nil }
        var summary: String {
            guard isReady else { return issueSummary }
            guard let strokes else { return "No handicap set · Gross scoring" }
            if resolution.entryFormat == .courseHandicap, let index = resolution.handicapIndex {
                return "Index \(ManualPersonalHandicap.display(index)) → \(strokes) strokes"
            }
            return "\(strokes) strokes · \(source == "Manual Strokes" ? "Manual entry" : source)"
        }
        var issueSummary: String {
            guard let issue else { return "Ready" }
            let handicapFields = issue.missingFields.filter { $0.contains("handicap") || $0.contains("index") || $0.contains("Index") || $0.contains("strokes") }
            let courseFields = issue.missingFields.filter { !handicapFields.contains($0) }
            var messages: [String] = []
            if !handicapFields.isEmpty { messages.append("Enter a valid Handicap Index or whole-number strokes.") }
            if !courseFields.isEmpty { messages.append("Review tee data: " + courseFields.joined(separator: ", ") + ".") }
            return messages.joined(separator: " ")
        }
        var maximumSummary: String? {
            guard let maximum = resolution.calculation.maximumIndex,
                  let index = resolution.handicapIndex, index > Double(maximum) else { return nil }
            return "Original Index \(ManualPersonalHandicap.display(index)) · Series maximum \(maximum) applied before tee conversion"
        }
        var allocationSummary: String? {
            if let allocationContext { return allocationContext }
            guard let strokes, resolution.entryFormat == .courseHandicap,
                  let courseHandicap = resolution.calculation.courseHandicap,
                  strokes != courseHandicap else { return nil }
            return "Course Handicap \(courseHandicap) · \(strokes) strokes received for the holes played"
        }
    }

    let players: [Player]
    var readyCount: Int { players.filter(\.isReady).count }
    var affectedMemberIDs: Set<String> { Set(players.filter { !$0.isReady }.map(\.id)) }
    var isReady: Bool { affectedMemberIDs.isEmpty }
    var title: String { isReady ? "Ready to Start" : "Handicap Setup Needed" }
    var summary: String {
        isReady ? "\(readyCount) of \(players.count) players ready"
            : "\(players.count - readyCount) of \(players.count) players need attention"
    }
}

extension SeriesRoundHandicapSetup {
    static func readiness(
        series: Series, round: SeriesRound, members: [SeriesMember],
        handicaps: [String: SeriesMemberHandicap], course: CourseSegment,
        drafts: [String: SeriesRoundHandicapDraft] = [:],
        presenceStatusByMemberID: [String: RoundParticipantPresenceStatus] = [:]
    ) -> SeriesRoundHandicapReadiness {
        var candidate = round
        var previewHandicaps = handicaps
        var invalidMemberIDs = Set<String>()
        for member in members {
            guard let draft = drafts[member.id] else { continue }
            if draft.method == .series { candidate.handicapInputs[member.id] = nil }
            else if let input = draft.input { candidate.handicapInputs[member.id] = input }
            else {
                candidate.handicapInputs[member.id] = nil
                previewHandicaps[member.id] = nil
                if requiresHandicaps(series: series, round: round)
                    || round.handicapInputs[member.id] != nil
                    || !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidMemberIDs.insert(member.id)
                    // Preserve the chosen entry method and tee while validating bad text.
                    // This temporary unresolved input is never persisted by applying(drafts:to:).
                    candidate.handicapInputs[member.id] = .init(
                        method: draft.method == .personalIndex ? .personalIndex : .strokes,
                        value: .nan, teeBoxID: draft.teeBoxID)
                }
            }
        }
        let issuesByID = Dictionary(uniqueKeysWithValues: issues(series: series, round: candidate,
            members: members, handicaps: previewHandicaps, course: course).map { ($0.memberID, $0) })
        var players: [SeriesRoundHandicapReadiness.Player] = members.map { member in
            let resolved = resolution(series: series, round: candidate, member: member,
                handicaps: previewHandicaps, course: course)
            var issue = issuesByID[member.id]
            if invalidMemberIDs.contains(member.id) {
                issue = SeriesCourseHandicapValidationIssue(memberID: member.id,
                    memberName: member.name.fullName, teeBoxID: resolved.tee?.id ?? "",
                    teeName: resolved.tee?.name,
                    missingFields: ["valid handicap input"] + (issue?.missingFields.filter { $0 != "handicap index" } ?? []))
            }
            let source: String
            switch candidate.handicapInputs[member.id]?.method {
            case .personalIndex: source = "Personal Index"
            case .strokes: source = "Manual Strokes"
            case nil: source = "Series"
            }
            let strokes = resolved.effectiveStrokes.map {
                ScoringEngine.handicapStrokesForPlayedHoles(handicap: $0,
                    basis: resolved.entryFormat == .courseHandicap || !candidate.handicapInputs.isEmpty
                        ? .defaultBasis(holeCount: course.holeSegment.holeCount)
                        : (candidate.roundConfig.handicapStrokeBasis ?? .defaultBasis(holeCount: course.holeSegment.holeCount)),
                    holesInPlay: course.holeSegment.holeCount)
            }
            return .init(member: member, resolution: resolved, issue: issue, source: source, strokes: strokes)
        }
        let basis = SeriesRoundCreationMapping.primaryGameFormat(series: series, seriesRound: candidate).configuration.basis
        if basis == .net, candidate.roundConfig.handicapNormalizationMode == .field,
           players.allSatisfy({ $0.isReady && $0.resolution.effectiveStrokes != nil }) {
            let participants = players.map { player in
                RoundParticipant(id: player.id, adjustedHandicap: player.resolution.effectiveStrokes!,
                    presenceStatus: presenceStatusByMemberID[player.id] ?? .active,
                    isSubstitute: candidate.plannedTeeGroups.flatMap(\.seats).contains { $0.memberID == player.id && $0.isSubstitute })
            }
            let eligible = ScoringEngine.scoringEligibleParticipants(participants,
                substitutesScore: candidate.policyBinding?.resolvedSubstitutesScore ?? series.settings.substitutesScore,
                attendanceConfirmationEnabled: series.settings.isAttendanceEnabled)
            let normalized = Dictionary(uniqueKeysWithValues: HandicapCalculator.normalizedParticipantsForField(eligible).map { ($0.id, $0.adjustedHandicap) })
            for index in players.indices {
                guard let allowance = normalized[players[index].id] else { continue }
                let resolved = players[index].resolution
                let strokes = ScoringEngine.handicapStrokesForPlayedHoles(handicap: allowance,
                    basis: resolved.entryFormat == .courseHandicap || !candidate.handicapInputs.isEmpty
                        ? .defaultBasis(holeCount: course.holeSegment.holeCount)
                        : (candidate.roundConfig.handicapStrokeBasis ?? .defaultBasis(holeCount: course.holeSegment.holeCount)),
                    holesInPlay: course.holeSegment.holeCount)
                players[index].strokes = strokes
                if let original = resolved.effectiveStrokes, original != allowance {
                    let label = resolved.entryFormat == .courseHandicap ? "Course Handicap" : "Round allowance"
                    players[index].allocationContext = "\(label) \(original) · \(strokes) strokes received after field normalization to the lowest handicap"
                }
            }
        }
        return SeriesRoundHandicapReadiness(players: players)
    }
}
