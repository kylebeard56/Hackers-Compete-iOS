//
//  ScoringView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/17/23.
//

import SwiftUI

struct ScoringView: View {
    
    @StateObject var viewModel: RoundViewModel
    
    var body: some View {
        Text("Scoring")
    }
}

struct ScoringView_Previews: PreviewProvider {
    static var previews: some View {
        ScoringView(viewModel: RoundViewModel())
    }
}
