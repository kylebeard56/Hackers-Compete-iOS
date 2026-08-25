import Foundation

@MainActor
struct RoundLiveActivityStateBuilder {
    func build(
        viewModel: LiveRoundViewModel,
        watchSnapshot: WatchRoundSnapshot,
        matchupProbabilities: [String: MatchupProbability]? = nil,
        scoreBasis: ScoreBasis? = nil,
        updatedAt: Date = Date()
    ) -> RoundLiveActivityAttributes.ContentState? {
        guard let participant = viewModel.currentParticipant else { return nil }
        let snapshot = viewModel.snapshot
        let basis = scoreBasis
            ?? (snapshot.configuration.useHandicaps ? ScoreBasis.net : .gross)
        let thru = viewModel.holesPlayedCount(for: participant.id)
        let sharedSubject = watchSnapshot.subjects.first {
            $0.holeUnits.contains { $0.participantIDs.contains(participant.id) }
        }
        let currentSharedUnitID = sharedSubject?.unit(for: watchSnapshot.selectedHole)?.scoringUnitID
            ?? sharedSubject?.holeUnits.first?.scoringUnitID
        let personalValue: Int
        if snapshot.isSharedScoreSource, let currentSharedUnitID {
            personalValue = viewModel.scoringUnitScoreToPar(
                scoringUnitID: currentSharedUnitID,
                basis: basis
            )
        } else {
            personalValue = viewModel.scoreToPar(for: participant, basis: basis)
        }
        let grossValue: Int
        if snapshot.isSharedScoreSource, let currentSharedUnitID {
            grossValue = viewModel.scoringUnitScoreToPar(
                scoringUnitID: currentSharedUnitID,
                basis: .gross
            )
        } else {
            grossValue = viewModel.scoreToPar(for: participant, basis: .gross)
        }

        let teamSummary = teamSummary(
            viewModel: viewModel,
            participant: participant,
            basis: basis,
            thru: thru,
            sharedScoringUnitID: currentSharedUnitID
        )
        let matchup = matchupSummary(
            viewModel: viewModel,
            participant: participant,
            probabilities: matchupProbabilities ?? viewModel.publishableMatchupProbabilities
        )
        let isPersonalScoreCounting = personalScoreCountingStatus(
            viewModel: viewModel,
            participant: participant
        )
        let competition = competitionSummary(
            viewModel: viewModel,
            participant: participant,
            basis: basis,
            sharedScoringUnitID: currentSharedUnitID,
            teamSummary: teamSummary
        )
            ?? matchup.flatMap { _ in
                individualStrokeStandingSummary(
                    viewModel: viewModel,
                    participant: participant
                )
            }
        let total = watchSnapshot.holes.count
        let completed = min(max(thru, 0), total)
        let selectedHole = viewModel.hole(
            for: watchSnapshot.selectedHole,
            teeID: participant.teeBoxID
        )
        let projectedHole = watchSnapshot.holes.first { $0.number == watchSnapshot.selectedHole }
        let resolvedPar = selectedHole?.par ?? projectedHole?.par
        let handicapStrokes: Int? = {
            let strokes: Int
            if snapshot.isSharedScoreSource, let currentSharedUnitID {
                strokes = viewModel.scoringUnitStrokesReceived(
                    scoringUnitID: currentSharedUnitID,
                    holeNumber: watchSnapshot.selectedHole
                )
            } else {
                strokes = viewModel.strokesReceivedOnHole(
                    participant: participant,
                    holeNumber: watchSnapshot.selectedHole
                )
            }
            return strokes > 0 ? strokes : nil
        }()
        let currentHoleScore = currentHoleScoreLabel(
            viewModel: viewModel,
            participant: participant,
            sharedScoringUnitID: currentSharedUnitID,
            holeNumber: watchSnapshot.selectedHole,
            par: resolvedPar
        )

        return RoundLiveActivityAttributes.ContentState(
            phase: watchSnapshot.phase == .paused ? .paused : .live,
            roundTitle: watchSnapshot.title,
            participantName: participant.name.fullName,
            formatLabel: formatLabel(snapshot: snapshot, basis: basis),
            holeLabel: "Hole \(watchSnapshot.selectedHole) of \(total)",
            holeProgress: Self.completionProgress(completed: completed, total: total),
            hole: .init(
                number: watchSnapshot.selectedHole,
                total: total,
                completed: completed,
                remaining: max(total - completed, 0),
                par: resolvedPar,
                yardage: selectedHole?.yardage,
                handicapStrokes: handicapStrokes,
                currentScoreLabel: currentHoleScore
            ),
            personalScore: .init(
                title: basis == .net ? "You · Net" : "You",
                value: scoreLabel(personalValue),
                thru: thruLabel(completed, total: total)
            ),
            grossScore: .init(
                title: "You · Gross",
                value: scoreLabel(grossValue),
                thru: thruLabel(completed, total: total)
            ),
            teamScore: teamSummary,
            matchup: matchup,
            competition: competition,
            isPersonalScoreCounting: isPersonalScoreCounting,
            deepLinkURL: deepLinkURL(
                roundID: watchSnapshot.roundID,
                holeNumber: watchSnapshot.selectedHole
            ),
            updatedAt: updatedAt
        )
    }

