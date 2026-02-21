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
    var lineLimit: Int = 1
    var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value.uppercased())
                .fontStyle(kFontName, size: size, weight: .semibold)
                .foregroundStyle(tint ?? palette.foregroundColor)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.5)

            HStack(spacing: 4) {
                Text(label.uppercased())
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(subTint ?? Color.neutral)
                if let icon {
                    Icon(name: icon, size: 10, weight: .semibold)
                        .foregroundStyle(iconTint ?? Color.neutral3)
                }
            }
        }
    }
}
