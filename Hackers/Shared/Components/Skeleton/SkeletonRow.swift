//
//  SkeletonRow.swift
//  Hackers
//
//  Created by Kyle Beard on 8/5/25.
//

import SkeletonUI
import SwiftUI

struct SkeletonRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: colorScheme.set(.gray5, .gray4),
                        background: colorScheme.set(.gray7, .gray5)
                    ),
                    shape: .rounded(.radius(8)),
                    lines: 1,
                    scales: [1: 0.5, 2: 0.25]
                )
                .frame(width: 200, height: 17)
                .alignLeading()
            
            RoundedRectangle(cornerRadius: 4)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: colorScheme.set(.gray5, .gray4),
                        background: colorScheme.set(.gray7, .gray5)
                    ),
                    shape: .rounded(.radius(8)),
                    lines: 1,
                    scales: [1: 0.5, 2: 0.25]
                )
                .frame(width: 100, height: 13)
                .alignLeading()
            
            
        }
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
