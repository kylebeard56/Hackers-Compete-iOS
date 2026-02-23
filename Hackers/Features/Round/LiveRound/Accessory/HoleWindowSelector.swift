//
//  HoleWindowSelector.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/26.
//

import SwiftUI

/// Hole navigation tab strip with smooth fractional-index tracking.
/// Visuals (state colors, indicator capsule) from the original design;
/// animation math (label-strip offset + underline position) from `HolePager`.
/// Passes coordinator so only this view observes fractionalIndex, avoiding parent re-renders during scroll.
struct HoleWindowSelector: View {
    let coordinator: PageCoordinator
    let holes: [Int]
    let visibleSlotCount: Int
    let accentColor: Color
    let activeColor: Color
    let inactiveColor: Color
    let fontSize: CGFloat
    let slotSpacing: CGFloat
    let itemSpacing: CGFloat
    let indicatorHeight: CGFloat
    let rowPadding: EdgeInsets
    let holeState: (Int) -> LiveRoundViewModel.HoleDisplayState
    let onSelect: (Int) -> Void

    private var fractionalIndex: CGFloat { coordinator.fractionalIndex }
    private var settledIndex: Int { Int(fractionalIndex.rounded()) }

    var body: some View {
        GeometryReader { proxy in
            let slotWidth   = proxy.size.width / CGFloat(max(1, visibleSlotCount))
            let stripOffset = labelStripOffset(for: fractionalIndex, slotWidth: slotWidth)
            let underlineX  = underlineSlot(for: fractionalIndex) * slotWidth

            ZStack(alignment: .bottomLeading) {
                // ── Label strip ──────────────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(Array(holes.enumerated()), id: \.element) { index, hole in
                        let isCurrent = settledIndex == index
                        let state     = holeState(hole)
                        let proximity = abs(fractionalIndex - CGFloat(index))
                        let opacity   = max(0.35, 1.0 - proximity * 0.3)

                        Button { onSelect(hole) } label: {
                            Text("Hole \(hole)")
                                .fontStyle(kFontName, size: fontSize, weight: isCurrent ? .semibold : .medium)
                                .foregroundStyle(holeForeground(isCurrent: isCurrent, state: state).opacity(opacity))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.vertical, itemSpacing)
                                .frame(width: slotWidth)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .offset(x: -stripOffset)
                .frame(width: proxy.size.width, alignment: .leading)
                .clipped()

                // ── Underline indicator ──────────────────────────────────────
                Capsule()
                    .fill(accentColor)
                    .frame(width: max(0, slotWidth - slotSpacing), height: indicatorHeight)
                    .offset(x: underlineX + slotSpacing / 2)
            }
        }
        .frame(height: itemSpacing * 2 + fontSize + 8 + indicatorHeight)
        .padding(rowPadding)
    }

    private func holeForeground(isCurrent: Bool, state: LiveRoundViewModel.HoleDisplayState) -> Color {
        if isCurrent { return accentColor }
        switch state {
        case .completed:            return activeColor
        case .error:                return .systemError
        case .unscored, .current:   return inactiveColor
        }
    }

    // Piecewise linear: tracks linearly through edge slots, pins at center slot.
    private func underlineSlot(for fi: CGFloat) -> CGFloat {
        let fi    = max(0, min(CGFloat(holes.count - 1), fi))
        let edge  = visibleSlotCount / 2
        let left  = CGFloat(edge)
        let right = CGFloat(holes.count - 1 - edge)
        if fi < left  { return fi }
        if fi > right { return CGFloat(edge) + (fi - right) }
        return CGFloat(edge)
    }

    private func labelStripOffset(for fi: CGFloat, slotWidth: CGFloat) -> CGFloat {
        let fi    = max(0, min(CGFloat(holes.count - 1), fi))
        let edge  = visibleSlotCount / 2
        let left  = CGFloat(edge)
        let right = CGFloat(holes.count - 1 - edge)
        if fi < left  { return 0 }
        if fi > right { return CGFloat(holes.count - visibleSlotCount) * slotWidth }
        return (fi - left) * slotWidth
    }
}

// MARK: - Preview

#Preview {
    let coordinator = PageCoordinator()
    coordinator.fractionalIndex = 1
    let holes = Array(1...18)

    return HoleWindowSelector(
        coordinator: coordinator,
        holes: holes,
        visibleSlotCount: 3,
        accentColor: .purple,
        activeColor: .green,
        inactiveColor: .secondary,
        fontSize: 14,
        slotSpacing: 10,
        itemSpacing: 4,
        indicatorHeight: 4,
        rowPadding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
        holeState: { hole in
            if hole == 2 { return .current }
            if hole <= 4 { return .completed }
            return .unscored
        },
        onSelect: { hole in
            guard let index = holes.firstIndex(of: hole) else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                coordinator.fractionalIndex = CGFloat(index)
            }
        }
    )
    .glassCardEffect(shape: .capsule)
    .padding(.horizontal, 48)
}
