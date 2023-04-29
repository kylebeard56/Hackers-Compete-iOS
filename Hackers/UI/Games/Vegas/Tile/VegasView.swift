//
//  VegasView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct VegasView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    var body: some View {
        FlippableCardView(front: { front }, back: { back })
    }
    
    private var front: some View {
        VegasFrontView(viewModel: viewModel, hole: hole)
    }
    
    private var back: some View {
        VegasBackView()
    }
}

struct VegasView_Previews: PreviewProvider {
    static var previews: some View {
        VegasView(viewModel: RoundViewModel(), hole: 1)
    }
}
