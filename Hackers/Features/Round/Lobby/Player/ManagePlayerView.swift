//
//  ManagePlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/12/25.
//

import SwiftUI

struct PlayerData {
    var name: String = ""
    var tee: Tee?
    var handicap: Int = 0
    
    func participant(for roundID: String) -> RoundParticipant {
        .init(
            name: .init(name),
            teeBoxID: tee?.id ?? "",
            originalHandicap: handicap,
            adjustedHandicap: handicap,
            parentID: roundID
        )
    }
}

struct ManagePlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot = .init()
    var onFinish: CallbackValue<PlayerData>? = nil
    // TODO: Update verbiage (new player, edit player, etc)
    
    @State private var name = ""
    @State private var tee: Tee? = nil
    @State private var showTeeSelection = false
    @State private var handicapString = "0"
    @State private var handicapValue: Int = 0
    
    @FocusState private var focus: FocusField?
    private enum FocusField { case name, handicap }
    
    @State private var player: Player = .init()
    @State private var participant: RoundParticipant = .init()
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var canSave: Bool { name.isPopulated && tee.exists }
    
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
                segment: snapshot.holeSegment,
                onChange: { t in
                    showTeeSelection = false
                    tee.toggle(to: t)
                }
            )
            .presentationDragIndicator(.visible)
        }
        .task {
            tee = snapshot.defaultTee
        }
    }
}

// MARK: - Content

extension ManagePlayerView {
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Name")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Spacer(minLength: 0)
                    
                    if name.isEmpty {
                        Chip.required
                    } else {
                        Chip.requiredConfirmation
                    }
                }
                
                HStack(spacing: 12) {
                    TextField("First last", text: $name)
                        .fontStyle(.poppins, size: 17, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .textInputAutocapitalization(.words)
                        .focused($focus, equals: .name)
                    
                    Spacer(minLength: 0)
                    
                    if focus == .name && name.isPopulated {
                        ClearTextButton(theme: palette.theme, onTap: { name = "" })
                    }
                }
                .borderedContentStyle(isActive: focus == .name, theme: palette.theme)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Tee Box")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Spacer(minLength: 0)
                    
                    if tee.doesNotExist {
                        Chip.required
                    } else {
                        Chip.requiredConfirmation
                    }
                }

                TeeDropdown(
                    tee: tee,
                    segment: snapshot.holeSegment,
                    onTap: { showTeeSelection = true }
                )
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Strokes")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    
                    Spacer(minLength: 0)
                    
//                    if snapshot.configuration.useHandicaps {
//                        Chip.required
//                    }
                }
                
                HStack(spacing: 12) {
                    TextField("0", text: $handicapString)
                        .fontStyle(.poppins, size: 17, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .handicap)
                    
                    Spacer(minLength: 0)
                    
                    if focus == .handicap && handicapString.isPopulated {
                        ClearTextButton(theme: palette.theme, onTap: { handicapString = "" })
                    }
                    
                    Text("Max: 36")
                        .fontStyle(.poppins, size: 15, weight: .regular)
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
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                    
                    // TODO: Shortcut toggle to use handicaps here?
                }
            }
            
            Spacer(minLength: 0)
            
            // TODO: Tee group (with option to create new?)
            
            // TODO: Team (with option to create new?)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Header

extension ManagePlayerView {
    fileprivate var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("New player")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }
            
            Text("This player can be managed by anyone during the round or linked to a Hackers account upon joining.")
                .fontStyle(.poppins, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
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
                
                PrimaryButton(
                    appearance: .fill,
                    title: "Create offline player",
                    labelColor: palette.backgroundColor,
                    buttonColor: palette.foregroundColor,
                    theme: palette.theme,
                    isDisabled: .constant(!canSave),
                    isLoading: .false,
                    onTap: finish
                )
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func finish() {
        let data = PlayerData(name: name, tee: tee, handicap: handicapValue)
        onFinish?(data)
    }
}

#Preview {
    Color.neutral
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: .true) {
            ManagePlayerView()
                .presentationDragIndicator(.visible)
    }
}