    static func completionProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    private func teamSummary(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        basis: ScoreBasis,
        thru: Int,
        sharedScoringUnitID: String?
    ) -> RoundLiveActivityAttributes.ScoreSummary? {
        let snapshot = viewModel.snapshot
        guard let teamID = participant.teamID,
              let team = snapshot.teams.first(where: { $0.id == teamID }),
              snapshot.requiresTeams
                || snapshot.usesTeamScoringAggregates
                || snapshot.hasScheduledTeamMatchups else {
            return nil
        }
        let score: Int
        if snapshot.isSharedScoreSource, let sharedScoringUnitID {
            score = viewModel.scoringUnitScoreToPar(
                scoringUnitID: sharedScoringUnitID,
                basis: basis
            )
        } else {
            score = viewModel.teamScoreToPar(teamID: teamID, basis: basis)
        }
        return .init(
            title: team.name,
            value: scoreLabel(score),
            thru: thruLabel(thru, total: LiveRoundHoleOrdering.courseHoleNumbers(holeRange: snapshot.holeRange).count)
        )
    }

    private func competitionSummary(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        basis: ScoreBasis,
        sharedScoringUnitID: String?,
        teamSummary: RoundLiveActivityAttributes.ScoreSummary?
    ) -> RoundLiveActivityAttributes.CompetitionSummary? {
        let snapshot = viewModel.snapshot
        guard snapshot.configuration.resolvedCompetitionScope == .field,
              !snapshot.isSecretScoring || snapshot.areScoresRevealed else {
            return nil
        }

        let result = viewModel.engineResult(for: basis)
        let scoredRows = result.rows.filter { $0.holesPlayed > 0 }
        let usesTeamTemplate = snapshot.requiresTeams
            || snapshot.usesTeamScoringAggregates
            || snapshot.isSharedScoreSource && participant.teamID != nil

        if usesTeamTemplate,
           let teamID = participant.teamID,
           let team = snapshot.teams.first(where: { $0.id == teamID }) {
            let candidateIDs = Set([teamID, sharedScoringUnitID].compactMap { $0 })
            let currentRow = scoredRows.first { row in
                candidateIDs.contains(row.scoringUnitID)
                    || (row.owner != .participant && row.participantIDs.contains(participant.id))
            }
            guard let currentRow else {
                return teamSummary.map {
                    .init(
                        kind: .team,
                        title: team.name,
                        position: nil,
                        score: $0.value,
                        detail: $0.thru,
                        participantCount: scoredRows.count
                    )
                }
            }
            let standing = Self.fieldStanding(
                candidates: scoredRows.map {
                    .init(id: $0.scoringUnitID, value: $0.total)
                },
                currentID: currentRow.scoringUnitID,
                isHighestWins: result.template.leaderboardSort == .highestWins,
                unit: fieldUnit(for: result.template)
            )
            return .init(
                kind: .team,
                title: team.name,
                position: standing?.position,
                score: competitionScoreLabel(currentRow.total, template: result.template),
                detail: standing?.detail ?? "Team competition",
                participantCount: scoredRows.count
            )
        }

        guard let currentRow = scoredRows.first(where: {
            $0.scoringUnitID == participant.id || $0.participantIDs.contains(participant.id)
        }) else {
            return nil
        }
        let standing = Self.fieldStanding(
            candidates: scoredRows.map {
                .init(id: $0.scoringUnitID, value: $0.total)
            },
            currentID: currentRow.scoringUnitID,
            isHighestWins: result.template.leaderboardSort == .highestWins,
            unit: fieldUnit(for: result.template)
        )
        return .init(
            kind: .individual,
            title: "Field position",
            position: standing?.position,
            score: nil,
            detail: standing?.detail ?? "Individual competition",
            participantCount: scoredRows.count
        )
    }

    private func individualStrokeStandingSummary(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant
    ) -> RoundLiveActivityAttributes.CompetitionSummary? {
        let scoredRows = viewModel.leaderboardRows.filter { $0.thru > 0 }
        guard scoredRows.contains(where: { $0.participant.id == participant.id }) else {
            return nil
        }

        let standing = Self.fieldStanding(
            candidates: scoredRows.map {
                .init(id: $0.participant.id, value: Double($0.scoreToPar))
            },
            currentID: participant.id,
            isHighestWins: false,
            unit: "stroke"
        )
        return .init(
            kind: .individual,
            title: "Field position",
            position: standing?.position,
            score: nil,
            detail: standing?.detail ?? "Individual leaderboard",
            participantCount: scoredRows.count
        )
    }

