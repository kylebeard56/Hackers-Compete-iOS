//
//  CarouselNumberPicker.swift
//  Hackers
//
//  Created by Kyle Beard on 2/4/26.
//

import SwiftUI

struct CarouselNumberPicker: View {
    @Environment(\.colorScheme) var colorScheme
    
    let values: [Int]
    let initialValue: Int
    let onChange: CallbackValue<Int>
    
    @State private var selectedValue: Int
    @State private var scrollPosition: Int?
    
    private let itemWidth: CGFloat = 120
    private let itemSpacing: CGFloat = 0
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    init(
        values: [Int],
        initialValue: Int,
        onChange: @escaping CallbackValue<Int> = { _ in }
    ) {
        self.values = values
        self.initialValue = initialValue
        self.onChange = onChange
        self._selectedValue = State(initialValue: initialValue)
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: itemSpacing) {
                ForEach(values, id: \.self) { value in
                    NumberItem(
                        value: value,
                        values: values,
                        selectedValue: selectedValue,
                        foregroundColor: palette.foregroundColor
                    )
                    .frame(width: itemWidth)
                    //.background(value % 2 == 0 ? Color.orange : Color.yellow)
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
                onChange(newValue)
            }
        }
        .onAppear {
            scrollPosition = initialValue
        }
    }
}

private struct NumberItem: View {
    let value: Int
    let values: [Int]
    let selectedValue: Int
    let foregroundColor: Color
    
    private var isSelected: Bool { value == selectedValue }
    
    var body: some View {
        Text("\(value)")
            .font(.system(size: isSelected ? 100 : 60, weight: isSelected ? .regular : .light))
            .foregroundColor(isSelected ? foregroundColor : Color.neutral)
    }
}

#Preview {
    CarouselNumberPicker(
        values: Array(1...10),
        initialValue: 3
    ) { _ in }
    .frame(height: 200)
}
