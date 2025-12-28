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
    case development = "Development"
    
    static var current: AppEnvironment = {
        #if SANDBOX
        return .development
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
        return Self.current == .development
    }
    
    static var googleServiceFileName: String {
        switch Self.current {
        case .production:   return "GoogleService-Info-Prod"
        case .development:  return "GoogleService-Info-Sandbox"
        }
    }
}
