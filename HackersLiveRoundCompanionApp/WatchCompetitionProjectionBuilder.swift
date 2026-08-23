import Foundation

@MainActor
struct WatchCompetitionProjectionBuilder {
    func build(
        viewModel: LiveRoundViewModel,
        participantID: String,
        nameDisplayFormat: NameDisplayFormat = .firstNameLastInitial,
        matchupProbabilities: [String: MatchupProbability]? = nil,
        scoreBasis: ScoreBasis? = nil
    ) -> [WatchRoundSnapshot.Competition] {
        let snapshot = viewModel.snapshot
        guard let participant = snapshot.participants.first(where: { $0.id == participantID }),
              !snapshot.isSecretScoring || snapshot.areScoresRevealed else {
            return []
        }

        let basis = scoreBasis
            ?? (snapshot.configuration.useHandicaps ? ScoreBasis.net : .gross)
        var competitions: [WatchRoundSnapshot.Competition] = []
        if let field = fieldCompetition(
            viewModel: viewModel,
            participant: participant,
            basis: basis,
            nameDisplayFormat: nameDisplayFormat
        ) {
            competitions.append(field)
        }
        if let matchup = matchupCompetition(
                viewModel: viewModel,
                participant: participant,
                basis: basis,
                probabilities: matchupProbabilities ?? viewModel.publishableMatchupProbabilities
        ) {
            competitions.append(matchup)
        }
        return competitions
    }

    private func fieldCompetition(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        basis: ScoreBasis,
        nameDisplayFormat: NameDisplayFormat
    ) -> WatchRoundSnapshot.Competition? {
        let result = viewModel.engineResult(for: basis)
        let formatGrossRows = viewModel.projectedIndividualLeaderboardRows(for: .gross)
        let formatNetRows = viewModel.projectedIndividualLeaderboardRows(for: .net)
        let hasFormatRows = formatGrossRows.isPopulated && formatNetRows.isPopulated
        let grossRows = hasFormatRows
            ? formatGrossRows
            : viewModel.projectedPlayerLeaderboardRows(for: .gross)
        let netRows = hasFormatRows
            ? formatNetRows
            : viewModel.projectedPlayerLeaderboardRows(for: .net)
        let rows = basis == .net ? netRows : grossRows
        guard rows.isPopulated else { return nil }

        let isHighestWins = hasFormatRows && result.template.leaderboardSort == .highestWins
        let grossRowsByID = Dictionary(uniqueKeysWithValues: grossRows.map { ($0.id, $0) })
        let netRowsByID = Dictionary(uniqueKeysWithValues: netRows.map { ($0.id, $0) })
        let projectedRows = rows.map { row in
            WatchRoundSnapshot.Competition.Row(
                id: row.scoringUnitID,
                position: normalizedPosition(row.placeLabel),
                title: row.teamName ?? nameDisplayFormat.displayName(for: row.participant.name),
                subtitle: leaderboardSubtitle(for: row),
                score: fieldScoreLabel(row: row, isHighestWins: isHighestWins),
                thru: "Thru \(row.thru)",
                winPercentage: nil,
                isCurrentUser: row.participants.contains { $0.id == participant.id },
                grossScore: grossRowsByID[row.id].map {
                    fieldScoreLabel(row: $0, isHighestWins: isHighestWins)
                },
                netScore: netRowsByID[row.id].map {
                    fieldScoreLabel(row: $0, isHighestWins: isHighestWins)
                },
                handicapLabel: leaderboardHandicapLabel(for: row)
            )
        }
        let currentIndex = rows.firstIndex {
            $0.participants.contains { $0.id == participant.id }
        }
        let currentRow = currentIndex.map { rows[$0] }
        let currentProjection = currentIndex.map { projectedRows[$0] }
        let candidates = rows.map {
            RoundLiveActivityStateBuilder.FieldStandingCandidate(
                id: $0.scoringUnitID,
                value: leaderboardValue(for: $0)
            )
        }
        let standing = currentRow.flatMap {
            RoundLiveActivityStateBuilder.fieldStanding(
                candidates: candidates,
                currentID: $0.scoringUnitID,
                isHighestWins: isHighestWins,
                unit: isHighestWins ? "point" : "stroke"
            )
        }
        let detail = [standing?.detail, currentProjection?.thru]
            .compactMap { $0 }
            .joined(separator: " · ")
        let variants = leaderboardVariants(
            viewModel: viewModel,
            participant: participant,
            sourceRows: rows,
            projectedRows: projectedRows
        )
        let defaultSections = variants.first?.sections ?? [
            .init(
                id: "field",
                title: "Standings",
                detail: nil,
                isCurrentUserSection: false,
                rows: projectedRows
            )
        ]

        return WatchRoundSnapshot.Competition(
            kind: .field,
            title: "Leaderboard",
            formatLabel: formatLabel(viewModel.snapshot, basis: basis),
            summary: .init(
                label: currentProjection?.title ?? "Field position",
                primary: standing?.position ?? "—",
                secondary: currentProjection?.score,
                detail: detail.isPopulated ? detail : "No score posted"
            ),
            sections: defaultSections,
            leaderboardVariants: variants
        )
    }

