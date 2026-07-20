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
        case createSeriesV2 = "createSeriesV2"
        case createSeriesRoundV2 = "createSeriesRoundV2"
        case transitionRoundV2 = "transitionRoundV2"
        case applySeriesDefaultsV2 = "applySeriesDefaultsV2"
        case adoptRoundIntoSeriesV2 = "adoptRoundIntoSeriesV2"
        case setSeriesMigrationPhaseV2 = "setSeriesMigrationPhaseV2"

        var name: String { self.rawValue }
    }
}

extension FirebaseService {
    func createSeriesV2(_ command: CreateSeriesV2Command) async -> Result<V2CommandResponse, Error> {
        await callV2Command(.createSeriesV2, payload: command)
    }

    func createSeriesRoundV2(_ command: CreateSeriesRoundV2Command) async -> Result<V2CommandResponse, Error> {
        await callV2Command(.createSeriesRoundV2, payload: command)
    }

    func transitionRoundV2(_ command: TransitionRoundV2Command) async -> Result<V2CommandResponse, Error> {
        await callV2Command(.transitionRoundV2, payload: command)
    }

    func applySeriesDefaultsV2(_ command: ApplySeriesDefaultsV2Command) async -> Result<V2CommandResponse, Error> {
        await callV2Command(.applySeriesDefaultsV2, payload: command)
    }

    func adoptRoundIntoSeriesV2(_ command: AdoptRoundIntoSeriesV2Command) async -> Result<V2CommandResponse, Error> {
        await callV2Command(.adoptRoundIntoSeriesV2, payload: command)
    }

    func setSeriesMigrationPhaseV2(
        _ command: SetSeriesMigrationPhaseV2Command
    ) async -> Result<V2CommandResponse, Error> {
        await callV2Command(.setSeriesMigrationPhaseV2, payload: command)
    }

    private func callV2Command<Payload: Encodable>(
        _ functionName: FunctionName,
        payload: Payload
    ) async -> Result<V2CommandResponse, Error> {
        addBreadcrumb(message: "\(#function), command: \(functionName.name)")
        do {
            let result = try await functions.httpsCallable(functionName.name).call(try payload.toDictionary())
            guard let value = result.data as? [String: Any],
                  let ok = value["ok"] as? Bool,
                  let commandID = value["command_id"] as? String,
                  let entityID = value["entity_id"] as? String,
                  let revision = (value["revision"] as? NSNumber)?.intValue,
                  let replayed = value["replayed"] as? Bool else {
                throw SeriesRoundV2Error.malformedCommandResponse
            }
            return .success(.init(
                ok: ok,
                commandID: commandID,
                entityID: entityID,
                revision: revision,
                replayed: replayed
            ))
        } catch {
            addBreadcrumb(level: .error, message: "V2 command failed: \(functionName.name)", error: error)
            return .failure(error)
        }
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
