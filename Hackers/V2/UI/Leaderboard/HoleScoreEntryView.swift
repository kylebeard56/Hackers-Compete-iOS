//
//  HoleScoreEntryView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/17/24.
//

import SwiftUI

struct HoleScoreEntryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    HoleScoreEntryView()
}
