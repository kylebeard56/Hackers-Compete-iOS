//
//  Styling.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.systemGray6 : Color.systemWhite.opacity(0.001))
            .cornerRadius(8)
    }
}

