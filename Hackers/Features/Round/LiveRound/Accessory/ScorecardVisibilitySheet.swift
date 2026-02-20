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

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chipsSection

                participantList

                footerButtons
            }
            .background(palette.backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.fire(.light)
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(palette.foregroundColor)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Scorecard visibility")
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Button("Select all") {
                            Haptics.fire(.light)
                            draftVisibleIDs = Set(viewModel.snapshot.participants.map(\.id))
                        }
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                        Button("Deselect all") {
                            Haptics.fire(.light)
                            draftVisibleIDs = []
                        }
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    }
                }
            }
            .onAppear {
                draftVisibleIDs = viewModel.visibleParticipantIDs
            }
        }
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var teeGroupChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tee group")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.snapshot.teeGroups, id: \.id) { group in
                        let participantIDs = Set(viewModel.snapshot.participants.filter { $0.groupID == group.id }.map(\.id))
                        Button {
                            Haptics.fire(.light)
                            let allVisible = participantIDs.allSatisfy { draftVisibleIDs.contains($0) }
                            if allVisible {
                                draftVisibleIDs = draftVisibleIDs.subtracting(participantIDs)
                            } else {
                                draftVisibleIDs = draftVisibleIDs.union(participantIDs)
                            }
                        } label: {
                            Text(group.teeTime ?? "Group \(group.index + 1)")
                                .fontStyle(kFontName, size: 13, weight: .medium)
                                .foregroundStyle(palette.foregroundColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassCardEffect(cornerRadius: 12, interactive: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var teamChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.snapshot.teams, id: \.id) { team in
                        let participantIDs = Set(viewModel.snapshot.participants.filter { $0.teamID == team.id }.map(\.id))
                        Button {
                            Haptics.fire(.light)
                            let allVisible = participantIDs.allSatisfy { draftVisibleIDs.contains($0) }
                            if allVisible {
                                draftVisibleIDs = draftVisibleIDs.subtracting(participantIDs)
                            } else {
                                draftVisibleIDs = draftVisibleIDs.union(participantIDs)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(team.teamColor.value)
                                    .frame(width: 8, height: 8)
                                Text(team.name)
                                    .fontStyle(kFontName, size: 13, weight: .medium)
                                    .foregroundStyle(palette.foregroundColor)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassCardEffect(cornerRadius: 12, interactive: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var participantList: some View {
        List {
            ForEach(viewModel.leaderboardRows, id: \.id) { row in
                HStack(spacing: 12) {
                    Text(row.participant.name.initials)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: 32, height: 32)
                        .background(Color.neutral6)
                        .clipShape(Circle())

                    Text(row.participant.name.fullName)
                        .fontStyle(kFontName, size: 16, weight: .medium)
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
                        }
                    ))
                    .labelsHidden()
                }
                .listRowBackground(palette.cardColor)
                .listRowSeparatorTint(Color.neutral5)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var footerButtons: some View {
        VStack(spacing: 12) {
            Line()
                .opacity(0.5)

            HStack(spacing: 12) {
                Button {
                    Haptics.fire(.light)
                    viewModel.resetScorecardVisibility()
                    draftVisibleIDs = viewModel.visibleParticipantIDs
                } label: {
                    Text("Reset")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassCardEffect(cornerRadius: 14, interactive: false)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.fire(.light)
                    viewModel.visibleParticipantIDs = draftVisibleIDs
                    viewModel.applyScorecardVisibility()
                    onDismiss()
                    dismiss()
                } label: {
                    Text("Apply")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.backgroundColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.foregroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(palette.backgroundColor)
    }
}