    struct FieldStandingCandidate: Equatable {
        let id: String
        let value: Double
    }

    struct FieldStanding: Equatable {
        let position: String
        let detail: String
    }

    static func fieldStanding(
        candidates: [FieldStandingCandidate],
        currentID: String,
        isHighestWins: Bool,
        unit: String
    ) -> FieldStanding? {
        guard let current = candidates.first(where: { $0.id == currentID }),
              candidates.isPopulated else {
            return nil
        }
        let ordered = candidates.sorted {
            guard !MatchupScoreComparison.totalsMatch($0.value, $1.value) else {
                return $0.id < $1.id
            }
            return isHighestWins ? $0.value > $1.value : $0.value < $1.value
        }
        guard let index = ordered.firstIndex(where: { $0.id == currentID }),
              let leader = ordered.first else {
            return nil
        }
        let place = ordered.prefix(index).filter {
            !MatchupScoreComparison.totalsMatch($0.value, current.value)
        }.count + 1
        let tiedCount = ordered.filter {
            MatchupScoreComparison.totalsMatch($0.value, current.value)
        }.count
        let position = tiedCount > 1 ? "T\(place)" : "\(place)"
        let gap = abs(current.value - leader.value)
        let detail: String
        if MatchupScoreComparison.totalsMatch(gap, 0) {
            detail = tiedCount > 1 ? "Tied for lead" : "Leader"
        } else {
            let value = matchupDifferentialLabel(gap)
            detail = "\(value) \(unit)\(value == "1" ? "" : "s") back"
        }
        return FieldStanding(position: position, detail: detail)
    }

    private func formatLabel(snapshot: RoundSnapshot, basis: ScoreBasis) -> String {
        "\(snapshot.resolvedActiveTemplate.name) · \(basis == .net ? "Net" : "Gross")"
    }

    private func fieldUnit(for template: GameTemplate) -> String {
        template.leaderboardSort == .highestWins ? "point" : "stroke"
    }

    private func competitionScoreLabel(_ value: Double, template: GameTemplate) -> String {
        if template.leaderboardSort == .highestWins {
            let formatted = Self.matchupDifferentialLabel(value)
            return "\(formatted) pts"
        }
        return scoreLabel(Int(value.rounded()))
    }

    private func currentHoleScoreLabel(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        sharedScoringUnitID: String?,
        holeNumber: Int,
        par: Int?
    ) -> String {
        let scoringUnitID = sharedScoringUnitID ?? participant.id
        if viewModel.scoreEntry(for: scoringUnitID, holeNumber: holeNumber)?.pickedUp == true {
            return "Picked up"
        }
        let gross: Int?
        if let sharedScoringUnitID {
            gross = viewModel.scoringUnitGrossStrokes(
                scoringUnitID: sharedScoringUnitID,
                holeNumber: holeNumber
            )
        } else {
            gross = viewModel.grossStrokes(
                for: participant.id,
                holeNumber: holeNumber
            )
        }
        guard let gross else { return "TBD" }
        guard let par else { return "\(gross) entered" }
        return viewModel.friendlyScoreLabel(
            strokes: gross,
            par: par,
            format: .full
        )
    }

