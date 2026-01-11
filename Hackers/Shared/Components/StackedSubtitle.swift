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
    var tint: Color? = nil
    var subTint: Color? = nil
    var size: CGFloat = 17
    var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value.uppercased())
                .fontStyle(.poppins, size: size, weight: .semibold)
                .foregroundStyle(tint ?? palette.foregroundColor)
            
            Text(label.uppercased())
                .fontStyle(.poppins, size: 14, weight: .regular)
                .foregroundStyle(subTint ?? Color.neutral)
        }
    }
}
