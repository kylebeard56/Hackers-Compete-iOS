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

struct FormatTemplateAvailability: Equatable, Identifiable {
    let template: GameTemplate
    let unmetRequirements: [String]

    var id: String { template.id }
    var isSelectable: Bool { unmetRequirements.isEmpty }
}

struct FormatSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let currentTemplateID: String
    let snapshot: RoundSnapshot
    let onSelect: (GameTemplate) -> Void

    @State private var searchText: String = ""
    @State private var selectedChip: FormatFilterChip = .all
    @State private var pendingTemplateID: String

    init(
        currentTemplateID: String,
        snapshot: RoundSnapshot = .init(),
        onSelect: @escaping (GameTemplate) -> Void
    ) {
        self.currentTemplateID = currentTemplateID
        self.snapshot = snapshot
        self.onSelect = onSelect
        let supportedTemplates = FormatTemplateRegistry.allTemplates
        let initialTemplateID = supportedTemplates.first(where: { $0.id == currentTemplateID })?.id
            ?? supportedTemplates.first?.id
            ?? FormatTemplateRegistry.strokePlay.id
        self._pendingTemplateID = State(initialValue: initialTemplateID)
    }

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private var templateAvailabilities: [FormatTemplateAvailability] {
        FormatTemplateRegistry.allTemplates.map { Self.availability(for: $0, in: snapshot) }
    }

    private var filteredAvailabilities: [FormatTemplateAvailability] {
        let byChip = templateAvailabilities.filter { selectedChip.matches($0.template) }
        guard searchText.trimmingCharacters(in: .whitespaces).isPopulated else { return byChip }
        let q = searchText.lowercased()
        return byChip.filter {
            $0.template.name.lowercased().contains(q)
                || $0.template.description.lowercased().contains(q)
                || ($0.template.aliases?.contains { $0.lowercased().contains(q) } ?? false)
                || $0.unmetRequirements.contains { $0.lowercased().contains(q) }
        }
    }

    private var pendingAvailability: FormatTemplateAvailability? {
        templateAvailabilities.first { $0.id == pendingTemplateID }
    }

    private var pendingTemplate: GameTemplate? {
        pendingAvailability?.template
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

//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 8) {
//                    ForEach(FormatFilterChip.allCases, id: \.self) { chip in
//                        let match = chip == selectedChip
//                        Button(action: {
//                            Haptics.fire(.light)
//                            selectedChip = chip
//                        }) {
//                            Chip(
//                                text: chip.rawValue,
//                                foreground: match ? .white : palette.foregroundColor,
//                                background: match ? Color.accentGreen : Color.neutral6
//                            )
//                        }
//                    }
//                    Spacer(minLength: 0)
//                }
//            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var content: some View {
        VStack(spacing: 12) {
            ForEach(filteredAvailabilities) { availability in
                FormatTemplateRow(
                    template: availability.template,
                    isSelected: availability.id == pendingTemplateID,
                    isSelectable: availability.isSelectable,
                    requirementChips: availability.unmetRequirements,
                    onTap: {
                        guard availability.isSelectable else { return }
                        pendingTemplateID = availability.id
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
            isDisabled: .constant(pendingAvailability?.isSelectable != true),
            isLoading: .false,
            onTap: {
                guard let template = pendingTemplate, pendingAvailability?.isSelectable == true else { return }
                onSelect(template)
                dismiss()
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

extension FormatSelectionView {
    static func availability(for template: GameTemplate, in snapshot: RoundSnapshot) -> FormatTemplateAvailability {
        var unmetRequirements: [String] = []
        let playerCount = snapshot.participants.count
        let requirements = template.requirements

        if let minPlayers = requirements.minPlayers, playerCount < minPlayers {
            unmetRequirements.append("Needs \(minPlayers)+ players")
        } else if let maxPlayers = requirements.maxPlayers, playerCount > maxPlayers {
            unmetRequirements.append("Max \(maxPlayers) players")
        }

        if requirements.requiresTeams && !snapshot.requiresTeams {
            unmetRequirements.append("Teams required")
        }

        if requirements.requiresTeams,
           snapshot.requiresTeams,
           let teamSizeRule = requirements.teamSize,
           !teamAssignmentsSatisfy(teamSizeRule, in: snapshot) {
            if let label = teamSizeRequirementText(for: teamSizeRule) {
                unmetRequirements.append(label)
            }
        }

        if requirements.requiresMatchups && !matchupsAreSupported(for: template, in: snapshot) {
            unmetRequirements.append("Matchups required")
        }

        return FormatTemplateAvailability(
            template: template,
            unmetRequirements: deduped(unmetRequirements)
        )
    }

    static func matchupsAreSupported(for template: GameTemplate, in snapshot: RoundSnapshot) -> Bool {
        guard template.requirements.requiresMatchups else { return true }
        let competitorCount: Int
        if template.requirements.requiresTeams || template.subject == .team {
            guard snapshot.requiresTeams else { return false }
            competitorCount = teamMembershipCounts(in: snapshot).count
        } else {
            competitorCount = snapshot.participants.count
        }
        return competitorCount >= 2 && competitorCount.isMultiple(of: 2)
    }

    static func teamAssignmentsSatisfy(_ rule: TeamSizeRule, in snapshot: RoundSnapshot) -> Bool {
        let counts = teamMembershipCounts(in: snapshot)
        guard counts.isPopulated else { return false }
        return counts.values.allSatisfy { count in
            switch rule {
            case .exact(let expected):
                return count == expected
            case .range(let min, let max):
                return count >= min && count <= max
            case .any:
                return count > 0
            }
        }
    }

    static func teamMembershipCounts(in snapshot: RoundSnapshot) -> [String: Int] {
        let assignedTeamIDs: [String] = snapshot.participants.compactMap { participant in
            guard let teamID = participant.teamID, teamID.isPopulated else { return nil }
            return teamID
        }
        let counts = Dictionary(grouping: assignedTeamIDs, by: { $0 }).mapValues(\.count)

        let validTeamIDs = Set(snapshot.teams.map(\.id))
        return counts.filter { validTeamIDs.contains($0.key) }
    }

    static func teamSizeRequirementText(for rule: TeamSizeRule) -> String? {
        switch rule {
        case .exact(let count):
            return "\(count) per team"
        case .range(let min, let max):
            return "\(min)-\(max) per team"
        case .any:
            return nil
        }
    }

    static func deduped(_ requirements: [String]) -> [String] {
        var seen: Set<String> = []
        return requirements.filter { seen.insert($0).inserted }
    }
}

// MARK: - Previews

#Preview("Format Selection") {
    Color.neutral6.sheet(isPresented: .constant(true)) {
        FormatSelectionView(
            currentTemplateID: FormatTemplateRegistry.strokePlayGross.id,
            snapshot: MockLobbyDuo.snapshot,
            onSelect: { _ in }
        )
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}
