//
//  PlayerAssignmentGridView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import SwiftUI

enum PlayerAssignmentMode {
    case teams([RoundTeam])
    case teeGroups([TeeTimeGroup])
    
    var label: String {
        switch self {
        case .teams(let _):
            return "team"
        case .teeGroups(let _):
            return "group"
        }
    }
}

struct PlayerAssignmentGridView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let mode: PlayerAssignmentMode
    let participants: [RoundParticipant]
    let snapshot: RoundSnapshot
    let onAssignmentChange: (RoundParticipant, String, Int) -> Void
    let onUnassign: (RoundParticipant, String) -> Void
    let onAdd: () -> Void

    /// Local overrides: participantID -> (columnID, slotIndex). nil columnID = unassigned.
    @State private var localOverrides: [String: (columnID: String?, slotIndex: Int)] = [:]
    @State private var isRotated = false

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private var columns: [(id: String, name: String, color: Color?)] {
        switch mode {
        case .teams(let teams):
            return teams.map { (id: $0.id, name: $0.name, color: $0.teamColor.value) }
        case .teeGroups(let groups):
            return groups.sorted { $0.index < $1.index }.map { (id: $0.id, name: $0.name, color: nil) }
        }
    }

    private func resolvedAssignment(for participant: RoundParticipant) -> (columnID: String?, slotIndex: Int) {
        if let override = localOverrides[participant.id] {
            return override
        }
        switch mode {
        case .teams:
            return (participant.teamID, 0)
        case .teeGroups:
            return (participant.groupID, participant.teeOrder ?? 0)
        }
    }

    private func slotIndexForNewAssignment(to columnID: String, excluding participantID: String) -> Int {
        participants.filter { p in
            p.id != participantID && resolvedAssignment(for: p).columnID == columnID
        }.count
    }

    /// Display name: full name if ≤14 chars, else "FirstInitial. LastName" to avoid clipping.
    private func displayName(for name: Name) -> String {
        let full = name.fullName
        if full.count <= 14 { return full }
        if name.familyName.isPopulated {
            let initial = name.givenName.prefix(1)
            return "\(initial). \(name.familyName)"
        }
        return String(full.prefix(14))
    }

    // MARK: - Layout constants

    private let rowHeight: CGFloat = 44
    private let toggleColumnMinWidth: CGFloat = 44

    var body: some View {
        GeometryReader { geom in
            let layoutSize = isRotated
                ? CGSize(width: max(1, geom.size.height), height: max(1, geom.size.width))
                : CGSize(width: max(1, geom.size.width), height: max(1, geom.size.height))

            StickyScrollView(
                header: { header },
                content: { content },
                footer: isRotated ? nil : { footer },
                theme: palette.theme,
                showHeaderDivider: false,
                onScroll: { _ in }
            )
            .rotationEffect(.degrees(isRotated ? 90 : 0))
            .frame(width: layoutSize.width, height: layoutSize.height)
            .position(x: geom.size.width / 2, y: geom.size.height / 2)
            .animation(.easeInOut(duration: 0.25), value: isRotated)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            NavButton() { dismiss() }

            if isRotated {
                PrimaryButton(
                    appearance: .fill,
                    title: "Clear all",
                    labelColor: .white,
                    buttonColor: .systemError,
                    theme: palette.theme,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: clearAll
                )
            }

            Spacer(minLength: 0)

            Text("Assign players")
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)

            Spacer(minLength: 0)

            NavButton(
                icon: isRotated ? "f066" : "f065",
                weight: .regular,
                theme: palette.theme,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRotated.toggle()
                    }
                }
            )
            
            if isRotated {
                PrimaryButton(
                    appearance: .fill,
                    title: "Done",
                    labelColor: .white,
                    buttonColor: palette.foregroundColor,
                    theme: palette.theme,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: applyAndDismiss
                )
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                leftPlayerColumn
                    .fixedSize(horizontal: true, vertical: false)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(columns, id: \.id) { col in
                            columnView(col)
                        }
                        addColumn
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            PrimaryButton(
                appearance: .fill,
                title: "Clear all",
                labelColor: .white,
                buttonColor: .systemError,
                theme: palette.theme,
                fillWidth: false,
                isDisabled: .false,
                isLoading: .false,
                onTap: clearAll
            )

            PrimaryButton(
                appearance: .fill,
                title: "Done",
                labelColor: .white,
                buttonColor: palette.foregroundColor,
                theme: palette.theme,
                isDisabled: .false,
                isLoading: .false,
                onTap: applyAndDismiss
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func clearAll() {
        Haptics.fire(.light)
        for p in participants {
            localOverrides[p.id] = (nil, 0)
        }
    }

    private func applyAndDismiss() {
        Haptics.fire(.light)
        switch mode {
        case .teams:
            for participant in participants {
                let resolved = resolvedAssignment(for: participant)
                let initial = participant.teamID
                if let colID = resolved.columnID {
                    if initial != colID {
                        onAssignmentChange(participant, colID, 0)
                    }
                } else if initial != nil {
                    onUnassign(participant, initial!)
                }
            }
        case .teeGroups:
            var columnOrder: [String: [(participant: RoundParticipant, storedSlot: Int)]] = [:]
            for participant in participants {
                let resolved = resolvedAssignment(for: participant)
                if let colID = resolved.columnID {
                    columnOrder[colID, default: []].append((participant, resolved.slotIndex))
                }
            }
            for (colID, list) in columnOrder {
                for (slotIndex, item) in list.sorted(by: { $0.storedSlot < $1.storedSlot }).enumerated() {
                    let p = item.participant
                    let initial = (p.groupID, p.teeOrder ?? 0)
                    if initial.0 != colID || initial.1 != slotIndex {
                        onAssignmentChange(p, colID, slotIndex)
                    }
                }
            }
            for participant in participants {
                let resolved = resolvedAssignment(for: participant)
                if resolved.columnID == nil, let initial = participant.groupID {
                    onUnassign(participant, initial)
                }
            }
        }
        dismiss()
    }

    // MARK: - Left player column

    private var leftPlayerColumn: some View {
        VStack(spacing: 0) {
            Text("Players (\(participants.count))")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .frame(height: rowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(participants, id: \.id) { participant in
                HStack(spacing: 8) {
                    Text(participant.name.initials)
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: 28, height: 28)
                        .background(Color.neutral5.opacity(0.5))
                        .clipShape(.circle)

                    Text(displayName(for: participant.name))
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .frame(height: rowHeight)
            }
        }
    }

    // MARK: - Column view

    private func columnView(_ col: (id: String, name: String, color: Color?)) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if let color = col.color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(col.name)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(height: rowHeight)
            .frame(minWidth: toggleColumnMinWidth)
            .padding(.horizontal, 4)

            ForEach(participants, id: \.id) { participant in
                let resolved = resolvedAssignment(for: participant)
                let isAssigned = resolved.columnID == col.id
                toggleCell(participant: participant, col: col, isAssigned: isAssigned)
                    .frame(height: rowHeight)
                    .frame(minWidth: toggleColumnMinWidth)
            }
        }
    }

    // MARK: - Add column

    private var addColumn: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.fire(.light)
                onAdd()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add new \(mode.label)")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                }
                .foregroundStyle(palette.foregroundColor)
                //.frame(height: rowHeight)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.neutral6)
            .clipShape(.capsule)
            .frame(height: rowHeight)
            //.background(Color.neutral6.opacity(0.3))

            ForEach(participants, id: \.id) { _ in
                Color.clear
                    .frame(height: rowHeight)
            }
        }
    }

    // MARK: - Toggle cell

    private func toggleCell(
        participant: RoundParticipant,
        col: (id: String, name: String, color: Color?),
        isAssigned: Bool
    ) -> some View {
        let accentColor = col.color ?? Color.accentGreen
        return Button {
            Haptics.fire(.light)
            if isAssigned {
                localOverrides[participant.id] = (nil, 0)
            } else {
                let slotIndex = slotIndexForNewAssignment(to: col.id, excluding: participant.id)
                localOverrides[participant.id] = (col.id, slotIndex)
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(
                        isAssigned ? accentColor : Color.neutral3,
                        lineWidth: isAssigned ? 2 : 1.5
                    )
                    .frame(width: 26, height: 26)

                if isAssigned {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 26, height: 26)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Teams mode") {
    Color.neutral6.sheet(isPresented: .constant(true)) {
        PlayerAssignmentGridView(
            mode: .teams(MockLobbyMatchups.teams),
            participants: MockLobbyMatchups.participants,
            snapshot: MockLobbyMatchups.snapshot,
            onAssignmentChange: { _, _, _ in },
            onUnassign: { _, _ in },
            onAdd: { }
        )
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }
}

#Preview("Tee groups mode") {
    Color.neutral6.sheet(isPresented: .constant(true)) {
        PlayerAssignmentGridView(
            mode: .teeGroups(MockLobbyMatchups.teeGroups),
            participants: MockLobbyMatchups.participants,
            snapshot: MockLobbyMatchups.snapshot,
            onAssignmentChange: { _, _, _ in },
            onUnassign: { _, _ in },
            onAdd: { }
        )
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }
}
