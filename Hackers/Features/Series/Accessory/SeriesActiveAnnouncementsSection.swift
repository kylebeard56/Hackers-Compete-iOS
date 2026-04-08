//
//  SeriesActiveAnnouncementsSection.swift
//  Hackers
//

import SwiftUI

/// Active announcements shown on the series rounds tab when at least one is in its active date window.
struct SeriesActiveAnnouncementsSection: View {
    let announcements: [SeriesAnnouncement]
    let palette: DesignPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Announcements".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            ForEach(announcements, id: \.id) { announcement in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "megaphone.fill")
                            .foregroundStyle(Color.accentGreen)
                        Text(announcement.title.isEmpty ? "Announcement" : announcement.title)
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                    }

                    Text(announcement.message)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)

                    Text(announcement.usesOpenEnd ? "No end date" : "Active until \(announcement.endsAt.formattedDate)")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral2)
                }
                .padding(12)
                .glassCardEffect(cornerRadius: 12, forceMaterial: true, tint: palette.whiteGlassButtonColor)
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
        .padding(.horizontal, 16)
    }
}
