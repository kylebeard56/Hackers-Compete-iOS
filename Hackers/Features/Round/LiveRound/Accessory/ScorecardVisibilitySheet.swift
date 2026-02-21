//
//  ScorecardVisibilitySheet.swift
//  Hackers
//
//  Created for Stage 6 scorecard enhancements.
//

import SwiftUI

struct ScorecardVisibilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: LiveRoundViewModel
    let onDismiss: () -> Void

    @State private var draftVisibleIDs: Set<String> = []
    @State private var localGroupID: String? = nil

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }
    private var effectiveAccentLabelColor: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.backgroundColor : palette.backgroundColor
    }
    private var allParticipantIDs: Set<String> { Set(viewModel.snapshot.participants.map(\.id)) }
    private var allSelected: Bool { draftVisibleIDs == allParticipantIDs }
    private var resetButtonTitle: String { allSelected ? "Clear all" : "Select all" }

    private func matchingChipID(for ids: Set<String>) -> String? {
        for group in viewModel.snapshot.teeGroups {
            let groupIDs = Set(viewModel.snapshot.participants.filter { $0.groupID == group.id }.map(\.id))
            if ids == groupIDs { return group.id }
        }
        if viewModel.snapshot.requiresTeams {
            for team in viewModel.snapshot.teams {
                let teamIDs = Set(viewModel.snapshot.participants.filter { $0.teamID == team.id }.map(\.id))
                if ids == teamIDs { return team.id }
            }
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                topBar

                ScrollView {
                    VStack(spacing: 16) {
                        chipsSection
                        
                        participantList
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(palette.backgroundColor)
            .onAppear {
                draftVisibleIDs = viewModel.visibleParticipantIDs
            }

            footerButtons
        }
    }

    private var topBar: some View {
        ZStack {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                Haptics.fire(.light)
                onDismiss()
                dismiss()
            }
            .alignLeading()

            Spacer(minLength: 0)

            Text("Player visibility")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
        }
        .padding(.horizontal, 16)
    }

    private var chipsSection: some View {
        VStack(spacing: 12) {
            if viewModel.snapshot.teeGroups.count > 1 {
                teeGroupChips
            }
            if viewModel.snapshot.requiresTeams, viewModel.snapshot.teams.isPopulated {
                teamChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var teeGroupChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tee group")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral2)
                .padding(.leading, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Padding(.horizontal, 8)
                    ForEach(viewModel.snapshot.teeGroups, id: \.id) { group in
                        let ids = Set(viewModel.snapshot.participants.filter { $0.groupID == group.id }.map(\.id))
                        if let teeTime = group.teeTime {
                            visibilityChip(chipID: group.id, label: "#\(group.index + 1) \(kDot) \(teeTime)", participantIDs: ids)
                        } else {
                            visibilityChip(chipID: group.id, label: "Group \(group.index + 1)", participantIDs: ids)
                        }
                    }
                    Padding(.horizontal, 8)
                }
            }
        }
    }

    private var teamChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral2)
                .padding(.leading, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Padding(.horizontal, 8)
                    ForEach(viewModel.snapshot.teams, id: \.id) { team in
                        let ids = Set(viewModel.snapshot.participants.filter { $0.teamID == team.id }.map(\.id))
                        visibilityChip(
                            chipID: team.id,
                            label: team.name,
                            participantIDs: ids,
                            accentColor: team.teamColor.value,
                            showColorDot: true
                        )
                    }
                    Padding(.horizontal, 8)
                }
            }
        }
    }

    private func visibilityChip(
        chipID: String,
        label: String,
        participantIDs: Set<String>,
        accentColor: Color? = nil,
        showColorDot: Bool = false
    ) -> some View {
        let isSelected = localGroupID == chipID
        let color = accentColor ?? effectiveAccent
        let tint = isSelected ? color.opacity(colorScheme.ultraTranslucent) : palette.glassButtonColor
        let foreground: Color = isSelected ? (accentColor ?? effectiveAccent) : palette.backgroundColor

        return HStack(spacing: (showColorDot && isSelected) ? 6 : 0) {
            if showColorDot, isSelected, let accentColor {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .glassCardEffect(cornerRadius: 12, interactive: false, tint: tint)
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    Haptics.fire(.light)
                    if isSelected {
                        localGroupID = nil
                        draftVisibleIDs = allParticipantIDs
                    } else {
                        localGroupID = chipID
                        draftVisibleIDs = participantIDs
                    }
                }
        )
    }

    private var participantList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.leaderboardRows, id: \.id) { row in
                
                if viewModel.leaderboardRows.first?.id == row.id {
                    let rowCount = viewModel.leaderboardRows.count
                    let draftCount = draftVisibleIDs.count
                    let all = rowCount == draftCount
                    Text("\(rowCount) players \(kDot) \(all ? "All" : "\(draftCount)") selected")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .padding(.horizontal, 16)
                        .alignLeading()
                } else {
                    Line()
                }
                
                HStack(spacing: 12) {
                    Text(row.participant.name.initials)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: 32, height: 32)
                        .background(Color.neutral6)
                        .clipShape(Circle())

                    Text(row.participant.name.fullName)
                        .fontStyle(kFontName, size: 17, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Toggle("", isOn: Binding(
                        get: { draftVisibleIDs.contains(row.participant.id) },
                        set: { visible in
                            if visible {
                                draftVisibleIDs = draftVisibleIDs.union([row.participant.id])
                            } else {
                                draftVisibleIDs = draftVisibleIDs.subtracting([row.participant.id])
                            }
                            localGroupID = matchingChipID(for: draftVisibleIDs)
                        }
                    ))
                    .tint(effectiveAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            GlassButton(
                title: resetButtonTitle,
                material: .bar,
                fillWidth: false,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTap: {
                    localGroupID = nil
                    if allSelected {
                        draftVisibleIDs = []
                    } else {
                        draftVisibleIDs = allParticipantIDs
                    }
                }
            )

            GlassButton(
                title: "Apply",
                labelColor: effectiveAccentLabelColor,
                tintColor: effectiveAccent,
                material: .bar,
                fillWidth: true,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTap: {
                    viewModel.visibleParticipantIDs = draftVisibleIDs
                    viewModel.applyScorecardVisibility()
                    onDismiss()
                    dismiss()
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Preview

#Preview("Scorecard Visibility (16 players, 4 groups, 4 teams)") {
    ScorecardVisibilitySheetPreview()
}

private struct ScorecardVisibilitySheetPreview: View {
    @StateObject private var viewModel: LiveRoundViewModel

    init() {
        let snapshot = MockLiveRoundVisibilityPreview.snapshot
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id

        let roundSession = RoundSession()
        roundSession.snapshot = snapshot

        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        vm.set(snapshot: snapshot)
        vm.visibleParticipantIDs = Set(snapshot.participants.map(\.id))
        vm.applyScorecardVisibility()

        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ScorecardVisibilitySheet(viewModel: viewModel, onDismiss: {})
    }
}
