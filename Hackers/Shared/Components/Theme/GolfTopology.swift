//
//  GolfTopology.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

struct GolfTopology: View {
    var theme: GolfTheme = .green
    var body: some View {
        Image(theme.image)
            .interpolation(.high)
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
    }
}
