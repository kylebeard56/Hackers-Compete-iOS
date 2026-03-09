//
//  FormatTemplateRow.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import SwiftUI

struct FormatTemplateRow: View {
    @Environment(\.colorScheme) var colorScheme

    let template: GameTemplate
    let isSelected: Bool
    let onTap: () -> Void

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Icon(name: template.icon, size: 20, weight: .regular)
                    .foregroundStyle(Color.accentGreen)
                    .frame(width: 40, height: 40)
                    .glassCardEffect(shape: .circle, interactive: false, tint: Color.accentGreen.opacity(colorScheme.translucent))

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text(template.description)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if let range = template.requirements.playersRangeDisplayString {
                            Chip(text: range, size: .xSmall, style: .outline)
                        }
                        if template.requirements.requiresTeams {
                            Chip(text: "Teams", size: .xSmall, style: .outline)
                        }
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Icon(name: "checkmark.circle.fill", size: 24, weight: .solid)
                        .foregroundStyle(Color.accentGreen)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentGreen.opacity(colorScheme.translucent * 0.5) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentGreen : palette.borderColor, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Selected") {
    FormatTemplateRow(
        template: FormatTemplateRegistry.strokePlayGross,
        isSelected: true,
        onTap: {}
    )
    .padding()
}

#Preview("Unselected") {
    FormatTemplateRow(
        template: FormatTemplateRegistry.bestBall,
        isSelected: false,
        onTap: {}
    )
    .padding()
}
