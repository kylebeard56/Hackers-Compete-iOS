//
//  SeriesRoundTileCopy.swift
//  Hackers
//
//  Presentation strings for series round list tiles (format line + matchup opponent block).
//

import Foundation

struct SeriesRoundTileOpponentSummary: Equatable {
    var primaryLine: String
    var secondaryLine: String?
}

enum SeriesRoundTileCopy {

    static func formatCaption(config: SeriesRoundConfiguration, series: Series) -> String {
        var basis = config.scoreBasisOverride ?? config.template.requirements.defaultScoreBasis
        if series.handicapConfig.isEnabled && config.scoreBasisOverride == nil {
            basis = .net
        }

        let requiresTeams = config.legacyGameFormat.configuration.requiresTeams
        var parts: [String] = [config.template.name]
        if basis == .net {
            parts.append("Net")
        }
        if requiresTeams {
            parts.append(teamScoringFragment(config.teamScoring))
        }
        return parts.joined(separator: " \(kDot) ")
    }

    static func opponentSummary(
        seriesRound: SeriesRound,
        configuration: SeriesRoundConfiguration,
        currentMemberID: String?,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        hasTeamsInLeague: Bool
    ) -> SeriesRoundTileOpponentSummary? {
        guard configuration.resolvedCompetitionScope == .matchup else { return nil }
        guard let currentMemberID,
              let selfMember = members.first(where: { $0.id == currentMemberID }) else { return nil }

        for plan in seriesRound.matchupPlans {
            if plan.validTeamPairing, let myTeam = selfMember.teamID {
                if plan.teamAID == myTeam {
                    return opponentTeamSummary(opponentTeamID: plan.teamBID, members: members, teams: teams)
                }
                if plan.teamBID == myTeam {
                    return opponentTeamSummary(opponentTeamID: plan.teamAID, members: members, teams: teams)
                }
            } else if plan.validMemberPairing {
                if plan.memberAID == currentMemberID, let oid = plan.memberBID {
                    return opponentMemberSummary(
                        opponentMemberID: oid,
                        members: members,
                        teams: teams,
                        pods: pods,
                        hasTeamsInLeague: hasTeamsInLeague
                    )
                }
                if plan.memberBID == currentMemberID, let oid = plan.memberAID {
                    return opponentMemberSummary(
                        opponentMemberID: oid,
                        members: members,
                        teams: teams,
                        pods: pods,
                        hasTeamsInLeague: hasTeamsInLeague
                    )
                }
            }
        }

        return nil
    }

    private static func teamScoringFragment(_ scoring: RoundTeamScoringConfiguration) -> String {
        switch scoring.mode {
        case .all:
            return "All scores count"
        case .bestN:
            let scopeWord = scoring.scope == .perRound ? "round" : "hole"
            return "Best \(scoring.count) per \(scopeWord)"
        case .worstN:
            let scopeWord = scoring.scope == .perRound ? "round" : "hole"
            return "Worst \(scoring.count) per \(scopeWord)"
        }
    }

    private static func opponentTeamSummary(
        opponentTeamID: String,
        members: [SeriesMember],
        teams: [SeriesTeam]
    ) -> SeriesRoundTileOpponentSummary? {
        guard let team = teams.first(where: { $0.id == opponentTeamID }) else { return nil }
        let opponentMembers = members.filter { $0.teamID == opponentTeamID && $0.role != .spectator }
        let secondary = teammateShortSubtitle(for: opponentMembers)
        return SeriesRoundTileOpponentSummary(primaryLine: team.name, secondaryLine: secondary)
    }

    private static func opponentMemberSummary(
        opponentMemberID: String,
        members: [SeriesMember],
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        hasTeamsInLeague: Bool
    ) -> SeriesRoundTileOpponentSummary? {
        guard let opponent = members.first(where: { $0.id == opponentMemberID }) else { return nil }
        let secondary = individualContextSubtitle(
            opponent: opponent,
            teams: teams,
            pods: pods,
            hasTeamsInLeague: hasTeamsInLeague
        )
        return SeriesRoundTileOpponentSummary(primaryLine: opponent.name.fullName, secondaryLine: secondary)
    }

    private static func individualContextSubtitle(
        opponent: SeriesMember,
        teams: [SeriesTeam],
        pods: [SeriesTeamPod],
        hasTeamsInLeague: Bool
    ) -> String? {
        let subtitlePod = pods.first { $0.isActive && $0.memberIDs.contains(opponent.id) }
        if let tid = opponent.teamID, let team = teams.first(where: { $0.id == tid }) {
            if let subtitlePod {
                return "\(team.name) \(kDot) \(subtitlePod.resolvedLabel)"
            }
            return team.name
        }
        if let subtitlePod {
            return subtitlePod.resolvedLabel
        }
        if hasTeamsInLeague {
            return "Unassigned"
        }
        return nil
    }

    private static func shortRosterName(_ name: Name) -> String {
        let given = name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let initial = family.first else { return given }
        return "\(given) \(String(initial).uppercased())"
    }

    private static func teammateShortSubtitle(for members: [SeriesMember]) -> String? {
        guard !members.isEmpty else { return nil }
        let labels = members.map { shortRosterName($0.name) }
        if members.count > 3 {
            return labels.prefix(2).joined(separator: ", ") + ", +\(members.count - 2)"
        }
        return labels.joined(separator: ", ")
    }
}
