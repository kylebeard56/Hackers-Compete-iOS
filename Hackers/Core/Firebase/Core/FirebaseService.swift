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

// TODO: Before Production, introduce FirebaseVersionable protocol for schemaVersioning and migration management.
enum Collections: String {
    /// Internal configuration
    case configuration = "configuration"
    
    /// Golf course data crowdsourced from API or OCR
    case courses = "courses"
    
    /// Player accounts
    case players = "players"
    
    /// Round objects
    case rounds = "rounds"

    /// V2 canonical round aggregates. V1 remains in `rounds` until migrated.
    case roundsV2 = "rounds-v2"
    
    /// Series (leagues / multi-round events)
    case series = "series"

    /// V2 Series roots. V1 remains in `series` until migrated.
    case seriesV2 = "series-v2"
    
    /// Suggestion-box
    case suggestionBox = "suggestion-box"
    
    /// User accounts
    case users = "users"
    
    /// Prefix sandbox with underscore to differentiate collection names
    var name: String { self.rawValue }
}

// MARK: - FirebaseService

final actor FirebaseService: Sendable, Loggable {
    static let shared = FirebaseService()

    var appVersionObserver: ListenerRegistration?
    
    private init() { print("init FirebaseService") }
    
    deinit {
        print("deinit FirebaseService")
    }
}
