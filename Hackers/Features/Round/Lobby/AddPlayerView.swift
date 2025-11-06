//
//  AddPlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/3/25.
//

import SwiftUI

struct AddPlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot
    var onConfirm: CallbackValue<[RoundParticipant]>?
    
    @State private var searchText: String = ""
    @State private var addedPlayers: [RoundParticipant] = []
    @State private var showAddEditPlayer: Bool = false
    
    let addEditSourceID = "addEdit"
    @Namespace private var addEditTransition
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var existingPlayers: [RoundParticipant] { snapshot.participants }
    private var playerCount: Int { existingPlayers.count + addedPlayers.count }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .sheet(isPresented: $showAddEditPlayer) {
            Text("TODO")
                .navigationTransition(.zoom(sourceID: addEditSourceID, in: addEditTransition))
                .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            if searchText.isPopulated {
                Text("show players from DB here")
            } else {
                // TODO: Show
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var addOfflineButton: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Add offline player",
            icon: "f234",
            iconWeight: .solid,
            labelColor: palette.foregroundColor,
            buttonColor: palette.buttonColor,
            fillWidth: true,
            isDisabled: .false,
            isLoading: .false,
            onTap: {
                showAddEditPlayer = true
            }
        )
        .matchedTransitionSource(id: addEditSourceID, in: addEditTransition)
    }
    
    // TODO: Add/Edit Player
    // Name (first, last)? or do we split by name
    // Tee (set to default)
    // Handicap (if configured)
    // Tee Group (if configured)
    // Team (if configured)
}

extension AddPlayerView {
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
            
            SearchBar(
                placeholder: "Search players",
                onDebounce: { text in
                    print("onDebounce \(text)")
                    searchText = text
                    // TODO: Query users for players to add (how do we do this?)
                    //await viewModel.searchCourses(for: text, using: kGreenville)
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
    
    fileprivate var footer: some View {
        VStack(spacing: 16) {
            Line()
            
            if addedPlayers.isEmpty {
                addOfflineButton
                    .padding(.horizontal, 16)
            } else {
                HStack(spacing: 16) {
                    PrimaryButton(
                        appearance: .fill,
                        icon: "f234",
                        iconWeight: .solid,
                        buttonColor: palette.buttonColor,
                        theme: palette.theme,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showAddEditPlayer = true }
                    )
                    .matchedTransitionSource(id: addEditSourceID, in: addEditTransition)
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Add \(addedPlayers.count) players",
                        theme: palette.theme,
                        isDisabled: .constant(addedPlayers.isEmpty),
                        isLoading: .false,
                        onTap: { onConfirm?(addedPlayers) }
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    Color.backgroundPrimary.sheet(isPresented: .true) {
        AddPlayerView(snapshot: .mock())
            .presentationDragIndicator(.visible)
    }
}
