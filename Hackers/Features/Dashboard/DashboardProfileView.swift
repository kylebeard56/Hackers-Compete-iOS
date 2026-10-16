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
    @EnvironmentObject private var liveRoundCompanion: LiveRoundCompanionCoordinator

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

                NavigationLink {
                    UserSettingsView(
                        palette: palette,
                        preferences: liveRoundCompanion.preferences,
                        companion: liveRoundCompanion
                    )
                } label: {
                    HStack {
                        Label("Settings", systemImage: "gearshape")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(16)
                    .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
                }
                .padding(.horizontal, 16)
                .accessibilityIdentifier("profile.settings")

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
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
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
        .environmentObject(LiveRoundCompanionCoordinator())
}


/// Native Settings use the same semantic palette as the rest of the iOS app.
struct UserSettingsView: View {
    let palette: DesignPalette
    @ObservedObject var preferences: UserCompanionPreferences
    @ObservedObject var companion: LiveRoundCompanionCoordinator

    private var canUseWatch: Bool {
        companion.watchIsPaired && companion.watchAppIsInstalled
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { preferences.state.appleWatch },
                    set: { preferences.setAppleWatch($0) }
                )) {
                    settingLabel(
                        "Apple Watch",
                        description: "View your round and enter scores in the Hackers Apple Watch app."
                    )
                }
                .disabled(preferences.state.userID == nil || (!canUseWatch && !preferences.state.appleWatch))
                .accessibilityIdentifier("settings.appleWatch")
                if !canUseWatch {
                    Text("Pair an Apple Watch and install Hackers on it to use this integration.")
                        .font(.footnote)
                        .foregroundStyle(Color.neutral)
                }
            }
            .listRowBackground(palette.cardColor)

            Section {
                Toggle(isOn: Binding(
                    get: { preferences.state.liveActivities },
                    set: { preferences.setLiveActivities($0) }
                )) {
                    settingLabel(
                        "Live Activities",
                        description: "Show live round updates on your Lock Screen and Dynamic Island."
                    )
                }
                .disabled(preferences.state.userID == nil || (!companion.liveActivitiesAvailable && !preferences.state.liveActivities))
                .accessibilityIdentifier("settings.liveActivities")
                if !companion.liveActivitiesAvailable {
                    Text("Live Activities are unavailable or disabled for Hackers in iOS Settings.")
                        .font(.footnote)
                        .foregroundStyle(Color.neutral)
                }
            } footer: {
                Text("Dynamic Island appears on supported devices. iOS controls where Live Activities appear, including on paired devices.")
            }
            .listRowBackground(palette.cardColor)
        }
        .tint(.accentGreen)
        .foregroundStyle(palette.foregroundColor)
        .scrollContentBackground(.hidden)
        .background(palette.backgroundColor.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingLabel(_ title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color.neutral)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
