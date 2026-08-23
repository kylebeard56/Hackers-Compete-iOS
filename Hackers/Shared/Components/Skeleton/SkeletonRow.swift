//
//  SkeletonRow.swift
//  Hackers
//
//  Created by Kyle Beard on 8/5/25.
//

import SkeletonUI
import SwiftUI

enum SkeletonDisplayType {
    
    case twoStaggeredRows, two
}

struct SkeletonRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    var theme: PaletteTheme = .primary
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    
    var body: some View {
        VStack(spacing: 8) {
            skeleton
                .frame(width: 200, height: 17)
                .alignLeading()
            
            skeleton
                .frame(width: 100, height: 13)
                .alignLeading()
        }
    }
    
    @ViewBuilder
    private var skeleton: some View {
        RoundedRectangle(cornerRadius: 4)
            .skeleton(
                with: true,
                animation: .linear(duration: 2),
                appearance: .solid(
                    color: palette.skeletonColor,
                    background: palette.skeletonBackground
                ),
                shape: .rounded(.radius(8)),
                lines: 1,
                scales: [1: 0.5, 2: 0.25]
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(0...5, id: \.self) { _ in
            SkeletonRow()
            Line()
        }

        Spacer()
    }
    .padding(16)
}
