//
//  SeriesTeamInsightBuilder.swift
//  Hackers
//

import Foundation

struct SeriesTeamInsight: Identifiable, Equatable {
    let teamID: String
    let teamName: String
    let roster: [SeriesMember]
    let rosterSubtitle: String?
    let totalPoints: Double
    let record: SeriesTeamRecord
    let averagePoints: Double?
    let averageGrossScore: Double?
    let scoreSpread: Double?
    let topContributorName: String
    let topContributorDetail: String
    let playerPerformances: [SeriesTeamPlayerPerformance]
    let scheduleRows: [SeriesTeamScheduleRow]

    var id: String { teamID }
}

struct SeriesTeamRecord: Equatable {
    var wins: Int = 0
    var losses: Int = 0
    var ties: Int = 0

    var displayString: String {
        "\(wins)-\(losses)-\(ties)"
    }
}

struct SeriesTeamPlayerPerformance: Identifiable, Equatable {
    let memberID: String
    let name: String
    let points: Double
    let roundsPlayed: Int
    let averageGross: Double?
    let bestGross: Int?
    let trendLabel: String?
    let trendKind: SeriesTeamPlayerTrendKind?

    var id: String { memberID }
}

enum SeriesTeamPlayerTrendKind: Equatable {
    case improved
    case worse
    case steady
}

enum SeriesTeamScheduleOutcomeKind: Equatable {
    case win
    case loss
    case tie
    case placement
    case pending
}

struct SeriesTeamScheduleRow: Identifiable, Equatable {
    let id: String
    let title: String
    let opponentName: String
    let statusLabel: String
    let outcomeLabel: String
    let pointsLabel: String?
    let outcomeKind: SeriesTeamScheduleOutcomeKind
}

enum SeriesTeamInsightBuilder {
    static func build(
        team: SeriesTeam,
        standing: SeriesStanding?,
        teams: [SeriesTeam],
        members: [SeriesMember],
        rounds: [SeriesRound],
        pointAwards: [SeriesPointAward],
        snapshotsBySeriesRoundID: [String: RoundSnapshot],
        statusBySeriesRoundID: [String: SeriesRoundStatus] = [:]
    ) -> SeriesTeamInsight {
        let roster = members
            .filter { $0.isActive && $0.teamID == team.id }
            .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
        let rosterSubtitle = rosterSubtitle(for: roster)
        let teamsByID = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let teamAwards = pointAwards.filter { $0.awardTrack == .team && $0.competitorID == team.id }
        let totalPoints = standing?.totalPoints ?? teamAwards.reduce(0) { $0 + $1.totalPoints }
        let averagePoints = average(teamAwards.map(\.totalPoints))
        let scheduleRows = scheduleRows(
            team: team,
            teamsByID: teamsByID,
            rounds: rounds,
            pointAwards: pointAwards,
            snapshotsBySeriesRoundID: snapshotsBySeriesRoundID,
            statusBySeriesRoundID: statusBySeriesRoundID
        )
        let record = scheduleRows.reduce(into: SeriesTeamRecord()) { result, row in
            switch row.outcomeKind {
            case .win: result.wins += 1
            case .loss: result.losses += 1
            case .tie: result.ties += 1
            case .placement, .pending: break
            }
        }
        let grossScoresByMemberID = grossScoresByMemberID(
            roster: roster,
            rounds: rounds,
            snapshotsBySeriesRoundID: snapshotsBySeriesRoundID
        )
        let roundAverages = rounds.compactMap { round -> Double? in
            let scores = roster.compactMap { member in
                grossScoresByMemberID[member.id]?.first { $0.roundID == round.id }?.gross
            }
            return average(scores.map(Double.init))
        }
        let allGrossScores = grossScoresByMemberID.values.flatMap { $0.map(\.gross) }
        let individualAwardsByMemberID = Dictionary(grouping: pointAwards.filter { $0.awardTrack == .individual }) {
            $0.competitorID
        }

        let playerPerformances = roster.map { member in
            let memberAwards = individualAwardsByMemberID[member.id] ?? []
            let grossScores = (grossScoresByMemberID[member.id] ?? []).sorted { $0.roundIndex < $1.roundIndex }
            let awardRounds = Set(memberAwards.map(\.seriesRoundID)).count
            let trend = trend(for: grossScores)
            return SeriesTeamPlayerPerformance(
                memberID: member.id,
                name: member.name.fullName,
                points: memberAwards.reduce(0) { $0 + $1.totalPoints },
                roundsPlayed: max(awardRounds, grossScores.count),
                averageGross: average(grossScores.map { Double($0.gross) }),
                bestGross: grossScores.map(\.gross).min(),
                trendLabel: trend?.label,
                trendKind: trend?.kind
            )
        }
        let topContributor = topContributor(from: playerPerformances)

        return SeriesTeamInsight(
            teamID: team.id,
            teamName: team.name,
            roster: roster,
            rosterSubtitle: rosterSubtitle,
            totalPoints: totalPoints,
            record: record,
            averagePoints: averagePoints,
            averageGrossScore: average(roundAverages),
            scoreSpread: standardDeviation(allGrossScores.map(Double.init)),
            topContributorName: topContributor.name,
            topContributorDetail: topContributor.detail,
            playerPerformances: playerPerformances,
            scheduleRows: scheduleRows
        )
    }