    private func leaderboardVariants(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        sourceRows: [LiveRoundViewModel.LeaderboardRow],
        projectedRows: [WatchRoundSnapshot.Competition.Row]
    ) -> [WatchRoundSnapshot.Competition.LeaderboardVariant] {
        viewModel.availableLeaderboardModes.compactMap { mode in
            let sections: [WatchRoundSnapshot.Competition.Section]
            switch mode {
            case .individual:
                sections = [
                    .init(
                        id: "individual",
                        title: "Standings",
                        detail: nil,
                        isCurrentUserSection: false,
                        rows: projectedRows
                    )
                ]
            case .team:
                sections = groupedLeaderboardSections(
                    sourceRows: sourceRows,
                    projectedRows: projectedRows,
                    participant: participant,
                    orderedGroups: viewModel.snapshot.teams
                        .sorted { $0.index < $1.index }
                        .map { ($0.id, $0.name) },
                    fallbackTitle: "Unassigned",
                    groupID: leaderboardTeamID
                )
            case .teeGroup:
                sections = groupedLeaderboardSections(
                    sourceRows: sourceRows,
                    projectedRows: projectedRows,
                    participant: participant,
                    orderedGroups: viewModel.snapshot.teeGroups
                        .sorted { $0.index < $1.index }
                        .map { ($0.id, $0.name) },
                    fallbackTitle: "Ungrouped",
                    groupID: leaderboardTeeGroupID
                )
            }
            guard sections.isPopulated else { return nil }
            return .init(
                id: mode.rawValue,
                label: viewModel.leaderboardModeLabel(for: mode),
                sections: sections
            )
        }
    }

    private func groupedLeaderboardSections(
        sourceRows: [LiveRoundViewModel.LeaderboardRow],
        projectedRows: [WatchRoundSnapshot.Competition.Row],
        participant: RoundParticipant,
        orderedGroups: [(id: String, title: String)],
        fallbackTitle: String,
        groupID: (LiveRoundViewModel.LeaderboardRow) -> String?
    ) -> [WatchRoundSnapshot.Competition.Section] {
        let projectedRowsByID = Dictionary(uniqueKeysWithValues: projectedRows.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: sourceRows, by: groupID)
        var groups = orderedGroups.compactMap { group -> (id: String?, title: String, rows: [LiveRoundViewModel.LeaderboardRow])? in
            guard let rows = grouped[group.id], rows.isPopulated else { return nil }
            return (group.id, group.title, rows)
        }
        if let fallbackRows = grouped[nil], fallbackRows.isPopulated {
            groups.append((nil, fallbackTitle, fallbackRows))
        }
        groups.sort { lhs, rhs in
            firstStandingIndex(for: lhs.rows, in: sourceRows)
                < firstStandingIndex(for: rhs.rows, in: sourceRows)
        }

        return groups.enumerated().map { index, group in
            let rows = group.rows.compactMap { projectedRowsByID[$0.id] }
            return .init(
                id: group.id ?? "fallback-\(index)",
                title: group.title,
                detail: nil,
                isCurrentUserSection: group.rows.contains {
                    $0.participants.contains { $0.id == participant.id }
                },
                rows: rows
            )
        }
    }

