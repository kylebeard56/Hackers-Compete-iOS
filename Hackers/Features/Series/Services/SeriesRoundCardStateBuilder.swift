//
//  SeriesRoundCardStateBuilder.swift
//  Hackers
//
//  Shared, model-driven card projection for V1 and V2 round snapshots.
//

import Foundation

enum SeriesRoundCardStateBuilder {
    struct Context {
        var id: String
        var canonicalRoundID: String
        var title: String
        var scheduleLabel: String
        var lifecycle: SeriesRoundCardLifecycle
        var configuration: SeriesRoundCardResolvedConfiguration
        var primaryAction: SeriesRoundCardPrimaryAction
        var viewerPlayerID: String?
        var viewerMemberID: String?
        var isAdjusted: Bool
        var setupDiffers: Bool
    }

    static func build(snapshot: RoundSnapshot, context: Context) -> SeriesRoundCardViewState {
        let segment = snapshot.roundSegment
        let scoringResult = segment.map { SeriesViewModel.buildScoringResult(from: snapshot, segment: $0) }
        let viewer = viewerParticipant(snapshot: snapshot, context: context)
        let sides: [SeriesRoundCardSide]

        if context.configuration.competitionScope == .matchup,
           let scoringResult,
           scoringResult.matchupResults.isPopulated {
            let presentations = scoringResult.matchupResults.map {
                MatchupResultPresentationBuilder.build(
                    snapshot: snapshot,
                    result: scoringResult,
                    matchupResult: $0,
                    basis: context.configuration.scoreBasis
                )
            }
            let presentation = presentations.first(where: { item in
                guard let viewer else { return false }
                return item.sides.contains { $0.participants.contains(where: { $0.id == viewer.id }) }
            }) ?? presentations[0]
            sides = matchupSides(
                presentation: presentation,
                snapshot: snapshot,
                context: context,
                viewerParticipantID: viewer?.id
            )
        } else if let scoringResult {
            sides = leaderboardSides(
                result: scoringResult,
                snapshot: snapshot,
                context: context,
                viewerParticipantID: viewer?.id
            )
        } else {
            sides = []
        }

        let activeParticipants = snapshot.participants.filter { $0.presenceStatus != .noShow }
        let participantCount = activeParticipants.count
        let totalParticipantCount = snapshot.participants.count
        let substituteCount = activeParticipants.filter(\.isSubstitute).count
        return SeriesRoundCardViewState(
            id: context.id,
            canonicalRoundID: context.canonicalRoundID,
            title: context.title,
            courseName: snapshot.courseInfo?.name ?? "Course TBD",
            scheduleLabel: context.scheduleLabel,
            lifecycle: context.lifecycle,
            presentationKind: context.configuration.presentationKind,
            formatLabel: context.configuration.formatName,
            scoringRuleLabel: context.configuration.scoringRuleLabel,
            scoreBasis: context.configuration.scoreBasis,
            showsHandicap: context.configuration.usesHandicaps,
            isProvisional: context.lifecycle == .live && scoringResult?.holeStates.values.contains(where: { state in
                if case .complete = state { return false }
                return true
            }) == true,
            sides: sides,
            viewer: viewerState(viewer: viewer, snapshot: snapshot, context: context),
            participantCountLabel: SeriesRoundCardFormatting.participantCountLabel(
                playing: participantCount,
                total: totalParticipantCount,
                lifecycle: context.lifecycle
            ),
            substituteCountLabel: SeriesRoundCardFormatting.substituteCountLabel(substituteCount),
            primaryAction: context.primaryAction,
            isAdjusted: context.isAdjusted,
            setupDiffers: context.setupDiffers
        )
    }

