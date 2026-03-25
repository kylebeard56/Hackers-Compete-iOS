//
//  ManagePlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/12/25.
//

import AlertToast
import SwiftUI

struct ManagePlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    @State var participant: RoundParticipant?
    
    @State private var name = ""
    @State private var tee: Tee? = nil
    @State private var showTeeSelection = false
    @State private var handicapString = "0"
    @State private var handicapValue: Int = 0
    @State private var groupID: String? = nil
    @State private var teamID: String? = nil
    
    @State private var showHostChangeSheet = false
    @State private var userIsHost = false
    private var isHost: Bool { participant?.isHost ?? false }
    
    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    
    @FocusState private var focus: FocusField?
    private enum FocusField { case name, handicap }
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var canSave: Bool {
        name.isPopulated && tee.exists
    }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            theme: palette.theme,
            onScroll: { _ in }
        )
        .resignKeyboardOnTapGesture()
        .sheet(isPresented: $showTeeSelection) {
            TeeSelectionSheet(
                selectedTee: tee,
                maleTees: snapshot.course?.tees.male ?? [],
                femaleTees: snapshot.course?.tees.female ?? [],
                otherTees: snapshot.course?.tees.other ?? [],
                segment: snapshot.holeSegment,
                onChange: { t in
                    showTeeSelection = false
                    tee.toggle(to: t)
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHostChangeSheet) {
            ChangeHostView(snapshot: snapshot) { newHost in
                Task {
                    do {
                        try await roundSession.changeHost(to: newHost)
                        showHostChangeSheet = false
                        participant = snapshot.participants.first(where: { $0.id == participant?.id })
                    } catch {
                        // TODO: Handle error
                    }
                }
            }
        }
        .task {
            name = participant?.name.fullName ?? ""
            tee = snapshot.tees.first(where: { $0.id == participant?.teeBoxID }) ?? snapshot.defaultTee
            handicapValue = participant?.adjustedHandicap ?? 0
            handicapString = String(handicapValue)
            groupID = participant?.groupID
            teamID = participant?.teamID
            
            if let user = await AppData.shared.user {
                userIsHost = snapshot.participants.first(where: \.isHost)?.userID == user.id
            }
        }
        .alert(
            "Are you sure you want to remove \(participant?.name.fullName ?? "this player") from this round?",
            isPresented: $showRemoveAlert
        ) {
            Button("Yes, remove", role: .destructive) {
                isRemoving = true
                if let participant { onRemove(participant) }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Content

extension ManagePlayerView {
    private var content: some View {
        VStack(spacing: 16) {
            nameSection
            teeBoxSection
            teeGroupSection
            if snapshot.requiresTeams {
                teamSection
            }
            strokesSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
    
    private var nameSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Name")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 12) {
                TextField("First last", text: $name)
                    .fontStyle(kFontName, size: 17, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .textInputAutocapitalization(.words)
                    .focused($focus, equals: .name)
                
                Spacer(minLength: 0)
                
                if focus == .name && name.isPopulated {
                    ClearTextButton(theme: palette.theme, onTap: { name = "" })
                }
            }
            .borderedContentStyle(isActive: focus == .name, theme: palette.theme)
            
            Text("Name changes are applied to only this round.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var teeBoxSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Tee Box")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
            }

            TeeDropdown(
                tee: tee,
                segment: snapshot.holeSegment,
                onTap: { showTeeSelection = true }
            )
        }
    }
    
    private var teeGroupSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Tee Group")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
            }
            
            teeGroupDropdown
        }
    }
    
    private var teamSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Team")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
            }
            
            teamDropdown
        }
    }
    
    private var strokesSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Strokes")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 12) {
                TextField("0", text: $handicapString)
                    .fontStyle(kFontName, size: 17, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .handicap)
                
                Spacer(minLength: 0)
                
                if focus == .handicap && handicapString.isPopulated {
                    ClearTextButton(theme: palette.theme, onTap: { handicapString = "" })
                }
                
                Text("Max: 36")
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(Color.neutral3)
            }
            .borderedContentStyle(isActive: focus == .handicap, theme: palette.theme)
            .onChange(of: handicapString) {
                if let value = Int(handicapString.filter(\.isNumber)) {
                    handicapValue = min(max(value, 0), 36)
                    handicapString = String(handicapValue)
                }
            }
            
            if !snapshot.configuration.useHandicaps {
                Text("Net scoring using handicap strokes is not enabled yet for this round, but you can still enter a value.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                
                // TODO: Shortcut toggle to use handicaps here?
            }
        }
    }
}

