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
    case roundSetup
    case players
    case format
    case sideGames
    case partyCode
    case roundPlay
}

class ViewFactory {
    @ViewBuilder static func viewForDestination(_ destination: Destination) -> some View {
        switch destination {
        case .landing:          LandingView()
        case .roundSetup:       RoundSetupView()
        case .players:          PlayerEntryView()
        case .format:           RoundFormatView()
        case .sideGames:        SideGameSelectionView()
        case .partyCode:        PartyCodeSetupView()
        case .roundPlay:        RoundView()
        }
    }
}
