//
//  Session+Auth.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {
    func signInWithApple() async {
        addBreadcrumb(#function)
        
        isSigningApple = true
        defer { isSigningApple = false }
        
        do {
            let user = try await AuthService.shared.signInWithApple()
            await AppData.shared.setUser(user)
            await load()
        } catch let error {
            addBreadcrumb(.error, .auth, "Sign in with Apple failed", error)
            // TODO: Toast
        }
    }
    
    func signInWithGoogle() async {
        addBreadcrumb(#function)
        
        isSigningGoogle = true
        defer { isSigningGoogle = false }
        
        do {
            let user = try await AuthService.shared.signInWithGoogle()
            await AppData.shared.setUser(user)
            await load()
        } catch let error {
            addBreadcrumb(.error, .auth, "Sign in with Google failed", error)
            // TODO: Toast
        }
    }
}
