//
//  ManagePlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/12/25.
//

import SwiftUI

/**
 AddPlayerView
 -------------
 1. POST offline player
 2. PUT offline player
 
 GameLobby
 -------------
 1. PUT offline participant
 
 ASSUMPTIONS:
 - RoundParticipant is created from Player.
 - Editing players will only change the participant, unless the player is yourself or offline (toggle to also update player profile)
 
 PHASES:
 1. Create an offline player
 2. Retrofit to edit offline player
 3.
 
 */

struct ManagePlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot = .init()
//    var existingPlayer: Player? = nil
//    var existingParticipant: RoundParticipant? = nil
    var onCreate: CallbackValue<Player>? = nil
    
    @State private var name = ""
    @State private var tee: Tee? = nil
    @State private var showTeeSelection = false
    @State private var handicapString = ""
    @State private var handicapValue: Int = 0
    
    @State private var player: Player = .init()
    @State private var participant: RoundParticipant = .init()
//    @State private var isEditing = false
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var canSave: Bool { name.isPopulated && tee.exists }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
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
                Text("Pick your course")
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignLeading()
                
                TextField("First last", text: $name)
                    .foregroundStyle(Color.foregroundPrimary)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(HackersTextFieldStyle())
            }

            
            TeeDropdown(
                tee: tee,
                segment: snapshot.holeSegment,
                onTap: { showTeeSelection = true }
            )
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Handicap")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                    
                    Spacer(minLength: 0)
                    
                    if snapshot.configuration.useHandicaps {
                        Chip.required
                    }
                }
                
                HStack(spacing: 12) {
                    TextField("0", text: $handicapString)
                        .foregroundStyle(Color.foregroundPrimary)
                        .keyboardType(.numberPad)
                    
                    // TODO: Clear button and focus state
                }
                .textFieldStyle(HackersTextFieldStyle())
                .onChange(of: handicapString) {
                    if let value = Int(handicapString.filter(\.isNumber)) {
                        handicapValue = min(max(value, 0), 36)
                        handicapString = String(handicapValue)
                    }
                }
                
                if !snapshot.configuration.useHandicaps {
                    Text("Handicaps aren’t enabled for this round, but you can still enter a value.")
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
    }
}

// MARK: - Header

extension ManagePlayerView {
    fileprivate var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Add players")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", onTap: { dismiss() })
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
        VStack(spacing: 16) {
            Line()
            
            PrimaryButton(
                appearance: .fill,
                title: "Add players",
                theme: palette.theme,
                isDisabled: .constant(!canSave),
                isLoading: .false,
                onTap: { print("add player") }
            )
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    ManagePlayerView()
}
