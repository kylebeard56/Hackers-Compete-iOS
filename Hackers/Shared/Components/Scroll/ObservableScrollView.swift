//
//  ObservableScrollView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/22/26.
//

import SwiftUI

struct ObservableScrollView<Content: View>: View {
    @Binding var offset: CGFloat
    
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: () -> Content
    
    @State private var coordinateSpace = UUID().uuidString
    
    init(
        offset: Binding<CGFloat>,
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._offset = offset
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
                .background(
                    ScrollGeometry(
                        name: coordinateSpace,
                        orientation: axes
                    )
                )
        }
        .coordinateSpace(name: coordinateSpace)
        .onPreferenceChange(ScrollPreferenceKey.self) { value in
            offset = value
        }
    }
}
