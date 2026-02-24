import SwiftUI

// MARK: - HoleTabDensity

enum HoleTabDensity: Int, CaseIterable {
    case compact = 1  // 3 visible slots
    case regular = 2  // 5 visible slots
    case wide    = 3  // 7 visible slots

    var visibleSlots: Int { (rawValue * 2) + 1 }
    var edgeCount: Int { rawValue }
}

// MARK: - HoleTabItem

struct HoleTabItem {
    let label: String
    let color: Color

    init(label: String, color: Color = .primary) {
        self.label = label
        self.color = color
    }
}

// MARK: - HoleTabGeometry

/// Pure geometry math — no SwiftUI, fully testable.
struct HoleTabGeometry {
    let density: HoleTabDensity
    let itemCount: Int

    var slots: Int { density.visibleSlots }
    var centerSlot: Int { density.edgeCount }
    var edge: Int { density.edgeCount }

    /// Which slot (as a continuous float) the underline occupies.
    /// Piecewise linear: travels across edge slots, then pins at center.
    func underlineSlot(for fractionalIndex: CGFloat) -> CGFloat {
        let fi = max(0, min(CGFloat(itemCount - 1), fractionalIndex))
        let leftBoundary  = CGFloat(edge)
        let rightBoundary = CGFloat(itemCount - 1 - edge)

        if fi < leftBoundary {
            return fi
        } else if fi > rightBoundary {
            return CGFloat(centerSlot) + (fi - rightBoundary)
        } else {
            return CGFloat(centerSlot)
        }
    }

    /// How far the full label strip has shifted left behind the visible window.
    func labelStripOffset(for fractionalIndex: CGFloat, slotWidth: CGFloat) -> CGFloat {
        let fi = max(0, min(CGFloat(itemCount - 1), fractionalIndex))
        let leftBoundary  = CGFloat(edge)
        let rightBoundary = CGFloat(itemCount - 1 - edge)

        if fi < leftBoundary {
            return 0
        } else if fi > rightBoundary {
            return CGFloat(itemCount - slots) * slotWidth
        } else {
            return (fi - leftBoundary) * slotWidth
        }
    }
}

// MARK: - PageCoordinator

/// Single shared object. The tab bar reads from it, the scroll view writes to it.
@Observable
final class PageCoordinator {
    var fractionalIndex: CGFloat = 0
    var programmaticTarget: Int? = nil

    func scrollTo(index: Int) {
        programmaticTarget = index
    }
}

// MARK: - HoleTabBar

struct HoleTabBar: View {
    let density: HoleTabDensity
    let items: [HoleTabItem]
    let fractionalIndex: CGFloat
    let onTap: (Int) -> Void
    let onSettled: (Int) -> Void

    private var tabGeometry: HoleTabGeometry {
        HoleTabGeometry(density: density, itemCount: items.count)
    }

    // Integer settled index — only used for font weight, not for positions
    private var settledIndex: Int {
        Int(fractionalIndex.rounded())
    }

