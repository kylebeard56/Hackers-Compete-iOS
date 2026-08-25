//
//  ScorecardZoomImageView.swift
//  Hackers
//

import SwiftUI
import UIKit

/// Pan/zoom wrapper for scorecard photos (Firebase Storage).
struct ScorecardZoomImageView: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    @State private var currentScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * currentScale)
                .offset(x: offset.width + currentOffset.width, y: offset.height + currentOffset.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = value
                        }
                        .onEnded { value in
                            scale *= value
                            currentScale = 1
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            currentOffset = value.translation
                        }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                            currentOffset = .zero
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            currentScale = 1
                            currentOffset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
