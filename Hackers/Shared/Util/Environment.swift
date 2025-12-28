//
//  Configuration.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation

@MainActor
enum AppEnvironment: String {
    case production = "Production"
    case sandbox = "Sandbox"
    
    static var current: AppEnvironment = {
        #if SANDBOX
        return .sandbox
        #else
        return .production
        #endif
    }()
    
    static var name: String {
        Self.current.rawValue
    }
    
    static var isProduction: Bool {
        return Self.current == .production
    }
    
    static var isSandbox: Bool {
        return Self.current == .sandbox
    }
    
    static var googleServiceFileName: String {
        switch Self.current {
        case .production:   return "GoogleService-Info-Prod"
        case .sandbox:      return "GoogleService-Info-Sandbox"
        }
    }
}
