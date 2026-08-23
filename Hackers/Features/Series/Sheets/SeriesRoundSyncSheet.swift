//
//  SeriesRoundSyncSheet.swift
//  Hackers
//
//  Commissioner UI: choose what to sync from the league into the linked live round.
//

import SwiftUI

struct SeriesRoundSyncSheet: View {
    private enum ReconciliationAction {
        case adoptLobby
        case resetLobby

        var title: String {
            switch self {
            case .adoptLobby: return "Adopt lobby settings?"
            case .resetLobby: return "Reset lobby settings?"
            }
        }

        var message: String {
            switch self {
            case .adoptLobby:
                return "This replaces the Series round setup with the linked lobby's current settings."
            case .resetLobby:
                return "This replaces the linked lobby setup with the settings saved on the Series round."
            }
        }

        var buttonTitle: String {
            switch self {
            case .adoptLobby: return "Adopt lobby"
            case .resetLobby: return "Reset lobby"
            }
        }
    }

    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    let onDismiss: () -> Void

    @State private var syncPlayer = true
    @State private var syncFormat = true
    @State private var syncOrganization = true
    @State private var syncPairs = true
    @State private var syncMatchups = true
    @State private var syncHandicapSettings = true
    @State private var preserveManualHandicap = false
    @State private var isApplying = false
    @State private var isReconciling = false
    @State private var reconciliationAction: ReconciliationAction?
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

    private var configurationDivergence: SeriesRoundConfigurationDivergence? {
        viewModel.linkedConfigurationDivergence(for: seriesRound)
    }

    private var canToggleFormat: Bool { !isCompleteRound }
    private var canToggleOrganization: Bool { !isCompleteRound }
    private var canTogglePlayer: Bool { !isCompleteRound }
    private var canTogglePairs: Bool { !isCompleteRound }
    private var canToggleMatchups: Bool { !isCompleteRound }
    private var canToggleHandicapSettings: Bool { !isCompleteRound }
    private var canTogglePreserveHandicap: Bool { (effectiveSyncPlayer || effectiveSyncHandicapSettings) && !isCompleteRound }

