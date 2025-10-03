//
//  StickyScrollView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct StickyScrollView<Header: View, Content: View, Footer: View>: View {
    @Environment(\.colorScheme) var colorScheme
    
    let name: String
    let header: (() -> Header)?
    let content: () -> Content
    let footer: (() -> Footer)?
    let axis: Axis.Set
    let theme: PaletteTheme
    let fillGeometry: Bool
    let onScroll: @Sendable (CGFloat) async -> Void
    
    init(
        name: String = "",
        header: (() -> Header)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        footer: (() -> Footer)? = nil,
        axis: Axis.Set = .vertical,
        theme: PaletteTheme = .primary,
        fillGeometry: Bool = false,
        onScroll: @escaping @Sendable (CGFloat) async -> Void
    ) {
        self.name = name
        self.header = header
        self.content = content
        self.footer = footer
        self.axis = axis
        self.theme = theme
        self.fillGeometry = fillGeometry
        self.onScroll = onScroll
    }
    
    @State private var animateHeaderDivider = false
    private let coordinateSpace = UUID().uuidString
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    
    var body: some View {
        VStack(spacing: 0) {
            /// 1. Optional header
            if let header {
                VStack(spacing: 12) {
                    header()
                    
                    Line()
                        .opacity(animateHeaderDivider ? 1 : 0)
                }
            }
            
            /// 2. Scrollable content
            GeometryReader { geom in
                ScrollView {
                    ScrollViewReader { proxy in
                        if fillGeometry {
                            fillableContent(proxy)
                                .frame(height: geom.size.height)
                        } else {
                            fillableContent(proxy)
                        }
                    }
                }
                .coordinateSpace(name: coordinateSpace)
                .onPreferenceChange(ScrollPreferenceKey.self) { offset in
                    Task {
                        await onPreferenceChange(offset)
                    }
                }
            }

            /// 3. Optional footer
            if let footer {
                footer()
            }
        }
        .background(palette.backgroundColor)
        .alignTop()
    }
    
    private func fillableContent(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            content()
                .background(ScrollGeometry(name: coordinateSpace, orientation: axis))
                .onReceive(HackersNotification.scrollToBottom.publisher(), perform: { data in
                    if let target = data.object as? String, target == name {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                })
            
            Spacer(minLength: 0)
                .frame(height: 16)
                .id("bottom")
        }
    }
    
    @MainActor
    private func onPreferenceChange(_ value: CGFloat) async {
        await onScroll(value)
        withAnimation(.easeInOut(duration: 0.3)) {
            animateHeaderDivider = value < 0
        }
    }
}
