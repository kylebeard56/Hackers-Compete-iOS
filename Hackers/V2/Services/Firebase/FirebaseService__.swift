//
//  FirebaseServiceV2.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation
import SwiftUI

class FirebaseServiceV2: Loggable {
    static let shared = FirebaseServiceV2()
    
    let database = Firestore.firestore()
    
    init() {
        print("init FirebaseServiceV2")
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        database.settings = settings
    }
    
    deinit { print("deinit FirebaseServiceV2") }
}

enum CollectionsV2: String {
    /// Internal configuration
    case configuration = "configuration"
    
    /// Rules belonging to Cards of Chaos
    case chaosRules = "chaos-rules-v1"
    
    /// Rules belonging to Cards of Chaos
    case rules = "rules-v1"
    
    /// Sessions belonging to live gameplay
    case sessions = "sessions-v3"//"sessions-test"
    
    /// Suggestion-box
    case suggestionBox = "suggestion-box-v1"
}

protocol FirebaseIdentifiable: Hashable, Codable {
    var id: String { get set }
}

extension FirebaseIdentifiable {
    /// POST to Firebase
    func post(to collection: String, cache: Bool = true) async -> Result<Self, Error> {
        return await FirebaseServiceV2.shared.post(self, to: collection, cache: cache)
    }

    /// PUT to Firebase
    func put(to collection: String, cache: Bool = true) async -> Result<Self, Error> {
        return await FirebaseServiceV2.shared.put(self, to: collection, cache: cache)
    }

    /// DELETE from Firebase
    func delete(from collection: String, cache: Bool = true) async -> Result<Bool, Error> {
        return await FirebaseServiceV2.shared.delete(self, in: collection, cache: cache)
    }
}
