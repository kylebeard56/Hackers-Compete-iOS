//
//  SizedSheet.swift
//  Hackers
//
//  Created by Cursor on 2/3/26.
//

import SwiftUI

// MARK: - Sized Sheet (content-driven height)

private struct SheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SizedSheetDetentModifier: ViewModifier {
    @State private var measuredHeight: CGFloat = 0
    @State private var detent: PresentationDetent
    
    var minHeight: CGFloat
    var maxHeightRatio: CGFloat
    
    init(minHeight: CGFloat, maxHeightRatio: CGFloat) {
        self.minHeight = minHeight
        self.maxHeightRatio = maxHeightRatio
        _detent = State(initialValue: .height(minHeight))
    }
    
    private var clampedHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let maxHeight = screenHeight * maxHeightRatio
        return min(max(measuredHeight, minHeight), maxHeight)
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SheetHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SheetHeightPreferenceKey.self) { newValue in
                measuredHeight = newValue
                updateDetentIfNeeded()
            }
            .onAppear {
                updateDetentIfNeeded()
            }
            .presentationDetents([detent], selection: $detent)
    }
    
    private func updateDetentIfNeeded() {
        let height = clampedHeight
        guard height > 0 else { return }
        
        DispatchQueue.main.async {
            let newDetent: PresentationDetent = .height(height)
            if detent != newDetent {
                withAnimation(.easeInOut(duration: 0.2)) {
                    detent = newDetent
                }
            }
        }
    }
}

extension View {
    /// Automatically sizes a sheet to match its content height.
    /// Use inside a sheet content view.
    func sizedSheetDetent(minHeight: CGFloat = 200, maxHeightRatio: CGFloat = 0.9) -> some View {
        modifier(SizedSheetDetentModifier(minHeight: minHeight, maxHeightRatio: maxHeightRatio))
    }
    
    /// Convenience wrapper around `sizedSheetDetent`.
    func sizedSheet(minHeight: CGFloat = 200, maxHeightRatio: CGFloat = 0.9) -> some View {
        sizedSheetDetent(minHeight: minHeight, maxHeightRatio: maxHeightRatio)
    }
}

// MARK: - Example
//
// .sheet(isPresented: $showSheet) {
//     ScorecardSheet(viewModel: viewModel, participant: participant)
//         .sizedSheetDetent()
//         // Optional customization:
//         // .sizedSheetDetent(minHeight: 260, maxHeightRatio: 0.85)
// }
