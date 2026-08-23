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
        addEvent("auth.sign_in_started", eventProps: ["provider": social.rawValue])
        
        do {
            switch social {
            case .anonymous:
                isSigningAnonymous = true
                defer { isSigningAnonymous = false }
                try await FirebaseService.shared.loginAnonymously()
                addEvent("auth.sign_in_succeeded", eventProps: ["provider": social.rawValue, "is_new_account": false])
                await onSuccess?(false)
            case .apple:
                let response = try await self.signInWithApple()
                addEvent(
                    "auth.sign_in_succeeded",
                    eventProps: [
                        "provider": social.rawValue,
                        "is_new_account": response.newlyCreated
                    ]
                )
                await onSuccess?(response.newlyCreated)
            case .google:
                let response = try await self.signInWithGoogle()
                addEvent(
                    "auth.sign_in_succeeded",
                    eventProps: [
                        "provider": social.rawValue,
                        "is_new_account": response.newlyCreated
                    ]
                )
                await onSuccess?(response.newlyCreated)
            }
        } catch let error {
            if let e = error as? AuthError, e == .userCancelledFlow {
                addBreadcrumb(message: "User cancelled auth flow for \(social.rawValue)")
                addEvent("auth.sign_in_cancelled", eventProps: ["provider": social.rawValue])
                return
            }
            addEvent(
                "auth.sign_in_failed",
                eventProps: [
                    "provider": social.rawValue,
                    "error": "\(error)"
                ]
            )
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
            TelemetryService.shared.identify(
                user: response.user,
                authUserID: AuthService.shared.getCurrentUser()?.uid
            )
            await syncUserState()
            try await load()
            return response
        } catch let error {
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
            TelemetryService.shared.identify(
                user: response.user,
                authUserID: AuthService.shared.getCurrentUser()?.uid
            )
            await syncUserState()
            return response
        } catch let error {
            throw error
        }
    }
}
