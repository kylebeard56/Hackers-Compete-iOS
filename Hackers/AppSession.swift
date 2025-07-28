//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

@MainActor
final class AppSession: ObservableObject, Sendable, Loggable {
    @Published var path = NavigationPath()
    @Published var isInitializing = true
    
    @Published var currentTermsVersion = ""
    @Published var currentPolicyVersion = ""
    
    @Published var isRouting = false
    @Published var isSigningApple = false
    @Published var isSigningGoogle = false
    @Published var isAcceptingTerms = false
    @Published var isSavingProfile = false
    
    init() {
        print("init AppSession")
        Task {
            await self.routeApp()
        }
    }
    
    deinit { print("deinit AppSession") }
    
    func initialize() async {
        addBreadcrumb(#function)
        
        self.isInitializing = true
        defer { self.isInitializing = false }
        
        /// 1. Ensure app version is sufficient
        await FirebaseService.shared.observeMinimumAppVersion()
        
        /// 2. Check if current user exists
        guard let u = AuthService.shared.getCurrentUser() else {
            routeTo(.auth)
            return
        }
    }
    
    func routeApp() async {
        addBreadcrumb(#function)
        
        self.isRouting = true
        defer { self.isRouting = false }
        
        /// 1. Ensure app version is sufficient
        await FirebaseService.shared.observeMinimumAppVersion()
        
        /// 2. Check if current user exists
        guard let u = AuthService.shared.getCurrentUser() else {
            routeTo(.auth)
            return
        }
        
        /// 3. Get the latest user record.
        do {
            let user = try await FirebaseService.shared.getUserByEmail(u.email ?? "").get()
            await AppData.shared.setUser(user)
            printPretty(user)
        } catch let error {
            addBreadcrumb(.error, .auth, "User not fetched during load", error)
            // TODO: Retry logic and then logout and back-route to auth
        }
        
        /// 4. Check if user's profile has latest required accepted terms yet
        do {
            self.currentTermsVersion = try await FirebaseService.shared.fetchLatestTermsVersion()
            self.currentPolicyVersion = try await FirebaseService.shared.fetchLatestPolicyVersion()
        } catch let error {
            addBreadcrumb(.error, .auth, "Latest legal document version(s) not found", error)
            // TODO: Retry?
        }
        
        return
    }
    
    func reset() {
        addBreadcrumb(#function)
        path.removeLast(path.count)
        Task { await AppData.shared.clearUser() }
        routeTo(.auth)
    }
}

// MARK: - Authentication

extension AppSession {
    func signInWithApple() async {
        addBreadcrumb(#function)
        
        isSigningApple = true
        defer { isSigningApple = false }
        
        do {
            let user = try await AuthService.shared.signInWithApple()
            await AppData.shared.setUser(user)
            await routeApp()
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
            await routeApp()
        } catch let error {
            addBreadcrumb(.error, .auth, "Sign in with Google failed", error)
            // TODO: Toast
        }
    }
}

extension AppSession {
    
    // MARK: - Navigation
    
    /// Route to a destination and optional pre-qeueue a list of views prior.
    /// Ex: If routing to .birthday for onboarding, you may want to add the prior onboarding steps for clean navigation.
    func routeTo(_ destination: Destination, prequeue: [Destination] = []) {
        addBreadcrumb(.info, .routing, "route to \(destination)")
        
        // TODO: Add ability to signify the view is a "major" "where you can dismiss routing back last major spot.
        
        if isInitializing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isInitializing = false
                }
            })
        }
        
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
