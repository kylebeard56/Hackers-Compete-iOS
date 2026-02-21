//
//  GolfTopology.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

enum GolfTopologyTheme: String {
    case green = "TopologyGreen"
    case purple = "TopologyPurple"
    case yellow = "TopologyYellow"
}

struct GolfTopology: View {
    var theme: GolfTopologyTheme = .green
    var body: some View {
        Image(theme.rawValue)
            .interpolation(.high)
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
    }
}
