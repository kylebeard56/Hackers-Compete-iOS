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
    // Core app flows
    case admin, auth, legal, general, routing

    // Backend and user interaction
    case firebase, session, waitlist, suggestionBox

    // Golf course API and searching
    case golfCourseAPI, golfCourseFinder
    
    // Legacy V2 app
    case rules, sideGame
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
        SentrySDK.addBreadcrumb(crumb)

        if [.error, .warning].contains(level) {
            SentrySDK.capture(event: Event(level: level))
        }
        
        print("[\(label(for: crumb.level))] \(crumb.message ?? "Message not available")")
    }
    
    /// Adds a breadcrumb that is purely a info function
    func addBreadcrumb(_ functionName: String) {
        self.addBreadcrumb(.info, .general, functionName)
    }

    func storeSentryUser(with email: String) {
        let user = User()
        user.email = email
        SentrySDK.setUser(user)
    }
    
    private func label(for level: SentryLevel) -> String {
        switch level {
        case .debug:        return "DEBUG"
        case .info:         return "INFO"
        case .warning:      return "WARNING"
        case .error:        return "ERROR"
        case .fatal:        return "FATAL"
        case .none:         return "NONE"
        @unknown default:   return "NONE"
        }
      }
}
