//
//  ChangeHostView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/5/26.
//

import SwiftUI

struct ChangeHostView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot
    var onChange: CallbackValue<RoundParticipant>? = nil
    
    @State private var currentHost: RoundParticipant?
    @State private var selectedParticipant: RoundParticipant?
    @State private var searchText = ""
    @State private var searchedPlayers: [RoundParticipant] = []
    @State private var searchFocused = false
    @State private var isSearchingPlayers = false
    
    @State private var changeConfirmed = false
    
    private var sortedParticipants: [RoundParticipant] {
        snapshot.participants.sorted { (lhs: RoundParticipant, rhs: RoundParticipant) -> Bool in
            if lhs.isHost != rhs.isHost { return lhs.isHost }

            return lhs.name
                .fullName
                .localizedCaseInsensitiveCompare(rhs.name.fullName) == .orderedAscending
        }
    }
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Change host")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }
            
            Text("The host has full control of the lobby and round, including updating scores for all players during and after the round.")
                .fontStyle(.poppins, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
//            VStack(spacing: 8) {
//                SearchBar(
//                    placeholder: "Search players",
//                    callToAction: "Cancel",
//                    autocapitalization: .words,
//                    milliseconds: 0,
//                    onDebounce: { text in
//                        searchedPlayers = snapshot.participants.filter { $0.name.matches(text) }
//                    },
//                    onFocusChange: { value in
//                        print("onFocusChange \(value)")
//                        searchFocused = value
//                    }
//                )
//            }
            
            ScrollView(showsIndicators: false) {
                ForEach(sortedParticipants, id: \.self) { participant in
                    row(for: participant)
                    Line()
                }
            }
            
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Confirm host",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(selectedParticipant == nil),
                isLoading: $changeConfirmed,
                onTap: {
                    if let selectedParticipant {
                        changeConfirmed = true
                        onChange?(selectedParticipant)
                    }
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(palette.backgroundColor)
        .onAppear() {
            currentHost = snapshot.participants.first(where: { $0.isHost })
        }
        .resignKeyboardOnTapGesture()
    }
    
    @ViewBuilder
    private func row(for participant: RoundParticipant) -> some View {
        let isSelected = selectedParticipant == participant
        
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.cardColor)
                    .frame(width: 36, height: 36)
                Text(participant.name.initials)
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            Text(participant.name.fullName)
                .fontStyle(.poppins, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            Spacer(minLength: 0)
            
            Button {
                if participant.isHost {
                    Haptics.fire(.warning)
                    return
                }
                Haptics.fire(.light)
                selectedParticipant = isSelected ? nil : participant
            } label: {
                Group {
                    if participant.isHost {
                        Chip(
                            text: "Current host",
                            size: .xSmall,
                            style: .fill,
                            tint: .accentPurple
                        )
                    } else if isSelected {
                        NavButton(
                            icon: "f00c",
                            size: 14,
                            color: .white,
                            background: .accentPurple
                        )
                        .disabled(true)
                    } else {
                        Circle()
                            .strokeBorder(.neutral3, lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                }
            }
        }
    }
}
