//
//  ChipButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

struct ChipButton: View {
    var text: String
    var foregroundColor: Color = Color.systemBlack
    var backgroundColor: Color = Color.systemGray6
    
    var body: some View {
        Text(text)
            .font(.dmSans(size: 15, weight: .medium))
            .foregroundColor(foregroundColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

struct ChipButton_Previews: PreviewProvider {
    static var previews: some View {
        ChipButton(text: "")
    }
}
