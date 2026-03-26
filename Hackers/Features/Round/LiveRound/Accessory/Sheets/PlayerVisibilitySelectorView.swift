//
//  PlayerVisibilitySelectorView.swift
//  Hackers
//
//  Player visibility selector for the edit visibility tile (sideways/rotated layout).
//

import SwiftUI

struct PlayerVisibilitySelectorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var viewModel: LiveRoundViewModel
    var onDismiss: (() -> Void)? = nil
    
    @State private var draftVisibleIDs: Set<String> = []
    @State private var localGroupID: String? = nil
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var effectiveAccent: Color { palette.foregroundColor }
    private var allParticipantIDs: Set<String> { Set(viewModel.snapshot.participants.map(\.id)) }
    
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
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    NavButton(style: .glass, icon: "f053", size: 15) {
                        if let onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }
                    .alignLeading()
                    
                    Text("Hide players")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                }
                .padding(.bottom, 16)
                
                chipsSection
                
                Divider()
                    .padding(.vertical, 6)
                
                ForEach(viewModel.leaderboardRows, id: \.id) { row in
                    let isVisible = draftVisibleIDs.contains(row.participant.id)
                    let teamColor = viewModel.teamColor(for: row.participant)
                    
                    Button {
                        Haptics.fire(.light)
                        if isVisible {
                            draftVisibleIDs = draftVisibleIDs.subtracting([row.participant.id])
                        } else {
                            draftVisibleIDs = draftVisibleIDs.union([row.participant.id])
                        }
                        localGroupID = matchingChipID(for: draftVisibleIDs)
                        viewModel.visibleParticipantIDs = draftVisibleIDs
                        viewModel.applyScorecardVisibility()
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(teamColor ?? Color.neutral6)
                                .frame(width: 8, height: 8)
                            
//                            Text(row.participant.name.fullName)
//                                .fontStyle(kFontName, size: 15, weight: .medium)
//                                .foregroundStyle(palette.foregroundColor)
//                                .lineLimit(1)
                            
                            ViewThatFits(in: .horizontal) {
                                Text(row.participant.name.fullName)
                                    .fontStyle(kFontName, size: 15, weight: .medium)
                                    .foregroundStyle(palette.foregroundColor)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Text(viewModel.formatDisplayName(for: row.participant))
                                    .fontStyle(kFontName, size: 15, weight: .medium)
                                    .foregroundStyle(palette.foregroundColor)
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 0)
                            
                            Icon(name: "checkmark", size: 18, weight: .semibold)
                                .foregroundStyle(effectiveAccent)
                                .opacity(isVisible ? 1 : 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button("Show all") {
                    Haptics.fire(.light)
                    localGroupID = nil
                    draftVisibleIDs = allParticipantIDs
                    viewModel.visibleParticipantIDs = draftVisibleIDs
                    viewModel.applyScorecardVisibility()
                }
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Button("Hide all") {
                    Haptics.fire(.light)
                    localGroupID = nil
                    draftVisibleIDs = []
                    viewModel.visibleParticipantIDs = draftVisibleIDs
                    viewModel.applyScorecardVisibility()
                }
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        //.navigationTitle("Player visibility")
        //.navigationBarTitleDisplayMode(.inline)
        //.navigationBarBackButtonHidden()
        .onAppear {
            draftVisibleIDs = viewModel.visibleParticipantIDs
        }
    }
    
    @ViewBuilder
    private var chipsSection: some View {
        let hasTeeGroups = viewModel.snapshot.teeGroups.count > 1
        let hasTeams = viewModel.snapshot.requiresTeams && viewModel.snapshot.teams.isPopulated
        if hasTeeGroups || hasTeams {
            VStack(alignment: .leading, spacing: 6) {
                if hasTeeGroups {
                    compactChipsRow(
                        label: "Tee group",
                        items: viewModel.snapshot.teeGroups.sorted(by: { $1.index > $0.index }),
                        chipID: { $0.id },
                        chipLabel: { group in
                            if let teeTime = group.teeTime {
                                "#\(group.index + 1) \(kDot) \(teeTime)"
                            } else {
                                "G\(group.index + 1)"
                            }
                        },
                        participantIDs: { group in
                            Set(viewModel.snapshot.participants.filter { $0.groupID == group.id }.map(\.id))
                        },
                        accentColor: nil
                    )
                }
                if hasTeams {
                    compactChipsRow(
                        label: "Team",
                        items: viewModel.snapshot.teams,
                        chipID: { $0.id },
                        chipLabel: { $0.name },
                        participantIDs: { team in
                            Set(viewModel.snapshot.participants.filter { $0.teamID == team.id }.map(\.id))
                        },
                        accentColor: { $0.swatchColor }
                    )
                }
            }
            .padding(.bottom, 4)
        }
    }
    
    private func compactChipsRow<T: Identifiable>(
        label: String,
        items: [T],
        chipID: @escaping (T) -> String,
        chipLabel: @escaping (T) -> String,
        participantIDs: @escaping (T) -> Set<String>,
        accentColor: ((T) -> Color)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .fontStyle(kFontName, size: 10, weight: .semibold)
                .foregroundStyle(Color.neutral2)
                .padding(.leading, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                        compactChip(
                            chipID: chipID(item),
                            label: chipLabel(item),
                            participantIDs: participantIDs(item),
                            accentColor: accentColor?(item)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollClipDisabled()
        }
    }
    
    @ViewBuilder
    private func compactChip(
        chipID: String,
        label: String,
        participantIDs: Set<String>,
        accentColor: Color? = nil
    ) -> some View {
        let isSelected = localGroupID == chipID
        let color = accentColor ?? effectiveAccent
        let tint = isSelected ? color.opacity(colorScheme.translucent) : palette.glassButtonColor
        let foreground: Color = isSelected ? (accentColor ?? effectiveAccent) : palette.foregroundColor
        
        Button {
            Haptics.fire(.light)
            if isSelected {
                localGroupID = nil
                draftVisibleIDs = allParticipantIDs
            } else {
                localGroupID = chipID
                draftVisibleIDs = participantIDs
            }
            viewModel.visibleParticipantIDs = draftVisibleIDs
            viewModel.applyScorecardVisibility()
        } label: {
            HStack(spacing: 4) {
                if accentColor != nil || isSelected {
                    Circle()
                        .fill(accentColor ?? effectiveAccent)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassCardEffect(cornerRadius: 8, interactive: false, tint: tint)
    }
}
