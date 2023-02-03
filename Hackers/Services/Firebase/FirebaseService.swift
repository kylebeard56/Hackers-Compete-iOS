//
//  FirebaseService.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import SwiftUI

class FirebaseService: Loggable {
    static let shared = FirebaseService()
    
    let database = Firestore.firestore()
    
    init() {
        print("init FirebaseService")
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        database.settings = settings
    }
    
    deinit { print("deinit FirebaseService") }
}

enum Collections: String {
    /// Play packs and their content
    case packs = "packs-v1"
    
    /// Rules belonging to packs
    case rules = "rules-v1"
    
    /// Sessions belonging to live gameplay
    case sessions = "sessions-v1"
}

protocol FirebaseIdentifiable: Hashable, Codable {
    var id: String { get set }
}

extension FirebaseIdentifiable {
    /// POST to Firebase
    func post(to collection: String, cache: Bool = true) async -> Result<Self, Error> {
        return await FirebaseService.shared.post(self, to: collection, cache: cache)
    }

    /// PUT to Firebase
    func put(to collection: String, cache: Bool = true) async -> Result<Self, Error> {
        return await FirebaseService.shared.put(self, to: collection, cache: cache)
    }

    /// DELETE from Firebase
    func delete(from collection: String, cache: Bool = true) async -> Result<Bool, Error> {
        return await FirebaseService.shared.delete(self, in: collection, cache: cache)
    }
}


