//
//  FormatSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import SwiftUI

enum FormatFilterChip: String, CaseIterable {
    case all = "All"
    case teams = "Teams"
    case individual = "Individual"
    case stroke = "Stroke"
    case match = "Match"
    case points = "Points"

    func matches(_ template: GameTemplate) -> Bool {
        switch self {
        case .all: return true
        case .teams: return template.subject == .team
        case .individual: return template.subject == .participant
        case .stroke: return template.category == .stroke
        case .match: return template.category == .match
        case .points: return template.category == .points
        }
    }
}

struct FormatSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let currentTemplateID: String
    let onSelect: (GameTemplate) -> Void

    @State private var searchText: String = ""
    @State private var selectedChip: FormatFilterChip = .all
    @State private var pendingTemplateID: String

    init(currentTemplateID: String, onSelect: @escaping (GameTemplate) -> Void) {
        self.currentTemplateID = currentTemplateID
        self.onSelect = onSelect
        self._pendingTemplateID = State(initialValue: currentTemplateID)
    }

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private var filteredTemplates: [GameTemplate] {
        let byChip = FormatTemplateRegistry.allTemplates.filter { selectedChip.matches($0) }
        guard searchText.trimmingCharacters(in: .whitespaces).isPopulated else { return byChip }
        let q = searchText.lowercased()
        return byChip.filter {
            $0.name.lowercased().contains(q)
                || $0.description.lowercased().contains(q)
                || ($0.aliases?.contains { $0.lowercased().contains(q) } ?? false)
        }
    }

    private var pendingTemplate: GameTemplate? {
        FormatTemplateRegistry.allTemplates.first { $0.id == pendingTemplateID }
    }

    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Pick format")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }

            SearchBar(
                placeholder: "Search games...",
                initialValue: searchText,
                onDebounce: { text in
                    searchText = text
                }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FormatFilterChip.allCases, id: \.self) { chip in
                        let match = chip == selectedChip
                        Button(action: {
                            Haptics.fire(.light)
                            selectedChip = chip
                        }) {
                            Chip(
                                text: chip.rawValue,
                                foreground: match ? .white : palette.foregroundColor,
                                background: match ? Color.accentGreen : Color.neutral6
                            )
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var content: some View {
        VStack(spacing: 12) {
            ForEach(filteredTemplates) { template in
                FormatTemplateRow(
                    template: template,
                    isSelected: template.id == pendingTemplateID,
                    onTap: {
                        Haptics.fire(.light)
                        pendingTemplateID = template.id
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .padding(.bottom, 80)
    }

    private var footer: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Play",
            labelColor: .white,
            buttonColor: .accentGreen,
            theme: palette.theme,
            height: 52,
            isDisabled: .constant(pendingTemplate == nil),
            isLoading: .false,
            onTap: {
                guard let template = pendingTemplate else { return }
                onSelect(template)
                dismiss()
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Previews

#Preview("Format Selection") {
    Color.neutral6.sheet(isPresented: .constant(true)) {
        FormatSelectionView(
            currentTemplateID: FormatTemplateRegistry.strokePlayGross.id,
            onSelect: { _ in }
        )
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}
