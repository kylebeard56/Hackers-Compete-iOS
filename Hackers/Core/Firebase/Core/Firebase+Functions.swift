//
//  Firebase+Functions.swift
//  Hackers
//
//  Created by Kyle Beard on 10/6/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import FirebaseFunctions
import Foundation
import SwiftUI

extension FirebaseService {
    fileprivate var functions: Functions { Functions.functions(region: "us-central1") }
    
    fileprivate enum FunctionName: String {
        case deleteFullRound = "deleteFullRound"
        case clearAllPlayerHistory = "clearAllPlayerHistory"

        var name: String { self.rawValue }
    }
}

extension FirebaseService {
    func delete(round: Round) async -> Bool {
        let path = "\(Collections.rounds)/\(round.id)"
        let data = ["path": path]
        let name = FunctionName.deleteFullRound.name
        
        addBreadcrumb(message: "\(#function), path: \(path)")
        
        do {
            let result = try await functions.httpsCallable(name).call(data)
            guard let dict = result.data as? [String: Any], let ok = dict["ok"] as? Bool, ok else {
                addBreadcrumb(level: .error, message: "Cloud Function \(name) failed to return OK, \(round.id)")
                return false
            }
            addBreadcrumb(message: "Cloud Function \(name) successful")
            return true
        } catch {
            addBreadcrumb(
                level: .error,
                message: "Cloud Function \(name) failed to delete round, \(round.id)",
                error: error
            )
            return false
        }
    }
}

extension FirebaseService {
    /// Clears player_history, course_history, and processed_round_ids for all players.
    /// Call when you need to nuke sandbox history without deleting player profiles.
    /// Example: Task { _ = await FirebaseService.shared.clearAllPlayerHistory() }
    func clearAllPlayerHistory() async -> Bool {
        addBreadcrumb(message: "\(#function)")
        
        let name = FunctionName.clearAllPlayerHistory.name
        
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable(name).call([:])
            guard let dict = result.data as? [String: Any],
                  let ok = dict["ok"] as? Bool, ok else {
                addBreadcrumb(level: .error, message: "Cloud Function \(name) failed to return OK")
                return false
            }
            addBreadcrumb(message: "Cloud Function \(name) successful, playersUpdated: \(dict["playersUpdated"] ?? "?")")
            return true
        } catch {
            addBreadcrumb(level: .error, message: "Cloud Function \(name) failed", error: error)
            return false
        }
    }

    // Add more sandbox-only, manually-invoked functions below as needed.
}

