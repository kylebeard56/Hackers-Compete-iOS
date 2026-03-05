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
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(allPlayers, id: \.playerID) { entry in
                        row(for: entry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.fire(.light)
                        onDismiss()
                    } label: {
                        Icon(name: "f00d", size: 18, weight: .solid)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(width: 44, height: 44)
                            .glassCardEffect(shape: .circle, interactive: false)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectMode {
                        Button("Add to round") {
                            Haptics.fire(.light)
                            onAddToRound(Array(selectedPlayerIDs))
                        }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(selectedPlayerIDs.isEmpty ? Color.neutral : Color.accentGreen)
                        .disabled(selectedPlayerIDs.isEmpty)
                    } else {
                        Button("Select") {
                            Haptics.fire(.light)
                            isSelectMode = true
                        }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                    }
                }
            }
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
