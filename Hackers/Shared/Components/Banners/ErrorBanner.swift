//
//  ErrorBanner.swift
//  Hackers
//
//  Created by Kyle Beard on 9/17/25.
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
                    .fontStyle(.poppins, size: 17, weight: .bold)
                    .alignLeading()
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundColor(Color.systemError)
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.systemError.opacity(0.125))
        .cornerRadius(12)
        .onTapGesture {
            Haptics.fire(.light)
            onTap?()
        }
    }
}

#Preview {
    ErrorBanner(title: "Error", subtitle: "Something went wrong. Please try again.")
}
