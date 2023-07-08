//
//  StrokePlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

struct StrokePlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    @StateObject var vm = StrokePlayViewModel()
    
    var format: StrokeScoringFormat
    
    var body: some View {
        Text("Stroke play view coming soon")
        /// If players, setup "This hole" and "Total" tiles side-by-side
        /// If teams, setup "Team one" and "Team two" tiles side-by-side
        /// Add two best ball toggle tile
    }
}

struct StrokePlayView_Previews: PreviewProvider {
    static var previews: some View {
        StrokePlayView(viewModel: RoundViewModel(), format: .medal)
    }
}
