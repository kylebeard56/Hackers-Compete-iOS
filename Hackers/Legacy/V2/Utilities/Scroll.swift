//
//  Scroll.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct ScrollPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

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