    private func firstStandingIndex(
        for rows: [LiveRoundViewModel.LeaderboardRow],
        in standings: [LiveRoundViewModel.LeaderboardRow]
    ) -> Int {
        let ids = Set(rows.map(\.id))
        return standings.firstIndex { ids.contains($0.id) } ?? Int.max
    }

    private func leaderboardTeamID(for row: LiveRoundViewModel.LeaderboardRow) -> String? {
        if let teamID = row.teamID, teamID.isPopulated { return teamID }
        let teamIDs = Set(row.participants.compactMap(\.teamID).filter(\.isPopulated))
        return teamIDs.count == 1 ? teamIDs.first : nil
    }

    private func leaderboardTeeGroupID(for row: LiveRoundViewModel.LeaderboardRow) -> String? {
        let groupIDs = Set(row.participants.compactMap(\.groupID).filter(\.isPopulated))
        return groupIDs.count == 1 ? groupIDs.first : nil
    }

    private func matchupCompetition(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        basis: ScoreBasis,
        probabilities: [String: MatchupProbability]
    ) -> WatchRoundSnapshot.Competition? {
        let orderedSections = viewModel.orderedMatchupSections
        guard orderedSections.isPopulated else { return nil }

        var currentSummary: WatchRoundSnapshot.Competition.Summary?
        let sections = orderedSections.compactMap { ordered -> WatchRoundSnapshot.Competition.Section? in
            let section = ordered.section
            let sideIDs = section.matchup.pairingIDs()
            guard sideIDs.count == 2 else { return nil }

            let presentation = viewModel.matchupPresentation(in: section)
            let probability = probabilities[section.matchup.id]
                .flatMap { $0.isSupported ? $0 : nil }
            let containsCurrentUser = viewModel.matchupSection(
                section,
                containsParticipantID: participant.id
            )
            let rows: [WatchRoundSnapshot.Competition.Row] = sideIDs.enumerated().compactMap {
                index, sideID -> WatchRoundSnapshot.Competition.Row? in
                guard let side = presentation.side(id: sideID) else { return nil }
                let thru = side.participants
                    .map { viewModel.holesPlayedCount(for: $0.id) }
                    .max()
                return WatchRoundSnapshot.Competition.Row(
                    id: "\(section.id):\(sideID)",
                    position: nil,
                    title: side.title,
                    subtitle: side.subtitle,
                    score: side.scoreLabel,
                    thru: thru.map { "Thru \($0)" },
                    winPercentage: probability.map {
                        index == 0 ? $0.leftWin : $0.rightWin
                    },
                    isCurrentUser: side.participants.contains { $0.id == participant.id }
                )
            }

            if containsCurrentUser,
               let currentSideIndex = sideIDs.firstIndex(where: { sideID in
                   viewModel.matchupSideParticipants(
                    scoringUnitID: sideID,
                    matchup: section.matchup
                   ).contains { $0.id == participant.id }
               }) {
                let opponentIndex = currentSideIndex == 0 ? 1 : 0
                let currentSide = presentation.side(id: sideIDs[currentSideIndex])
                let opponentSide = presentation.side(id: sideIDs[opponentIndex])
                let standing = RoundLiveActivityStateBuilder.matchupStanding(
                    currentTotal: currentSide?.total,
                    opponentTotal: opponentSide?.total,
                    isPointsFormat: presentation.isPointsFormat
                )
                let winPercentage = probability.map {
                    currentSideIndex == 0 ? $0.leftWin : $0.rightWin
                }
                let estimateDetail = probability?.confidence == .limited
                    ? " · Early estimate"
                    : ""
                currentSummary = .init(
                    label: "vs \(opponentSide?.title ?? "Opponent")",
                    primary: standing.label,
                    secondary: winPercentage.map {
                        "\($0)% \(basis == .net ? "net" : "gross") win"
                    },
                    detail: "\(standing.detail)\(estimateDetail)"
                )
            }

            return .init(
                id: section.id,
                title: section.name,
                detail: matchupDetail(presentation),
                isCurrentUserSection: containsCurrentUser,
                rows: rows
            )
        }
        guard sections.isPopulated else { return nil }

        return WatchRoundSnapshot.Competition(
            kind: .matchup,
            title: "Matchups",
            formatLabel: formatLabel(viewModel.snapshot, basis: basis),
            summary: currentSummary ?? .init(
                label: "Matchups",
                primary: String(sections.count),
                secondary: nil,
                detail: "Live matches"
            ),
            sections: sections
        )
    }

