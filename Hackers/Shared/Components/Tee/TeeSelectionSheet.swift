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
    var segment: HoleSegment = .full18
    var onChange: CallbackValue<Tee>? = nil

    @State private var gender: Gender = .male
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 0)
            
            VStack(spacing: 4) {
                Text("Select your default tee")
                    .fontStyle(.poppins, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Text("Pick the default tee based on yardage, course/slope rating, and normalized difficulty.")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }

            Picker("Gender", selection: $gender) {
                ForEach([Gender.male, Gender.female]) { gender in
                    Text(gender.name)
                        .tag(gender)
                }
            }
            .pickerStyle(.segmented)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if maleTees.isPopulated, gender == .male {
                        ForEach(maleTees.sortedByDifficulty(for: segment), id: \.id) { tee in
                            display(for: tee)
                            
                        }
                    }
                    if femaleTees.isPopulated, gender == .female {
                        ForEach(femaleTees.sortedByDifficulty(for: segment), id: \.id) { tee in
                            display(for: tee)
                        }
                    }
                }
                .padding(1)
            }
        }
        .padding(16)
        .background(palette.backgroundColor)
    }
    
    @ViewBuilder
    private func display(for tee: Tee) -> some View {
        let isSelected = tee.id == selectedTee?.id

        Button(action: {
            Haptics.fire(.light)
            onChange?(tee)
        }) {
            TeeRow(tee: tee, showDifficulty: true, segment: segment)
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
}

//#Preview {
//    TeeSelectionSheet()
//}
