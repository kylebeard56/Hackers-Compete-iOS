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
    @Published var joinRoundID: String?
    
    @Published var activeRoundID: String?
    @Published var rounds: [Round] = []
    
    @Published var currentTermsVersion = ""
    @Published var currentPolicyVersion = ""
    @Published var promptForLegalAcceptance = false
    
    @Published var isRouting = false
    @Published var isSigningApple = false
    @Published var isSigningGoogle = false
    @Published var isAcceptingTerms = false
    @Published var isSavingProfile = false
    
    init() {
        print("init AppSession")
        Task {
            await self.load()
        }
    }
    
    deinit { print("deinit AppSession") }
}

extension AppSession {
    func reset() {
        addBreadcrumb(#function)
        path.removeLast(path.count)
        Task { await AppData.shared.clearUser() }
        routeTo(.auth)
    }
}
