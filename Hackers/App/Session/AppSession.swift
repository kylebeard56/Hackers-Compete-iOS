//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

enum PendingJoinLink: Equatable {
    /// Deep link or lookup scoped to a round (`round_id` or legacy `code` treated as round-only in resolver).
    case round(token: String)
    case series(token: String)
    /// Manual entry or QR without query keys — may resolve to round, series, or both.
    case freeform(token: String)
}

@MainActor
final class AppSession: ObservableObject, Sendable, Loggable {
    @Published var path = NavigationPath()
    @Published var isLoading = true
    
    @Published var shareCode: String?
    @Published var pendingJoinLink: PendingJoinLink?
    @Published var ephemeralParticipantID: String?
    @Published var isSpectating: Bool = false
    
    @Published var activeRoundID: String?
    /// When navigating to round outcome, callers set whether the user may edit the round (lobby) and scores (full scorecard). Default true for standalone rounds.
    @Published var roundOutcomeAllowsEditing: Bool = true
    @Published var rounds: Set<Round> = .init()
    @Published var isLoadingRounds = false
    @Published var preQueuedPlayerIDs: [String]? = nil
    
    @Published var activeSeriesID: String?
    @Published var seriesList: [Series] = []
    /// Prefetched `SeriesRound` documents keyed by series ID (dashboard home chips).
    @Published var seriesRoundsBySeriesID: [String: [SeriesRound]] = [:]
    @Published var isLoadingSeries = false
    
    @Published var isUserAuthenticated = false
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
    
    /// Use for SwiftUI previews with mock data. Caller should set rounds before presenting DashboardView.
    static func forPreview(mockRounds: Set<Round> = MockDashboardData.rounds) -> AppSession {
        let session = AppSession()
        session.rounds = mockRounds
        session.seriesList = MockDashboardData.previewSeriesList
        session.seriesRoundsBySeriesID = MockDashboardData.previewSeriesRoundsByID
        return session
    }
}

extension AppSession {
    func syncUserState() async {
        isUserAuthenticated = await AppData.shared.user.exists
    }
    
    func reset(routeToAuth: Bool = true) {
        addBreadcrumb()
        TelemetryService.shared.resetUser()

        activeRoundID = nil
        activeSeriesID = nil
        rounds = []
        seriesList = []
        seriesRoundsBySeriesID = [:]
        preQueuedPlayerIDs = nil
        ephemeralParticipantID = nil
        isSpectating = false
        
        // 1. Clear user and sync state to session
        Task {
            await AppData.shared.clearUser()
            await syncUserState()
        }
        
        // 2. Route to auth, if requested
        if routeToAuth {
            path.removeLast(path.count)
            routeTo(.auth)
        }
        
    }
}
