//
//  SentryService.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import Sentry

/// https://docs.sentry.io/platforms/apple/configuration/

enum SentryCategory: String {
    case auth, firebase, packs, rules, session
}

protocol Loggable {
    func addBreadcrumb(_ level: SentryLevel, _ category: SentryCategory, _ message: String, _ error: Error?)
}

extension Loggable {
    /// Hook a breadcumb onto the Sentry SDK logging service chain. This is useful to passing as much information as
    /// possible through the app lifecycle.
    /// - Parameters:
    ///   - level: The specific level of logging associated with the breadcrumb (defult is `.info`).
    ///   - category: The specific category throughout the application for filtering.
    ///   - message: The textual message to send with the breadcrumb.
    func addBreadcrumb(
        _ level: SentryLevel,
        _ category: SentryCategory,
        _ message: String,
        _ error: Error? = nil
    ) {
        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = category.rawValue
        crumb.message = message
        if let error = error {
            crumb.message = message + " with error: \(error)"
        }
        SentrySDK.addBreadcrumb(crumb: crumb)

        switch level {
        case .error, .warning:
            print("Breadcrumb trail captured...")
            SentrySDK.capture(event: Event(level: level))
        default:
            print("Breadcrumb trail is growing...")
        }
        if let error = error {
            print("\(level): \(message), \(error)")
        } else {
            print("\(level): \(message)")
        }
    }

    func storeSentryUser(with email: String) {
        let user = User()
        user.email = email
        SentrySDK.setUser(user)
    }
}
