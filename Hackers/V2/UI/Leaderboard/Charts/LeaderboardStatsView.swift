//
//  LeaderboardStatsView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/24.
//

import SwiftUI

struct LeaderboardStatsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    
    var body: some View {
        VStack(spacing: 20) {
            header
            
            LeaderboardLineChart()
                .alignTop()
        }
        .padding(20)
    }
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()

            Text("Stats & trends")
                .font(.dmSans, size: 20, weight: .bold)
                .foregroundColor(Color.systemBlack)
        }
    }
}

#Preview {
    LeaderboardStatsView()
}
