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

    /// Sets best N override for templates that support it (e.g. best 2 of 4).
    func setBestN(_ n: Int) async {
        addBreadcrumb()
        let previousBestN = snapshot.configuration.bestNSelected
        let previousBestWorst = snapshot.configuration.bestWorstEnabled ?? false

        do {
            if snapshot.round.configuration.bestNSelected != n || snapshot.round.configuration.bestWorstEnabled == true {
                snapshot.round.configuration.bestNSelected = n
                snapshot.round.configuration.bestWorstEnabled = false
                _ = try await snapshot.round.put().get()
            }

            guard previousBestN != n || previousBestWorst else { return }
            var props: [String: Any] = [
                "best_n_selected": n,
                "best_worst_enabled": false,
                "previous_best_worst_enabled": previousBestWorst
            ]
            if let previousBestN {
                props["previous_best_n_selected"] = previousBestN
            }
            emitRoundSetupEvent("round_setup.best_n_changed", extra: props)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set best N", error: error)
        }
    }

    /// Sets worst-score mode for Best Ball (e.g. 2-man worst ball). Uses team size from participants.
    func setBestWorst() async {
        addBreadcrumb()
        let previousBestN = snapshot.configuration.bestNSelected
        let previousBestWorst = snapshot.configuration.bestWorstEnabled ?? false

        do {
            let teamSize = max(2, snapshot.participants.reduce(0) { count, p in
                guard let teamID = p.teamID else { return count }
                return max(count, snapshot.participants.filter { $0.teamID == teamID }.count)
            })
            if snapshot.round.configuration.bestWorstEnabled != true || snapshot.round.configuration.bestNSelected != teamSize {
                snapshot.round.configuration.bestWorstEnabled = true
                snapshot.round.configuration.bestNSelected = teamSize
                _ = try await snapshot.round.put().get()
            }

            guard previousBestN != teamSize || !previousBestWorst else { return }
            var props: [String: Any] = [
                "best_n_selected": teamSize,
                "best_worst_enabled": true,
                "previous_best_worst_enabled": previousBestWorst
            ]
            if let previousBestN {
                props["previous_best_n_selected"] = previousBestN
            }
            emitRoundSetupEvent("round_setup.best_n_changed", extra: props)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set best worst", error: error)
        }
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
        let isMatchPlay = template.pipeline.contains { stage in
            if case .compare = stage { return true }
            return false
        }
        let type: GameFormatType = isMatchPlay ? .matchPlay : .strokePlay
        let aggregation: Aggregation? = template.subject == .team
            ? Aggregation(mode: .countBest, scope: .perHole, bestN: 1)
            : nil
        let config = GameConfiguration(
            method: template.subject == .team ? .aggregate : .individual,
            aggregation: aggregation,
            basis: template.requirements.defaultScoreBasis,
            handicap: template.requirements.defaultHandicapConfig,
            requiresTeams: template.requirements.requiresTeams,
            maxScoreOverPar: template.requirements.defaultMaxScoreOverPar
        )
        return GameFormat(type: type, configuration: config)
    }
}
