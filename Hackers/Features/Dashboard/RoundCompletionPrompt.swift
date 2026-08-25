//
//  RoundCompletionPrompt.swift
//  Hackers
//
//  Created by Kyle Beard on 3/3/26.
//

import SwiftUI

struct RoundCompletionPrompt: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let info: StalledCompletionInfo
    let currentPlayerID: String?
    let onRespond: () -> Void

    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    @State private var isSubmitting = false

    // MARK: - Derived

    private var completedPlayerLabel: String {
        switch info.completedPlayers.count {
        case 1:
            return info.completedPlayers.first?.playerDisplayName ?? "a player"
        default:
            return "multiple players"
        }
    }

    private var courseName: String {
        info.round.configuration.courses.first?.courseInfo.name ?? "your course"
    }

    private var formatName: String {
        info.round.configuration.primaryFormat.type.displayName
    }

    private var bodyText: String {
        "It looks like \(completedPlayerLabel) finished your round of \(formatName) at \(courseName). Would you like to finish this round or leave it open?"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .green)

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Icon(name: "f11e", size: 36, weight: .regular)
                        .foregroundStyle(Color.accentYellow)
                        .padding(.top, 8)

                    Text("Round complete")
                        .fontStyle(kFontName, size: 22, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text(bodyText)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    GlassButton(
                        title: "Finish",
                        tintColor: .accentYellow,
                        isDisabled: .constant(isSubmitting),
                        isLoading: .constant(isSubmitting),
                        onTap: { Task { await respond(type: .signedScorecard) } }
                    )

                    GlassButton(
                        title: "Keep open",
                        isDisabled: .constant(isSubmitting),
                        isLoading: .constant(false),
                        onTap: { Task { await respond(type: .keepOpen) } }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Action

    private func respond(type: RoundCompletionType) async {
        guard let playerID = currentPlayerID else {
            dismiss()
            onRespond()
            return
        }

        isSubmitting = true
        let entry = CompletedPlayer(
            playerID: playerID,
            completedAt: .init(),
            type: type,
            scorecardStorageID: nil
        )
        try? await FirebaseService.shared.markPlayerComplete(
            roundID: info.round.id,
            completedPlayer: entry
        )
        isSubmitting = false
        dismiss()
        onRespond()
    }
}
