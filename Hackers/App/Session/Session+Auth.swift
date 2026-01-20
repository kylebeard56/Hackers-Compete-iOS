//
//  Session+Auth.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {
    // Return onSuccess bool for whether this is a newly created or existing account
    func attemptLogin(
        for social: AuthType,
        onSuccess: AsyncCallbackValue<Bool>? = nil,
        onError: Callback? = nil
    ) async {
        addBreadcrumb(message: "\(#function) for type: \(social.rawValue)")
        
        do {
            switch social {
            case .anonymous:
                isSigningAnonymous = true
                defer { isSigningAnonymous = false }
                try await FirebaseService.shared.loginAnonymously()
                await onSuccess?(false)
            case .apple:
                let response = try await self.signInWithApple()
                await onSuccess?(response.newlyCreated)
            case .google:
                let response = try await self.signInWithGoogle()
                await onSuccess?(response.newlyCreated)
            }
        } catch {
            onError?()
        }
    }
    
    private func signInWithApple() async throws -> HackersUserCreation {
        addBreadcrumb()
        
        isSigningApple = true
        defer { isSigningApple = false }
        
        do {
            let response = try await AuthService.shared.signInWithApple()
            await AppData.shared.setUser(response.user)
            try await load()
            return response
        } catch let error {
            addBreadcrumb(level: .error, message: "Sign in with Apple failed", error: error)
            throw error
        }
    }
    
    private func signInWithGoogle() async throws -> HackersUserCreation {
        addBreadcrumb()
        
        isSigningGoogle = true
        defer { isSigningGoogle = false }
        
        do {
            let response = try await AuthService.shared.signInWithGoogle()
            await AppData.shared.setUser(response.user)
            try await load()
            return response
        } catch let error {
            addBreadcrumb(level: .error, message: "Sign in with Google failed", error: error)
            throw error
        }
    }
}