    private func matchupSummary(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        probabilities: [String: MatchupProbability]
    ) -> RoundLiveActivityAttributes.MatchupSummary? {
        let snapshot = viewModel.snapshot
        guard snapshot.configuration.resolvedCompetitionScope == .matchup,
              !snapshot.isSecretScoring || snapshot.areScoresRevealed,
              let section = viewModel.matchupSections.first(where: {
                  viewModel.matchupSection($0, containsParticipantID: participant.id)
              }) else {
            return nil
        }
        let sideIDs = section.matchup.pairingIDs()
        guard sideIDs.count == 2,
              let participantSideIndex = sideIDs.firstIndex(where: { sideID in
                  viewModel.matchupSideParticipants(
                    scoringUnitID: sideID,
                    matchup: section.matchup
                  ).contains { $0.id == participant.id }
              }) else {
            return nil
        }
        let opponentIndex = participantSideIndex == 0 ? 1 : 0
        let opponentID = sideIDs[opponentIndex]
        let presentation = viewModel.matchupPresentation(in: section)
        let currentSide = presentation.side(id: sideIDs[participantSideIndex])
        let opponentSide = presentation.side(id: opponentID)
        let standing = Self.matchupStanding(
            currentTotal: currentSide?.total,
            opponentTotal: opponentSide?.total,
            isPointsFormat: presentation.isPointsFormat
        )
        let probability = probabilities[section.matchup.id]
            .flatMap { $0.isSupported ? $0 : nil }
        let sideSummaries = sideIDs.enumerated().map { index, sideID in
            let side = presentation.side(id: sideID)
            return RoundLiveActivityAttributes.MatchupSideSummary(
                title: side?.title ?? viewModel.outcomeMatchupSideName(
                    scoringUnitID: sideID,
                    matchup: section.matchup
                ),
                score: side?.scoreLabel ?? "—",
                winPercentage: probability.map { index == 0 ? $0.leftWin : $0.rightWin },
                isCurrentUserSide: index == participantSideIndex,
                countingPlayers: side.flatMap(countingPlayerNames)
            )
        }
        return .init(
            opponent: opponentSide?.title ?? viewModel.outcomeMatchupSideName(
                scoringUnitID: opponentID,
                matchup: section.matchup
            ),
            standingLabel: standing.label,
            differentialLabel: standing.detail,
            winPercentage: probability.map {
                participantSideIndex == 0 ? $0.leftWin : $0.rightWin
            },
            tiePercentage: probability.flatMap { $0.tie > 0 ? $0.tie : nil },
            isEarlyEstimate: probability?.confidence == .limited,
            left: sideSummaries[0],
            right: sideSummaries[1]
        )
    }

    private func personalScoreCountingStatus(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant
    ) -> Bool? {
        let snapshot = viewModel.snapshot
        guard snapshot.configuration.resolvedCompetitionScope == .matchup,
              let teamID = participant.teamID,
              let section = viewModel.matchupSections.first(where: {
                  viewModel.matchupSection($0, containsParticipantID: participant.id)
              }) else {
            return nil
        }
        return viewModel.doesParticipantScoreCount(
            participantID: participant.id,
            teamID: teamID,
            matchup: section.matchup
        )
    }

    private func countingPlayerNames(
        for side: MatchupResultPresentation.Side
    ) -> [String]? {
        let names = side.participants
            .filter { side.countingParticipantIDs.contains($0.id) }
            .prefix(2)
            .map { participant in
                let givenName = participant.name.givenName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return givenName.isEmpty
                    ? participant.name.teeGroupDisplayName
                    : givenName
            }
            .filter { !$0.isEmpty }
        return names.isEmpty ? nil : names
    }

    struct MatchupStanding: Equatable {
        let label: String
        let detail: String
    }

    static func matchupStanding(
        currentTotal: Double?,
        opponentTotal: Double?,
        isPointsFormat: Bool
    ) -> MatchupStanding {
        guard let currentTotal, let opponentTotal else {
            return MatchupStanding(label: "TBD", detail: "No scores entered")
        }
        let delta = currentTotal - opponentTotal
        guard abs(delta) >= MatchupScoreComparison.tieTolerance else {
            return MatchupStanding(label: "TIED", detail: "All square")
        }

        let isAhead = isPointsFormat ? delta > 0 : delta < 0
        let magnitude = abs(delta)
        let value = matchupDifferentialLabel(magnitude)
        let unit: String
        if isPointsFormat {
            unit = "point"
        } else {
            unit = "stroke"
        }
        return MatchupStanding(
            label: "\(isAhead ? "UP" : "DOWN") \(value)",
            detail: "\(value)-\(unit) differential"
        )
    }

    private static func matchupDifferentialLabel(_ value: Double) -> String {
        let roundedTenth = (value * 10).rounded() / 10
        if abs(roundedTenth - roundedTenth.rounded()) < MatchupScoreComparison.tieTolerance {
            return String(Int(roundedTenth.rounded()))
        }
        return String(format: "%.1f", roundedTenth)
    }

    private func scoreLabel(_ score: Int) -> String {
        if score == 0 { return "E" }
        return score > 0 ? "+\(score)" : String(score)
    }

    private func thruLabel(_ thru: Int, total: Int) -> String {
        thru >= total && total > 0 ? "Finalizing" : "Thru \(thru)"
    }

    private func deepLinkURL(roundID: String, holeNumber: Int) -> URL {
        #if SANDBOX
        let scheme = "hackersgolfsandbox"
        #else
        let scheme = "hackersgolf"
        #endif
        var components = URLComponents()
        components.scheme = scheme
        components.path = "/live-round"
        components.queryItems = [
            URLQueryItem(name: "round_id", value: roundID),
            URLQueryItem(name: "hole", value: String(holeNumber))
        ]
        return components.url ?? URL(string: "\(scheme):///live-round")!
    }
}
