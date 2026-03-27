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
}
