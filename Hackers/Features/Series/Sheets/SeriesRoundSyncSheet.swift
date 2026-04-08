//
//  SeriesRoundSyncSheet.swift
//  Hackers
//
//  Commissioner UI: choose what to sync from the league into the linked live round.
//

import SwiftUI

struct SeriesRoundSyncSheet: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    let onDismiss: () -> Void

    @State private var step: Int = 0
    @State private var syncPlayer = true
    @State private var syncFormat = true
    @State private var syncOrganization = true
    @State private var preserveManualHandicap = false
    @State private var isApplying = false
    @State private var errorMessage: String?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var linkedStatus: RoundStatus? {
        guard let rid = seriesRound.roundID else { return nil }
        return viewModel.linkedRounds[rid]?.status
    }

    private var isCompleteRound: Bool {
        linkedStatus == .complete || linkedStatus == .archived
    }

    private var isLive: Bool {
        linkedStatus == .live || linkedStatus == .paused
    }

    private var canToggleFormat: Bool { !isLive && !isCompleteRound }
    private var canToggleOrganization: Bool { !isLive && !isCompleteRound }
    private var canTogglePlayer: Bool { !isCompleteRound }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                syncStepIndicator

                TabView(selection: $step) {
                    playerStep.tag(0)
                    formatStep.tag(1)
                    organizationStep.tag(2)
                    reviewStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 420)
            }
            .navigationTitle("Sync from league")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                        .disabled(isApplying)
                }
            }
            .alert("Could not sync", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var syncStepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.accentGreen : Color.neutral.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 10)
    }

    private var playerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Player data")
                    .fontStyle(kFontName, size: 20, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)

                Text("Update display names, default tee boxes, and strokes from the league handicap index (same as when the round was started).")
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(Color.neutral)

                Toggle(isOn: $syncPlayer) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync player names, tees & handicaps")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text("Does not change tee groups, teams, or matchups.")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }
                .disabled(!canTogglePlayer)
                .accessibilityHint("Updates participant rows from league roster and handicaps.")

                Toggle(isOn: $preserveManualHandicap) {
                    Text("Preserve manual handicap edits made in the lobby")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                }
                .disabled(!syncPlayer || !canTogglePlayer)

                navigationRow(back: nil, next: 1)
            }
            .padding(20)
        }
    }

    private var formatStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Format & competition")
                    .fontStyle(kFontName, size: 20, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)

                Text("Align game format, competition scope, team scoring modes, and related league options with this scheduled round. The course layout already on the live round is kept.")
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(Color.neutral)

                Toggle(isOn: $syncFormat) {
                    Text("Sync format & competition settings")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
                .disabled(!canToggleFormat)
                .accessibilityHint("Updates round configuration from league round template.")

                if isLive {
                    Text("Format sync is disabled while the round is live.")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.systemError)
                }

                navigationRow(back: 0, next: 2)
            }
            .padding(20)
        }
    }

    private var organizationStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Organization")
                    .fontStyle(kFontName, size: 20, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)

                Text("Sync teams, tee sheet groups, partnerships, scoring groups, and matchups. Requires the same number of tee groups as the league expects.")
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(Color.neutral)

                Toggle(isOn: $syncOrganization) {
                    Text("Sync teams, tee groups & matchups")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
                .disabled(!canToggleOrganization)
                .accessibilityHint("Restructures lobby setup from league pods and schedule.")

                if isLive {
                    Text("Organization sync is disabled while the round is live to protect score entries.")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.systemError)
                }

                Text("Players added only to the league after this round started are not added to the live round here—use the game lobby if you need new participants.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

                navigationRow(back: 1, next: 3)
            }
            .padding(20)
        }
    }

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review")
                    .fontStyle(kFontName, size: 20, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)

                summaryRow("Player data", enabled: syncPlayer && canTogglePlayer)
                summaryRow("Format & competition", enabled: syncFormat && canToggleFormat)
                summaryRow("Organization", enabled: syncOrganization && canToggleOrganization)

                if preserveManualHandicap && syncPlayer {
                    Text("Manual handicap edits will be kept where the commissioner previously changed strokes in the lobby.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                PrimaryButton(
                    appearance: .fill,
                    title: "Apply sync",
                    labelColor: .white,
                    buttonColor: Color.accentGreen,
                    theme: palette.theme,
                    height: 48,
                    fillWidth: true,
                    fontSize: 16,
                    isDisabled: Binding(
                        get: { !hasSelectedSync || isApplying || isCompleteRound },
                        set: { _ in }
                    ),
                    isLoading: $isApplying,
                    onTap: { Task { await applySync() } }
                )
                .padding(.top, 8)

                navigationRow(back: 2, next: nil)

                Spacer(minLength: 24)
            }
            .padding(20)
        }
    }

    private func summaryRow(_ title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
                .fontStyle(kFontName, size: 16, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
            Spacer()
            Text(enabled ? "On" : "Off")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(enabled ? Color.accentGreen : Color.neutral)
        }
        .padding(.vertical, 6)
    }

    private var hasSelectedSync: Bool {
        let p = syncPlayer && canTogglePlayer
        let f = syncFormat && canToggleFormat
        let o = syncOrganization && canToggleOrganization
        return p || f || o
    }

    @ViewBuilder
    private func navigationRow(back: Int?, next: Int?) -> some View {
        HStack {
            if let back {
                Button("Back") { step = back }
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
            }
            Spacer()
            if let next {
                Button("Next") { step = next }
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
            }
        }
        .padding(.top, 12)
    }

    private func applySync() async {
        guard hasSelectedSync, !isCompleteRound else { return }
        isApplying = true
        defer { isApplying = false }

        let options = SeriesRoundSyncOptions(
            syncPlayerData: syncPlayer && canTogglePlayer,
            syncFormat: syncFormat && canToggleFormat,
            syncOrganization: syncOrganization && canToggleOrganization,
            preserveManualHandicapEdits: preserveManualHandicap
        )

        let result = await viewModel.syncLinkedRoundFromSeries(seriesRound: seriesRound, options: options)
        switch result {
        case .success:
            onDismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
