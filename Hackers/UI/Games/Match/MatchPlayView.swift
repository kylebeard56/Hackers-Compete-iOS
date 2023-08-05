//
//  MatchPlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/1/23.
//

import SwiftUI

struct MatchPlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var skins: Bool = false
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct MatchPlayView_Previews: PreviewProvider {
    static var previews: some View {
        MatchPlayView(viewModel: HoleViewModel(), hole: 1)
            .environmentObject(RoundSession())
    }
}
