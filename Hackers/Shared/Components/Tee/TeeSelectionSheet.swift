//
//  TeeSelectionSheet.swift
//  Hackers
//
//  Created by Kyle Beard on 9/26/25.
//

import SwiftUI

struct TeeSelectionSheet: View {
    @Environment(\.colorScheme) var colorScheme
    
    var selectedTee: Tee? = nil
    var maleTees: [Tee] = []
    var femaleTees: [Tee] = []
    var otherTees: [Tee] = []
    var segment: HoleSegment = .full18
    var onChange: CallbackValue<Tee>? = nil

    @State private var category: TeeSelectionCategory = .male
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var availableCategories: [TeeSelectionCategory] {
        var categories: [TeeSelectionCategory] = []
        if maleTees.isPopulated { categories.append(.male) }
        if femaleTees.isPopulated { categories.append(.female) }
        if otherTees.isPopulated { categories.append(.other) }
        return categories
    }

    private var displayedTees: [Tee] {
        switch category {
        case .male:
            return maleTees
        case .female:
            return femaleTees
        case .other:
            return otherTees
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 0)
            
            VStack(spacing: 4) {
                Text("Select your default tee")
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Text("Pick the default tee based on yardage, rating, and difficulty.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }

            if availableCategories.count > 1 {
                Picker("Tee group", selection: $category) {
                    ForEach(availableCategories) { category in
                        Text(category.title)
                            .tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if displayedTees.isPopulated {
                        ForEach(displayedTees.sortedByDifficulty(for: segment), id: \.id) { tee in
                            display(for: tee)
                        }
                    } else {
                        Text("No tees available")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .alignCenter()
                    }
                }
                .padding(1)
            }
        }
        .padding(16)
        .background(palette.backgroundColor)
        .onAppear(perform: syncSelectedCategory)
    }
    
    @ViewBuilder
    private func display(for tee: Tee) -> some View {
        let isSelected = tee.id == selectedTee?.id

        Button(action: {
            Haptics.fire(.light)
            onChange?(tee)
        }) {
            TeeRow(tee: tee, showGender: true, showDifficulty: true, segment: segment)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(palette.backgroundColor)
        .cornerRadius(radius: 10)
        .border(
            isSelected ? palette.foregroundColor : palette.borderColor,
            width: isSelected ? 3 : 1.5,
            cornerRadius: 10
        )
    }

    private func syncSelectedCategory() {
        if let selectedTee {
            if maleTees.contains(where: { $0.id == selectedTee.id }) {
                category = .male
                return
            }
            if femaleTees.contains(where: { $0.id == selectedTee.id }) {
                category = .female
                return
            }
            if otherTees.contains(where: { $0.id == selectedTee.id }) {
                category = .other
                return
            }
        }

        category = availableCategories.first ?? .other
    }
}

private enum TeeSelectionCategory: String, CaseIterable, Identifiable {
    case male
    case female
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male:
            return "Men"
        case .female:
            return "Women"
        case .other:
            return "Other"
        }
    }
}

//#Preview {
//    TeeSelectionSheet()
//}
