//
//  RecentPlayersView.swift
//  Hackers
//
//  Full player history + select mode for pre-queue into game lobby.
//

import SwiftUI

struct RecentPlayersView: View {
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @ObservedObject var homeViewModel: DashboardHomeViewModel

    let palette: DesignPalette
    let onDismiss: () -> Void
    let onAddToRound: ([String]) -> Void
    let onRouteToLobby: (String) -> Void

    @State private var isSelectMode = false
    @State private var selectedPlayerIDs: Set<String> = []

    private var allPlayers: [PlayerHistoryEntry] {
        homeViewModel.recentPlayers
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    navPadding

                    ForEach(allPlayers, id: \.playerID) { entry in
                        row(for: entry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.top, UIApplication.shared.topSafeAreaInset)
            }

            playersNavHeader
                .padding(.horizontal, 16)
                .alignTop()
        }
    }

    private var navPadding: some View {
        playersNavHeader
            .disabled(true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var playersNavHeader: some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                Haptics.fire(.light)
                onDismiss()
            }

            Spacer(minLength: 0)

            Text(headerTitle)
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            trailingButton
        }
    }

    private var headerTitle: String {
        if isSelectMode {
            return "Select players"
        }
        return "Player History"
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isSelectMode {
            if selectedPlayerIDs.isEmpty {
                Button("Cancel") {
                    Haptics.fire(.light)
                    isSelectMode = false
                    selectedPlayerIDs = []
                }
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            } else {
                PrimaryButton(
                    appearance: .fill,
                    title: "Next: Pick course",
                    labelColor: palette.backgroundColor,
                    buttonColor: palette.foregroundColor,
                    theme: palette.theme,
                    fillWidth: false,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {
                        onAddToRound(Array(selectedPlayerIDs))
                    }
                )
            }
        } else {
            Button("Select") {
                Haptics.fire(.light)
                isSelectMode = true
            }
            .fontStyle(kFontName, size: 15, weight: .semibold)
            .foregroundStyle(Color.accentGreen)
        }
    }

    private func row(for entry: PlayerHistoryEntry) -> some View {
        Button {
            Haptics.fire(.light)
            if isSelectMode {
                if selectedPlayerIDs.contains(entry.playerID) {
                    selectedPlayerIDs.remove(entry.playerID)
                } else {
                    selectedPlayerIDs.insert(entry.playerID)
                }
            }
        } label: {
            HStack(spacing: 12) {
                if isSelectMode {
                    Image(systemName: selectedPlayerIDs.contains(entry.playerID) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selectedPlayerIDs.contains(entry.playerID) ? Color.accentGreen : Color.neutral3)
                }

                DashboardPlayerRow(entry: entry, palette: palette)
            }
        }
        .buttonStyle(.plain)
    }
}
