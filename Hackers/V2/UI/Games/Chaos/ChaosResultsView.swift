//
//  ChaosResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct ChaosResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    var body: some View {
        SideGameResultsView(
            session: session,
            winnerLabel: "",
            content: { EmptyView() }
        )
    }
}
