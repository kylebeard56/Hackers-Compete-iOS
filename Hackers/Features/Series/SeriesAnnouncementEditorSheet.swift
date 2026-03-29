//
//  SeriesAnnouncementEditorSheet.swift
//  Hackers
//

import SwiftUI

struct SeriesAnnouncementEditorContext: Identifiable {
    let id: String
    let announcement: SeriesAnnouncement?

    static func newAnnouncement() -> Self {
        Self(id: "__new__", announcement: nil)
    }

    static func edit(_ announcement: SeriesAnnouncement) -> Self {
        Self(id: announcement.id, announcement: announcement)
    }
}

struct SeriesAnnouncementEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let context: SeriesAnnouncementEditorContext
    var onFinished: () -> Void = {}

    @State private var title = ""
    @State private var message = ""
    @State private var useStart = false
    @State private var useEnd = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var didLoadExisting = false
    @State private var isSaving = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var elevatedSurface: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground)
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard trimmedMessage.isPopulated else { return false }
        if useStart && useEnd, endDate <= startDate { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: context.announcement == nil ? "New announcement" : "Edit announcement",
                subtitle: "Optional start and end control when members see this.",
                onClose: {
                    dismiss()
                    onFinished()
                }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Title", text: $title)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .padding(12)
                        .background(elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Message", text: $message, axis: .vertical)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(4...10)
                        .padding(12)
                        .background(elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Toggle("Schedule start", isOn: $useStart)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .tint(Color.accentGreen)

                    if useStart {
                        DatePicker(
                            "Starts",
                            selection: $startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .fontStyle(kFontName, size: 14, weight: .regular)
                    }

                    Toggle("Schedule end", isOn: $useEnd)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .tint(Color.accentGreen)

                    if useEnd {
                        DatePicker(
                            "Ends",
                            selection: $endDate,
                            in: useStart ? startDate.addingTimeInterval(60)... : Date.distantPast...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .fontStyle(kFontName, size: 14, weight: .regular)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            PrimaryButton(
                appearance: .fill,
                title: context.announcement == nil ? "Post" : "Save",
                labelColor: .white,
                buttonColor: Color.accentGreen,
                fillWidth: true,
                isDisabled: .init(get: { !canSave }, set: { _ in }),
                isLoading: $isSaving,
                onTapAsync: {
                    guard canSave else { return }
                    isSaving = true
                    defer { isSaving = false }
                    let startOpt = useStart ? startDate : nil
                    let endOpt = useEnd ? endDate : nil
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ok: Bool
                    if let existing = context.announcement {
                        ok = await viewModel.updateAnnouncement(
                            existing,
                            title: trimmedTitle,
                            message: trimmedMessage,
                            start: startOpt,
                            end: endOpt
                        )
                    } else {
                        ok = await viewModel.addAnnouncement(
                            title: trimmedTitle,
                            message: trimmedMessage,
                            start: startOpt,
                            end: endOpt
                        )
                    }
                    guard ok else { return }
                    dismiss()
                    onFinished()
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear {
            guard !didLoadExisting, let existing = context.announcement else { return }
            didLoadExisting = true
            title = existing.title
            message = existing.message
            useStart = !existing.usesOpenStart
            useEnd = !existing.usesOpenEnd
            startDate = Date(timeIntervalSince1970: existing.startsAt.unix)
            endDate = Date(timeIntervalSince1970: existing.endsAt.unix)
        }
    }
}