    static func rosterSubtitle(for members: [SeriesMember]) -> String? {
        guard members.isPopulated else { return nil }
        return members.map { shortRosterName($0.name) }.joined(separator: ", ")
    }

    static func shortRosterName(_ name: Name) -> String {
        let given = name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let initial = family.first else { return given.isPopulated ? given : name.fullName }
        return "\(given) \(String(initial).uppercased())"
    }

    private struct GrossScore {
        let roundID: String
        let roundIndex: Int
        let gross: Int
    }

    private static func scheduleRows(
        team: SeriesTeam,
        teamsByID: [String: SeriesTeam],
        rounds: [SeriesRound],
        pointAwards: [SeriesPointAward],
        snapshotsBySeriesRoundID: [String: RoundSnapshot],
        statusBySeriesRoundID: [String: SeriesRoundStatus]
    ) -> [SeriesTeamScheduleRow] {
        let awardsByRoundID = Dictionary(grouping: pointAwards.filter { $0.awardTrack == .team }, by: \.seriesRoundID)
        return rounds.sorted { $0.index < $1.index }.map { round in
            let roundAwards = awardsByRoundID[round.id] ?? []
            let teamAward = roundAwards.first { $0.competitorID == team.id }
            let linkedOpponentAward = opponentAward(
                for: teamAward,
                roundAwards: roundAwards,
                snapshot: snapshotsBySeriesRoundID[round.id]
            )
            let plannedOpponentID = opponentTeamID(for: team.id, round: round)
            let opponentAward = linkedOpponentAward ?? plannedOpponentID.flatMap { id in
                roundAwards.first { $0.competitorID == id }
            }
            let status = statusBySeriesRoundID[round.id] ?? round.status
            let title = round.title.isPopulated ? round.title : "Round \(round.index + 1)"
            let opponentName = opponentAward.flatMap { teamsByID[$0.competitorID]?.name }
                ?? plannedOpponentID.flatMap { teamsByID[$0]?.name }
                ?? (round.matchupPlans.isPopulated || round.plannedMatchups.isPopulated ? "TBD" : "Field")
            let outcome = outcome(
                teamAward: teamAward,
                opponentAward: opponentAward,
                status: status
            )
            return SeriesTeamScheduleRow(
                id: round.id,
                title: title,
                opponentName: opponentName,
                statusLabel: status.rawValue.capitalized,
                outcomeLabel: outcome.label,
                pointsLabel: teamAward.map { "\($0.totalPoints.seriesPointsDisplayString) pts" },
                outcomeKind: outcome.kind
            )
        }
    }

    private static func opponentTeamID(for teamID: String, round: SeriesRound) -> String? {
        let plans = round.matchupPlans + round.plannedMatchups.map(\.matchupPlan)
        return plans.compactMap { plan -> String? in
            if plan.teamAID == teamID, plan.teamBID.isPopulated { return plan.teamBID }
            if plan.teamBID == teamID, plan.teamAID.isPopulated { return plan.teamAID }
            return nil
        }.first
    }

    private static func opponentAward(
        for teamAward: SeriesPointAward?,
        roundAwards: [SeriesPointAward],
        snapshot: RoundSnapshot?
    ) -> SeriesPointAward? {
        guard let teamAward,
              let roundOwnerID = teamAward.roundOwnerID?.trimmingCharacters(in: .whitespacesAndNewlines),
              roundOwnerID.isPopulated,
              let snapshot else { return nil }

        let matchups = snapshot.segments.flatMap { $0.matchups ?? [] }
        for matchup in matchups {
            let pairingIDs = matchup.pairingIDs().filter(\.isPopulated)
            guard pairingIDs.count == 2, pairingIDs.contains(roundOwnerID) else { continue }
            guard let opponentOwnerID = pairingIDs.first(where: { $0 != roundOwnerID }) else { continue }
            if let award = roundAwards.first(where: {
                $0.awardTrack == .team
                    && $0.roundOwnerID == opponentOwnerID
                    && $0.competitorID != teamAward.competitorID
            }) {
                return award
            }
            if let award = roundAwards.first(where: {
                $0.awardTrack == .team
                    && $0.competitorID == opponentOwnerID
                    && $0.competitorID != teamAward.competitorID
            }) {
                return award
            }
        }

        return nil
    }

