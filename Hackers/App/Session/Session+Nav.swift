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
    func routeTo(_ destination: Destination, prequeue: [Destination] = []) {
        addBreadcrumb(.info, .routing, "route to \(destination)")
        UIApplication.shared.endEditing()
        
        for p in prequeue {
            path.append(p)
        }
        
        if destination == .auth {
            path.removeLast(path.count)
        } else {
            path.append(destination)
        }
    }
}
