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
            snapshot.round.configuration.primaryFormat.configuration.basis = value ? .net : .gross
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set handicap config", error: error)
        }
    }
    
    func toggleTeams(_ value: Bool) async {
        addBreadcrumb()
        
        do {
            snapshot.round.configuration.primaryFormat.configuration.requiresTeams = value
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set team config", error: error)
        }
    }
}
