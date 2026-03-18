//
//  Untitled.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import SwiftUI

enum ChipSize: String, CaseIterable {
    case tiny, xSmall, small, medium, large
    
    var fontSize: CGFloat {
        switch self {
        case .tiny:         return 11
        case .xSmall:       return 13
        case .small:        return 15
        case .medium:       return 17
        case .large:        return 20
        }
    }
    
    var iconSize: CGFloat {
        fontSize
    }
    
    var verticalPadding: CGFloat {
        fontSize * 0.334
    }
    
    var horizontalPadding: CGFloat {
        verticalPadding * 2
    }
    
    var cornerRadius: CGFloat {
        fontSize * 0.5
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .tiny:         return 1.25
        case .xSmall:       return 1.5
        case .small:        return 2
        case .medium:       return 2
        case .large:        return 2.5
        }
    }
}

struct Chip: View {
    @Environment(\.colorScheme) var colorScheme
    
    var text: String?
    var weight: FontModule.Weight = .medium
    var icon: String?
    var iconWeight: FontModule.Weight? = .regular
    var iconColor: Color?
    var size: ChipSize = .small
    var style: HackersButtonAppearance = .fill
    var tint: Color? = nil
    var foreground: Color? = nil
    var background: Color? = nil
    var border: Color? = nil
    var theme: PaletteTheme = .primary
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    private var backgroundColor: Color {
        if let tint {
            return tint.opacity(colorScheme.translucent)
        } else {
            return background ??  palette.buttonColor
        }
    }
    private var foregroundColor: Color {
        tint ?? foreground ?? palette.foregroundColor
    }
    private var borderColor: Color {
        tint ?? border ?? palette.buttonColor
    }
    
    var body: some View {
        button
    }
    
    @ViewBuilder private var button: some View {
        if style == .outline {
            content
                .cornerRadius(size.cornerRadius)
                .border(borderColor, width: size.borderWidth, cornerRadius: size.cornerRadius)
        } else {
            content
                .background(backgroundColor)
                .cornerRadius(size.cornerRadius)
        }
    }
    
    private var content: some View {
        HStack(spacing: size.horizontalPadding) {
            if let icon, let iconWeight {
                Icon(name: icon, size: size.iconSize, maxSize: size.iconSize, weight: iconWeight)
                    .foregroundStyle(iconColor ?? tint ?? foregroundColor)
            }
            if let text {
                Text(text)
                    .fontStyle(kFontName, size: size.fontSize, weight: weight)
                    .foregroundStyle(foregroundColor)
            }
        }
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
    }
}

extension Chip {
    static var required: Chip {
        Chip(text: "Required", size: .xSmall, tint: .systemError)
    }

    static var optional: Chip {
        Chip(
            text: "Optional",
            size: .xSmall,
            foreground: .neutral,
            background: .neutral6
        )
    }

    static var requiredSuccess: Chip {
        Chip(text: "Required", icon: "f00c", iconWeight: .solid, size: .xSmall, tint: .accentGreen)
    }
    
    static var requiredConfirmation: Chip {
        requiredSuccess
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(ChipSize.allCases, id: \.self) { size in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("\(size.rawValue)")
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("\(size.rawValue)")
                    Chip(text: "Write workout", icon: "f044", size: size, style: .fill)
                    Chip(text: "Take photo", icon: "f03e", iconColor: .neutral3, size: size, style: .outline)
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