    var body: some View {
        GeometryReader { proxy in
            let slotWidth   = proxy.size.width / CGFloat(density.visibleSlots)
            let windowWidth = proxy.size.width
            let stripOffset = tabGeometry.labelStripOffset(for: fractionalIndex, slotWidth: slotWidth)
            let underlineX  = tabGeometry.underlineSlot(for: fractionalIndex) * slotWidth

            ZStack(alignment: .bottomLeading) {

                // ── Label strip ──────────────────────────────────────────────
                // All labels laid out in a single HStack, wider than the window.
                // Clipped to windowWidth so only the visible slots show.
                // Offset by -stripOffset to slide the correct labels into view.
                HStack(spacing: 0) {
                    ForEach(0..<items.count, id: \.self) { index in
                        let item      = items[index]
                        let isActive  = settledIndex == index
                        let proximity = abs(fractionalIndex - CGFloat(index))
                        let opacity   = max(0.35, 1.0 - (proximity * 0.3))

                        Button { onTap(index) } label: {
                            Text(item.label)
                                .font(.subheadline)
                                .fontWeight(isActive ? .semibold : .regular)
                                .foregroundStyle(item.color.opacity(opacity))
                                .frame(width: slotWidth)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .offset(x: -stripOffset)
                .frame(width: windowWidth, alignment: .leading)
                .clipped() // ← hides everything outside the visible slot window

                // ── Underline ────────────────────────────────────────────────
                // No animation modifier — tracks fractionalIndex directly so it
                // moves frame-perfect with the finger. Animation comes from the
                // scroll view's own spring settle, not from a SwiftUI curve here.
                RoundedRectangle(cornerRadius: 1.5)
                    .frame(width: slotWidth, height: 3)
                    .foregroundStyle(underlineColor)
                    .offset(x: underlineX)
            }
        }
        .frame(height: 44)
        .onChange(of: settledIndex) { _, newIndex in
            onSettled(newIndex)
        }
    }

    /// Switches color at the 50% midpoint between neighbors.
    /// Replace with UIColor RGB interpolation for a true cross-fade.
    private var underlineColor: Color {
        let fi    = max(0, min(CGFloat(items.count - 1), fractionalIndex))
        let lower = Int(fi)
        let upper = min(lower + 1, items.count - 1)
        guard lower != upper else { return items[lower].color }
        return (fi - CGFloat(lower)) < 0.5 ? items[lower].color : items[upper].color
    }
}

// MARK: - PagedHoleScrollView

struct PagedHoleScrollView<Content: View>: View {
    let holeNumbers: [Int]
    @Binding var scoringPageHole: Int?
    let coordinator: PageCoordinator
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(holeNumbers.enumerated()), id: \.offset) { index, holeNumber in
                        content(index)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .containerRelativeFrame(.horizontal)
                            .id(holeNumber)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scoringPageHole)
            // ── Key fix ──────────────────────────────────────────────────────
            // onScrollGeometryChange fires on EVERY frame during a drag gesture,
            // unlike PreferenceKey + coordinateSpace which can skip frames or
            // fail to fire during active touches. This is the correct iOS 17+ API
            // for continuous offset tracking.
            .onScrollGeometryChange(for: CGFloat.self) { scrollGeo in
                let width = scrollGeo.containerSize.width
                guard width > 0 else { return 0 }
                return scrollGeo.contentOffset.x / width
            } action: { _, newFractional in
                coordinator.fractionalIndex = newFractional
            }
            // ── Programmatic scroll from tab tap ─────────────────────────────
            .onChange(of: coordinator.programmaticTarget) { _, targetIndex in
                guard let targetIndex, targetIndex < holeNumbers.count else { return }
                let holeNumber = holeNumbers[targetIndex]
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(holeNumber, anchor: .leading)
                }
                coordinator.programmaticTarget = nil
            }
        }
    }
}

// MARK: - HolePageView (demo content)

struct HolePageView: View {
    let holeIndex: Int

    private var holeColor: Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .red,
            .teal, .indigo, .mint, .cyan, .yellow
        ]
        return colors[holeIndex % colors.count]
    }

    var body: some View {
        ZStack {
            holeColor.opacity(0.08).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("⛳️")
                    .font(.system(size: 64))

                Text("Hello, Hole \(holeIndex + 1)!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(holeColor)

                Text("Swipe or tap a tab to navigate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - HoleScorecardView (root demo)

struct HoleScorecardView: View {
    private let holeCount = 18
    private let holeNumbers = Array(1...18)
    private let density: HoleTabDensity = .regular  // 5 visible slots

    @State private var coordinator = PageCoordinator()
    @State private var scoringPageHole: Int?
    @State private var lastSettledIndex: Int = 0

    private var tabItems: [HoleTabItem] {
        (0..<holeCount).map { index in
            HoleTabItem(
                label: "Hole \(index + 1)",
                color: tabColor(for: index)
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HoleTabBar(
                density: density,
                items: tabItems,
                fractionalIndex: coordinator.fractionalIndex,
                onTap: { coordinator.scrollTo(index: $0) },
                onSettled: { lastSettledIndex = $0 }
            )
            .background(.ultraThinMaterial)

            Divider()

            PagedHoleScrollView(holeNumbers: holeNumbers, scoringPageHole: $scoringPageHole, coordinator: coordinator) { index in
                HolePageView(holeIndex: index)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func tabColor(for index: Int) -> Color {
        switch index {
        case 0, 2, 5: return .green
        case 1, 4:    return .red
        case 3:       return .yellow
        default:      return .primary
        }
    }
}

// MARK: - Preview

#Preview {
    HoleScorecardView()
}
