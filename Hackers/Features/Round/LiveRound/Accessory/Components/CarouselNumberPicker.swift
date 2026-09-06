//
//  CarouselNumberPicker.swift
//  Hackers
//
//  Created by Kyle Beard on 2/4/26.
//

import SwiftUI

private let itemWidth: CGFloat = 130
private let itemHeight: CGFloat = 120
private let majorFontSize: CGFloat = 100
private let minorFontSize: CGFloat = 60
private let itemSpacing: CGFloat = 0

/// Keeps the score represented by the carousel independent from its displayed
/// stroke count. Friendly scoring stores values relative to par (`0` is par),
/// while standard scoring stores actual strokes.
enum ScoreCarouselSelection {
    static func initialValue(savedScore: Int?, par: Int, isFriendlyMode: Bool) -> Int {
        savedScore ?? (isFriendlyMode ? 0 : par)
    }

    static func displayedStrokes(for value: Int, par: Int, isFriendlyMode: Bool) -> Int {
        isFriendlyMode ? par + value : value
    }

    static func displayedTriplet(centeredOn value: Int, par: Int, isFriendlyMode: Bool) -> [Int] {
        [value - 1, value, value + 1].map {
            displayedStrokes(for: $0, par: par, isFriendlyMode: isFriendlyMode)
        }
    }
}

struct CarouselNumberPicker: View {
    @Environment(\.colorScheme) var colorScheme
    
    let values: [Int]
    @Binding var selectedValue: Int
    let labelForValue: (Int) -> String
    /// When set (e.g. `0.5`), a leading ASCII `+` or `-` with more than one character renders at this fraction of the main number size.
    let leadingSignFontScale: CGFloat?
    let onChange: CallbackValue<Int>
    
    @State private var displayedValue: Int
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    init(
        values: [Int],
        selectedValue: Binding<Int>,
        labelForValue: @escaping (Int) -> String = { "\($0)" },
        leadingSignFontScale: CGFloat? = nil,
        onChange: @escaping CallbackValue<Int> = { _ in }
    ) {
        self.values = values
        self._selectedValue = selectedValue
        self.labelForValue = labelForValue
        self.leadingSignFontScale = leadingSignFontScale
        self.onChange = onChange
        self._displayedValue = State(initialValue: selectedValue.wrappedValue)
        self._scrollPosition = State(initialValue: selectedValue.wrappedValue)
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: itemSpacing) {
                ForEach(values, id: \.self) { value in
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) {
                            scrollPosition = value
                        }
                    } label: {
                        numberItem(for: value)
                    }
                    .buttonStyle(.plain)
                    .frame(width: itemWidth)
                    .id(value)
                }
            }
            .scrollTargetLayout()
        }
        .safeAreaPadding(.horizontal, (UIScreen.main.bounds.width - itemWidth) / 2)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue else { return }
            displayedValue = newValue
            if scrollPhase == .idle {
                commitSelection(newValue)
            }
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            if newPhase == .idle, let scrollPosition {
                commitSelection(scrollPosition)
            }
        }
        .onChange(of: selectedValue) { _, newValue in
            guard values.contains(newValue), newValue != scrollPosition else { return }
            displayedValue = newValue
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                scrollPosition = newValue
            }
        }
    }
    
    @ViewBuilder
    private func numberItem(for value: Int) -> some View {
        let isSelected = value == displayedValue
        let label = labelForValue(value)
        let bodySize = isSelected ? majorFontSize : minorFontSize
        let weight: FontModule.Weight = isSelected ? .regular : .light
        let foreground = isSelected ? palette.foregroundColor : Color.neutral2

        if let scale = leadingSignFontScale, let split = Self.splitLeadingSignForScaledTypography(label) {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(split.prefix)
                    .fontStyle(.poppins, size: bodySize * scale, weight: weight)
                Text(split.rest)
                    .fontStyle(.poppins, size: bodySize, weight: weight)
            }
            .foregroundColor(foreground)
            .frame(width: itemWidth, height: itemHeight)
        } else {
            Text(label)
                .fontStyle(.poppins, size: bodySize, weight: weight)
                .foregroundColor(foreground)
                .frame(width: itemWidth, height: itemHeight)
        }
    }

    private func commitSelection(_ value: Int) {
        guard value != selectedValue else { return }
        selectedValue = value
        onChange(value)
    }

    /// Splits `+N` / `-N` (ASCII sign) so the sign can use a smaller font; single-glyph labels (e.g. clear `−`) are not split.
    private static func splitLeadingSignForScaledTypography(_ label: String) -> (prefix: String, rest: String)? {
        guard label.count > 1, let first = label.first else { return nil }
        if first == "+" || first == "-" {
            return (String(first), String(label.dropFirst()))
        }
        return nil
    }
}

#Preview {
    CarouselNumberPicker(
        values: Array(1...10),
        selectedValue: .constant(3),
        onChange: { _ in }
    )
    .frame(height: 200)
}
