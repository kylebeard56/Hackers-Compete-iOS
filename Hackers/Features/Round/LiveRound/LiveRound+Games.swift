//
//  LiveRound+Games.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

// MARK: - Game Content

extension LiveRound {
    var gameContent: some View {
        // Alternative side games, or bets.
        VStack {
            Text("Side game content coming soon")
                .fontStyle(kFontName, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
}
