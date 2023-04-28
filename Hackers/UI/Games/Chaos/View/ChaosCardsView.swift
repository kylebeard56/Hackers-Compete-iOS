//
//  ChaosCard.swift
//  Hackers
//
//  Created by Kyle Beard on 4/27/23.
//

import SwiftUI

struct ChaosCardsView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    var body: some View {
        FlippableCardView(isFlipped: $viewModel.chaosFlipped, front: { front }, back: { back })
    }
    
    private var front: some View {
        ChaosCardsFrontView(viewModel: viewModel, hole: hole)
    }
    
    private var back: some View {
        ChaosCardsBackView()
    }
}

struct ChaosCardsView_Previews: PreviewProvider {
    static var view: some View {
        ChaosCardsView(viewModel: RoundViewModel(), hole: 1)
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
