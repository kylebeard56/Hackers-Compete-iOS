//
//  TeeDropdown.swift
//  Hackers
//
//  Created by Kyle Beard on 9/28/25.
//

import SwiftUI

struct TeeDropdown: View {
    @Environment(\.colorScheme) var colorScheme
    
    var tee: Tee? = nil
    var segment: HoleSegment = .full18
    var showGender = false
    var showDifficulty = false
    var placeholder = "Select default tee"
    var background: Color = .systemClear
    var onTap: Callback? = nil
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap?()
        }) {
            HStack {
                if let tee {
                    TeeRow(tee: tee, showGender: showGender, showDifficulty: showDifficulty, segment: segment)
                } else {
                    Text(placeholder)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
                
                Icon(name: "f078", size: 13, weight: .solid)
                    .foregroundStyle(Color.neutral3)
            }
            .borderedContentStyle(theme: palette.theme)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .border(palette.theme.borderColor, width: 1.5, cornerRadius: 10)
//            .background(background)
//            .cornerRadius(10)
        }
    }
}

#Preview {
    TeeDropdown()
        .padding(16)
}