    static func projection(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        generatedAt: Time = .init()
    ) -> SeriesRoundCardProjection? {
        guard let roundID = seriesRound.roundID else { return nil }
        let roundConfiguration = snapshot.configuration
        let template = roundConfiguration.activeTemplate
        let configuration = SeriesRoundCardResolvedConfiguration(
            templateID: template.id,
            formatName: roundConfiguration.formatSummary?.name ?? template.name,
            competitionScope: roundConfiguration.resolvedCompetitionScope,
            teamScoring: roundConfiguration.teamScoring,
            scoreOwnerScope: roundConfiguration.scoreOwnerScope,
            scoreBasis: roundConfiguration.primaryFormat.configuration.basis,
            usesHandicaps: roundConfiguration.useHandicaps,
            highestWins: template.leaderboardSort == .highestWins
        )
        var state = build(
            snapshot: snapshot,
            context: .init(
                id: seriesRound.id,
                canonicalRoundID: roundID,
                title: seriesRound.title.isPopulated ? seriesRound.title : "Round \(seriesRound.index + 1)",
                scheduleLabel: SeriesRoundCardFormatting.scheduleLabel(
                    lifecycle: .completed,
                    scheduledAt: seriesRound.scheduledAt,
                    completedAt: seriesRound.completedAt
                ),
                lifecycle: .completed,
                configuration: configuration,
                primaryAction: .viewResults,
                viewerPlayerID: nil,
                viewerMemberID: nil,
                isAdjusted: seriesRound.isAdjusted,
                setupDiffers: false
            )
        )
        // Result projections are shared across the Series; viewer-specific participation
        // is merged by the adapter at read time and is never persisted here.
        state.viewer = nil
        return .init(state: state, generatedAt: generatedAt)
    }

    private static func viewerParticipant(snapshot: RoundSnapshot, context: Context) -> RoundParticipant? {
        snapshot.participants.first { participant in
            if let playerID = context.viewerPlayerID, participant.playerID == playerID { return true }
            if let memberID = context.viewerMemberID, participant.seriesMemberID == memberID { return true }
            return false
        }
    }

    private static func viewerState(
        viewer: RoundParticipant?,
        snapshot: RoundSnapshot,
        context: Context
    ) -> SeriesRoundCardViewerState? {
        guard let viewer else {
            switch context.lifecycle {
            case .completed, .needsReview, .finalized:
                return context.viewerPlayerID != nil || context.viewerMemberID != nil
                    ? .init(participation: .didNotPlay, scoreLabel: nil)
                    : nil
            default:
                return nil
            }
        }

        if viewer.presenceStatus == .noShow {
            return .init(participation: .didNotPlay, scoreLabel: nil)
        }
        let score = participantScoreLabel(
            participantID: viewer.id,
            snapshot: snapshot,
            configuration: context.configuration
        )
        switch context.lifecycle {
        case .completed, .needsReview, .finalized:
            return .init(participation: .played, scoreLabel: score)
        case .live:
            return .init(participation: .playing, scoreLabel: score)
        case .upcoming, .lobby:
            return .init(participation: viewer.presenceStatus == .unconfirmed ? .pending : .playing, scoreLabel: nil)
        case .canceled, .archived:
            return nil
        }
    }

    private static func matchupSides(
        presentation: MatchupResultPresentation,
        snapshot: RoundSnapshot,
        context: Context,
        viewerParticipantID: String?
    ) -> [SeriesRoundCardSide] {
        presentation.sides.map { side in
            let sorted = side.participants.sorted {
                compareParticipants($0, $1, snapshot: snapshot, configuration: context.configuration)
            }
            let result: SeriesRoundCardResult
            if presentation.isTie {
                result = .tied
            } else if presentation.winningSideID == side.id {
                result = context.lifecycle == .live ? .leading : .winner
            } else if presentation.winningSideID != nil {
                result = context.lifecycle == .live ? .trailing : .loser
            } else {
                result = .none
            }
            return SeriesRoundCardSide(
                id: side.id,
                title: side.title,
                subtitle: nil,
                scoreLabel: side.scoreLabel,
                result: result,
                contributors: sorted.map {
                    contributor(
                        participant: $0,
                        snapshot: snapshot,
                        configuration: context.configuration,
                        role: context.configuration.scoreOwnerScope == .individual
                            ? context.configuration.defaultContributorRole
                            : .sharedScoreMember,
                        isViewer: $0.id == viewerParticipantID,
                        countsTowardScore: side.isParticipantActive($0)
                    )
                },
                hiddenContributorCount: 0
            )
        }
    }

