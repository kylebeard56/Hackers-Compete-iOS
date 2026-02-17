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
        
        do {
            let desiredBasis: ScoreBasis = value ? .net : .gross
            
            if snapshot.round.configuration.primaryFormat.configuration.basis != desiredBasis {
                snapshot.round.configuration.primaryFormat.configuration.basis = desiredBasis
                _ = try await snapshot.round.put().get()
            }
            
            if var mainSegment = snapshot.segments.first, mainSegment.gameFormat.configuration.basis != desiredBasis {
                mainSegment.gameFormat.configuration.basis = desiredBasis
                snapshot.segments[0] = mainSegment
                _ = try await mainSegment.put().get()
            }
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set handicap config", error: error)
        }
    }
    
    func toggleTeams(_ value: Bool) async {
        addBreadcrumb()
        
        do {
            if snapshot.round.configuration.primaryFormat.configuration.requiresTeams != value {
                snapshot.round.configuration.primaryFormat.configuration.requiresTeams = value
                _ = try await snapshot.round.put().get()
            }
            
            if var mainSegment = snapshot.segments.first, mainSegment.gameFormat.configuration.requiresTeams != value {
                mainSegment.gameFormat.configuration.requiresTeams = value
                snapshot.segments[0] = mainSegment
                _ = try await mainSegment.put().get()
            }
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team config", error: error)
        }
    }
    
    func setMaxScoreOverPar(_ value: MaxScoreOverPar) async {
        addBreadcrumb()
        
        do {
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
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set max score config", error: error)
        }
    }
}
