//
//  WolfHammerView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct WolfHammerView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    var body: some View {
        FlippableCardView(front: { front }, back: { back })
    }
    
    private var front: some View {
        WolfFrontView(viewModel: viewModel, hole: hole)
    }
    
    private var back: some View {
        WolfBackView()
    }
}

struct WolfHammerView_Previews: PreviewProvider {
    static var view: some View {
        WolfHammerView(viewModel: RoundViewModel(), hole: 1)
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
