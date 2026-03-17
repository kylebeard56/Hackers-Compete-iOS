//
//  SeriesRoundAttendanceView.swift
//  Hackers
//

import SwiftUI

struct SeriesRoundAttendanceView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    let seriesRound: SeriesRound
    var onDismiss: () -> Void

    @State private var declinedNote: String = ""

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Attendance")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: palette.theme, onTap: {
                    onDismiss()
                    dismiss()
                })
            }

            Text(seriesRound.title.isEmpty ? "Round \(seriesRound.index + 1)" : seriesRound.title)
                .fontStyle(kFontName, size: 17, weight: .medium)
                .foregroundStyle(Color.neutral)
                .alignLeading()

            VStack(spacing: 12) {
                ForEach(viewModel.activeMembers, id: \.id) { member in
                    attendanceRow(for: member)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(palette.backgroundColor)
        .task {
            await viewModel.loadAttendance(for: seriesRound.id)
        }
        .onChange(of: viewModel.attendanceByMember) { _, _ in
            if declinedNote.isEmpty,
               let currentMember = viewModel.activeMembers.first(where: { $0.playerID == viewModel.currentPlayerID }),
               let att = viewModel.attendanceByMember[currentMember.id],
               att.status == SeriesRoundAttendanceStatus.no.rawValue {
                declinedNote = att.declinedNote ?? ""
            }
        }
    }

    private func attendanceRow(for member: SeriesMember) -> some View {
        let attendance = viewModel.attendanceByMember[member.id] ?? defaultAttendance(for: member)
        let isCurrentUser = member.playerID == viewModel.currentPlayerID

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                PlayerAvatarView(initials: member.name.initials, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text(attendanceStatusLabel(attendance.status))
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)
                if isCurrentUser {
                    attendancePicker(for: member, current: attendance)
                }
            }
            .padding(12)
            .glassCardEffect(cornerRadius: 12)

            if isCurrentUser && attendance.status == SeriesRoundAttendanceStatus.no.rawValue {
                TextField("Optional: Why can't you make it?", text: $declinedNote)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(12)
                    .background(Color.neutral6)
                    .cornerRadius(radius: 10)
                    .onChange(of: declinedNote) { _, new in
                        Task {
                            await viewModel.updateAttendance(
                                seriesRoundID: seriesRound.id,
                                memberID: member.id,
                                status: .no,
                                declinedNote: new.isEmpty ? nil : new
                            )
                        }
                    }
            }
        }
    }

    private func attendancePicker(for member: SeriesMember, current: SeriesRoundAttendance) -> some View {
        Menu {
            ForEach(SeriesRoundAttendanceStatus.allCases, id: \.rawValue) { status in
                Button {
                    Task {
                        await viewModel.updateAttendance(
                            seriesRoundID: seriesRound.id,
                            memberID: member.id,
                            status: status,
                            declinedNote: status == .no ? (declinedNote.isEmpty ? nil : declinedNote) : nil
                        )
                    }
                } label: {
                    HStack {
                        Text(statusLabel(status))
                        if current.status == status.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(attendanceStatusLabel(current.status))
                .fontStyle(kFontName, size: 14, weight: .medium)
                .foregroundStyle(Color.accentGreen)
        }
    }

    private func defaultAttendance(for member: SeriesMember) -> SeriesRoundAttendance {
        SeriesRoundAttendance(
            id: "\(seriesRound.id)_\(member.id)",
            seriesRoundID: seriesRound.id,
            memberID: member.id,
            status: SeriesRoundAttendanceStatus.pending.rawValue,
            parentID: viewModel.seriesID
        )
    }

    private func attendanceStatusLabel(_ status: String) -> String {
        switch status {
        case SeriesRoundAttendanceStatus.accepted.rawValue: return "Accepted"
        case SeriesRoundAttendanceStatus.no.rawValue: return "Can't make it"
        default: return "Pending"
        }
    }

    private func statusLabel(_ status: SeriesRoundAttendanceStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .no: return "Can't make it"
        }
    }
}