    private static func leaderboardSides(
        result: ScoringResult,
        snapshot: RoundSnapshot,
        context: Context,
        viewerParticipantID: String?
    ) -> [SeriesRoundCardSide] {
        let sortedRows = result.rows
            .filter { $0.holesPlayed > 0 }
            .sorted {
                if $0.total != $1.total {
                    return context.configuration.highestWins ? $0.total > $1.total : $0.total < $1.total
                }
                return $0.scoringUnitID < $1.scoringUnitID
            }
        return sortedRows.prefix(2).enumerated().map { index, row in
            let participants = row.participantIDs.compactMap { id in
                snapshot.participants.first(where: { $0.id == id })
            }
            let selectedIDs = Set(row.countingParticipantIDs)
            let candidates = participants.sorted {
                compareParticipants($0, $1, snapshot: snapshot, configuration: context.configuration)
            }
            return SeriesRoundCardSide(
                id: row.scoringUnitID,
                title: ownerTitle(row: row, snapshot: snapshot),
                subtitle: "\(ordinal(index + 1)) place",
                scoreLabel: SeriesRoundCardFormatting.scoreLabel(total: row.total, highestWins: context.configuration.highestWins),
                result: index == 0 ? (context.lifecycle == .live ? .leading : .winner) : .none,
                contributors: candidates.map {
                    contributor(
                        participant: $0,
                        snapshot: snapshot,
                        configuration: context.configuration,
                        role: context.configuration.scoreOwnerScope == .individual
                            ? context.configuration.defaultContributorRole
                            : .sharedScoreMember,
                        isViewer: $0.id == viewerParticipantID,
                        countsTowardScore: selectedIDs.isEmpty || selectedIDs.contains($0.id)
                    )
                },
                hiddenContributorCount: 0
            )
        }
    }

    private static func contributor(
        participant: RoundParticipant,
        snapshot: RoundSnapshot,
        configuration: SeriesRoundCardResolvedConfiguration,
        role: SeriesRoundCardContributorRole,
        isViewer: Bool,
        countsTowardScore: Bool
    ) -> SeriesRoundCardContributor {
        .init(
            id: participant.id,
            name: participant.name.fullName,
            scoreLabel: participantScoreLabel(
                participantID: participant.id,
                snapshot: snapshot,
                configuration: configuration
            ),
            handicapLabel: configuration.usesHandicaps ? "\(participant.adjustedHandicap)" : nil,
            progressLabel: participantProgressLabel(participantID: participant.id, snapshot: snapshot),
            role: role,
            isViewer: isViewer,
            isSubstitute: participant.isSubstitute,
            countsTowardScore: countsTowardScore
        )
    }

    private static func participantScoreLabel(
        participantID: String,
        snapshot: RoundSnapshot,
        configuration: SeriesRoundCardResolvedConfiguration
    ) -> String? {
        let entries = snapshot.scoring.filter {
            $0.scoringUnitID == participantID && ($0.strokes != nil || $0.relativeToPar != nil || $0.points != nil)
        }
        guard entries.isPopulated else { return nil }
        if configuration.highestWins {
            let points = entries.compactMap(\.points)
            if points.isPopulated {
                return SeriesRoundCardFormatting.scoreLabel(total: points.reduce(0, +), highestWins: true)
            }
        }
        let relative = entries.compactMap(\.relativeToPar)
        if relative.isPopulated {
            let total = relative.reduce(0, +) - (configuration.scoreBasis == .net ? snapshot.participants.first(where: { $0.id == participantID })?.adjustedHandicap ?? 0 : 0)
            return SeriesRoundCardFormatting.scoreLabel(total: Double(total), highestWins: false)
        }
        let strokes = entries.compactMap(\.strokes)
        return strokes.isPopulated ? "\(strokes.reduce(0, +))" : nil
    }

    private static func participantProgressLabel(participantID: String, snapshot: RoundSnapshot) -> String? {
        let holes = Set(snapshot.scoring.filter {
            $0.scoringUnitID == participantID && ($0.strokes != nil || $0.relativeToPar != nil || $0.points != nil)
        }.map(\.holeNumber))
        return holes.isEmpty ? nil : "\(holes.count)"
    }

