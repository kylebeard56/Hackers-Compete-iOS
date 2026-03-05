//
//  Navigator.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftUI

enum Destination: Equatable {
    case auth
    case minimumAppVersion
    case dashboard
    case lobby
    case liveRound
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
        }
    }
}
