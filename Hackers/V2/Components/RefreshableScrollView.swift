////
////  RefreshableScrollView.swift
////  Hackers
////
////  Created by Kyle Beard on 7/19/23.
////
//
//import SwiftUI
//
//struct RefreshableScrollView<Content: View>: View {
//    @State private var previousScrollOffset: CGFloat = 0
//    @State private var scrollOffset: CGFloat = 0
//    @State private var frozen: Bool = false
//    @State private var rotation: Angle = .degrees(0)
//
//    var threshold: CGFloat = 70
//    var color: Color = Color.white
//    @Binding var refreshing: Bool
//    let content: Content
//
//    init(
//        height: CGFloat = 70,
//        color: Color = Color.white,
//        refreshing: Binding<Bool>,
//        @ViewBuilder content: () -> Content
//    ) {
//        self.threshold = height
//        self.color = color
//        self._refreshing = refreshing
//        self.content = content()
//    }
//
//    var body: some View {
//        return VStack {
//            ScrollViewReader { reader in
//                ScrollView(showsIndicators: false) {
//                    ZStack(alignment: .top) {
//                        MovingView()
//                            .id(0)
//
//                        content
//                            .alignmentGuide(.top, computeValue: { _ in refreshing && frozen ? -threshold : 0.0 })
//
//                        if refreshing {
//                            ProgressView()
//                                .progressViewStyle(.circular)
//                                .frame(height: threshold)
//                                .fixedSize()
//                                .alignMiddle()
//                        }
//                        
////                        SymbolView(
////                            color: color,
////                            height: threshold,
////                            loading: refreshing,
////                            frozen: frozen,
////                            rotation: rotation
////                        )
//                    }
//                }
//                .background(FixedView())
//                .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
//                    self.refreshLogic(values: values, proxy: reader)
//                }
//            }
//        }
//    }
//
//    func refreshLogic(values: [RefreshableKeyTypes.PrefData], proxy: ScrollViewProxy) {
//        DispatchQueue.main.async {
//
//            // Calculate scroll offset
//            let movingBounds = values.first { $0.vType == .movingView }?.bounds ?? .zero
//            let fixedBounds = values.first { $0.vType == .fixedView }?.bounds ?? .zero
//
//            self.scrollOffset = movingBounds.minY - fixedBounds.minY
//            self.rotation = self.symbolRotation(self.scrollOffset)
//
//            // Crossing the threshold on the way down, we start the refresh process
//            if !self.refreshing && (self.scrollOffset > self.threshold && self.previousScrollOffset <= self.threshold) {
//                self.refreshing = true
//            }
//
//            if self.refreshing {
//                // Crossing the threshold on the way up, we add a space at the top of the scrollview
//                if self.previousScrollOffset > self.threshold && self.scrollOffset <= self.threshold {
//                    self.frozen = true
//                    proxy.scrollTo(0)
//                }
//            } else {
//                // remove the space at the top of the scroll view
//                self.frozen = false
//            }
//
//            // Update last scroll offset
//            self.previousScrollOffset = self.scrollOffset
//        }
//    }
//
//    func symbolRotation(_ scrollOffset: CGFloat) -> Angle {
//
//        // We will begin rotation, only after we have passed
//        // 60% of the way of reaching the threshold.
//        if scrollOffset < self.threshold * 0.60 {
//            return .degrees(0)
//        } else {
//            // Calculate rotation, based on the amount of scroll offset
//            let h = Double(self.threshold)
//            let d = Double(scrollOffset)
//            let v = max(min(d - (h * 0.6), h * 0.4), 0)
//            return .degrees(180 * v / (h * 0.4))
//        }
//    }
//
//    struct SymbolView: View {
//        var color: Color
//        var height: CGFloat
//        var loading: Bool
//        var frozen: Bool
//        var rotation: Angle
//
//        var body: some View {
//            Group {
//                if loading {
//
//                    ProgressView()
//                        .progressViewStyle(.circular)
//                        .alignMiddle()
//                        .frame(height: height)
//                        .fixedSize()
//
//                } else {
//
//                    Image(systemName: "arrow.down")
//                        .font(.system(size: 15, weight: .semibold))
//                        .fixedSize()
//                        .padding(height * 0.375)
//                        .rotationEffect(rotation)
//                        .foregroundColor(color)
//                }
//            }
//            .offset(y: -height + (loading && frozen ? height : 0.0))
//        }
//    }
//
//    struct MovingView: View {
//        var body: some View {
//            GeometryReader { proxy in
//                Color.clear.preference(
//                    key: RefreshableKeyTypes.PrefKey.self,
//                    value: [RefreshableKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))])
//            }.frame(height: 0)
//        }
//    }
//
//    struct FixedView: View {
//        var body: some View {
//            GeometryReader { proxy in
//                Color.clear.preference(
//                    key: RefreshableKeyTypes.PrefKey.self,
//                    value: [RefreshableKeyTypes.PrefData(vType: .fixedView, bounds: proxy.frame(in: .global))])
//            }
//        }
//    }
//}
//
//struct RefreshableKeyTypes {
//    enum ViewType: Int {
//        case movingView
//        case fixedView
//    }
//
//    struct PrefData: Equatable {
//        let vType: ViewType
//        let bounds: CGRect
//    }
//
//    struct PrefKey: PreferenceKey {
//        static var defaultValue: [PrefData] = []
//
//        static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
//            value.append(contentsOf: nextValue())
//        }
//
//        typealias Value = [PrefData]
//    }
//}
