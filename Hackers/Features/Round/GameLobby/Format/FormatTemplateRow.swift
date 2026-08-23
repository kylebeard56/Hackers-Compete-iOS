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
    let isSelectable: Bool
    let requirementChips: [String]
    let onTap: () -> Void

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }
    private var usesSelectedAccent: Bool { isSelected && isSelectable }

    private var titleColor: Color {
        if isSelectable { return palette.foregroundColor }
        return palette.foregroundColor.opacity(colorScheme.isLight ? 0.72 : 0.82)
    }

    private var descriptionColor: Color {
        if isSelectable { return Color.neutral }
        return Color.neutral
    }

    private var iconBackgroundColor: Color {
        if usesSelectedAccent { return Color.accentGreen }
        if isSelectable { return Color.accentGreen.opacity(colorScheme.translucent) }
        return palette.cardEmbeddedRowBackground
    }

    private var iconForegroundColor: Color {
        if usesSelectedAccent { return palette.backgroundColor }
        if isSelectable { return Color.accentGreen }
        return palette.foregroundColor.opacity(colorScheme.isLight ? 0.68 : 0.8)
    }

    private var rangeChipForeground: Color {
        if isSelectable { return Color.charcoal }
        return palette.foregroundColor.opacity(colorScheme.isLight ? 0.68 : 0.8)
    }

    private var rangeChipBackground: Color {
        if isSelectable { return Color.neutral6 }
        return palette.cardEmbeddedRowBackground
    }

    private var rowBorderColor: Color {
        if usesSelectedAccent { return Color.accentGreen }
        if isSelectable { return palette.borderColor }
        return palette.borderColor
    }

    private var requirementChipForeground: Color {
        palette.foregroundColor.opacity(colorScheme.isLight ? 0.68 : 0.8)
    }

    private var requirementChipBackground: Color {
        palette.cardEmbeddedRowBackground
    }

    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 48, height: 48)
                    Icon(name: template.icon, size: 20, weight: .regular)
                        .foregroundStyle(iconForegroundColor)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .fontStyle(kFontName, size: 20, weight: .semibold)
                            .foregroundStyle(titleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer(minLength: 10)

                        if let range = template.requirements.playersRangeDisplayString {
                            HStack(spacing: 4) {
                                Text(range)
                                Image(systemName: "figure.golf")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(rangeChipForeground)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(rangeChipBackground)
                            .cornerRadius(4)
                        }
                    }

                    Text(template.description)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(descriptionColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    if requirementChips.isPopulated {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(requirementChips, id: \.self) { chip in
                                    Chip(
                                        text: chip,
                                        size: .xSmall,
                                        foreground: requirementChipForeground,
                                        background: requirementChipBackground
                                    )
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(rowBorderColor, lineWidth: usesSelectedAccent ? 3 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }
}

// MARK: - Previews

#Preview("Selected") {
    FormatTemplateRow(
        template: FormatTemplateRegistry.stableford,
        isSelected: true,
        isSelectable: true,
        requirementChips: [],
        onTap: {}
    )
    .padding()
}

#Preview("Unselected") {
    FormatTemplateRow(
        template: FormatTemplateRegistry.bestBall,
        isSelected: false,
        isSelectable: true,
        requirementChips: [],
        onTap: {}
    )
    .padding()
}

#Preview("Disabled") {
    FormatTemplateRow(
        template: FormatTemplateRegistry.vegas,
        isSelected: false,
        isSelectable: false,
        requirementChips: ["Needs 4+ players", "Teams required"],
        onTap: {}
    )
    .padding()
}
