//
//  Navigator.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftUI

enum Destination {
    case auth
    case minimumAppVersion
    case joinWithCode
    case dashboard
    //case createProfile(_ step: OnboardingStep)
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
        default:                    EmptyView()
        //case .onboarding(let step): Navigator.onboardingView(for: step)
        }
    }
}
