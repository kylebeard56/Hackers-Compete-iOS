//
//  ViewFactoryV2.swift
//  Hackers
//
//  Created by Kyle Beard on 2/18/23.
//

import Foundation
import SwiftUI

enum DestinationV2 {
    case landing
    case roundSetup
    case players
    case sideGames
    case partyCode
    case roundPlay
}

class ViewFactoryV2 {
    @ViewBuilder static func viewForDestinationV2(_ destinationV2: DestinationV2) -> some View {
        switch destinationV2 {
        case .landing:          LandingView()
        case .roundSetup:       RoundSetupView()
        case .players:          PickPlayersView()
        case .sideGames:        PickSideGameView()
        case .partyCode:        PartyCodeSetupView()
        case .roundPlay:        RoundView()
        }
    }
}