    private static func compareParticipants(
        _ lhs: RoundParticipant,
        _ rhs: RoundParticipant,
        snapshot: RoundSnapshot,
        configuration: SeriesRoundCardResolvedConfiguration
    ) -> Bool {
        let lhsValue = participantSortValue(lhs.id, snapshot: snapshot, configuration: configuration)
        let rhsValue = participantSortValue(rhs.id, snapshot: snapshot, configuration: configuration)
        if let lhsValue, let rhsValue, lhsValue != rhsValue {
            return configuration.highestWins ? lhsValue > rhsValue : lhsValue < rhsValue
        }
        if lhsValue != nil, rhsValue == nil { return true }
        if lhsValue == nil, rhsValue != nil { return false }
        return lhs.name.fullName.localizedCaseInsensitiveCompare(rhs.name.fullName) == .orderedAscending
    }

    private static func participantSortValue(
        _ id: String,
        snapshot: RoundSnapshot,
        configuration: SeriesRoundCardResolvedConfiguration
    ) -> Double? {
        let entries = snapshot.scoring.filter { $0.scoringUnitID == id }
        if configuration.highestWins {
            let points = entries.compactMap(\.points)
            return points.isPopulated ? points.reduce(0, +) : nil
        }
        let relative = entries.compactMap(\.relativeToPar)
        let strokes = entries.compactMap(\.strokes)
        guard relative.isPopulated || strokes.isPopulated else { return nil }
        let handicap = configuration.scoreBasis == .net
            ? snapshot.participants.first(where: { $0.id == id })?.adjustedHandicap ?? 0
            : 0
        if relative.isPopulated {
            return Double(relative.reduce(0, +) - handicap)
        }
        return Double(strokes.reduce(0, +) - handicap)
    }

    private static func ownerTitle(row: ScoringRow, snapshot: RoundSnapshot) -> String {
        switch row.owner {
        case .participant:
            return snapshot.participants.first(where: { $0.id == row.scoringUnitID })?.name.fullName ?? "Player"
        case .team:
            return snapshot.teams.first(where: { $0.id == row.scoringUnitID })?.name ?? "Team"
        case .scoreOwner:
            if let group = snapshot.scoringGroups.first(where: { $0.id == row.scoringUnitID }) {
                return group.label ?? group.memberIDs.compactMap { id in
                    snapshot.participants.first(where: { $0.id == id })?.name.givenName
                }.joined(separator: " & ")
            }
            return "Partnership"
        }
    }

    private static func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }
}

extension RoundSnapshotV2 {
    /// V2 and V1 intentionally share scoring semantics. This adapter is presentation-only:
    /// it converts the canonical V2 aggregate into the established scoring-engine input and
    /// never writes a V1 document or creates a second configuration authority.
    func scoringSnapshot() -> RoundSnapshot {
        let template = FormatTemplateRegistry.template(for: round.configuration.templateID)
        let legacyFormat = GameFormat(
            type: template.category == .match ? .matchPlay : .strokePlay,
            configuration: .init(
                method: template.scoreSource == .shared ? .aggregate : .individual,
                basis: round.configuration.scoreBasis,
                handicap: template.requirements.defaultHandicapConfig,
                requiresTeams: template.requirements.requiresTeams,
                minPlayers: template.requirements.minPlayers,
                maxPlayers: template.requirements.maxPlayers,
                maxScoreOverPar: round.configuration.maxScoreOverPar
            )
        )
        let configuration = RoundConfiguration(
            primaryFormat: legacyFormat,
            formatSummary: round.configuration.formatSummary,
            courses: round.configuration.courses,
            competitionScope: round.configuration.competitionScope,
            teamScoring: round.configuration.teamScoring,
            stablefordPoints: round.configuration.stablefordPoints,
            scoreOwnerScope: round.configuration.scoreOwnerScope,
            matchupScoringStyle: round.configuration.matchupScoringStyle,
            holeWinPoints: round.configuration.holeWinPoints,
            matchWinnerBonusPoints: round.configuration.matchWinnerBonusPoints,
            matchTiePolicy: round.configuration.matchTiePolicy,
            selectionDomain: round.configuration.selectionDomain,
            scoreInputMode: round.configuration.scoreInputMode,
            secretScoring: round.configuration.secretScoring,
            scoresRevealed: round.configuration.scoresRevealed,
            handicapStrokeBasis: round.configuration.handicapStrokeBasis,
            handicapsEnabled: round.configuration.scoreBasis == .net,
            sharedScoreHandicapConfig: round.configuration.sharedScoreHandicapConfig,
            handicapEntryFormat: round.configuration.handicapEntryFormat,
            handicapNormalizationMode: round.configuration.handicapNormalizationMode,
            leagueHandicapMaximum: round.configuration.handicapMaximum,
            teamColorsEnabled: round.configuration.teamColorsEnabled,
            substitutesScore: round.configuration.substitutesScore
        )
        let legacyRound = Round(
            id: round.id,
            name: round.name,
            shareCode: round.shareCode,
            createdBy: round.createdByUserID,
            status: round.status.legacyStatus,
            players: round.participantPlayerIDs,
            configuration: configuration,
            createdAt: round.createdAt,
            lastUpdatedAt: round.lastUpdatedAt
        )
        return RoundSnapshot(
            round: legacyRound,
            participants: participants.map(\.legacyParticipant),
            teams: teams.map(\.legacyTeam),
            teeGroups: teeGroups.map(\.legacyTeeGroup),
            scoringGroups: scoringGroups.map(\.legacyScoringGroup),
            segments: segments.map(\.legacySegment),
            scoring: scores.map(\.legacyScore)
        )
    }
}