extension ManagePlayerView {
    fileprivate func onFinish(_ p: RoundParticipant) {
        Task {
            // TODO: handle error display here before dismissing?
            try? await roundSession.update(participant: p)
            dismiss()
        }
    }
    
    fileprivate func onRemove(_ p: RoundParticipant) {
        Task {
            // TODO: handle error display here before dismissing?
            try? await roundSession.remove(participant: p)
            dismiss()
        }
    }
}

extension ManagePlayerView {
    fileprivate var teeGroupDropdown: some View {
        Menu {
            ForEach(snapshot.teeGroups.sorted(by: { $0.index < $1.index })) { group in
                Button {
                    Haptics.fire(.light)
                    groupID = group.id
                } label: {
                    if group.id == groupID {
                        Label(group.name, systemImage: "checkmark")
                    } else {
                        Text(group.name)
                    }
                }
            }
        } label: {
            HStack {
                if let groupID, let group = snapshot.teeGroups.first(where: { $0.id == groupID }) {
                    let startingHoleLabel = group.startingHoleDisplayLabel(in: snapshot.teeGroups)
                    VStack(spacing: 4) {
                        Text(group.name)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()
                        
                        HStack {
                            Text("Starting on Hole \(startingHoleLabel)")
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)
                            
                            if let teeTime = group.teeTime {
                                Dot()
                                
                                Text(teeTime)
                                    .fontStyle(kFontName, size: 14, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                } else {
                    Text("Select tee time group")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
                
                Icon(name: "f078", size: 13, weight: .solid)
                    .foregroundStyle(Color.neutral3)
            }
            .borderedContentStyle(theme: palette.theme)
        }
    }
    
    fileprivate var teamDropdown: some View {
        Menu {
            ForEach(snapshot.teams.sorted(by: { $0.index < $1.index })) { team in
                Button {
                    Haptics.fire(.light)
                    teamID = team.id
                } label: {
                    if team.id == teamID {
                        Label(team.name, systemImage: "checkmark")
                    } else {
                        Text(team.name)
                    }
                }
            }
        } label: {
            HStack {
                if let teamID, let team = snapshot.teams.first(where: { $0.id == teamID }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(team.teamColor.value)
                            .frame(width: 12, height: 12)
                        
                        Text(team.name)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()
                        
                        // [FUTURE] TODO: Add other plays on the team here?
                    }
                } else {
                    Text("Select team")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
                
                Icon(name: "f078", size: 13, weight: .solid)
                    .foregroundStyle(Color.neutral3)
            }
            .borderedContentStyle(theme: palette.theme)
        }
    }
}

// MARK: - Header

extension ManagePlayerView {
    fileprivate var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Edit player")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
}

// MARK: - Footer

extension ManagePlayerView {
    
    @ViewBuilder
    fileprivate var footer: some View {
        if focus.exists {
            EmptyView()
        } else {
            VStack(spacing: 16) {
                Line()
                
                HStack(spacing: 12) {
                    // Uncomment below if you want to make it where only the host can change hosts.
                    
                    //if (userIsHost && isHost) || !isHost {
                    PrimaryButton(
                        appearance: .fill,
                        title: isHost ? "Change host" : "Remove",
                        labelColor: isHost ? palette.foregroundColor : .white,
                        buttonColor: isHost ? palette.buttonColor : .systemError,
                        theme: palette.theme,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: $isRemoving,
                        onTap: {
                            if isHost {
                                showHostChangeSheet = true
                            } else {
                                showRemoveAlert = true
                            }
                        }
                    )
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Update player",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .constant(!canSave),
                        isLoading: .false,
                        onTap: finish
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func finish() {
        var p = participant ?? .init()
        p.name = Name(name)
        p.teeBoxID = tee?.id ?? ""
        p.originalHandicap = handicapValue
        p.adjustedHandicap = handicapValue
        p.groupID = groupID
        p.teamID = teamID
        onFinish(p)
    }
}

#Preview {
    Color.neutral
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: .true) {
            ManagePlayerView(roundSession: .init())
                .presentationDragIndicator(.visible)
    }
}
