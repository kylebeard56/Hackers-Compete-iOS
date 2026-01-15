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
    @Published var isLoading = true
    
    @Published var shareCode: String?
    @Published var ephemeralParticipantID: String?
    
    @Published var activeRoundID: String?
    @Published var rounds: Set<Round> = .init()
    @Published var roundService: RoundService?
    
    @Published var currentTermsVersion = ""
    @Published var currentPolicyVersion = ""
    @Published var promptForLegalAcceptance = false
    
    @Published var isRouting = false
    @Published var isSigningApple = false
    @Published var isSigningGoogle = false
    @Published var isSigningAnonymous = false
    @Published var isAcceptingTerms = false
    @Published var isSavingProfile = false
    
    init() {
        print("init AppSession")
        Task {
            if let fullyAuthenticated = try? await self.load(), fullyAuthenticated {
                /// Route to wherever we want the user to go after auth, which in this instance is the home dashboard.
                routeTo(.dashboard)
            }
        }
    }
    
    deinit { print("deinit AppSession") }
}

extension AppSession {
    func reset() {
        addBreadcrumb()
        path.removeLast(path.count)
        Task { await AppData.shared.clearUser() }
        routeTo(.auth)
    }
}
