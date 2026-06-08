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
    var slotMode: MatchupMode = .team
    let availableTeamsForSlot0: [RoundTeam]
    let availableTeamsForSlot1: [RoundTeam]
    let availableParticipantsForSlot0: [RoundParticipant]
    let availableParticipantsForSlot1: [RoundParticipant]
    let availableScoreOwnersForSlot0: [RoundScoringGroup]
    let availableScoreOwnersForSlot1: [RoundScoringGroup]
    let onAssignTeam: (Int, String?) -> Void
    let onAssignParticipant: (Int, String?) -> Void
    let onAssignScoreOwner: (Int, String?) -> Void
    var onSwapTeams: (() -> Void)? = nil
    var onSwapParticipants: (() -> Void)? = nil
    var onSwapScoreOwners: (() -> Void)? = nil

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    private var matchupParticipants: [RoundParticipant] {
        switch slotMode {
        case .team:
            let teamIDs = Set(matchup.teamIDs)
            return snapshot.participants.filter { participant in
                guard let teamID = participant.teamID else { return false }
                return teamIDs.contains(teamID)
            }
        case .individual:
            let ids = Set(matchup.participantIDs ?? [])
            return snapshot.participants.filter { ids.contains($0.id) }
        case .partnership, .teeGroup, .scoreOwner:
            let ownerIDs = Set(matchup.scoreOwnerIDs ?? [])
            let participantIDs = Set(snapshot.scoringGroups.filter { ownerIDs.contains($0.id) }.flatMap(\.memberIDs))
            return snapshot.participants.filter { participantIDs.contains($0.id) }
        }
    }

    private var showsSubstituteScoringFootnote: Bool {
        !snapshot.configuration.substitutesScore && matchupParticipants.contains(where: \.isSubstitute)
    }

    private func slotID(_ index: Int) -> String? {
        switch slotMode {
        case .team:
            return matchup.teamIDs.count > index ? matchup.teamIDs[index] : nil
        case .individual:
            let ids = matchup.participantIDs ?? []
            return ids.count > index ? ids[index] : nil
        case .partnership, .teeGroup, .scoreOwner:
            let ids = matchup.scoreOwnerIDs ?? []
            return ids.count > index ? ids[index] : nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Match \(matchIndex + 1)")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                slotView(slotID: slotID(0), slotIndex: 0)
                vsDivider
                slotView(slotID: slotID(1), slotIndex: 1)
            }

            if showsSubstituteScoringFootnote {
                Text("* Substitute players do not count towards scoring")
                    .fontStyle(kFontName, size: 11, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
    }

    private var vsDivider: some View {
        Text("VS")
            .fontStyle(kFontName, size: 12, weight: .bold)
            .foregroundStyle(Color.neutral)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func slotView(slotID: String?, slotIndex: Int) -> some View {
        switch slotMode {
        case .team:
            teamSlot(
                teamID: slotID,
                slotIndex: slotIndex,
                availableTeams: slotIndex == 0 ? availableTeamsForSlot0 : availableTeamsForSlot1
            )
        case .individual:
            participantSlot(
                participantID: slotID,
                slotIndex: slotIndex,
                availableParticipants: slotIndex == 0 ? availableParticipantsForSlot0 : availableParticipantsForSlot1
            )
        case .partnership, .teeGroup, .scoreOwner:
            scoreOwnerSlot(
                scoreOwnerID: slotID,
                slotIndex: slotIndex,
                availableScoreOwners: slotIndex == 0 ? availableScoreOwnersForSlot0 : availableScoreOwnersForSlot1
            )
        }
    }

    @ViewBuilder
    private func teamSlot(teamID: String?, slotIndex: Int, availableTeams: [RoundTeam]) -> some View {
        let team = teamID.flatMap { id in snapshot.teams.first(where: { $0.id == id }) }
        let isEmpty = teamID == nil || team == nil
        let canSwap = onSwapTeams != nil && matchup.teamIDs.count == 2

        Menu {
            ForEach(availableTeams, id: \.id) { team in
                Button {
                    Haptics.fire(.light)
                    onAssignTeam(slotIndex, team.id)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(team.displaySwatchColor ?? Color.neutral6)
                            .frame(width: 8, height: 8)
                        Text(team.name)
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
            slotLabelContent(
                title: team?.name ?? "Tap to assign",
                subtitle: team.flatMap(compactTeamSubtitle(for:)) ?? (isEmpty ? "(Empty)" : nil),
                swatchColor: team?.displaySwatchColor,
                isEmpty: isEmpty
            )
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func participantSlot(participantID: String?, slotIndex: Int, availableParticipants: [RoundParticipant]) -> some View {
        let participant = participantID.flatMap { id in snapshot.participants.first(where: { $0.id == id }) }
        let isEmpty = participantID == nil || participant == nil
        let canSwap = onSwapParticipants != nil && (matchup.participantIDs?.count ?? 0) == 2

        Menu {
            ForEach(availableParticipants, id: \.id) { participant in
                Button {
                    Haptics.fire(.light)
                    onAssignParticipant(slotIndex, participant.id)
                } label: {
                    Text(markedFullName(for: participant))
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
            slotLabelContent(
                title: participant.map(markedFullName(for:)) ?? "Tap to assign",
                subtitle: isEmpty ? "(Empty)" : nil,
                participantNamesWithMarkers: participant.map { [($0.name, $0.isSubstitute)] },
                swatchColor: nil,
                isEmpty: isEmpty
            )
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func scoreOwnerSlot(scoreOwnerID: String?, slotIndex: Int, availableScoreOwners: [RoundScoringGroup]) -> some View {
        let scoreOwner = snapshot.scoringGroup(id: scoreOwnerID)
        let isEmpty = scoreOwnerID == nil || scoreOwner == nil
        let canSwap = onSwapScoreOwners != nil && (matchup.scoreOwnerIDs?.count ?? 0) == 2

        Menu {
            ForEach(availableScoreOwners, id: \.id) { owner in
                Button {
                    Haptics.fire(.light)
                    onAssignScoreOwner(slotIndex, owner.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scoreOwnerTitle(for: owner))
                        if let subtitle = scoreOwnerSubtitle(for: owner) {
                            Text(subtitle)
                        }
                    }
                }
            }

            if !isEmpty {
                Divider()
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    onAssignScoreOwner(slotIndex, nil)
                } label: {
                    Label("Clear slot", systemImage: "trash")
                }
            }

            if canSwap {
                Divider()
                Button {
                    Haptics.fire(.light)
                    onSwapScoreOwners?()
                } label: {
                    Label("Swap sides", systemImage: "arrow.left.arrow.right")
                }
            }
        } label: {
            let participantNames = scoreOwner.flatMap(scoreOwnerParticipantNames(for:))
            let subtitle = participantNames?.isPopulated == true
                ? nil
                : scoreOwner.flatMap(scoreOwnerSubtitle(for:)) ?? (isEmpty ? "(Empty)" : nil)

            slotLabelContent(
                title: scoreOwner.map(scoreOwnerTitle(for:)) ?? "Tap to assign",
                subtitle: subtitle,
                participantNames: participantNames,
                participantNamesWithMarkers: scoreOwner.flatMap(scoreOwnerParticipantNamesWithMarkers(for:)),
                swatchColor: scoreOwner.flatMap(scoreOwnerColor(for:)),
                isEmpty: isEmpty
            )
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func slotLabelContent(
        title: String,
        subtitle: String?,
        participantNames: [Name]? = nil,
        participantNamesWithMarkers: [(Name, Bool)]? = nil,
        swatchColor: Color?,
        isEmpty: Bool
    ) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                if let swatchColor {
                    Circle()
                        .fill(swatchColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }

                if let participantNamesWithMarkers, participantNamesWithMarkers.isPopulated {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(participantNamesWithMarkers.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                LiveRoundAdaptiveNameText(
                                    name: item.0,
                                    format: .firstNameLastInitial,
                                    fontSize: 15,
                                    weight: .semibold,
                                    color: palette.foregroundColor
                                )
                                if item.1 {
                                    Text("*")
                                        .fontStyle(kFontName, size: 15, weight: .semibold)
                                        .foregroundStyle(palette.foregroundColor)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let participantNames, participantNames.isPopulated {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(participantNames.enumerated()), id: \.offset) { _, name in
                            LiveRoundAdaptiveNameText(
                                name: name,
                                format: .firstNameLastInitial,
                                fontSize: 15,
                                weight: .semibold,
                                color: palette.foregroundColor
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(title)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(isEmpty ? Color.neutral : palette.foregroundColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(isEmpty ? Color.neutral3 : Color.neutral)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .map { participant in
                let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if given.isPopulated { return participant.isSubstitute ? "\(given)*" : given }
                let family = participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = family.isPopulated ? family : participant.name.fullName
                return participant.isSubstitute ? "\(fallback)*" : fallback
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

    private func scoreOwnerTitle(for owner: RoundScoringGroup) -> String {
        if let label = owner.label, label.isPopulated { return label }
        if owner.kind == .teeGroup { return "Tee group" }
        let members = owner.memberIDs.compactMap { id in
            snapshot.participants.first(where: { $0.id == id })
        }
        return members
            .map { participant in
                let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                return given.isPopulated ? given : participant.name.fullName
            }
            .joined(separator: " + ")
    }

    private func scoreOwnerSubtitle(for owner: RoundScoringGroup) -> String? {
        let memberNames = owner.memberIDs
            .compactMap { id in snapshot.participants.first(where: { $0.id == id })?.name.fullName }
        guard memberNames.isPopulated else { return nil }
        return memberNames.joined(separator: ", ")
    }

    private func scoreOwnerParticipantNames(for owner: RoundScoringGroup) -> [Name]? {
        let names = owner.memberIDs
            .compactMap { id in snapshot.participants.first(where: { $0.id == id })?.name }
        return names.isPopulated ? names : nil
    }

    private func scoreOwnerParticipantNamesWithMarkers(for owner: RoundScoringGroup) -> [(Name, Bool)]? {
        let names = owner.memberIDs.compactMap { id -> (Name, Bool)? in
            guard let participant = snapshot.participants.first(where: { $0.id == id }) else { return nil }
            return (participant.name, participant.isSubstitute)
        }
        return names.isPopulated ? names : nil
    }

    private func scoreOwnerColor(for owner: RoundScoringGroup) -> Color? {
        owner.teamID.flatMap { teamID in
            snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor
        }
    }

    private func markedFullName(for participant: RoundParticipant) -> String {
        participant.isSubstitute ? "\(participant.name.fullName)*" : participant.name.fullName
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
        slotMode: .team,
        availableTeamsForSlot0: [],
        availableTeamsForSlot1: [],
        availableParticipantsForSlot0: [],
        availableParticipantsForSlot1: [],
        availableScoreOwnersForSlot0: [],
        availableScoreOwnersForSlot1: [],
        onAssignTeam: { _, _ in },
        onAssignParticipant: { _, _ in },
        onAssignScoreOwner: { _, _ in }
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
        slotMode: .team,
        availableTeamsForSlot0: snapshot.teams,
        availableTeamsForSlot1: [],
        availableParticipantsForSlot0: [],
        availableParticipantsForSlot1: [],
        availableScoreOwnersForSlot0: [],
        availableScoreOwnersForSlot1: [],
        onAssignTeam: { _, _ in },
        onAssignParticipant: { _, _ in },
        onAssignScoreOwner: { _, _ in }
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
        slotMode: .team,
        availableTeamsForSlot0: snapshot.teams,
        availableTeamsForSlot1: snapshot.teams,
        availableParticipantsForSlot0: [],
        availableParticipantsForSlot1: [],
        availableScoreOwnersForSlot0: [],
        availableScoreOwnersForSlot1: [],
        onAssignTeam: { _, _ in },
        onAssignParticipant: { _, _ in },
        onAssignScoreOwner: { _, _ in }
    )
    .padding()
}
