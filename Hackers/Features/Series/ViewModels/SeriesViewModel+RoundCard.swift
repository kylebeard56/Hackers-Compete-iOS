//
//  SeriesViewModel+RoundCard.swift
//  Hackers
//

import Foundation

@MainActor
extension SeriesViewModel {
    func baseRoundCardViewState(for seriesRound: SeriesRound) -> SeriesRoundCardViewState {
        makeRoundCardViewState(for: seriesRound, outcome: nil)
    }

    func enrichedRoundCardViewState(for seriesRound: SeriesRound) async -> SeriesRoundCardViewState {
        let configuration = V1SeriesRoundCardAdapter.resolvedConfiguration(
            seriesRound: seriesRound,
            linkedRound: linkedRound(for: seriesRound),
            series: series
        )
        guard let roundID = seriesRound.roundID else {
            return baseRoundCardViewState(for: seriesRound)
        }

        let snapshot = await loadLinkedRoundSnapshot(for: seriesRound)
        guard let snapshot else {
            return projectedRoundCardViewState(for: seriesRound) ?? baseRoundCardViewState(for: seriesRound)
        }
        let viewerParticipantID = snapshot.participants.first(where: { participant in
            if let currentPlayerID, participant.playerID == currentPlayerID { return true }
            if let currentMemberID, participant.seriesMemberID == currentMemberID { return true }
            return false
        })?.id
        let lifecycle = V1SeriesRoundCardAdapter.lifecycle(
            status: effectiveStatus(for: seriesRound),
            awardsStatus: seriesRound.awardsStatus
        )
        let viewer = viewerParticipantID.flatMap { id in snapshot.participants.first(where: { $0.id == id }) }
        let state = SeriesRoundCardStateBuilder.build(
            snapshot: snapshot,
            context: .init(
                id: seriesRound.id,
                canonicalRoundID: roundID,
                title: seriesRound.title.isPopulated ? seriesRound.title : "Round \(seriesRound.index + 1)",
                scheduleLabel: SeriesRoundCardFormatting.scheduleLabel(
                    lifecycle: lifecycle,
                    scheduledAt: seriesRound.scheduledAt,
                    completedAt: seriesRound.completedAt
                ),
                lifecycle: lifecycle,
                configuration: configuration,
                primaryAction: primaryAction(
                    for: seriesRound,
                    lifecycle: lifecycle,
                    viewer: viewer.map { _ in
                        .init(
                            participation: lifecycle == .live ? .playing : .played,
                            scoreLabel: nil
                        )
                    }
                ),
                viewerPlayerID: currentPlayerID,
                viewerMemberID: currentMemberID,
                isAdjusted: seriesRound.isAdjusted,
                setupDiffers: linkedConfigurationDivergence(for: seriesRound) != nil
            )
        )
        return state
    }

    private func projectedRoundCardViewState(for seriesRound: SeriesRound) -> SeriesRoundCardViewState? {
        guard var state = canonicalRoundResults.values
            .filter({ $0.seriesRoundID == seriesRound.id })
            .sorted(by: { $0.generatedAt.unix > $1.generatedAt.unix })
            .first?
            .cardProjection?
            .state else { return nil }
        let lifecycle = V1SeriesRoundCardAdapter.lifecycle(
            status: effectiveStatus(for: seriesRound),
            awardsStatus: seriesRound.awardsStatus
        )
        state.lifecycle = lifecycle
        state.viewer = viewerState(
            for: seriesRound,
            lifecycle: lifecycle,
            scoreContext: currentUserScoreContext(for: seriesRound)
        )
        state.setupDiffers = linkedConfigurationDivergence(for: seriesRound) != nil
        return state
    }

