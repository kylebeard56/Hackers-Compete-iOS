//
//  DashboardProfileView.swift
//  Hackers
//
//  Profile tab content for Dashboard.
//

import SwiftUI

struct DashboardProfileView: View, Loggable {
    let palette: DesignPalette
    let currentPlayerID: String?

    @EnvironmentObject private var appSession: AppSession

    @State private var loadedUser: HackersUser?
    @State private var loadedPlayer: Player?

    @State private var showEditNameAlert = false
    @State private var nameDraft = ""
    @State private var saveErrorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text("Profile")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 16)
                    .alignLeading()

                profileCard
                    .padding(.horizontal, 16)

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.systemError)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                logoutButton
                    .padding(.horizontal, 16)

                Spacer(minLength: 80)
            }
        }
        .task(id: currentPlayerID) {
            await loadProfile()
        }
        .alert("Edit name", isPresented: $showEditNameAlert) {
            TextField("First Last", text: $nameDraft)
                .textInputAutocapitalization(.words)
            Button("Save") {
                Task { @MainActor in
                    await saveEditedName()
                }
            }
            .disabled(appSession.isSavingProfile)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This name appears when you play rounds with others.")
        }
    }

    private var profileCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                PlayerAvatarView(
                    initials: profileInitials,
                    size: 56,
                    fillColor: .accentGreen.opacity(0.6),
                    glassTint: .neutral6,
                    badgeIcon: "e20e",
                    badgeIconColor: Color.charcoal,
                    badgeBackgroundColor: palette.whiteGlassButtonColor
                )
                .onTapGesture {
                    Haptics.fire(.light)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    Haptics.fire(.light)
                    nameDraft = loadedPlayer?.name.trimmedFullName ?? ""
                    showEditNameAlert = true
                } label: {
                    Text(profileDisplayName)
                        .fontStyle(kFontName, size: 20, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .disabled(loadedPlayer == nil)

                Text("Joined \(joinedDateFormatted)  \(kDot)  \(roundsPlayed) round\(roundsPlayed.pluralized)")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCardEffect()
    }

    private var profileDisplayName: String {
        loadedPlayer?.name.displayNameWithPlaceholder ?? "First Last"
    }

    private var profileInitials: String {
        loadedPlayer?.name.displayInitialsWithPlaceholder ?? "FL"
    }

    private var joinedDateFormatted: String {
        guard let user = loadedUser else { return "—" }
        return user.createdAt.formattedDate
    }

    private var roundsPlayed: Int {
        guard let playerID = loadedPlayer?.id else { return 0 }
        return appSession.rounds.filter { $0.players.contains(playerID) }.count
    }

    private var logoutButton: some View {
        Button {
            Haptics.fire(.light)
            try? AuthService.shared.logout()
        } label: {
            Text("Logout")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .glassCardEffect(
            cornerRadius: 24,
            tint: Color.systemError.opacity(0.9)
        )
    }

    private func loadProfile() async {
        saveErrorMessage = nil
        let user = await AppData.shared.user
        let player = await AppData.shared.getPrimaryPlayer()
        loadedUser = user
        loadedPlayer = player
    }

    @MainActor
    private func saveEditedName() async {
        guard var player = loadedPlayer else { return }
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated else { return }
        saveErrorMessage = nil
        appSession.isSavingProfile = true
        defer { appSession.isSavingProfile = false }
        player.name = Name(trimmed)
        do {
            loadedPlayer = try await player.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update primary player name", error: error)
            saveErrorMessage = "Couldn't save your name. Try again."
        }
    }
}

#Preview {
    DashboardProfileView(palette: .init(theme: .glass, scheme: .light), currentPlayerID: nil)
        .environmentObject(AppSession.forPreview())
}