private extension RoundStatusV2 {
    var legacyStatus: RoundStatus {
        switch self {
        case .lobby: return .lobby
        case .live: return .live
        case .completed: return .complete
        case .archived: return .archived
        }
    }
}

private extension RoundParticipantV2 {
    var legacyParticipant: RoundParticipant {
        .init(
            id: id,
            userID: userID,
            playerID: playerID,
            name: name,
            teeBoxID: teeBoxID,
            originalHandicap: originalHandicap,
            adjustedHandicap: adjustedHandicap,
            handicapIndex: handicapIndex,
            seriesMemberID: seriesMemberID,
            teamID: teamID,
            groupID: teeGroupID,
            teeOrder: teeOrder,
            isHost: isHost,
            presenceStatus: participationStatus.legacyPresence,
            isSubstitute: isSubstitute,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt,
            parentID: parentID
        )
    }
}

private extension RoundParticipationStatusV2 {
    var legacyPresence: RoundParticipantPresenceStatus {
        switch self {
        case .confirmed: return .active
        case .pending: return .unconfirmed
        case .declined, .withdrawn, .noShow: return .noShow
        }
    }
}

private extension RoundTeamV2 {
    var legacyTeam: RoundTeam {
        .init(id: id, name: name, color: color, index: index, createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, parentID: parentID)
    }
}

private extension RoundTeeGroupV2 {
    var legacyTeeGroup: TeeTimeGroup {
        .init(id: id, index: index, teeTime: teeTime, startingHole: startingHole, createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, parentID: parentID)
    }
}

private extension RoundScoringGroupV2 {
    var legacyScoringGroup: RoundScoringGroup {
        .init(
            id: id,
            teamID: teamID,
            teeGroupID: teeGroupID,
            kind: kind,
            memberIDs: participantIDs,
            label: label,
            seedSeriesPodID: sourceSeriesPodID,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt,
            parentID: parentID
        )
    }
}

private extension RoundSegmentV2 {
    var legacySegment: RoundSegment {
        .init(
            id: id,
            roundID: parentID,
            holeRange: holeRange,
            gameFormat: FormatTemplateRegistry.template(for: templateID).category == .match ? .matchPlay : .strokePlay,
            templateID: templateID,
            scoringUnits: scoringUnits,
            matchups: matchups,
            competitionScope: competitionScope,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt,
            parentID: parentID
        )
    }
}

private extension ScoreEntryV2 {
    var legacyScore: ScoreEntry {
        .init(
            id: id,
            holeNumber: holeNumber,
            segmentID: segmentID,
            groupID: teeGroupID,
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            strokes: strokes,
            relativeToPar: relativeToPar,
            entryMode: entryMode,
            value: value,
            pickedUp: pickedUp,
            gameTemplateID: gameTemplateID,
            points: points,
            outcome: outcome,
            entryID: entryID,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt,
            parentID: parentID
        )
    }
}
