//
//  RoundSession+Config.swift
//  Hackers
//
//  Created by Kyle Beard on 11/13/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundSession {
    func toggleHandicaps(_ value: Bool) async {
        addBreadcrumb()
        let previousValue = snapshot.configuration.useHandicaps
        
        do {
            let desiredBasis: ScoreBasis = value ? .net : .gross
            
            // Legacy dual-write (kept for backward compatibility)
            if snapshot.round.configuration.primaryFormat.configuration.basis != desiredBasis {
                snapshot.round.configuration.primaryFormat.configuration.basis = desiredBasis
                _ = try await snapshot.round.put().get()
            }
            
            if var mainSegment = snapshot.segments.first, mainSegment.gameFormat.configuration.basis != desiredBasis {
                mainSegment.gameFormat.configuration.basis = desiredBasis
                snapshot.segments[0] = mainSegment
                _ = try await mainSegment.put().get()
            }

            guard previousValue != value else { return }
            emitRoundSetupEvent(
                "round_setup.handicaps_toggled",
                extra: [
                    "enabled": value,
                    "previous_value": previousValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set handicap config", error: error)
        }
    }
    
    func toggleTeams(_ value: Bool) async {
        addBreadcrumb()
        let previousValue = snapshot.requiresTeams
        guard !snapshot.isVegasFormat || value else { return }
        
        do {
            // Legacy dual-write (kept for backward compatibility)
            if snapshot.round.configuration.primaryFormat.configuration.requiresTeams != value {
                snapshot.round.configuration.primaryFormat.configuration.requiresTeams = value
                _ = try await snapshot.round.put().get()
            }
            
            if var mainSegment = snapshot.segments.first, mainSegment.gameFormat.configuration.requiresTeams != value {
                mainSegment.gameFormat.configuration.requiresTeams = value
                snapshot.segments[0] = mainSegment
                _ = try await mainSegment.put().get()
            }

            guard previousValue != value else { return }
            emitRoundSetupEvent(
                "round_setup.teams_toggled",
                extra: [
                    "enabled": value,
                    "previous_value": previousValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team config", error: error)
        }
    }

    func setTeamColorsEnabled(_ value: Bool) async {
        addBreadcrumb()
        let previousUses = snapshot.configuration.usesTeamColors

        do {
            if snapshot.round.configuration.teamColorsEnabled != value {
                snapshot.round.configuration.teamColorsEnabled = value
                _ = try await snapshot.round.put().get()
            }

            let nowUses = snapshot.configuration.usesTeamColors
            guard previousUses != nowUses else { return }

            try await applyTeamColorMode(useColors: nowUses)

            emitRoundSetupEvent(
                "round_setup.team_colors_toggled",
                extra: [
                    "enabled": nowUses,
                    "previous_value": previousUses
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team colors config", error: error)
        }
    }

    func setMaxScoreOverPar(_ value: MaxScoreOverPar) async {
        addBreadcrumb()
        let previousValue = snapshot.gameFormat.configuration.maxScoreOverPar
        
        do {
            // Legacy dual-write (kept for backward compatibility)
            if snapshot.round.configuration.primaryFormat.configuration.maxScoreOverPar != value {
                snapshot.round.configuration.primaryFormat.configuration.maxScoreOverPar = value
                _ = try await snapshot.round.put().get()
            }
            
            if var mainSegment = snapshot.segments.first,
               mainSegment.gameFormat.configuration.maxScoreOverPar != value {
                mainSegment.gameFormat.configuration.maxScoreOverPar = value
                snapshot.segments[0] = mainSegment
                _ = try await mainSegment.put().get()
            }

            guard previousValue != value else { return }
            emitRoundSetupEvent(
                "round_setup.max_score_changed",
                extra: [
                    "value": value.rawValue,
                    "previous_value": previousValue.rawValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set max score config", error: error)
        }
    }

    func setSecretScoring(_ enabled: Bool) async {
        addBreadcrumb()
        do {
            snapshot.round.configuration.secretScoring = enabled
            if !enabled {
                snapshot.round.configuration.scoresRevealed = nil
            }
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set secret scoring", error: error)
        }
    }

    func revealScores() async {
        addBreadcrumb()
        do {
            snapshot.round.configuration.scoresRevealed = true
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to reveal scores", error: error)
        }
    }

    func toggleSequentialTeeStarts(_ value: Bool) async {
        addBreadcrumb()
        let previousValue = snapshot.configuration.usesSequentialTeeStarts

        do {
            if snapshot.round.configuration.sequentialTeeStartsEnabled != value {
                snapshot.round.configuration.sequentialTeeStartsEnabled = value
                _ = try await snapshot.round.put().get()
            }

            if value {
                try await resequenceTeeGroupsForSequentialStarts()
            }

            guard previousValue != value else { return }
            emitRoundSetupEvent(
                "round_setup.sequential_tee_starts_toggled",
                extra: [
                    "enabled": value,
                    "previous_value": previousValue
                ]
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update sequential tee starts", error: error)
        }
    }
}
