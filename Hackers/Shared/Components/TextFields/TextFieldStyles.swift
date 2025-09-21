//
//  TextFieldStyles.swift
//  Hackers
//
//  Created by Kyle Beard on 9/17/25.
//

import Foundation
import SwiftUI

struct HackersTextFieldStyle: TextFieldStyle {
    let background: Color
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let textColor: Color
    let fontSize: CGFloat
    let fontWeight: FontModule.Weight
    
    init(
        background: Color = .hackersGray6,
        cornerRadius: CGFloat = 12,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 12,
        textColor: Color = .hackersForeground,
        fontSize: CGFloat = 17,
        fontWeight: FontModule.Weight = .regular
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .fontStyle(.poppins, size: fontSize, weight: fontWeight)
            .foregroundStyle(textColor)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(background)
            .cornerRadius(cornerRadius)
    }
}

