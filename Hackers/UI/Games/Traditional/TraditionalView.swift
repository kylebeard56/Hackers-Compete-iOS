//
//  TraditionalView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/30/23.
//

import SwiftUI

struct TraditionalView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    var body: some View {
        FlippableCardView(front: { front }, back: { back })
    }
    
    private var front: some View {
        TraditionalFrontView(viewModel: viewModel, hole: hole)
    }
    
    private var back: some View {
        TraditionalBackView()
    }
}

struct TraditionalView_Previews: PreviewProvider {
    static var previews: some View {
        TraditionalView(viewModel: RoundViewModel(), hole: 1)
    }
}
