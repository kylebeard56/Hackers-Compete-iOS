//
//  RoundSession+Format.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundSession {
    /// Updates the round format to the given template. Syncs formatSummary, primaryFormat (legacy), and segment templateID.
    func setFormat(_ template: GameTemplate) async {
        addBreadcrumb()
        let previousTemplate = snapshot.resolvedActiveTemplate

        do {
            let summary = RoundFormatSummary(from: template)
            let legacyFormat = legacyGameFormat(for: template)

            // Round root
            if snapshot.round.configuration.formatSummary != summary {
                snapshot.round.configuration.formatSummary = summary
                snapshot.round.configuration.primaryFormat = legacyFormat
                _ = try await snapshot.round.put().get()
            }

            // Sync competition scope from template when template has explicit scope
            if let templateScope = template.competitionScope,
               snapshot.round.configuration.competitionScope != templateScope {
                snapshot.round.configuration.competitionScope = templateScope
                _ = try await snapshot.round.put().get()
            }

            // Segment
            if var mainSegment = snapshot.segments.first {
                var changed = mainSegment.templateID != template.id
                    || mainSegment.gameFormat.configuration.requiresTeams != template.requirements.requiresTeams
                    || mainSegment.gameFormat.configuration.basis != template.requirements.defaultScoreBasis

                if let templateScope = template.competitionScope, mainSegment.competitionScope != templateScope {
                    mainSegment.competitionScope = templateScope
                    changed = true
                }

                if changed {
                    mainSegment.templateID = template.id
                    mainSegment.gameFormat = legacyFormat
                    snapshot.segments[0] = mainSegment
                    _ = try await mainSegment.put().get()
                }
            }

            try await rebuildRoundScoringConfiguration()

            guard previousTemplate.id != template.id else { return }
            emitRoundSetupEvent(
                "round_setup.format_changed",
                extra: [
                    "previous_format_template_id": previousTemplate.id,
                    "previous_format_name": previousTemplate.name,
                    "previous_format_category": previousTemplate.category.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set format", error: error)
        }
    }

    /// Sets competition scope (field vs matchup). Persists to round config and segment.
    func setCompetitionScope(_ scope: CompetitionScope) async {
        addBreadcrumb()
        let previousScope = snapshot.configuration.resolvedCompetitionScope

        do {
            if snapshot.round.configuration.competitionScope != scope {
                snapshot.round.configuration.competitionScope = scope
                _ = try await snapshot.round.put().get()
            }

            if var mainSegment = snapshot.segments.first {
                mainSegment.competitionScope = scope
                if scope != .matchup {
                    mainSegment.matchups = nil
                }
                snapshot.segments[0] = mainSegment
                _ = try await mainSegment.put().get()
            }

            try await rebuildRoundScoringConfiguration()

            guard previousScope != scope else { return }
            emitRoundSetupEvent(
                "round_setup.competition_scope_changed",
                extra: [
                    "value": scope.rawValue,
                    "previous_value": previousScope.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set competition scope", error: error)
        }
    }

    func setScoreOwnerScope(_ scope: RoundScoreOwnerScope) async {
        addBreadcrumb()
        let previousScope = snapshot.configuration.scoreOwnerScope

        do {
            if snapshot.round.configuration.scoreOwnerScope != scope {
                snapshot.round.configuration.scoreOwnerScope = scope
                _ = try await snapshot.round.put().get()
            }

            try await rebuildRoundScoringConfiguration(
                preserveExistingPartnerships: scope == .partnership
            )

            guard previousScope != scope else { return }
            emitRoundSetupEvent(
                "round_setup.score_owner_scope_changed",
                extra: [
                    "value": scope.rawValue,
                    "previous_value": previousScope.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set score owner scope", error: error)
        }
    }

    func setMatchupScoringStyle(_ style: RoundMatchupScoringStyle) async {
        addBreadcrumb()
        let previousStyle = snapshot.configuration.matchupScoringStyle

        do {
            if snapshot.round.configuration.matchupScoringStyle != style {
                snapshot.round.configuration.matchupScoringStyle = style
                _ = try await snapshot.round.put().get()
            }

            guard previousStyle != style else { return }
            emitRoundSetupEvent(
                "round_setup.matchup_scoring_style_changed",
                extra: [
                    "value": style.rawValue,
                    "previous_value": previousStyle.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set matchup scoring style", error: error)
        }
    }

    func setHoleWinPoints(_ value: Double) async {
        addBreadcrumb()
        let previousValue = snapshot.configuration.resolvedHoleWinPoints

        do {
            if snapshot.round.configuration.holeWinPoints != value {
                snapshot.round.configuration.holeWinPoints = value
                _ = try await snapshot.round.put().get()
            }

            guard previousValue != value else { return }
            emitRoundSetupEvent(
                "round_setup.hole_win_points_changed",
                extra: [
                    "value": value,
                    "previous_value": previousValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set hole win points", error: error)
        }
    }

    func setMatchWinnerBonusPoints(_ value: Double) async {
        addBreadcrumb()
        let previousValue = snapshot.configuration.resolvedMatchWinnerBonusPoints

        do {
            if snapshot.round.configuration.matchWinnerBonusPoints != value {
                snapshot.round.configuration.matchWinnerBonusPoints = value
                _ = try await snapshot.round.put().get()
            }

            guard previousValue != value else { return }
            emitRoundSetupEvent(
                "round_setup.match_winner_bonus_changed",
                extra: [
                    "value": value,
                    "previous_value": previousValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set match winner bonus", error: error)
        }
    }

    func autoPairPartnershipsByTeeOrder() async {
        addBreadcrumb()

        do {
            let groups = resolvedPartnershipGroups(fillRemainder: true)
            try await rebuildRoundScoringConfiguration(
                providedScoringGroups: groups,
                preserveExistingPartnerships: false
            )
            emitRoundSetupEvent(
                "round_setup.partnerships_auto_paired",
                extra: [
                    "partnership_count": groups.count
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to auto-pair partnerships", error: error)
        }
    }

    func clearPartnerships() async {
        addBreadcrumb()

        do {
            try await rebuildRoundScoringConfiguration(
                providedScoringGroups: [],
                preserveExistingPartnerships: false
            )
            emitRoundSetupEvent("round_setup.partnerships_cleared")
        } catch {
            addBreadcrumb(level: .error, message: "Failed to clear partnerships", error: error)
        }
    }

    func createOrReplacePartnership(
        memberIDs: [String],
        label: String? = nil,
        seedSeriesPodID: String? = nil
    ) async {
        addBreadcrumb()

        do {
            let participants = memberIDs.compactMap { id in
                snapshot.participants.first(where: { $0.id == id })
            }
            guard participants.count == 2 else { return }

            let groupIDs = Set(participants.compactMap(\.groupID).filter(\.isPopulated))
            let teamIDs = Set(participants.compactMap(\.teamID).filter(\.isPopulated))
            guard groupIDs.count == 1, teamIDs.count == 1 else { return }

            let remaining = snapshot.scoringGroups.filter { group in
                group.kind != .partnership || Set(group.memberIDs).isDisjoint(with: Set(memberIDs))
            }

            let group = RoundScoringGroup(
                id: "partnership_\(memberIDs.sorted().joined(separator: "_"))",
                teamID: teamIDs.first,
                teeGroupID: groupIDs.first,
                kind: .partnership,
                memberIDs: memberIDs,
                label: label ?? partnershipLabel(for: participants),
                seedSeriesPodID: seedSeriesPodID,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: snapshot.round.id
            )

            try await rebuildRoundScoringConfiguration(
                providedScoringGroups: remaining.filter { $0.kind != .partnership } + remaining.filter { $0.kind == .partnership } + [group],
                preserveExistingPartnerships: false
            )

            emitRoundSetupEvent(
                "round_setup.partnership_created",
                extra: [
                    "partnership_id": group.id,
                    "member_ids": group.memberIDs,
                    "tee_group_id": group.teeGroupID ?? "",
                    "team_id": group.teamID ?? ""
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to create partnership", error: error)
        }
    }

    func removePartnership(groupID: String) async {
        addBreadcrumb()

        do {
            let remaining = snapshot.scoringGroups.filter { $0.id != groupID }
            try await rebuildRoundScoringConfiguration(
                providedScoringGroups: remaining,
                preserveExistingPartnerships: false
            )
            emitRoundSetupEvent(
                "round_setup.partnership_removed",
                extra: [
                    "partnership_id": groupID
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to remove partnership", error: error)
        }
    }

    func seedPartnershipsFromSeriesPods(seriesID: String) async {
        addBreadcrumb()
        guard seriesID.isPopulated else { return }

        let pods = await FirebaseService.shared.fetchSeriesPods(seriesID: seriesID)
        let participantBySeriesMemberID: [String: RoundParticipant] = Dictionary(uniqueKeysWithValues: snapshot.participants.compactMap { participant in
            guard let seriesMemberID = participant.seriesMemberID, seriesMemberID.isPopulated else { return nil }
            return (seriesMemberID, participant)
        })

        let groups = pods
            .filter(\.isSchedulable)
            .compactMap { pod -> RoundScoringGroup? in
                let participants = pod.memberIDs.compactMap { participantBySeriesMemberID[$0] }
                guard participants.count == 2 else { return nil }
                let groupIDs = Set(participants.compactMap(\.groupID).filter(\.isPopulated))
                let teamIDs = Set(participants.compactMap(\.teamID).filter(\.isPopulated))
                guard groupIDs.count == 1, teamIDs.count == 1 else { return nil }
                return RoundScoringGroup(
                    id: pod.id,
                    teamID: teamIDs.first,
                    teeGroupID: groupIDs.first,
                    kind: .partnership,
                    memberIDs: participants.map(\.id),
                    label: pod.resolvedLabel,
                    seedSeriesPodID: pod.id,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: snapshot.round.id
                )
            }

        do {
            try await rebuildRoundScoringConfiguration(
                providedScoringGroups: groups,
                preserveExistingPartnerships: false
            )
            emitRoundSetupEvent(
                "round_setup.partnerships_seeded_from_series",
                extra: [
                    "series_id": seriesID,
                    "seeded_partnership_count": groups.count
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to seed partnerships from series pods", error: error)
        }
    }

    func setTeamScoringMode(_ mode: RoundTeamScoringMode) async {
        addBreadcrumb()
        let previousMode = snapshot.configuration.teamScoring.mode

        do {
            if snapshot.round.configuration.teamScoring.mode != mode {
                snapshot.round.configuration.teamScoring.mode = mode
                _ = try await snapshot.round.put().get()
            }

            guard previousMode != mode else { return }
            emitRoundSetupEvent(
                "round_setup.team_scoring_mode_changed",
                extra: [
                    "value": mode.rawValue,
                    "previous_value": previousMode.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team scoring mode", error: error)
        }
    }

    func setTeamScoringCount(_ count: Int) async {
        addBreadcrumb()
        let previousCount = snapshot.configuration.teamScoring.count

        do {
            if snapshot.round.configuration.teamScoring.count != count {
                snapshot.round.configuration.teamScoring.count = count
                _ = try await snapshot.round.put().get()
            }

            guard previousCount != count else { return }
            emitRoundSetupEvent(
                "round_setup.team_scoring_count_changed",
                extra: [
                    "value": count,
                    "previous_value": previousCount
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team scoring count", error: error)
        }
    }

    func setTeamScoringScope(_ scope: AggregationScope) async {
        addBreadcrumb()
        let previousScope = snapshot.configuration.teamScoring.scope

        do {
            if snapshot.round.configuration.teamScoring.scope != scope {
                snapshot.round.configuration.teamScoring.scope = scope
                _ = try await snapshot.round.put().get()
            }

            guard previousScope != scope else { return }
            emitRoundSetupEvent(
                "round_setup.team_scoring_scope_changed",
                extra: [
                    "value": scope.rawValue,
                    "previous_value": previousScope.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team scoring scope", error: error)
        }
    }

    /// Transitional wrapper while the UI moves from Best N wording to the builder.
    func setBestN(_ n: Int) async {
        await setTeamScoringMode(.bestN)
        await setTeamScoringCount(n)
    }

    /// Transitional wrapper while the UI moves from Best/Worst wording to the builder.
    func setBestWorst() async {
        let teamSize = max(2, snapshot.participants.reduce(0) { count, participant in
            guard let teamID = participant.teamID else { return count }
            return max(count, snapshot.participants.filter { $0.teamID == teamID }.count)
        })
        await setTeamScoringMode(.worstN)
        await setTeamScoringCount(teamSize)
    }

    /// Updates matchups for the main segment. Persists to Firestore.
    func setMatchups(_ matchups: [TeamMatchup]) async {
        addBreadcrumb()
        let previousCount = snapshot.roundSegment?.matchups?.count ?? 0

        do {
            guard var mainSegment = snapshot.segments.first else { return }
            mainSegment.matchups = matchups
            snapshot.segments[0] = mainSegment
            _ = try await mainSegment.put().get()

            emitRoundSetupEvent(
                "round_setup.matchups_updated",
                extra: [
                    "matchup_count": matchups.count,
                    "previous_matchup_count": previousCount,
                    "valid_matchup_count": matchups.filter(\.isValid).count
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set matchups", error: error)
        }
    }

    private func legacyGameFormat(for template: GameTemplate) -> GameFormat {
        let requiresTeams = snapshot.round.configuration.primaryFormat.configuration.requiresTeams
        let isMatchPlay = !requiresTeams && template.pipeline.contains { stage in
            if case .compare = stage { return true }
            return false
        }
        let type: GameFormatType = isMatchPlay ? .matchPlay : .strokePlay
        let aggregation: Aggregation? = requiresTeams
            ? Aggregation(
                mode: snapshot.round.configuration.teamScoring.mode == .all ? .sumAll : .countBest,
                scope: snapshot.round.configuration.teamScoring.scope,
                bestN: snapshot.round.configuration.teamScoring.mode == .all ? nil : snapshot.round.configuration.teamScoring.count
            )
            : (template.subject == .team ? Aggregation(mode: .countBest, scope: .perHole, bestN: 1) : nil)
        let config = GameConfiguration(
            method: requiresTeams ? .aggregate : .individual,
            aggregation: aggregation,
            basis: template.requirements.defaultScoreBasis,
            handicap: template.requirements.defaultHandicapConfig,
            requiresTeams: requiresTeams || template.requirements.requiresTeams,
            maxScoreOverPar: template.requirements.defaultMaxScoreOverPar
        )
        return GameFormat(type: type, configuration: config)
    }

    func rebuildRoundScoringConfiguration(
        providedScoringGroups: [RoundScoringGroup]? = nil,
        preserveExistingPartnerships: Bool = true
    ) async throws {
        guard var mainSegment = snapshot.segments.first else { return }

        let scoringGroups = try await persistScoringGroups(
            resolvedScoringGroups(
                providedScoringGroups: providedScoringGroups,
                preserveExistingPartnerships: preserveExistingPartnerships
            )
        )

        let scoringUnits = buildScoringUnits(
            template: snapshot.resolvedActiveTemplate,
            scope: snapshot.configuration.scoreOwnerScope,
            participants: snapshot.participants,
            teams: snapshot.teams,
            scoringGroups: scoringGroups
        )
        let rebuiltMatchups = rebuildMatchups(
            current: mainSegment.matchups ?? [],
            scoringGroups: scoringGroups
        )

        guard mainSegment.scoringUnits != scoringUnits || mainSegment.matchups != rebuiltMatchups else { return }

        mainSegment.scoringUnits = scoringUnits
        mainSegment.matchups = rebuiltMatchups.isEmpty ? nil : rebuiltMatchups
        snapshot.segments[0] = mainSegment
        _ = try await mainSegment.put().get()
    }

    private func persistScoringGroups(_ groups: [RoundScoringGroup]) async throws -> [RoundScoringGroup] {
        let existing = snapshot.scoringGroups
        let nextByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let removed = existing.filter { nextByID[$0.id] == nil }

        for group in removed {
            _ = try await group.delete().get()
        }

        if groups.isPopulated {
            _ = try await groups.batchPut().get()
        }

        snapshot.scoringGroups = groups
        return groups
    }

    private func resolvedScoringGroups(
        providedScoringGroups: [RoundScoringGroup]?,
        preserveExistingPartnerships: Bool
    ) -> [RoundScoringGroup] {
        switch snapshot.configuration.scoreOwnerScope {
        case .individual:
            return []
        case .partnership:
            if let providedScoringGroups {
                return normalizedPartnershipGroups(
                    from: providedScoringGroups,
                    fillRemainder: false
                )
            }
            return resolvedPartnershipGroups(fillRemainder: preserveExistingPartnerships)
        case .teeGroup:
            return buildTeeGroupScoringGroups()
        }
    }

    private func resolvedPartnershipGroups(fillRemainder: Bool) -> [RoundScoringGroup] {
        normalizedPartnershipGroups(
            from: snapshot.scoringGroups.filter { $0.kind == .partnership },
            fillRemainder: fillRemainder
        )
    }

    private func normalizedPartnershipGroups(
        from groups: [RoundScoringGroup],
        fillRemainder: Bool
    ) -> [RoundScoringGroup] {
        let participantByID = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        var usedMemberIDs = Set<String>()
        var resolved: [RoundScoringGroup] = []

        let sortedGroups = groups
            .filter { $0.kind == .partnership }
            .sorted { lhs, rhs in
                let lhsGroup = lhs.teeGroupID ?? ""
                let rhsGroup = rhs.teeGroupID ?? ""
                if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
                let lhsTeam = lhs.teamID ?? ""
                let rhsTeam = rhs.teamID ?? ""
                if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
                return lhs.id < rhs.id
            }

        for group in sortedGroups {
            let memberIDs = Array(Set(group.memberIDs.filter(\.isPopulated))).sorted()
            guard memberIDs.count == 2 else { continue }
            guard Set(memberIDs).isDisjoint(with: usedMemberIDs) else { continue }

            let participants = memberIDs.compactMap { participantByID[$0] }
            guard participants.count == 2 else { continue }

            let groupIDs = Set(participants.compactMap(\.groupID).filter(\.isPopulated))
            let teamIDs = Set(participants.compactMap(\.teamID).filter(\.isPopulated))
            guard groupIDs.count == 1, teamIDs.count == 1 else { continue }

            usedMemberIDs.formUnion(memberIDs)
            resolved.append(
                RoundScoringGroup(
                    id: group.id.isPopulated ? group.id : partnershipID(for: memberIDs),
                    teamID: teamIDs.first,
                    teeGroupID: groupIDs.first,
                    kind: .partnership,
                    memberIDs: memberIDs,
                    label: group.label ?? partnershipLabel(for: participants),
                    seedSeriesPodID: group.seedSeriesPodID,
                    createdAt: group.createdAt,
                    lastUpdatedAt: .init(),
                    parentID: snapshot.round.id
                )
            )
        }

        guard fillRemainder else { return resolved }
        return resolved + autoPairedPartnershipGroups(excluding: usedMemberIDs)
    }

    private func autoPairedPartnershipGroups(excluding usedMemberIDs: Set<String>) -> [RoundScoringGroup] {
        let teeGroups = snapshot.teeGroups.sorted { $0.index < $1.index }
        var results: [RoundScoringGroup] = []

        for teeGroup in teeGroups {
            let groupedByTeam = Dictionary(grouping: snapshot.participants.filter {
                $0.groupID == teeGroup.id && !usedMemberIDs.contains($0.id)
            }) { $0.teamID ?? "" }

            for (teamID, members) in groupedByTeam.sorted(by: { $0.key < $1.key }) where teamID.isPopulated {
                let orderedMembers = members.sorted {
                    if ($0.teeOrder ?? Int.max) != ($1.teeOrder ?? Int.max) {
                        return ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max)
                    }
                    return $0.name.fullName < $1.name.fullName
                }

                stride(from: 0, to: orderedMembers.count, by: 2).forEach { startIndex in
                    guard startIndex + 1 < orderedMembers.count else { return }
                    let pair = [orderedMembers[startIndex], orderedMembers[startIndex + 1]]
                    let memberIDs = pair.map(\.id).sorted()
                    results.append(
                        RoundScoringGroup(
                            id: partnershipID(for: memberIDs),
                            teamID: teamID,
                            teeGroupID: teeGroup.id,
                            kind: .partnership,
                            memberIDs: memberIDs,
                            label: partnershipLabel(for: pair),
                            createdAt: .init(),
                            lastUpdatedAt: .init(),
                            parentID: snapshot.round.id
                        )
                    )
                }
            }
        }

        return results
    }

    private func buildTeeGroupScoringGroups() -> [RoundScoringGroup] {
        snapshot.teeGroups
            .sorted { $0.index < $1.index }
            .compactMap { teeGroup in
                let members = snapshot.participants
                    .filter { $0.groupID == teeGroup.id }
                    .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
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
                    parentID: snapshot.round.id
                )
            }
    }

    private func buildScoringUnits(
        template: GameTemplate,
        scope: RoundScoreOwnerScope,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup]
    ) -> [ScoringUnit] {
        let participantUnits = participants.map { participant in
            ScoringUnit(
                id: participant.id,
                owner: .participant,
                ownerIDs: [participant.id],
                scoringMethod: .individual
            )
        }

        switch scope {
        case .individual:
            if template.scoreSource == .shared, snapshot.requiresTeams, teams.isPopulated {
                return teams
                    .sorted { $0.index < $1.index }
                    .map { team in
                        ScoringUnit(
                            id: team.id,
                            owner: .team,
                            ownerIDs: [team.id],
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole)
                        )
                    }
            }
            return participantUnits
        case .partnership:
            if template.scoreSource == .shared {
                return scoringGroups
                    .filter { $0.kind == .partnership }
                    .map { group in
                        ScoringUnit(
                            id: group.id,
                            owner: .scoreOwner,
                            ownerIDs: group.memberIDs,
                            scoringMethod: .aggregate,
                            aggregation: .init(mode: .sumAll, scope: .perHole)
                        )
                    }
            }
            return participantUnits
        case .teeGroup:
            return scoringGroups
                .filter { $0.kind == .teeGroup }
                .map { group in
                    ScoringUnit(
                        id: group.id,
                        owner: .scoreOwner,
                        ownerIDs: group.memberIDs,
                        scoringMethod: .aggregate,
                        aggregation: .init(mode: .sumAll, scope: .perHole)
                    )
                }
        }
    }

    private func rebuildMatchups(
        current: [TeamMatchup],
        scoringGroups: [RoundScoringGroup]
    ) -> [TeamMatchup] {
        guard snapshot.configuration.resolvedCompetitionScope == .matchup else { return [] }

        let expectedMode: MatchupMode =
            snapshot.configuration.scoreOwnerScope == .individual
            ? (snapshot.requiresTeams ? .team : .individual)
            : .scoreOwner

        let otherModes = current.filter { ($0.mode ?? .team) != expectedMode }
        let currentModeMatchups = current.filter { ($0.mode ?? .team) == expectedMode }
        let availableIDs = availableOwnerIDs(for: expectedMode, scoringGroups: scoringGroups)
        let prunedCurrentMode = currentModeMatchups.filter {
            matchup($0, referencesOnly: availableIDs, in: expectedMode)
        }

        if prunedCurrentMode.isPopulated {
            return otherModes + prunedCurrentMode
        }

        return otherModes + defaultMatchups(
            for: expectedMode,
            scoringGroups: scoringGroups
        )
    }

    private func availableOwnerIDs(
        for mode: MatchupMode,
        scoringGroups: [RoundScoringGroup]
    ) -> Set<String> {
        switch mode {
        case .team:
            return Set(snapshot.teams.map(\.id))
        case .individual:
            return Set(snapshot.participants.map(\.id))
        case .scoreOwner:
            return Set(scoringGroups.map(\.id))
        }
    }

    private func matchup(
        _ matchup: TeamMatchup,
        referencesOnly availableIDs: Set<String>,
        in mode: MatchupMode
    ) -> Bool {
        guard matchup.isValid else { return false }

        switch mode {
        case .team:
            return matchup.teamIDs.allSatisfy(availableIDs.contains)
        case .individual:
            return (matchup.participantIDs ?? []).allSatisfy(availableIDs.contains)
        case .scoreOwner:
            return (matchup.scoreOwnerIDs ?? []).allSatisfy(availableIDs.contains)
        }
    }

    private func defaultMatchups(
        for mode: MatchupMode,
        scoringGroups: [RoundScoringGroup]
    ) -> [TeamMatchup] {
        switch mode {
        case .team:
            let teams = snapshot.teams.sorted { $0.index < $1.index }
            return stride(from: 0, to: teams.count, by: 2).compactMap { index in
                guard index + 1 < teams.count else { return nil }
                return TeamMatchup(
                    id: "team_matchup_\(teams[index].id)_\(teams[index + 1].id)",
                    teamIDs: [teams[index].id, teams[index + 1].id],
                    participantIDs: nil,
                    mode: .team
                )
            }
        case .individual:
            let teeGroups = Dictionary(grouping: snapshot.participants) { $0.groupID ?? "" }
            return teeGroups.keys.sorted().flatMap { groupID in
                let participants = (teeGroups[groupID] ?? []).sorted {
                    if ($0.teeOrder ?? Int.max) != ($1.teeOrder ?? Int.max) {
                        return ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max)
                    }
                    return $0.name.fullName < $1.name.fullName
                }
                return stride(from: 0, to: participants.count, by: 2).compactMap { index -> TeamMatchup? in
                    guard index + 1 < participants.count else { return nil }
                    return TeamMatchup(
                        id: "individual_matchup_\(participants[index].id)_\(participants[index + 1].id)",
                        teamIDs: [],
                        participantIDs: [participants[index].id, participants[index + 1].id],
                        mode: .individual
                    )
                }
            }
        case .scoreOwner:
            if snapshot.configuration.scoreOwnerScope == .partnership {
                let groupsByTeeGroup = Dictionary(grouping: scoringGroups.filter { $0.kind == .partnership }) { $0.teeGroupID ?? "" }
                return groupsByTeeGroup.keys.sorted().compactMap { teeGroupID in
                    let groups = (groupsByTeeGroup[teeGroupID] ?? []).sorted {
                        let lhsTeam = $0.teamID ?? ""
                        let rhsTeam = $1.teamID ?? ""
                        if lhsTeam != rhsTeam { return lhsTeam < rhsTeam }
                        return ($0.label ?? $0.id) < ($1.label ?? $1.id)
                    }
                    guard groups.count == 2 else { return nil }
                    return TeamMatchup(
                        id: "score_owner_matchup_\(groups[0].id)_\(groups[1].id)",
                        teamIDs: [],
                        participantIDs: nil,
                        scoreOwnerIDs: [groups[0].id, groups[1].id],
                        scoreOwnerScope: .partnership,
                        mode: .scoreOwner
                    )
                }
            }

            let orderedGroups = scoringGroups.sorted {
                if ($0.teeGroupID ?? "") != ($1.teeGroupID ?? "") {
                    return ($0.teeGroupID ?? "") < ($1.teeGroupID ?? "")
                }
                return ($0.label ?? $0.id) < ($1.label ?? $1.id)
            }
            return stride(from: 0, to: orderedGroups.count, by: 2).compactMap { index in
                guard index + 1 < orderedGroups.count else { return nil }
                return TeamMatchup(
                    id: "score_owner_matchup_\(orderedGroups[index].id)_\(orderedGroups[index + 1].id)",
                    teamIDs: [],
                    participantIDs: nil,
                    scoreOwnerIDs: [orderedGroups[index].id, orderedGroups[index + 1].id],
                    scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
                    mode: .scoreOwner
                )
            }
        }
    }

    private func partnershipID(for memberIDs: [String]) -> String {
        "partnership_\(memberIDs.sorted().joined(separator: "_"))"
    }

    private func partnershipLabel(for participants: [RoundParticipant]) -> String {
        participants
            .map { participant in
                let firstName = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if firstName.isPopulated { return firstName }
                return participant.name.fullName
            }
            .joined(separator: " + ")
    }
}
