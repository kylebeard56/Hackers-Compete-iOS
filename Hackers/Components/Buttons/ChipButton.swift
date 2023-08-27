//
//  ChipButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

struct ChipButton: View {
    var style: HackersButtonStyle = .solid
    var text: String
    var foregroundColor: Color = Color.systemBlack
    var backgroundColor: Color = Color.systemGray6
    
    var body: some View {
        button
    }
    
    @ViewBuilder private var button: some View {
        if style == .outline {
            Text(text)
                .font(.dmSans(size: 15, weight: .medium))
                .foregroundColor(foregroundColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .border(backgroundColor, width: 2, cornerRadius: 4)
                .cornerRadius(4)
        } else {
            Text(text)
                .font(.dmSans(size: 15, weight: .medium))
                .foregroundColor(foregroundColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(backgroundColor)
                .cornerRadius(4)
        }
    }
}

struct ChipButton_Previews: PreviewProvider {
    static var previews: some View {
        ChipButton(text: "Which player")
    }
}
