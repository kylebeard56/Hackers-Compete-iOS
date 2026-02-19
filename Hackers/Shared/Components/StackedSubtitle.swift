//
//  StackedSubtitle.swift
//  Hackers
//
//  Created by Kyle Beard on 1/9/26.
//

import SwiftUI

struct StackedSubtitle: View {
    @Environment(\.colorScheme) var colorScheme
    
    var value: String
    var label: String
    var icon: String?
    var tint: Color? = nil
    var subTint: Color? = nil
    var iconTint: Color? = nil
    var size: CGFloat = 17
    var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value.uppercased())
                .fontStyle(kFontName, size: size, weight: .semibold)
                .foregroundStyle(tint ?? palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 4) {
                Text(label.uppercased())
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(subTint ?? Color.neutral)
                if let icon {
                    Icon(name: icon, size: 10, weight: .semibold)
                        .foregroundStyle(iconTint ?? Color.neutral3)
                }
            }
        }
    }
}
