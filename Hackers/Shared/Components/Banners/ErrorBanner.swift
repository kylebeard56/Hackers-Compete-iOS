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
    var color: Color = .systemError
    var background: Color = .systemError.opacity(0.2)
    var material: Material? = nil
    var onTap: Callback?
    
    var body: some View {
        VStack(spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .foregroundColor(color)
                    .fontStyle(kFontName, size: 17, weight: .bold)
                    .alignLeading()
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundColor(color)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .fixedSize(horizontal: false, vertical: true)
        .applyBackground(color: background, material: material)
        .cornerRadius(12)
        .onTapGesture {
            Haptics.fire(.light)
            onTap?()
        }
    }
}
private extension View {
    @ViewBuilder
    func applyBackground(
        color: Color,
        material: Material?
    ) -> some View {
        if let material {
            self.background(material)
        } else {
            self.background(color)
        }
    }
}

#Preview {
    ErrorBanner(title: "Error", subtitle: "Something went wrong. Please try again.")
}
