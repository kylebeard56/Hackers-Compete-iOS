//
//  FirebaseService.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation
import SwiftUI

enum Collections: String {
    /// Internal configuration
    case configuration = "configuration"
    
    /// Rules belonging to Cards of Chaos
    case chaosRules = "chaos-rules-v1"
    
    /// Rules belonging to Cards of Chaos
    case rules = "rules-v1"
    
    /// Sessions belonging to live gameplay -> bump to V4
    case sessions = "sessions-v4" //"sessions-test"
    
    /// Suggestion-box
    case suggestionBox = "suggestion-box-v1"
    
    /// User accounts
    case users = "users-v1"
    
    /// Prefix sandbox with underscore to differentiate collection names
    var name: String {
        self.rawValue
    }
}

// MARK: - FirebaseService

final actor FirebaseService: Sendable, Loggable {
    static let shared = FirebaseService()

    var appVersionObserver: ListenerRegistration?
    
    private init() {
        print("init FirebaseService")

        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 200 * 1024 * 1024 as NSNumber) // Disk size 200 MB
        Firestore.firestore().settings = settings
    }
    
    deinit {
        print("deinit FirebaseService")
    }
}
