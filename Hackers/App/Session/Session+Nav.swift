//
//  Session+Nav.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {

    /// Route to a destination and optional pre-qeueue a list of views prior.
    /// Ex: If routing to .birthday for onboarding, you may want to add the prior onboarding steps for clean navigation.
    /// - Parameter replacingCurrent: When true, pops the current top of the stack before pushing. Use when transitioning lobby→live so exit returns to dashboard.
    func routeTo(_ destination: Destination, prequeue: [Destination] = [], replacingCurrent: Bool = false) {
        addBreadcrumb(message: "route to \(destination)")
        UIApplication.shared.endEditing()
        
        for p in prequeue {
            path.append(p)
        }
        
        if destination == .auth {
            path.removeLast(path.count)
        } else {
            if replacingCurrent, path.count > 0 {
                path.removeLast()
            }
            path.append(destination)
        }
    }
}
