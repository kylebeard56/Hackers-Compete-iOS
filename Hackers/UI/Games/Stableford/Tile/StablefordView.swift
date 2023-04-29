//
//  StablefordView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct StablefordView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    var body: some View {
        FlippableCardView(front: { front }, back: { back })
    }
    
    private var front: some View {
        StablefordFrontView(viewModel: viewModel, hole: hole)
    }
    
    private var back: some View {
        StablefordBackView()
    }
}

struct StablefordView_Previews: PreviewProvider {
    static var previews: some View {
        StablefordView(viewModel: RoundViewModel(), hole: 1)
    }
}
