//
//  Session+Auth.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {
    func attemptLogin(
        for social: AuthType,
        onSuccess: AsyncCallback? = nil,
        onError: Callback? = nil
    ) async {
        addBreadcrumb(message: "\(#function) for type: \(social.rawValue)")
        
        do {
            switch social {
            case .anonymous:
                isSigningAnonymous = true
                defer { isSigningAnonymous = false }
                try await FirebaseService.shared.loginAnonymously()
                await onSuccess?()
            case .apple:
                try await self.signInWithApple()
                await onSuccess?()
            case .google:
                try await self.signInWithGoogle()
                await onSuccess?()
            }
        } catch {
            onError?()
        }
    }
    
    private func signInWithApple() async throws {
        addBreadcrumb()
        
        isSigningApple = true
        defer { isSigningApple = false }
        
        do {
            let user = try await AuthService.shared.signInWithApple()
            await AppData.shared.setUser(user)
            try await load()
        } catch let error {
            addBreadcrumb(level: .error, message: "Sign in with Apple failed", error: error)
            throw error
        }
    }
    
    private func signInWithGoogle(routeOnSuccess: Destination = .dashboard) async throws {
        addBreadcrumb()
        
        isSigningGoogle = true
        defer { isSigningGoogle = false }
        
        do {
            let user = try await AuthService.shared.signInWithGoogle()
            await AppData.shared.setUser(user)
            try await load()
        } catch let error {
            addBreadcrumb(level: .error, message: "Sign in with Google failed", error: error)
            throw error
        }
    }
}
