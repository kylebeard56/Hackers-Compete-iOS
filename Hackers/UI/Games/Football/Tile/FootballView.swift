//
//  FootballView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct FootballView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    var body: some View {
        FlippableCardView(front: { front }, back: { back })
    }
    
    private var front: some View {
        FootballFrontView(viewModel: viewModel, hole: hole)
    }
    
    private var back: some View {
        FootballBackView()
    }
}

struct FootballView_Previews: PreviewProvider {
    static var previews: some View {
        FootballView(viewModel: RoundViewModel(), hole: 1)
    }
}
