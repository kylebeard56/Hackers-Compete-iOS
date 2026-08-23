//
//  LiveRound+Chat.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

// MARK: - Chat Content

extension LiveRound {
    var chatContent: some View {
        // Place for players to chat, share pics, post announcements.
        VStack {
            Text("In-round chat coming soon")
                .fontStyle(kFontName, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
}
