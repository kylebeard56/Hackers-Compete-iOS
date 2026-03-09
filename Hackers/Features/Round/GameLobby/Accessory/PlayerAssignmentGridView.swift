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

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private var columns: [(id: String, name: String, color: Color?)] {
        switch mode {
        case .teams(let teams):
            return teams.map { (id: $0.id, name: $0.name, color: $0.teamColor.value) }
        case .teeGroups(let groups):
            return groups.sorted { $0.index < $1.index }.map { (id: $0.id, name: $0.name, color: nil) }
        }
    }

    private func assignedColumnID(for participant: RoundParticipant) -> String? {
        switch mode {
        case .teams: return participant.teamID
        case .teeGroups: return participant.groupID
        }
    }

    private func slotIndex(for participant: RoundParticipant, in columnID: String) -> Int {
        switch mode {
        case .teams:
            return participants.filter { $0.teamID == columnID }.count
        case .teeGroups:
            return participants.filter { $0.groupID == columnID }.count
        }
    }

    // MARK: - Layout constants

    private let rowHeight: CGFloat = 44
    private let playerColumnWidth: CGFloat = 150
    private let toggleColumnWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            VStack(spacing: 0) {
                // Space for header
                Color.clear.frame(height: 56)

                Divider().opacity(0.15)

                // Spreadsheet table
                HStack(alignment: .top, spacing: 0) {
                    // Left pinned: Players column
                    leftPlayerColumn

                    // Right: horizontally scrollable group/team columns + add button
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(columns, id: \.id) { col in
                                columnView(col)
                            }

                            // "+" add column
                            addColumn
                        }
                    }
                }

                // Bottom padding for floating confirm button
                Color.clear.frame(height: 100)
            }

            // Floating ZStack header
            header
                .background(.ultraThinMaterial)

            // Floating confirm button
            VStack {
                Spacer()
                confirmButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            NavButton(
                style: .glass,
                icon: "f00d",
                size: 16,
                color: palette.foregroundColor,
                onTap: { dismiss() }
            )
            .padding(.leading, 12)

            Spacer(minLength: 0)

            Text("Advanced assignment")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)

            Spacer(minLength: 0)

            NavButton(
                style: .glass,
                icon: "f00c",
                size: 16,
                color: .accentGreen,
                onTap: { dismiss() }
            )
            .padding(.trailing, 12)
        }
        .frame(height: 56)
    }

    // MARK: - Confirm button

    private var confirmButton: some View {
        GlassButton(
            title: "Done",
            icon: "f00c",
            labelColor: .white,
            tintColor: .accentGreen,
            height: 52,
            isDisabled: .false,
            isLoading: .false,
            onTap: { dismiss() }
        )
    }

    // MARK: - Left player column

    private var leftPlayerColumn: some View {
        VStack(spacing: 0) {
            // "Players" header
            Text("Players")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .frame(width: playerColumnWidth, height: rowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .background(Color.neutral6.opacity(0.3))
                .overlay(Divider().opacity(0.12), alignment: .bottom)

            ForEach(participants, id: \.id) { participant in
                HStack(spacing: 8) {
                    Text(participant.name.initials)
                        .fontStyle(kFontName, size: 12, weight: .bold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: 28, height: 28)
                        .background(Color.neutral5.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(participant.name.fullName)
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .frame(width: playerColumnWidth, height: rowHeight)
                .padding(.horizontal, 12)
                .overlay(Divider().opacity(0.12), alignment: .bottom)
            }
        }
    }

    // MARK: - Column view

    private func columnView(_ col: (id: String, name: String, color: Color?)) -> some View {
        VStack(spacing: 0) {
            // Column header
            HStack(spacing: 4) {
                if let color = col.color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(col.name)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
            }
            .frame(width: toggleColumnWidth, height: rowHeight)
            .padding(.horizontal, 4)
            .background(Color.neutral6.opacity(0.3))
            .overlay(Divider().opacity(0.12), alignment: .bottom)
            .overlay(Divider().opacity(0.12), alignment: .leading)

            // Toggle cells — one per player
            ForEach(participants, id: \.id) { participant in
                let isAssigned = assignedColumnID(for: participant) == col.id
                toggleCell(participant: participant, col: col, isAssigned: isAssigned)
                    .frame(width: toggleColumnWidth, height: rowHeight)
                    .overlay(Divider().opacity(0.12), alignment: .bottom)
                    .overlay(Divider().opacity(0.12), alignment: .leading)
            }
        }
    }

    // MARK: - Add column

    private var addColumn: some View {
        VStack(spacing: 0) {
            // Header: "+" button
            Button {
                Haptics.fire(.light)
                onAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: toggleColumnWidth, height: rowHeight)
            }
            .background(Color.neutral6.opacity(0.3))
            .overlay(Divider().opacity(0.12), alignment: .bottom)
            .overlay(Divider().opacity(0.12), alignment: .leading)

            // Empty cells to match player rows
            ForEach(participants, id: \.id) { _ in
                Color.clear
                    .frame(width: toggleColumnWidth, height: rowHeight)
                    .overlay(Divider().opacity(0.12), alignment: .bottom)
                    .overlay(Divider().opacity(0.12), alignment: .leading)
            }
        }
    }

    // MARK: - Toggle cell

    private func toggleCell(
        participant: RoundParticipant,
        col: (id: String, name: String, color: Color?),
        isAssigned: Bool
    ) -> some View {
        Button {
            Haptics.fire(.light)
            if isAssigned {
                onUnassign(participant, col.id)
            } else {
                let index = slotIndex(for: participant, in: col.id)
                onAssignmentChange(participant, col.id, index)
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(
                        isAssigned ? Color.accentGreen : Color.neutral3,
                        lineWidth: isAssigned ? 2 : 1.5
                    )
                    .frame(width: 26, height: 26)

                if isAssigned {
                    Circle()
                        .fill(Color.accentGreen.opacity(0.15))
                        .frame(width: 26, height: 26)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentGreen)
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
