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
    let onAssignmentChange: (RoundParticipant, String, Int) -> Void  // participant, columnID, slotIndex
    let onUnassign: (RoundParticipant, String) -> Void

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private var columns: [(id: String, name: String, color: Color?)] {
        switch mode {
        case .teams(let teams):
            return teams.map { (id: $0.id, name: $0.name, color: $0.teamColor.value) }
        case .teeGroups(let groups):
            return groups.sorted { $0.index < $1.index }.map { (id: $0.id, name: $0.name, color: nil) }
        }
    }

    private func participants(in columnID: String) -> [RoundParticipant] {
        switch mode {
        case .teams:
            return participants.filter { $0.teamID == columnID }
        case .teeGroups:
            return participants
                .filter { $0.groupID == columnID }
                .sorted { ($0.teeOrder ?? 0) < ($1.teeOrder ?? 0) }
        }
    }

    private func maxSlots(for columnID: String) -> Int {
        switch mode {
        case .teams:
            return max(participants(in: columnID).count + 1, 2)
        case .teeGroups:
            return max(participants(in: columnID).count + 1, 4)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick assign")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
                Button {
                    Haptics.fire(.light)
                    dismiss()
                } label: {
                    Icon(name: "f00d", size: 24, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 0) {
                playerList
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(columns, id: \.id) { col in
                            columnView(columnID: col.id, name: col.name, color: col.color)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private var playerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(participants, id: \.id) { p in
                        HStack(spacing: 8) {
                            PlayerAvatarView(
                                initials: p.name.initials,
                                size: 32,
                                fillColor: nil,
                                glassTint: Color.neutral6,
                                initialsColor: palette.foregroundColor
                            )
                            VStack(alignment: .leading, spacing: 0) {
                                Text(p.name.fullName)
                                    .fontStyle(kFontName, size: 14, weight: .medium)
                                    .foregroundStyle(palette.foregroundColor)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(Color.neutral6.opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 140)
    }

    private func columnView(columnID: String, name: String, color: Color?) -> some View {
        let assigned = participants(in: columnID)
        let slotCount = maxSlots(for: columnID)

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(name)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
            }

            ForEach(0..<slotCount, id: \.self) { slotIndex in
                slotCell(columnID: columnID, slotIndex: slotIndex, assigned: assigned)
            }
        }
        .padding(12)
        .frame(minWidth: 100)
        .background(Color.neutral6.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func slotCell(columnID: String, slotIndex: Int, assigned: [RoundParticipant]) -> some View {
        let participant = assigned[safe: slotIndex]

        Group {
            if let p = participant {
                Menu {
                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        onUnassign(p, columnID)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    slotFilledContent(p)
                }
            } else {
                Menu {
                    ForEach(participants, id: \.id) { p in
                        Button {
                            Haptics.fire(.light)
                            onAssignmentChange(p, columnID, slotIndex)
                        } label: {
                            Text(p.name.fullName)
                        }
                    }
                } label: {
                    slotEmptyContent
                }
            }
        }
    }

    private func slotFilledContent(_ p: RoundParticipant) -> some View {
        HStack(spacing: 6) {
            PlayerAvatarView(
                initials: p.name.initials,
                size: 28,
                fillColor: nil,
                glassTint: Color.neutral6,
                initialsColor: palette.foregroundColor
            )
            Text(p.name.fullName)
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(Color.accentGreen.opacity(colorScheme.translucent * 0.5))
        .cornerRadius(8)
    }

    private var slotEmptyContent: some View {
        Image(systemName: "plus.circle")
            .font(.system(size: 24))
            .foregroundStyle(Color.neutral)
            .frame(height: 32)
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
            onUnassign: { _, _ in }
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
            onUnassign: { _, _ in }
        )
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }
}