    private func makeRoundCardViewState(
        for seriesRound: SeriesRound,
        outcome: SeriesMatchupOutcome?
    ) -> SeriesRoundCardViewState {
        let linked = linkedRound(for: seriesRound)
        let status = effectiveStatus(for: seriesRound)
        let lifecycle = V1SeriesRoundCardAdapter.lifecycle(
            status: status,
            awardsStatus: seriesRound.awardsStatus
        )
        let configuration = V1SeriesRoundCardAdapter.resolvedConfiguration(
            seriesRound: seriesRound,
            linkedRound: linked,
            series: series
        )
        let title = seriesRound.title.isPopulated
            ? seriesRound.title
            : "Round \(seriesRound.index + 1)"
        let courseName = linked?.configuration.courses.first?.courseInfo.name
            ?? seriesRound.resolvedCourse(using: series)?.cachedName
            ?? "Course TBD"
        let scoreContext = currentUserScoreContext(for: seriesRound)
        let viewer = viewerState(
            for: seriesRound,
            lifecycle: lifecycle,
            scoreContext: scoreContext
        )
        let counts = attendanceCounts(for: seriesRound.id)
        let participantCount = linked?.players.count ?? counts.playing
        let totalParticipantCount = max(eligibleMembers.count, participantCount)
        let plannedSubstituteCount = Set(
            seriesRound.plannedTeeGroups
                .flatMap(\.seats)
                .filter(\.isSubstitute)
                .map(\.memberID)
        ).count
        let sides = outcome.map {
            roundCardSides(
                from: $0,
                configuration: configuration,
                lifecycle: lifecycle
            )
        } ?? plannedRoundCardSides(
            for: seriesRound,
            configuration: configuration
        )

        return SeriesRoundCardViewState(
            id: seriesRound.id,
            canonicalRoundID: seriesRound.roundID,
            title: title,
            courseName: courseName,
            scheduleLabel: SeriesRoundCardFormatting.scheduleLabel(
                lifecycle: lifecycle,
                scheduledAt: seriesRound.scheduledAt,
                completedAt: seriesRound.completedAt
            ),
            lifecycle: lifecycle,
            presentationKind: configuration.presentationKind,
            formatLabel: configuration.formatName,
            scoringRuleLabel: configuration.scoringRuleLabel,
            scoreBasis: configuration.scoreBasis,
            showsHandicap: configuration.usesHandicaps,
            isProvisional: lifecycle == .live && !allScoresComplete(for: seriesRound),
            sides: sides,
            viewer: viewer,
            participantCountLabel: SeriesRoundCardFormatting.participantCountLabel(
                playing: participantCount,
                total: totalParticipantCount,
                lifecycle: lifecycle
            ),
            substituteCountLabel: SeriesRoundCardFormatting.substituteCountLabel(plannedSubstituteCount),
            primaryAction: primaryAction(for: seriesRound, lifecycle: lifecycle, viewer: viewer),
            isAdjusted: seriesRound.isAdjusted,
            setupDiffers: linkedConfigurationDivergence(for: seriesRound) != nil
        )
    }

    private func viewerState(
        for seriesRound: SeriesRound,
        lifecycle: SeriesRoundCardLifecycle,
        scoreContext: (played: Bool, scoreLabel: String?)?
    ) -> SeriesRoundCardViewerState? {
        if let scoreContext {
            if scoreContext.played {
                return .init(
                    participation: lifecycle == .live ? .playing : .played,
                    scoreLabel: scoreContext.scoreLabel
                )
            }
            return .init(participation: .didNotPlay, scoreLabel: nil)
        }

        guard lifecycle == .upcoming || lifecycle == .lobby else { return nil }
        switch currentAttendanceStatus(for: seriesRound.id) {
        case .accepted:
            return .init(participation: .playing, scoreLabel: nil)
        case .no:
            return .init(participation: .declined, scoreLabel: nil)
        case .pending:
            return .init(participation: .pending, scoreLabel: nil)
        }
    }

    private func primaryAction(
        for seriesRound: SeriesRound,
        lifecycle: SeriesRoundCardLifecycle,
        viewer: SeriesRoundCardViewerState?
    ) -> SeriesRoundCardPrimaryAction {
        switch lifecycle {
        case .upcoming:
            return isRSVPEligible(for: seriesRound) ? .rsvp : .openLobby
        case .lobby:
            return .openLobby
        case .live:
            return viewer?.participation == .playing ? .continuePlaying : .watchLive
        case .completed, .needsReview, .finalized:
            return .viewResults
        case .canceled, .archived:
            return .none
        }
    }

