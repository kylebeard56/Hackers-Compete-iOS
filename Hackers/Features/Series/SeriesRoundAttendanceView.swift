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
    @State private var showDeclinedReasonAlert = false
    @State private var declinedReasonInput = ""

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var sortedMembersForAttendance: [SeriesMember] {
        guard let currentID = viewModel.currentPlayerID else { return viewModel.activeMembers }
        let current = viewModel.activeMembers.filter { $0.playerID == currentID }
        let others = viewModel.activeMembers.filter { $0.playerID != currentID }
        return current + others
    }

    private var groupedOthers: (playing: [SeriesMember], declined: [SeriesMember], noResponse: [SeriesMember]) {
        let currentID = viewModel.currentPlayerID
        let others = viewModel.activeMembers.filter { $0.playerID != currentID }
        var playing: [SeriesMember] = []
        var declined: [SeriesMember] = []
        var noResponse: [SeriesMember] = []
        for member in others {
            let att = viewModel.attendanceByMember[member.id] ?? defaultAttendance(for: member)
            switch att.status {
            case SeriesRoundAttendanceStatus.accepted.rawValue: playing.append(member)
            case SeriesRoundAttendanceStatus.no.rawValue: declined.append(member)
            default: noResponse.append(member)
            }
        }
        return (playing, declined, noResponse)
    }

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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let currentMember = sortedMembersForAttendance.first, currentMember.playerID == viewModel.currentPlayerID {
                        currentUserRow(for: currentMember)
                    }

                    let groups = groupedOthers
                    if !groups.playing.isEmpty || !groups.declined.isEmpty || !groups.noResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if !groups.playing.isEmpty {
                                sectionHeader("Playing")
                                ForEach(groups.playing, id: \.id) { member in
                                    otherMemberRow(for: member)
                                }
                            }
                            if !groups.declined.isEmpty {
                                sectionHeader("Declined")
                                ForEach(groups.declined, id: \.id) { member in
                                    otherMemberRow(for: member)
                                }
                            }
                            if !groups.noResponse.isEmpty {
                                sectionHeader("No response")
                                ForEach(groups.noResponse, id: \.id) { member in
                                    otherMemberRow(for: member)
                                }
                            }
                        }
                    }
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

    private func currentUserRow(for member: SeriesMember) -> some View {
        let attendance = viewModel.attendanceByMember[member.id] ?? defaultAttendance(for: member)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                PlayerAvatarView(initials: member.name.initials, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("You")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)
                currentUserStatusChip(for: member, attendance: attendance)
            }
            .padding(12)
            .background(palette.cardColor)
            .cornerRadius(16)

            if attendance.status == SeriesRoundAttendanceStatus.no.rawValue {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reason")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    TextField("Optional note", text: $declinedNote)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .mutedGlassTextFieldContainer(cornerRadius: 12, baseFill: palette.cardEmbeddedRowBackground)
                }
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

    @ViewBuilder
    private func currentUserStatusChip(for member: SeriesMember, attendance: SeriesRoundAttendance) -> some View {
        Menu {
            Button {
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: seriesRound.id,
                        memberID: member.id,
                        status: .accepted,
                        declinedNote: nil
                    )
                }
            } label: {
                Label("Attending", systemImage: "checkmark")
            }
            Button {
                declinedReasonInput = attendance.declinedNote ?? ""
                showDeclinedReasonAlert = true
            } label: {
                Label("Declined", systemImage: "xmark")
            }
            Button {
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: seriesRound.id,
                        memberID: member.id,
                        status: .pending,
                        declinedNote: nil
                    )
                }
            } label: {
                Label("Pending", systemImage: "questionmark")
            }
        } label: {
            Group {
                switch attendance.status {
                case SeriesRoundAttendanceStatus.pending.rawValue:
                    Text("RSVP")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                case SeriesRoundAttendanceStatus.accepted.rawValue:
                    Text("Playing")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                case SeriesRoundAttendanceStatus.no.rawValue:
                    Text("Declined")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.systemError)
                default:
                    Text("RSVP")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
        }
        .alert("Why can't you make it?", isPresented: $showDeclinedReasonAlert) {
            TextField("Optional reason", text: $declinedReasonInput)
            Button("Save") {
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: seriesRound.id,
                        memberID: member.id,
                        status: .no,
                        declinedNote: declinedReasonInput.isEmpty ? nil : declinedReasonInput
                    )
                    declinedNote = declinedReasonInput
                }
            }
            Button("Skip", role: .cancel) {
                Task {
                    await viewModel.updateAttendance(
                        seriesRoundID: seriesRound.id,
                        memberID: member.id,
                        status: .no,
                        declinedNote: nil
                    )
                    declinedNote = ""
                }
            }
        } message: {
            Text("Add an optional note explaining why you can't attend.")
        }
    }

    private func otherMemberRow(for member: SeriesMember) -> some View {
        let attendance = viewModel.attendanceByMember[member.id] ?? defaultAttendance(for: member)
        let statusLabel = attendanceStatusLabel(attendance.status)

        return HStack(spacing: 12) {
            PlayerAvatarView(initials: member.name.initials, size: 36)
            Text(member.name.fullName)
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            Text(statusLabel)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .padding(10)
        .background(palette.cardEmbeddedRowBackground)
        .cornerRadius(14)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(Color.neutral)
            .alignLeading()
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
        case SeriesRoundAttendanceStatus.accepted.rawValue: return "Playing"
        case SeriesRoundAttendanceStatus.no.rawValue: return "Declined"
        default: return "No response"
        }
    }
}
