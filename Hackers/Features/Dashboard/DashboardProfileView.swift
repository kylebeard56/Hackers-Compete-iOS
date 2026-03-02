//
//  DashboardProfileView.swift
//  Hackers
//
//  Profile tab content for Dashboard.
//

import SwiftUI

struct DashboardProfileView: View {
    let palette: DesignPalette

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

                logoutButton
                    .padding(.horizontal, 16)

                Spacer(minLength: 80)
            }
        }
    }

    private var profileCard: some View {
        let profile = MockDashboardData.mockProfile
        return HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                PlayerAvatarView(
                    initials: profile.initials,
                    size: 56,
                    fillColor: .accentGreen.opacity(0.6),
                    glassTint: .neutral6,
                    badgeIcon: "e20e",
                    badgeIconColor: Color.charcoal,
                    badgeBackgroundColor: palette.whiteGlassButtonColor
                )
                .onTapGesture {
                    Haptics.fire(.light)
                    // Fake door: edit profile
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text("Joined \(profile.joinedDateFormatted)  \(kDot)  \(profile.roundsPlayed) rounds")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCardEffect()
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
}
