//
//  SeriesAnnouncementsView.swift
//  Hackers
//

import SwiftUI

struct SeriesAnnouncementsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel

    @State private var editorContext: SeriesAnnouncementEditorContext?
    @State private var announcementPendingDelete: SeriesAnnouncement?
    @State private var showDeleteConfirmation = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var elevatedSurface: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Announcements",
                subtitle: "Planned, live, and past announcements for this league.",
                onClose: { dismiss() },
                actions: {
                    if viewModel.isCommissioner {
                        Button {
                            Haptics.fire(.light)
                            editorContext = .newAnnouncement()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.accentGreen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    announcementSection(
                        title: "Planned",
                        empty: "No scheduled announcements.",
                        items: viewModel.plannedAnnouncements
                    )
                    announcementSection(
                        title: "Live",
                        empty: "Nothing active right now.",
                        items: viewModel.liveAnnouncements
                    )
                    announcementSection(
                        title: "Expired",
                        empty: "No past announcements.",
                        items: viewModel.expiredAnnouncements
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(item: $editorContext) { ctx in
            SeriesAnnouncementEditorSheet(viewModel: viewModel, context: ctx) {
                editorContext = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete announcement?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let a = announcementPendingDelete {
                    Task { await viewModel.deleteAnnouncement(a) }
                }
                announcementPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                announcementPendingDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    @ViewBuilder
    private func announcementSection(title: String, empty: String, items: [SeriesAnnouncement]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            if items.isEmpty {
                Text(empty)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(elevatedSurface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(items, id: \.id) { announcement in
                    announcementRow(announcement)
                }
            }
        }
    }

    private func announcementRow(_ announcement: SeriesAnnouncement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)

                Text(announcement.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Announcement"
                    : announcement.title)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)
            }

            Text(announcement.message)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            Text(scheduleCaption(for: announcement))
                .fontStyle(kFontName, size: 11, weight: .regular)
                .foregroundStyle(Color.neutral2)

            if viewModel.isCommissioner {
                HStack(spacing: 8) {
                    Button {
                        Haptics.fire(.light)
                        editorContext = .edit(announcement)
                    } label: {
                        Chip(
                            text: "Edit",
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: palette.cardEmbeddedRowBackground
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.fire(.light)
                        announcementPendingDelete = announcement
                        showDeleteConfirmation = true
                    } label: {
                        Chip(
                            text: "Delete",
                            size: .xSmall,
                            foreground: .systemError,
                            background: Color.systemError.opacity(colorScheme.translucent)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func scheduleCaption(for announcement: SeriesAnnouncement) -> String {
        let start = Date(timeIntervalSince1970: announcement.startsAt.unix)
        let end = Date(timeIntervalSince1970: announcement.endsAt.unix)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        switch (announcement.usesOpenStart, announcement.usesOpenEnd) {
        case (true, true):
            return "No start or end date"
        case (true, false):
            return "Until \(df.string(from: end))"
        case (false, true):
            return "From \(df.string(from: start)) — no end date"
        case (false, false):
            return "\(df.string(from: start)) – \(df.string(from: end))"
        }
    }
}
