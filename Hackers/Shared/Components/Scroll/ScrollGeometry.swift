//
//  ScrollPreferenceKey.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import Foundation
import SwiftUI

// CRASH: Investigate here if you get a SwiftUI.async crash. Sentry posts a more detailed error.
@preconcurrency
struct ScrollPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

@MainActor
struct ScrollGeometry: View {
    var name: String
    var orientation: Axis.Set = .vertical
    
    var body: some View {
        GeometryReader { gr in
            if orientation == .vertical {
                Color.clear.preference(
                    key: ScrollPreferenceKey.self,
                    value: gr.frame(in: .named(name)).minY
                )
            }
            if orientation == .horizontal {
                Color.clear.preference(
                    key: ScrollPreferenceKey.self,
                    value: gr.frame(in: .named(name)).minX
                )
            }
        }
    }
}
