//
//  InfoBanner.swift
//  Hackers
//
//  Created by Kyle Beard on 9/17/25.
//

import SwiftUI

struct InfoBanner: View {
    var icon: String = "f0eb"
    var text: String = ""
    var foregroundColor: Color = .systemBlack
    var backgroundColor: Color = .hackersGray6
    var onTap: Callback?
    
    var body: some View {
        HStack(spacing: 10) {
            Icon(name: icon, size: 15, weight: .regular)
                .foregroundStyle(foregroundColor)

            Text(LocalizedStringKey(text))
                .foregroundColor(foregroundColor)
                .fontStyle(.poppins, size: 13, weight: .medium)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(12)
        .onTapGesture {
            Haptics.fire(.light)
            onTap?()
        }
    }
}

#Preview {
    InfoBanner(text: "This is an info banner")
}
