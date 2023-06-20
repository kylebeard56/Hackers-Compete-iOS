//
//  InfoBanner.swift
//  Hackers
//
//  Created by Kyle Beard on 6/20/23.
//

import SwiftUI

struct InfoBanner: View {
    var icon: String = "f0eb"
    var text: String = ""
    var foregroundColor: Color = .systemBlack
    var backgroundColor: Color = .systemGray6
    var onTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 10) {
            AwesomeImage(rawIcon: icon.unicode, style: .regular, size: 15, color: foregroundColor)
            Text(text)
                .foregroundColor(foregroundColor)
                .font(.dmSans(size: 13, weight: .medium))
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(12)
        .onTapGesture {
            if let a = onTap { a() }
        }
    }
}

struct InfoBanner_Previews: PreviewProvider {
    static var previews: some View {
        InfoBanner()
    }
}