    private func plannedRoundCardSides(
        for seriesRound: SeriesRound,
        configuration: SeriesRoundCardResolvedConfiguration
    ) -> [SeriesRoundCardSide] {
        guard configuration.competitionScope == .matchup else { return [] }
        let plans = seriesRound.matchupPlans
        guard plans.isPopulated else { return [] }

        let viewerTeamID = currentMemberID.flatMap { memberID in
            activeMembers.first(where: { $0.id == memberID })?.teamID
        }
        let preferred = plans.first { plan in
            if let viewerTeamID, plan.validTeamPairing {
                return plan.teamAID == viewerTeamID || plan.teamBID == viewerTeamID
            }
            if let currentMemberID, plan.validMemberPairing {
                return plan.memberAID == currentMemberID || plan.memberBID == currentMemberID
            }
            return false
        } ?? plans[0]

        if preferred.validTeamPairing {
            return [preferred.teamAID, preferred.teamBID].compactMap { teamID in
                guard let team = teams.first(where: { $0.id == teamID }) else { return nil }
                let roster = activeMembers
                    .filter { $0.teamID == teamID && $0.role != .spectator }
                    .sorted { lhs, rhs in
                        if lhs.id == currentMemberID { return true }
                        if rhs.id == currentMemberID { return false }
                        return lhs.name.fullName.localizedCaseInsensitiveCompare(rhs.name.fullName) == .orderedAscending
                    }
                return SeriesRoundCardSide(
                    id: teamID,
                    title: team.name,
                    subtitle: roster.isEmpty ? nil : "Scheduled lineup",
                    scoreLabel: nil,
                    result: .none,
                    contributors: roster.map { member in
                        contributor(
                            member: member,
                            role: .leaderOnly,
                            scoreLabel: nil,
                            handicapLabel: effectiveHandicap(for: member.id).map(Self.handicapLabel)
                        )
                    },
                    hiddenContributorCount: 0
                )
            }
        }

        if preferred.validMemberPairing {
            return [preferred.memberAID, preferred.memberBID].compactMap { memberID in
                guard let member = activeMembers.first(where: { $0.id == memberID }) else { return nil }
                return SeriesRoundCardSide(
                    id: member.id,
                    title: member.name.fullName,
                    subtitle: nil,
                    scoreLabel: nil,
                    result: .none,
                    contributors: [],
                    hiddenContributorCount: 0
                )
            }
        }

        return []
    }

    private func roundCardSides(
        from outcome: SeriesMatchupOutcome,
        configuration: SeriesRoundCardResolvedConfiguration,
        lifecycle: SeriesRoundCardLifecycle
    ) -> [SeriesRoundCardSide] {
        outcome.sides.map { side in
            let players = outcome.players.filter { $0.ownerID == side.id }
            let result: SeriesRoundCardResult
            if outcome.isTie {
                result = lifecycle == .live ? .tied : .tied
            } else if outcome.winningSideID == side.id {
                result = lifecycle == .live ? .leading : .winner
            } else if outcome.winningSideID != nil {
                result = lifecycle == .live ? .trailing : .loser
            } else {
                result = .none
            }

            return SeriesRoundCardSide(
                id: side.id,
                title: side.title,
                subtitle: nil,
                scoreLabel: side.score,
                result: result,
                contributors: players.map { player in
                    SeriesRoundCardContributor(
                        id: player.participantID,
                        name: player.name,
                        scoreLabel: configuration.scoreBasis == .net ? player.net : player.gross,
                        handicapLabel: configuration.usesHandicaps ? player.handicap : nil,
                        progressLabel: nil,
                        role: configuration.defaultContributorRole,
                        isViewer: player.participantID == currentPlayerID,
                        isSubstitute: player.isSubstitute,
                        countsTowardScore: player.scoreCounts
                    )
                },
                hiddenContributorCount: 0
            )
        }
    }

    private func contributor(
        member: SeriesMember,
        role: SeriesRoundCardContributorRole,
        scoreLabel: String?,
        handicapLabel: String?
    ) -> SeriesRoundCardContributor {
        .init(
            id: member.id,
            name: member.name.fullName,
            scoreLabel: scoreLabel,
            handicapLabel: handicapLabel,
            progressLabel: nil,
            role: role,
            isViewer: member.id == currentMemberID,
            isSubstitute: member.role == .substitute
        )
    }

    private static func handicapLabel(_ value: Double) -> String {
        SeriesMemberHandicap.formatHandicapIndexForDisplay(value)
    }
}
