//
//  Navigator.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftUI

enum Destination: Hashable {
    case auth
    case minimumAppVersion
    case dashboard
    case lobby
    case liveRound
    case roundOutcome
    case series(id: String)
    #if SANDBOX
    case designStudio
    #endif
}

enum OnboardingStep: Hashable {
    case name, phone, gender, birthday, username
}

class Navigator {
    @MainActor @ViewBuilder
    static func viewFor(destination: Destination) -> some View {
        switch destination {
        case .auth:                 AuthView()
        case .minimumAppVersion:    AppVersionView()
        case .dashboard:            DashboardView()
        case .lobby:                GameLobby()
        case .liveRound:            LiveRound()
        case .roundOutcome:         RoundOutcomeView()
        case .series(let id):       SeriesRouterView(seriesID: id)
        #if SANDBOX
        case .designStudio:         DesignStudioRootView()
        #endif
        }
    }
}