    private func matchupDetail(_ presentation: MatchupResultPresentation) -> String {
        guard presentation.sides.count == 2,
              let left = presentation.sides[0].total,
              let right = presentation.sides[1].total else {
            return "No scores entered"
        }
        guard !MatchupScoreComparison.totalsMatch(left, right) else {
            return "All square"
        }

        let leftIsAhead = presentation.isPointsFormat ? left > right : left < right
        let leader = presentation.sides[leftIsAhead ? 0 : 1]
        let difference = formattedNumber(abs(left - right))
        let unit: String
        if presentation.isPointsFormat {
            unit = difference == "1" ? "point" : "points"
        } else {
            unit = difference == "1" ? "stroke" : "strokes"
        }
        return "\(leader.title) leads by \(difference) \(unit)"
    }

    private func leaderboardSubtitle(for row: LiveRoundViewModel.LeaderboardRow) -> String? {
        guard row.teamName != nil || row.isSharedScoreUnit else { return nil }
        let value = row.participants
            .map { $0.name.teeGroupDisplayName }
            .filter(\.isPopulated)
            .joined(separator: ", ")
        return value.isPopulated ? value : nil
    }

    private func leaderboardHandicapLabel(for row: LiveRoundViewModel.LeaderboardRow) -> String? {
        if let shared = row.sharedHandicapLabel, shared.isPopulated {
            return shared.hasPrefix("HCP") ? shared : "HCP \(shared)"
        }
        guard row.participants.count == 1 else { return nil }
        return "HCP \(row.participant.lockedHandicapAllowance)"
    }

    private func leaderboardValue(for row: LiveRoundViewModel.LeaderboardRow) -> Double {
        row.totalPoints ?? Double(row.scoreToPar)
    }

    private func fieldScoreLabel(
        row: LiveRoundViewModel.LeaderboardRow,
        isHighestWins: Bool
    ) -> String {
        if isHighestWins {
            return "\(formattedNumber(leaderboardValue(for: row))) pts"
        }
        return scoreLabel(row.scoreToPar)
    }

    private func normalizedPosition(_ value: String) -> String? {
        let normalized = value
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
        return normalized.isPopulated && normalized != "—" ? normalized : nil
    }

    private func formatLabel(_ snapshot: RoundSnapshot, basis: ScoreBasis) -> String {
        "\(snapshot.resolvedActiveTemplate.name) · \(basis == .net ? "Net" : "Gross")"
    }

    private func scoreLabel(_ score: Int) -> String {
        if score == 0 { return "E" }
        return score > 0 ? "+\(score)" : String(score)
    }

    private func formattedNumber(_ value: Double) -> String {
        let roundedTenth = (value * 10).rounded() / 10
        if MatchupScoreComparison.totalsMatch(roundedTenth, roundedTenth.rounded()) {
            return String(Int(roundedTenth.rounded()))
        }
        return String(format: "%.1f", roundedTenth)
    }
}
