//
//  HoleFooterView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct HoleFooterView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Divider()
            
            CurrentHoleButton(viewModel: viewModel)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
    }
}

struct HoleFooterView_Previews: PreviewProvider {
    static var previews: some View {
        HoleFooterView(viewModel: RoundViewModel())
            .environmentObject(AppSession())
            .holisticPreview()
    }
}
