//
//  BingoResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

struct BingoResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct BingoResultsView_Previews: PreviewProvider {
    static var previews: some View {
        BingoResultsView(session: SideGameSession())
    }
}
