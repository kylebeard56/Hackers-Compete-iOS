//
//  FinishRoundPlayerRow.swift
//  Hackers
//
//  Created by Kyle Beard on 8/27/23.
//

import SwiftUI

// TODO: Leaderboard tiles with trophy icon for 1st and expandable scorecard scroller
struct FinishRoundPlayerRow: View {
    @Environment(\.colorScheme) var colorScheme
    var player: Player
    var teamStyle: Bool = false
    
    var body: some View {
        Group {
            if teamStyle {
                teamContent
            } else {
                playerContent
            }
        }
    }
    
    private var playerContent: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
            .cornerRadius(12)
    }
    
    private var teamContent: some View {
        content
            .background(Color.systemCard)
            .cornerRadius(12)
    }
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 20) {
            HStack {
                // Place w/ trophy or wreath T-1st or 1st etc
                Spacer(minLength: 0)
                // name
                // score gross/net
            }
            // Hole ->
            // Gross
            // Strokes given
            // Net
        }
    }
}

struct FinishRoundPlayerRow_Previews: PreviewProvider {
    static var previews: some View {
        FinishRoundPlayerRow(player: kPlayerKyle)
    }
}