    private static func outcome(
        teamAward: SeriesPointAward?,
        opponentAward: SeriesPointAward?,
        status: SeriesRoundStatus
    ) -> (label: String, kind: SeriesTeamScheduleOutcomeKind) {
        if let teamAward, let opponentAward {
            if teamAward.totalPoints > opponentAward.totalPoints { return ("Win", .win) }
            if teamAward.totalPoints < opponentAward.totalPoints { return ("Loss", .loss) }
            return ("Tie", .tie)
        }
        if let teamAward {
            let placement = teamAward.placement.map { "#\($0)" } ?? "Placed"
            return (placement, .placement)
        }
        if status == .complete { return ("Complete", .pending) }
        return (status.rawValue.capitalized, .pending)
    }

    private static func grossScoresByMemberID(
        roster: [SeriesMember],
        rounds: [SeriesRound],
        snapshotsBySeriesRoundID: [String: RoundSnapshot]
    ) -> [String: [GrossScore]] {
        var scores: [String: [GrossScore]] = [:]
        for round in rounds.sorted(by: { $0.index < $1.index }) {
            guard let snapshot = snapshotsBySeriesRoundID[round.id] else { continue }
            for member in roster {
                guard let gross = grossTotal(member: member, snapshot: snapshot) else { continue }
                scores[member.id, default: []].append(GrossScore(roundID: round.id, roundIndex: round.index, gross: gross))
            }
        }
        return scores
    }

    private static func grossTotal(member: SeriesMember, snapshot: RoundSnapshot) -> Int? {
        guard let participant = snapshot.participants.first(where: { participant in
            participant.seriesMemberID == member.id
                || (member.playerID?.isPopulated == true && participant.playerID == member.playerID)
                || participant.id == member.id
        }) else { return nil }

        let entriesByHole = Dictionary(
            grouping: snapshot.scoring.filter { $0.scoringUnitID == participant.id },
            by: \.holeNumber
        ).compactMapValues(\.first)
        guard entriesByHole.isPopulated else { return nil }

        var total = 0
        var hasScore = false
        for entry in entriesByHole.values {
            if let strokes = entry.strokes {
                total += strokes
                hasScore = true
            } else if let relative = entry.relativeToPar,
                      let par = par(for: entry.holeNumber, participant: participant, snapshot: snapshot) {
                total += par + relative
                hasScore = true
            }
        }
        return hasScore ? total : nil
    }

    private static func par(for holeNumber: Int, participant: RoundParticipant, snapshot: RoundSnapshot) -> Int? {
        let tee = snapshot.courseSegment?.tee(from: participant.teeBoxID)
            ?? snapshot.defaultTee
            ?? snapshot.tees.first
        return tee?.holes.first { $0.number == holeNumber }?.par
    }

    private static func trend(for grossScores: [GrossScore]) -> (label: String, kind: SeriesTeamPlayerTrendKind)? {
        guard grossScores.count >= 2,
              let previous = grossScores.dropLast().last,
              let latest = grossScores.last else { return nil }
        let delta = latest.gross - previous.gross
        if delta == 0 { return ("Gross even vs prev", .steady) }
        if delta < 0 { return ("Gross -\(abs(delta)) vs prev", .improved) }
        return ("Gross +\(delta) vs prev", .worse)
    }

    private static func topContributor(from performances: [SeriesTeamPlayerPerformance]) -> (name: String, detail: String) {
        if let topByPoints = performances
            .filter({ $0.points > 0 })
            .sorted(by: {
                if $0.points != $1.points { return $0.points > $1.points }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            })
            .first {
            return (topByPoints.name, "\(topByPoints.points.seriesPointsDisplayString) player pts")
        }

        if let topByScore = performances
            .compactMap({ performance -> (SeriesTeamPlayerPerformance, Double)? in
                guard let averageGross = performance.averageGross else { return nil }
                return (performance, averageGross)
            })
            .sorted(by: {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
            })
            .first {
            return (topByScore.0.name, "\(formatDecimal(topByScore.1)) avg gross")
        }

        return ("No results yet", "Complete a round to build form")
    }

    private static func average(_ values: [Double]) -> Double? {
        guard values.isPopulated else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2, let avg = average(values) else { return nil }
        let variance = values.reduce(0) { $0 + pow($1 - avg, 2) } / Double(values.count)
        return sqrt(variance)
    }

    static func formatDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
