//
//  Firebase+Player.swift
//  Hackers
//
//  Created by Kyle Beard on 11/5/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection: String = Collections.players.rawValue

extension FirebaseService {
    func getPlayerByID(_ value: String) async -> Result<Player, Error> {
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "id", isEqualTo: value, in: collection)
    }
    
    func getPlayersByIDs(_ values: [String]) async -> Result<[Player], Error> {
        addBreadcrumb("\(#function), \(values)")
        return await fetchByIDs(values, in: collection)
    }
    
    func searchPlayersByName(_ prefix: String) async -> Result<[Player], Error> {
        addBreadcrumb("\(#function), \(prefix)")
        return await fetch(where: "name.search_key", hasPrefix: prefix, in: collection)
    }
    
    // MARK: - Helpers
    
    /// Query the `Players` collection to see if email is linked to existing document in Cloud Firestore.
    func doesPlayerExistByID(_ value: String) async -> Bool {
        addBreadcrumb("\(#function), \(value)")
        switch await getPlayerByID(value) {
        case .success(_):   return true
        case .failure(_):   return false
        }
    }
}
