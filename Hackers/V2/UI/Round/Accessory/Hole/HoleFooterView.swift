//
//  HoleFooterView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct HoleFooterView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var roundSession: RoundSession
    
    var body: some View {
        VStack(spacing: 20) {
            Divider()
            
            CurrentHoleButton()
                .padding(.horizontal, 20)
        }
        .environmentObject(roundSession)
        .padding(.bottom, 10)
    }
}

struct HoleFooterView_Previews: PreviewProvider {
    static var previews: some View {
        HoleFooterView()
            .environmentObject(AppSessionV2())
            .environmentObject(RoundSession())
            .holisticPreview()
    }
}
