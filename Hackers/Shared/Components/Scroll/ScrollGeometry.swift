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

@preconcurrency
struct MultiPreferenceKey: PreferenceKey {
    static var defaultValue: [PreferenceKeyChoice: CGFloat] = [:]
    
    static func reduce(
        value: inout [PreferenceKeyChoice: CGFloat],
        nextValue: () -> [PreferenceKeyChoice: CGFloat]
    ) {
        let next = nextValue()
        for (key, newVal) in next {
            if let oldVal = value[key] {
                switch key {
                case .scroll:
                    value[key] = oldVal + newVal
                case .measureMax:
                    value[key] = max(oldVal, newVal)
                }
            } else {
                value[key] = newVal
            }
        }
    }
}

enum PreferenceKeyChoice: Hashable {
    /// Measures the scrolling offset
    case scroll
    
    /// Measures the max width or height depending on the axis
    case measureMax
}

@preconcurrency
struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Measures its child's height and reports via ContentHeightKey. Use as .background(MeasureHeight()).
struct MeasureHeight: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
        }
    }
}

@MainActor
struct ScrollGeometry: View {
    var name: String
    var orientation: Axis.Set = .vertical
    var choice: PreferenceKeyChoice = .scroll
    
    /// TODO: Uncomment this out and use if you ever need measureMax
//    var body: some View {
//        GeometryReader { gr in
//            let value: CGFloat = {
//                switch choice {
//                case .scroll:
//                    let frame = gr.frame(in: .named(name))
//                    return orientation == .vertical ? frame.minY : frame.minX
//                case .measureMax:
//                    let size = gr.size
//                    return orientation == .vertical ? size.height : size.width
//                }
//            }()
//            
//            Color.clear.preference(
//                key: MultiPreferenceKey.self,
//                value: [choice: value]
//            )
//        }
//    }
    
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
