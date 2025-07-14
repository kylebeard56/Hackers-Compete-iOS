//
//  Application.swift
//  Hackers
//
//  Created by Kyle Beard on 7/14/25.
//

import Foundation
import UIKit

extension UIApplication {
    // Force resign the active first responder in key window.
    func endEditing() {
        currentKeyWindow?.endEditing(true)
    }
    
    var currentWindowScene: UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 }).first
    }
    
    var currentKeyWindow: UIWindow? {
        // Get connected scenes
        return UIApplication.shared.connectedScenes
            // Keep only active scenes, onscreen and visible to the user
            .filter { $0.activationState == .foregroundActive }
            // Keep only the first `UIWindowScene`
            .first(where: { $0 is UIWindowScene })
            // Get its associated windows
            .flatMap({ $0 as? UIWindowScene })?.windows
            // Finally, keep only the key window
            .first(where: \.isKeyWindow)
    }

    /// Fetch the root view controller for the application
    var rootViewController: UIViewController? {
        return currentKeyWindow?.rootViewController
    }
}
