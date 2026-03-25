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

struct CarouselNumberPicker: View {
    @Environment(\.colorScheme) var colorScheme
    
    let values: [Int]
    let initialValue: Int
    let labelForValue: (Int) -> String
    let onChange: CallbackValue<Int>
    
    @State private var selectedValue: Int
    @State private var scrollPosition: Int?
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    init(
        values: [Int],
        initialValue: Int,
        labelForValue: @escaping (Int) -> String = { "\($0)" },
        onChange: @escaping CallbackValue<Int> = { _ in }
    ) {
        self.values = values
        self.initialValue = initialValue
        self.labelForValue = labelForValue
        self.onChange = onChange
        self._selectedValue = State(initialValue: initialValue)
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: itemSpacing) {
                ForEach(values, id: \.self) { value in
                    numberItem(for: value)
                    .frame(width: itemWidth)
                    .id(value)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            scrollPosition = value
                        }
                    }
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
            
            if newValue != selectedValue {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedValue = newValue
                }
            }
            onChange(newValue)
        }
        .task(id: initialValue) {
            // Delay to ensure ScrollView is fully laid out before setting position
            try? await Task.sleep(for: .milliseconds(50))
            scrollPosition = initialValue
        }
    }
    
    @ViewBuilder
    private func numberItem(for value: Int) -> some View {
        let isSelected = value == selectedValue
        Text(labelForValue(value))
            .fontStyle(
                .poppins,
                size: isSelected ? majorFontSize : minorFontSize,
                weight: isSelected ? .regular : .light
            )
            .foregroundColor(isSelected ? palette.foregroundColor : Color.neutral2)
            .frame(width: itemWidth, height: itemHeight)
    }
}

#Preview {
    CarouselNumberPicker(
        values: Array(1...10),
        initialValue: 3,
        onChange: { _ in }
    )
    .frame(height: 200)
}
