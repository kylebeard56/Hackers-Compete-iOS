//
//  ChipButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

enum ChipSize {
    case medium, large, extraLarge
    
    var verticalPadding: CGFloat {
        switch self {
        case .medium:       return 4
        case .large:        return 6
        case .extraLarge:   return 8
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .medium:       return 8
        case .large:        return 12
        case .extraLarge:   return 16
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .medium:       return 4
        case .large:        return 6
        case .extraLarge:   return 10
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .medium:       return 15
        case .large:        return 17
        case .extraLarge:   return 22
        }
    }
}

struct ChipButton: View {
    var size: ChipSize = .medium
    var style: HackersButtonStyle = .solid
    var text: String
    var foregroundColor: Color = Color.systemBlack
    var backgroundColor: Color = Color.systemGray6
    
    var body: some View {
        button
    }
    
    @ViewBuilder private var button: some View {
        if style == .outline {
            Text(text)
                .font(.dmSans, size: size.fontSize, weight: .medium)
                .foregroundColor(foregroundColor)
                .padding(.vertical, size.verticalPadding)
                .padding(.horizontal, size.horizontalPadding)
                .cornerRadius(size.cornerRadius)
                .border(backgroundColor, width: 2, cornerRadius: size.cornerRadius)
        } else {
            Text(text)
                .font(.dmSans, size: size.fontSize, weight: .medium)
                .foregroundColor(foregroundColor)
                .padding(.vertical, size.verticalPadding)
                .padding(.horizontal, size.horizontalPadding)
                .background(backgroundColor)
                .cornerRadius(size.cornerRadius)
        }
    }
}

struct ChipButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChipButton(size: .medium, text: "Which player")
            ChipButton(size: .large, text: "Which player")
            ChipButton(size: .extraLarge, text: "Which player")
        }
        
    }
}
