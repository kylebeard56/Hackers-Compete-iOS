//
//  Configuration.swift
//  Hackers
//
//  Created by Kyle Beard on 4/12/23.
//

import Foundation
import SwiftUI

var appConfig = HackersConfiguration.load()

class HackersConfiguration {

    /// Load the app's configuration properties
    static func load() -> ConfigurationProperties {
        guard let env = fetchValue(forKey: "Environment mode") as? String,
              let environment = AppEnvironment(rawValue: env) else {
            fatalError("Unable to fetch environment from ConfigurationLoader")
        }
        return ConfigurationProperties(environment: environment)
    }

    /// Query the `info.plist` and load in the `ConfigurationProperties` dictionary.
    static func fetchValue(forKey key: String) -> Any {
        guard let resourceFile = Bundle.main.infoDictionary,
              let dict = resourceFile["Configuration properties"] as? [String: Any]
        else {
            fatalError("Unable to load configuration properties from info.plist")
        }
        return dict[key]!
    }

    static func choose<T>(dev: T, prod: T) -> T {
        #if DEBUG
        return dev
        #else
        return prod
        #endif
    }
}

/// Represents the `info.plist ConfigurationProperties` key for the application, which is bundled
/// and mapped depending on the scheme in which the application is built upon.
struct ConfigurationProperties {
    var environment: AppEnvironment
    
    var isSandbox: Bool {
        return self.environment == .admin
    }
}

enum AppEnvironment: String {
    case user = "User mode"
    case admin = "Admin mode"

    var name: String {
        return self.rawValue
    }
}
