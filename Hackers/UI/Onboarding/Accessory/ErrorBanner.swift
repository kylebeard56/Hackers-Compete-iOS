//
//  ErrorBanner.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import SwiftUI

struct ErrorBanner: View {
    var title: String = ""
    var subtitle: String = ""
    
    var onTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .foregroundColor(Color.systemError)
                    .font(.dmSans(size: 17, weight: .bold))
                    .alignLeading()
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundColor(Color.systemError)
                    .font(.dmSans(size: 13, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemError.opacity(0.125))
        .cornerRadius(12)
        .onTapGesture {
            if let a = onTap { a() }
        }
    }
}
