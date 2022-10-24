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

protocol FirebaseIdentifiable: Hashable, Codable {
    var id: String { get set }
}

enum Collections: String {
    /// Gameplay packs and their content
    case packs = "packs-v1"
    
    /// Rules belonging to packs
    case rules = "rules-v1"
}

class FirebaseService { //}: Alertable, Loggable {
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
