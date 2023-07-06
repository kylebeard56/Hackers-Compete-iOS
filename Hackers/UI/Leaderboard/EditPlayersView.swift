//
//  EditPlayersView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/30/23.
//

import SwiftUI

struct EditPlayersView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: RoundViewModel
    
    @FocusState private var focus: String?
    @State private var showColor: Bool = false
    
    @State private var players: [Player] = []
    @State private var showMissingPlayer: Bool = false
    
    private var isDisabled: Bool {
        players.filter(\.isPlaying).isEmpty
    }
    
    var body: some View {
        bodyView
            .padding(.bottom, 10)
            .background(Color.systemViewBackground)
    }
    
    var bodyView: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    Text("Edit your party")
                        .font(.dmSans(size: 28, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()

                    BackButton( icon: .xmark, onTap: { dismiss() })
                        .alignTrailing()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                ScrollView {
                    content
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .alignTop()
                }
            }
            
            if focus != nil {
                focusButtons
            } else {
                VStack(spacing: 20) {
                    Divider()
                    
                    BigButton(
                        title: "Update",
                        labelColor: .systemWhite,
                        buttonColor: .systemHackersGreen,
                        isDisabled: .false,
                        isLoading: .false
                    )
                    .onTap {
                        update()
                    }
                    .padding(.horizontal, 20)
                }
                .alignBottom()
            }
        }
        .onAppear() { players = viewModel.players }
        .onChange(of: focus, perform: { _ in showColor = false })
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            if showMissingPlayer {
                ErrorBanner(
                    title: "Missing player name",
                    subtitle: "Make sure everyone in your party has a name.",
                    onTap: { showMissingPlayer = false }
                )
            } else {
                InfoBanner(
                    text: "Scores, teams, and side games will stay the same.",
                    foregroundColor: Color.systemHackersGreen,
                    backgroundColor: Color.systemHackersGreen.opacity(0.1)
                )
            }
            
            ForEach(0..<players.count, id: \.self) { i in
                let player = players[i]
                HStack(spacing: 16) {
                    Button(action: {
                        focus = player.id
                        Haptics.fire(.light)
                    }) {
                        Circle()
                            .fill(player.color.value)
                            .frame(width: 15, height: 15, alignment: .center)
                    }
                    
                    TextField("Player \(i + 1)", text: $players[i].name)
                        .font(.dmSans(size: 20, weight: .regular))
                        .keyboardType(.alphabet)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.return)
                        .focused($focus, equals: player.id)
                        .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                }
                .modifier(BorderedTextFieldModifier(isActive: focus == player.id))
            }
        }
    }
    
    private var focusButtons: some View {
        HStack(spacing: 20) {
            if let i = players.firstIndex(where: { $0.id == focus }) {
                KeyboardColorButton(
                    selectedColor: players[i].color,
                    reveal: $showColor,
                    onSelect: { c in players[i].color = c }
                )
            }
            Spacer()
            KeyboardFloatingButton(
                systemIcon: "chevron.up",
                tint:  players.first?.id == focus ? .systemGray3 : .systemBlue,
                onTap: back)
            KeyboardFloatingButton(
                systemIcon: "chevron.down",
                tint: players.last?.id == focus ? .systemGray3 : .systemBlue,
                onTap: next)
            KeyboardDismissalButton()
        }
        .padding(.bottom, 10)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Update
    
    private func update() {
        /// NOTE:
        /// We will need to structure side games where the user picks the players who are playing if the # of playable players is
        /// outside of the range. For example, if 4 players in a group want to play Monkey in Middle, they'll need to pick the 3
        /// players who are playing and we track their IDs for players.
        
        if viewModel.players.filter(\.isPlaying).count != players.filter(\.isPlaying).count {
            Haptics.fire(.error)
            showMissingPlayer  = true
            return
        }
        
        viewModel.players = players
        dismiss()
    }
    
    // MARK: - Toolbar Shenanigans
    
    private func toolbar(color: Binding<GameColor>) -> some View {
        PlayerColorSelector(
            color: color,
            width: UIScreen.main.bounds.width * 0.65, // Note: No idea why 65% of full width worked here...
            diameter: 20,
            keyboardEmbedded: true
        )
    }
    
    private func next() {
        if let i = players.firstIndex(where: { $0.id == focus }) {
            focus = players[safe: i + 1]?.id
        }
    }
    
    private func back() {
        if let i = players.firstIndex(where: { $0.id == focus }) {
            focus = players[safe: i - 1]?.id
        }
    }
}

struct EditPlayersView_Previews: PreviewProvider {
    static var vm = RoundViewModel()
    static let players: [Player] = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
    
    static var previews: some View {
        EditPlayersView(viewModel: vm)
            .onAppear() { vm.players = players }
            .holisticPreview()
    }
}
