//
//  Untitled.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import SwiftUI

enum ChipSize: CaseIterable {
    case xSmall, small, medium, large
    
    var fontSize: CGFloat {
        switch self {
        case .xSmall:       return 13
        case .small:        return 15
        case .medium:       return 17
        case .large:        return 20
        }
    }
    
    var iconSize: CGFloat {
        return fontSize + 2.0
    }
    
    var verticalPadding: CGFloat {
        return fontSize * 0.4
    }
    
    var horizontalPadding: CGFloat {
        return verticalPadding * 2
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .xSmall:       return 6
        case .small:        return 8
        case .medium:       return 10
        case .large:        return 12
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .xSmall:       return 1.5
        case .small:        return 2
        case .medium:       return 2
        case .large:        return 2.5
        }
    }
}

struct Chip: View {
    var text: String?
    var weight: FontModule.Weight = .medium
    var icon: String?
    var iconWeight: FontModule.Weight? = .regular
    var iconColor: Color?
    var size: ChipSize = .small
    var style: HackersButtonAppearance = .fill
    var foreground: Color = .hackersForeground
    var background: Color = .hackersGray6
    var border: Color = .hackersGray6
    
    var body: some View {
        button
    }
    
    @ViewBuilder private var button: some View {
        if style == .outline {
            content
                .cornerRadius(size.cornerRadius)
                .border(border, width: size.borderWidth, cornerRadius: size.cornerRadius)
        } else {
            content
                .background(background)
                .cornerRadius(size.cornerRadius)
        }
    }
    
    private var content: some View {
        HStack(spacing: size.horizontalPadding) {
            if let icon, let iconWeight {
                Icon(name: icon, size: size.iconSize, maxSize: size.iconSize, weight: iconWeight)
                    .foregroundStyle(iconColor ?? foreground)
            }
            if let text {
                Text(text)
                    .fontStyle(.poppins, size: size.fontSize, weight: weight)
                    .foregroundStyle(foreground)
            }
        }
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(ChipSize.allCases, id: \.self) { size in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Chip(text: "Today", size: size, style: .fill)
                    Chip(text: "Tomorrow", size: size, style: .outline)
                    Chip(text: "Friday", size: size, style: .outline)
                    Chip(text: "Saturday", size: size, style: .outline)
                    Chip(icon: "2b", size: size, style: .outline)
                    Spacer()
                }
                .padding(1)
            }
        }
        
        ForEach(ChipSize.allCases, id: \.self) { size in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Chip(text: "Write workout", icon: "f044", size: size, style: .fill)
                    Chip(text: "Take photo", icon: "f03e", iconColor: .hackersGray3, size: size, style: .outline)
                    Chip(text: "Friday", size: size, style: .outline)
                    Chip(text: "Saturday", size: size, style: .outline)
                    Chip(icon: "2b", size: size, style: .outline)
                    Spacer()
                }
                .padding(1)
            }
        }
    }
    .padding(16)
}
