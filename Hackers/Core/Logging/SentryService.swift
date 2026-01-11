//
//  SentryService.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import Sentry

/// https://docs.sentry.io/platforms/apple/configuration/

//enum SentryCategory: String {
//    // Core app flows
//    case admin, auth, legal, general, routing
//
//    // Core servies
//    case locationServices
//    
//    // Backend and user interaction
//    case firebase, session, waitlist, suggestionBox
//
//    // Golf course API and searching
//    case golfCourseAPI, golfCourseFinder
//    
//    // Round
//    case gameLobby, roundService, joinRound
//    
//    // Legacy V2 app
//    case rules, sideGame
//}

protocol Loggable {
    //func addBreadcrumb(_ level: SentryLevel, _ category: SentryCategory, _ message: String, _ error: Error?)
}

//extension SentryLevel {
//    var consoleColor: ConsoleColor {
//        switch self {
//        case .debug:    return .green
//        case .info:     return .blue
//        case .warning:  return .orange
//        case .error:    return .red
//        case .fatal:    return .red
//        default:        return .white
//        }
//    }
//}

extension Loggable {
    /// Hook a breadcumb onto the Sentry SDK logging service chain. This is useful to passing as much information as
    /// possible through the app lifecycle.
    /// - Parameters:
    ///   - level: The specific level of logging associated with the breadcrumb (defult is `.info`).
    ///   - category: The specific category throughout the application for filtering.
    ///   - message: The textual message to send with the breadcrumb.
    func addBreadcrumb(
        level: SentryLevel = .info,
        category: String? = nil,
        message: String? = nil,
        error: Error? = nil,
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        parameters: [String: Any]? = nil
    ) {
        let breadcrumb = Breadcrumb()
        breadcrumb.level = level
        breadcrumb.category = category ?? ""
        breadcrumb.message = message ?? function
        
        if let error = error {
            breadcrumb.message = (message ?? function) + " with error: \(error)"
        }
        SentrySDK.addBreadcrumb(breadcrumb)

        if [.error, .warning, .fatal].contains(level) {
            let event = Event(level: level)
            
            let eventMessage = breadcrumb.message ?? message ?? function
            event.message = SentryMessage(formatted: eventMessage)
            
            SentrySDK.capture(event: event) { scope in
                if let error {
                    scope.setContext(value: ["error": "\(error)"], key: "Error")
                }
                
                scope.setContext(
                    value: [
                        "File": file.fileNameWithoutExtension,
                        "Line": "\(line)",
                        "Function": function
                    ],
                    key: "Source Code"
                )
                
                if let parameters {
                    scope.setContext(value: parameters, key: "Additional Details")
                }
                
                if let category {
                    scope.setTag(value: category, key: "Category")
                }
                
                scope.setTag(
                    value: SentrySDK.crashedLastRun ? "TRUE" : "FALSE",
                    key: "Crashed last run"
                )
            }
        }
        
        let label  = label(for: breadcrumb.level)
        let time = Date().timestamp
        let fileLine = "\(file.fileNameWithoutExtension):\(line)"
        let line = "[\(label)] [\(time)] [\(fileLine)] \(breadcrumb.message ?? "Message not available")"
        print(line)
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

private extension Date {
    static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()
    
    var timestamp: String {
        Date.formatter.string(from: self)
    }
}

private extension String {
    var fileNameWithoutExtension: String {
        URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }
}
