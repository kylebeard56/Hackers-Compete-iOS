//
//  Alerts.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import SwiftUI

// MARK: - Alertable

protocol Alertable {}

struct AlertData: Identifiable {
    var id = UUID()
    var alert: HackersAlert
    var onTap: OnSelection
}

extension Alertable {
    func present(alert: HackersAlert, onTap: OnSelection = nil) {
        DispatchQueue.main.async {
            HackersNotification.presentAlert.send(with: AlertData(alert: alert, onTap: onTap))
        }
    }
}

extension View {
    func present(alert: HackersAlert, onTap: OnSelection = nil) {
        HackersNotification.presentAlert.send(with: AlertData(alert: alert, onTap: onTap))
    }
}

// MARK: - Alerts


enum HackersAlert: String, Error {
    /// Extensive list of all native Alerts presets.
    case generic = "Generic"
    
    /// Testing & Previews
    case previewTest = "Normal Test"
    case previewTestDestructive = "Destructive Test"
}

extension HackersAlert {
    /// Header of the alert (in bold)
    var title: String {
        switch self {
        case .generic:
            return "Fore!"
        default:
            return self.rawValue
        }
    }

    /// Body of the alert (can be multiple lines)
    var message: String? {
        // swiftlint:disable line_length
        switch self {
            // TODO: Add feedback button to generics
        case .generic: return "We apologize, but something went wrong. Please try again. If the issue persists, please report and let us know."
        case .previewTest, .previewTestDestructive:
            return "This is an alert that is to be shown only as a preview test and therefore the current words you are reading are not only pointless, but have also wasted your time."
        }
        // swiftlint:enable line_length
    }

    /// Set whether the alert will be a singular or dual action button.
    var isMultiButton: Bool {
        switch self {
        case .generic:                                  return true
        case .previewTest, .previewTestDestructive:     return true
        default:                                        return false
        }
    }

    /// Main action button text (i.e. Submit, Delete, Add, Accept, Continue, etc..)
    var primaryText: String? {
        switch self {
        case .generic:                  return "Report"
        case .previewTest:              return "Continue"
        case .previewTestDestructive:   return "Delete"
        default:                        return nil
        }
    }

    /// Closing action button text (i.e. OK, Cancel, Close, etc...)
    var dismissText: String {
        switch self {
        case .generic:                                  return "Close"
        case .previewTest, .previewTestDestructive:     return "Cancel"
        default:                                        return "OK"
        }
    }

    /// Display red text for primary button
    var isDestructive: Bool {
        switch self {
        case .generic:                  return true
        case .previewTestDestructive:   return true
        default:                        return false
        }
    }
}
