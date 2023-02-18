//
//  ViewFactory.swift
//  Hackers
//
//  Created by Kyle Beard on 2/18/23.
//

import Foundation
import SwiftUI

enum Destination {
    case landing
    case players
    case roundPlay
    case roundSummary
}

class ViewFactory {
    @ViewBuilder static func viewForDestination(_ destination: Destination) -> some View {
        switch destination {
        case .landing:          LandingView()
        case .players:          PlayerEntry()
        case .roundPlay:        RoundView()
        case .roundSummary:     RoundSummaryView()
        }
    }
}
