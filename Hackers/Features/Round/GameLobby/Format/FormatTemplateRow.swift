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
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentGreen)
                            .frame(width: 48, height: 48)
                        Icon(name: template.icon, size: 20, weight: .regular)
                            .foregroundStyle(palette.backgroundColor)
                    } else {
                        Circle()
                            .fill(Color.accentGreen.opacity(colorScheme.translucent))
                            .frame(width: 48, height: 48)
                        Icon(name: template.icon, size: 20, weight: .regular)
                            .foregroundStyle(Color.accentGreen)
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .fontStyle(kFontName, size: 20, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
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
                            .foregroundStyle(Color.charcoal)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.neutral6)
                            .cornerRadius(4)
                        }
                    }

                    Text(template.description)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
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
                            .stroke(isSelected ? Color.accentGreen : palette.borderColor, lineWidth: isSelected ? 3 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Selected") {
    FormatTemplateRow(
        template: FormatTemplateRegistry.strokePlay,
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