    private var effectiveSyncPlayer: Bool { syncPlayer && canTogglePlayer }
    private var effectiveSyncFormat: Bool { syncFormat && canToggleFormat }
    private var effectiveSyncOrganization: Bool { syncOrganization && canToggleOrganization }
    private var effectiveSyncPairs: Bool { syncPairs && canTogglePairs }
    private var effectiveSyncMatchups: Bool { syncMatchups && canToggleMatchups }
    private var effectiveSyncHandicapSettings: Bool { syncHandicapSettings && canToggleHandicapSettings }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Sync Round",
                    subtitle: "Choose which league round settings should update the linked round.",
                    onClose: {
                        guard !isApplying, !isReconciling else { return }
                        onDismiss()
                    }
                )
            },
            content: {
                VStack(spacing: 16) {
                    if let configurationDivergence {
                        configurationDivergenceCard(configurationDivergence)
                    }

                    if isLive {
                        betaWarningTile
                    }

                    if isCompleteRound {
                        lockedRoundTile
                    }

                    syncSettingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    Button {
                        Task { await applySync() }
                    } label: {
                        Text(isApplying ? "Applying..." : "Apply sync")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(applyButtonDisabled ? palette.foregroundColor : palette.backgroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(applyButtonDisabled ? Color.neutral3 : palette.foregroundColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(applyButtonDisabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .alert("Could not sync", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
        .confirmationDialog(
            reconciliationAction?.title ?? "Confirm configuration change",
            isPresented: Binding(
                get: { reconciliationAction != nil },
                set: { if !$0 { reconciliationAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = reconciliationAction {
                Button(action.buttonTitle, role: .destructive) {
                    Task { await reconcile(action) }
                }
            }
            Button("Cancel", role: .cancel) {
                reconciliationAction = nil
            }
        } message: {
            if let reconciliationAction {
                Text(reconciliationAction.message)
            }
        }
    }

    private func configurationDivergenceCard(
        _ divergence: SeriesRoundConfigurationDivergence
    ) -> some View {
        SeriesSheetCard(palette: palette) {
            SeriesSheetRow(palette: palette) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Lobby setup differs", systemImage: "exclamationmark.triangle.fill")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.orange)

                    Text("The linked lobby differs in \(divergence.summary). Choose which setup should become authoritative.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            reconciliationAction = .adoptLobby
                        } label: {
                            Label("Adopt lobby", systemImage: "arrow.down.to.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            reconciliationAction = .resetLobby
                        } label: {
                            Label("Reset lobby", systemImage: "arrow.up.to.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .disabled(isApplying || isReconciling)
                }
            }
        }
    }

    private var betaWarningTile: some View {
        SeriesSheetRow(palette: palette, rowBackground: Color.neutral6.opacity(colorScheme == .dark ? 0.35 : 0.65)) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.neutral2)
                    .padding(.top, 1)

                Text("This feature is in beta, syncing during a live round may cause unknown issues")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lockedRoundTile: some View {
        SeriesSheetRow(palette: palette, rowBackground: Color.neutral6.opacity(colorScheme == .dark ? 0.35 : 0.65)) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.neutral2)
                    .padding(.top, 2)

                Text("Completed and archived rounds cannot be synced from the league.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var syncSettingsCard: some View {
        SeriesSheetCard(palette: palette) {
            sectionHeaderRow("Sync settings")

            syncToggleRow(
                title: "Player data",
                description: "Update display names, default tee boxes, and handicap strokes from the league roster.",
                isOn: effectiveBinding(storage: $syncPlayer, isEnabled: canTogglePlayer),
                isEnabled: canTogglePlayer
            )

            syncToggleRow(
                title: "Format & scoring",
                description: "Update template, competition scope, team scoring, and matchup scoring settings.",
                disabledDescription: lockedSyncText,
                isOn: effectiveBinding(storage: $syncFormat, isEnabled: canToggleFormat),
                isEnabled: canToggleFormat
            )

            syncToggleRow(
                title: "Teams & tee sheet",
                description: "Update round teams, tee groups, tee times, and player team or tee order assignments.",
                disabledDescription: lockedSyncText,
                isOn: effectiveBinding(storage: $syncOrganization, isEnabled: canToggleOrganization),
                isEnabled: canToggleOrganization
            )

            syncToggleRow(
                title: "Pairs",
                description: "Update partnership scoring groups from the pairs configured on this series round.",
                isOn: effectiveBinding(storage: $syncPairs, isEnabled: canTogglePairs),
                isEnabled: canTogglePairs
            )

            syncToggleRow(
                title: "Matchups",
                description: "Update head-to-head team, player, or pair matchups from this series round.",
                isOn: effectiveBinding(storage: $syncMatchups, isEnabled: canToggleMatchups),
                isEnabled: canToggleMatchups
            )

            syncToggleRow(
                title: "Handicap settings",
                description: "Update course-handicap and normalization settings, then recompute league handicap strokes.",
                isOn: effectiveBinding(storage: $syncHandicapSettings, isEnabled: canToggleHandicapSettings),
                isEnabled: canToggleHandicapSettings
            )

            syncToggleRow(
                title: "Preserve manual handicaps",
                description: "Keep manual handicap edits where the commissioner changed strokes in the lobby.",
                isOn: effectiveBinding(storage: $preserveManualHandicap, isEnabled: canTogglePreserveHandicap),
                isEnabled: canTogglePreserveHandicap
            )
        }
    }

    private func syncToggleRow(
        title: String,
        description: String,
        disabledDescription: String? = nil,
        isOn: Binding<Bool>,
        isEnabled: Bool
    ) -> some View {
        SeriesSheetRow(palette: palette) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(isEnabled ? palette.foregroundColor : Color.neutral)

                    Text(verbatim: disabledDescription ?? description)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(!isEnabled)
            .tint(Color.accentGreen)
        }
    }

    private func effectiveBinding(storage: Binding<Bool>, isEnabled: Bool) -> Binding<Bool> {
        Binding(
            get: { isEnabled && storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
        )
    }

    private var lockedSyncText: String? {
        isCompleteRound ? "Completed and archived rounds cannot be synced." : nil
    }

    private func sectionHeaderRow(_ title: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            Text(selectedSyncCountText)
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.cardEmbeddedRowBackground)
                .clipShape(Capsule())
        }
    }

    private var selectedSyncCountText: String {
        let count = [
            effectiveSyncPlayer,
            effectiveSyncFormat,
            effectiveSyncOrganization,
            effectiveSyncPairs,
            effectiveSyncMatchups,
            effectiveSyncHandicapSettings,
        ].filter { $0 }.count
        return count == 1 ? "1 on" : "\(count) on"
    }

    private var hasSelectedSync: Bool {
        effectiveSyncPlayer
            || effectiveSyncFormat
            || effectiveSyncOrganization
            || effectiveSyncPairs
            || effectiveSyncMatchups
            || effectiveSyncHandicapSettings
    }

    private var applyButtonDisabled: Bool {
        !hasSelectedSync || isApplying || isReconciling || isCompleteRound
    }

    private func reconcile(_ action: ReconciliationAction) async {
        guard !isApplying, !isReconciling else { return }
        reconciliationAction = nil
        isReconciling = true
        defer { isReconciling = false }

        let result: Result<Void, SeriesRoundSyncError>
        switch action {
        case .adoptLobby:
            result = await viewModel.adoptLinkedRoundConfiguration(for: seriesRound)
        case .resetLobby:
            result = await viewModel.resetLinkedRoundConfiguration(for: seriesRound)
        }

        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }

    private func applySync() async {
        guard hasSelectedSync, !isCompleteRound, !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        let options = SeriesRoundSyncOptions(
            syncPlayerData: effectiveSyncPlayer,
            syncFormat: effectiveSyncFormat,
            syncOrganization: effectiveSyncOrganization,
            syncPairs: effectiveSyncPairs,
            syncMatchups: effectiveSyncMatchups,
            syncHandicapSettings: effectiveSyncHandicapSettings,
            preserveManualHandicapEdits: preserveManualHandicap && (effectiveSyncPlayer || effectiveSyncHandicapSettings)
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
