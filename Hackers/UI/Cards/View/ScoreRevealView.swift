//
//  ScoreRevealView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/17/23.
//

import SwiftUI

struct ScoreRevealView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: RoundViewModel
    
    var body: some View {
        ZStack {
            Blur(style: .dark).onTapGesture(perform: close)
            CardScoringView(viewModel: viewModel, onNextHole: nextHole, onClose: close)
        }
        .edgesIgnoringSafeArea(.vertical)
        .environmentObject(appSession)
    }
    
    private func nextHole() {
        if viewModel.currentHole == 18 {
            appSession.endSession()
            close()
        } else {
            viewModel.currentHole += 1
            close()
        }
    }
    
    private func close() {
        appSession.revealScore = false
    }
}

struct ScoreRevealView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreRevealView(viewModel: RoundViewModel())
    }
}
