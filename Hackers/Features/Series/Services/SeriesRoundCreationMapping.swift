//
//  SeriesRoundCreationMapping.swift
//  Hackers
//
//  Pure mapping from series round + roster state into round documents used when starting a live round.
//  Covered by SeriesRoundCreationMappingTests.
//

import Foundation

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

    private static func primaryGameFormat(series: Series, seriesRound: SeriesRound) -> GameFormat {
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
        let handicapEntryFormat = seriesRound.roundConfig.handicapEntryFormat == .courseHandicap
            && !HandicapCalculator.hasCourseHandicapData(courseSegment: courseSegment)
            ? .strokes
            : seriesRound.roundConfig.handicapEntryFormat
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
            sequentialTeeStartsEnabled: seriesRound.roundConfig.sequentialTeeStartsEnabled ?? false,
            handicapStrokeBasis: seriesRound.roundConfig.handicapStrokeBasis,
            handicapsEnabled: primaryFormat.configuration.basis == .net,
            sharedScoreHandicapConfig: seriesRound.roundConfig.sharedScoreHandicapConfig,
            handicapEntryFormat: handicapEntryFormat,
            handicapNormalizationMode: seriesRound.roundConfig.handicapNormalizationMode,
            leagueHandicapMaximum: series.handicapConfig.isEnabled ? series.handicapConfig.config.maximumHandicap : nil,
            attendanceConfirmationEnabled: series.settings.isAttendanceEnabled
        )
    }

    static func participatingMembersAndPresenceStatuses(
        series: Series,
        eligibleMembers: [SeriesMember],
        attendance: [SeriesRoundAttendance]
    ) -> (members: [SeriesMember], presenceStatusByMemberID: [String: RoundParticipantPresenceStatus]) {
        guard series.settings.isAttendanceEnabled else {
            return (eligibleMembers, [:])
        }

        let attendanceByMemberID = Dictionary(uniqueKeysWithValues: attendance.map { ($0.memberID, $0) })
        let members = eligibleMembers.filter { member in
            guard let attendance = attendanceByMemberID[member.id] else {
                return series.settings.attendanceDefault != .no
            }
            return attendance.status == SeriesRoundAttendanceStatus.pending.rawValue
                || attendance.status == SeriesRoundAttendanceStatus.accepted.rawValue
        }
        let presenceStatusByMemberID = Dictionary(uniqueKeysWithValues: members.map { member in
            let resolvedStatus: RoundParticipantPresenceStatus
            if let attendance = attendanceByMemberID[member.id],
               attendance.status == SeriesRoundAttendanceStatus.pending.rawValue {
                resolvedStatus = .unconfirmed
            } else if attendanceByMemberID[member.id] == nil,
                      series.settings.attendanceDefault == .pending {
                resolvedStatus = .unconfirmed
            } else {
                resolvedStatus = .active
            }
            return (member.id, resolvedStatus)
        })

        return (members, presenceStatusByMemberID)
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
            let orderedMembers = members.sorted {
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
        if seriesRound.roundConfig.teeGroupMode == .podAligned || seriesRound.roundConfig.podGroupingStrategy.usesPodAlignment {
            let podPlans = buildPodAlignedGroupPlans(
                members: members,
                pods: pods,
                matchupPlans: matchupPlans
            )
            if podPlans.isPopulated {
                let assignedMemberIDs = Set(podPlans.flatMap(\.memberIDs))
                let leftovers = members.filter { !assignedMemberIDs.contains($0.id) }
                return podPlans + sequentialGroupPlans(for: leftovers, teams: teams)
            }
        }

        return sequentialGroupPlans(for: members, teams: teams)
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
        intervalMinutes: Int = 8
    ) -> [SeriesRoundPlannedTeeGroup] {
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
        if seriesRound.partnershipPlans.isPopulated {
            return seriesRound.partnershipPlans
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
        return pods
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
        hostPlayerID: String?,
        presenceStatusByMemberID: [String: RoundParticipantPresenceStatus] = [:]
    ) -> [RoundParticipant] {
        let resolvedHandicapEntryFormat: HandicapEntryFormat = handicapEntryFormat == .courseHandicap
            && !HandicapCalculator.hasCourseHandicapData(courseSegment: courseSegment)
            ? .strokes
            : handicapEntryFormat
        return members.map { member in
            let assignment = memberAssignments[member.id]
            let effectiveIndex = handicaps[member.id]?.effectiveIndex
            let effectiveHandicap = handicaps[member.id]?.effectiveStrokes(maximumHandicap: maximumHandicap) ?? 0
            let teamMapping = member.teamID.flatMap { teamMappings[$0] }
            let teeBoxID = resolvedTeeBoxID(for: member, courseSegment: courseSegment)
            let template = RoundParticipant(
                teeBoxID: teeBoxID,
                originalHandicap: effectiveHandicap,
                adjustedHandicap: effectiveHandicap
            )
            let computedHandicap = effectiveIndex.map {
                HandicapCalculator.strokes(
                    for: $0,
                    format: resolvedHandicapEntryFormat,
                    participant: template,
                    courseSegment: courseSegment,
                    maximumHandicap: maximumHandicap,
                    handicapStrokeBasis: handicapStrokeBasis ?? SeriesHandicapStrokeBasis.defaultBasis(holeCount: courseSegment.holeSegment.holeCount)
                )
            } ?? effectiveHandicap
            let originalHandicap = resolvedHandicapEntryFormat == .courseHandicap
                ? max(0, Int((effectiveIndex ?? 0).rounded()))
                : effectiveHandicap
            return RoundParticipant(
                id: HackersID.string(),
                userID: member.userID,
                playerID: member.playerID,
                name: member.name.normalizedForStorage,
                teeBoxID: teeBoxID,
                originalHandicap: originalHandicap,
                adjustedHandicap: computedHandicap,
                handicapIndex: resolvedHandicapEntryFormat == .courseHandicap ? effectiveIndex : nil,
                leagueHandicapStrokesAtCreation: computedHandicap,
                seriesMemberID: member.id,
                teamID: teamMapping?.roundTeamID,
                groupID: assignment?.groupID,
                teeOrder: assignment?.teeOrder,
                isHost: hostPlayerID != nil && member.playerID == hostPlayerID,
                presenceStatus: presenceStatusByMemberID[member.id] ?? .active,
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
                        participantIDsBySeriesMemberID[seriesMemberID] ?? participantsBySeriesMemberID[seriesMemberID]?.id
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
                      let participantAID = participantIDsBySeriesMemberID[memberAID],
                      let participantBID = participantIDsBySeriesMemberID[memberBID] else {
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
        let participatingTeamIDs = Set(members.compactMap(\.teamID).filter(\.isPopulated))
        seriesTeamsForRound = seriesRound.roundConfig.teamAssignmentMode == .seriesTeams
            ? teams.filter { participatingTeamIDs.contains($0.id) }
            : []
    }

    private static func courseSelection(from segment: CourseSegment) -> SeriesCourseSelection {
        SeriesCourseSelection(
            courseID: segment.courseInfo.golfCourseApiID.map(String.init) ?? segment.courseInfo.id,
            cachedName: segment.courseInfo.name,
            defaultTeeBoxID: segment.defaultTee ?? "",
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
        let autoMatchupPlans = SeriesRoundCreationMapping.resolvedMatchupPlans(
            seriesRound: seriesRound,
            teams: teams,
            members: activeMembers
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

        let plannedMatchups = normalizePlannedMatchups(
            seriesRound.plannedMatchups,
            fallback: effectiveMatchupPlans
        )

        let autoTeeGroups = autoPlannedTeeGroups(
            seriesRound: seriesRound,
            members: activeMembers,
            teams: teams,
            pods: pods,
            matchupPlans: effectiveMatchupPlans,
            courseSelection: courseSelection
        )

        let plannedTeeGroups = normalizePlannedTeeGroups(
            seriesRound.plannedTeeGroups,
            fallback: autoTeeGroups,
            allMembers: activeMembers,
            holeRange: courseSelection?.holeSegment.holeRange ?? .init(startHole: 1, endHole: 18)
        )

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

        let validMemberIDs = Set(allMembers.map(\.id))
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
                              validMemberIDs.contains(seat.memberID),
                              !seenMemberIDs.contains(seat.memberID) else { return nil }
                        seenMemberIDs.insert(seat.memberID)
                        return SeriesRoundPlannedSeat(
                            id: seat.id,
                            memberID: seat.memberID,
                            teeOrder: max(1, seat.teeOrder),
                            source: seat.source
                        )
                    }
                updated.seats = seats.enumerated().map { offset, seat in
                    var next = seat
                    next.teeOrder = offset + 1
                    return next
                }
                return updated
            }

        let leftovers = allMembers.filter { !seenMemberIDs.contains($0.id) }
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
