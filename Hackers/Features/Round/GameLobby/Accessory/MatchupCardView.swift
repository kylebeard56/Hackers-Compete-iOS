//
//  MatchupCardView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import SwiftUI

struct MatchupCardView: View {
    @Environment(\.colorScheme) var colorScheme

    let matchup: TeamMatchup
    let matchIndex: Int
    let snapshot: RoundSnapshot
    var participantMode: Bool = false
    let availableTeamsForSlot0: [RoundTeam]
    let availableTeamsForSlot1: [RoundTeam]
    let availableParticipantsForSlot0: [RoundParticipant]
    let availableParticipantsForSlot1: [RoundParticipant]
    let onAssignTeam: (Int, String?) -> Void
    let onAssignParticipant: (Int, String?) -> Void
    var onSwapTeams: (() -> Void)? = nil
    var onSwapParticipants: (() -> Void)? = nil

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private func slot0ID() -> String? {
        if participantMode {
            return matchup.participantIDs?.count ?? 0 > 0 ? matchup.participantIDs?[0] : nil
        }
        return matchup.teamIDs.count > 0 ? matchup.teamIDs[0] : nil
    }

    private func slot1ID() -> String? {
        if participantMode {
            return matchup.participantIDs?.count ?? 0 > 1 ? matchup.participantIDs?[1] : nil
        }
        return matchup.teamIDs.count > 1 ? matchup.teamIDs[1] : nil
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Match \(matchIndex + 1)")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                slotView(slotID: slot0ID(), slotIndex: 0)
                vsDivider
                slotView(slotID: slot1ID(), slotIndex: 1)
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    private var vsDivider: some View {
        Text("VS")
            .fontStyle(kFontName, size: 12, weight: .bold)
            .foregroundStyle(Color.neutral)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func slotView(slotID: String?, slotIndex: Int) -> some View {
        if participantMode {
            participantSlot(participantID: slotID, slotIndex: slotIndex, availableParticipants: slotIndex == 0 ? availableParticipantsForSlot0 : availableParticipantsForSlot1)
        } else {
            teamSlot(teamID: slotID, slotIndex: slotIndex, availableTeams: slotIndex == 0 ? availableTeamsForSlot0 : availableTeamsForSlot1)
        }
    }

    @ViewBuilder
    private func teamSlot(teamID: String?, slotIndex: Int, availableTeams: [RoundTeam]) -> some View {
        let team = teamID.flatMap { id in snapshot.teams.first(where: { $0.id == id }) }
        let isEmpty = teamID == nil || team == nil
        let canSwap = onSwapTeams != nil && matchup.teamIDs.count == 2

        Menu {
            ForEach(availableTeams, id: \.id) { t in
                Button {
                    Haptics.fire(.light)
                    onAssignTeam(slotIndex, t.id)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(t.swatchColor)
                            .frame(width: 8, height: 8)
                        Text(t.name)
                    }
                }
            }
            if !isEmpty {
                Divider()
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    onAssignTeam(slotIndex, nil)
                } label: {
                    Label("Clear slot", systemImage: "trash")
                }
            }
            if canSwap {
                Divider()
                Button {
                    Haptics.fire(.light)
                    onSwapTeams?()
                } label: {
                    Label("Swap teams", systemImage: "arrow.left.arrow.right")
                }
            }
        } label: {
            slotLabelContent(team: team, participant: nil, isEmpty: isEmpty)
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func participantSlot(participantID: String?, slotIndex: Int, availableParticipants: [RoundParticipant]) -> some View {
        let participant = participantID.flatMap { id in snapshot.participants.first(where: { $0.id == id }) }
        let isEmpty = participantID == nil || participant == nil
        let canSwap = onSwapParticipants != nil && (matchup.participantIDs?.count ?? 0) == 2

        Menu {
            ForEach(availableParticipants, id: \.id) { p in
                Button {
                    Haptics.fire(.light)
                    onAssignParticipant(slotIndex, p.id)
                } label: {
                    Text(p.name.fullName)
                }
            }
            if !isEmpty {
                Divider()
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    onAssignParticipant(slotIndex, nil)
                } label: {
                    Label("Clear slot", systemImage: "trash")
                }
            }
            if canSwap {
                Divider()
                Button {
                    Haptics.fire(.light)
                    onSwapParticipants?()
                } label: {
                    Label("Swap players", systemImage: "arrow.left.arrow.right")
                }
            }
        } label: {
            slotLabelContent(team: nil, participant: participant, isEmpty: isEmpty)
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func slotLabelContent(team: RoundTeam?, participant: RoundParticipant?, isEmpty: Bool) -> some View {
        VStack(spacing: 4) {
            if let team {
                HStack(spacing: 6) {
                    Circle()
                        .fill(team.swatchColor)
                        .frame(width: 8, height: 8)
                    Text(team.name)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = compactTeamSubtitle(for: team) {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let participant {
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Tap to assign")
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(Color.neutral)
                Text("(Empty)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEmpty ? palette.borderColor : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isEmpty ? Color.neutral6.opacity(0.3) : Color.clear)
        )
    }

    private func compactTeamSubtitle(for team: RoundTeam) -> String? {
        let participants = snapshot.participants.filter { $0.teamID == team.id }
        let names = participants
            .map { p in
                let given = p.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if given.isPopulated { return given }
                let family = p.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                return family.isPopulated ? family : p.name.fullName
            }
            .filter(\.isPopulated)

        guard names.isPopulated else { return nil }
        let visible = names.prefix(3)
        let overflow = names.count - visible.count
        if overflow > 0 {
            return visible.joined(separator: ", ") + ", +\(overflow) more"
        }
        return visible.joined(separator: ", ")
    }
}

// MARK: - Previews

#Preview("Matchup with teams") {
    let snapshot = MockLobbyMatchups.snapshot
    let matchup = TeamMatchup(id: "m1", teamIDs: ["team_red", "team_blue"])
    return MatchupCardView(
        matchup: matchup,
        matchIndex: 0,
        snapshot: snapshot,
        availableTeamsForSlot0: [],
        availableTeamsForSlot1: [],
        availableParticipantsForSlot0: [],
        availableParticipantsForSlot1: [],
        onAssignTeam: { _, _ in },
        onAssignParticipant: { _, _ in }
    )
    .padding()
}

#Preview("Matchup with empty slot") {
    let snapshot = MockLobbyMatchups.snapshot
    let matchup = TeamMatchup(id: "m2", teamIDs: ["team_green"])
    return MatchupCardView(
        matchup: matchup,
        matchIndex: 1,
        snapshot: snapshot,
        availableTeamsForSlot0: snapshot.teams,
        availableTeamsForSlot1: [],
        availableParticipantsForSlot0: [],
        availableParticipantsForSlot1: [],
        onAssignTeam: { _, _ in },
        onAssignParticipant: { _, _ in }
    )
    .padding()
}

#Preview("Matchup fully empty") {
    let snapshot = MockLobbyMatchups.snapshot
    let matchup = TeamMatchup(id: "m3", teamIDs: [])
    return MatchupCardView(
        matchup: matchup,
        matchIndex: 2,
        snapshot: snapshot,
        availableTeamsForSlot0: snapshot.teams,
        availableTeamsForSlot1: snapshot.teams,
        availableParticipantsForSlot0: [],
        availableParticipantsForSlot1: [],
        onAssignTeam: { _, _ in },
        onAssignParticipant: { _, _ in }
    )
    .padding()
}
