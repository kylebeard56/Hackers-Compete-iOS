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
    
    private var isDisabled: Bool {
        players.filter(\.isPlaying).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        content
                            .padding(.horizontal, 20)
                            .alignTop()
                    }
                }
                
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
                        viewModel.players = players
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                }
                .alignBottom()
                .ignoresSafeArea(.keyboard)
                
                if focus != nil {
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
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 10)
           
            .navigationTitle("Edit your party")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
            })
        }
        .onAppear() { players = viewModel.players }
        .onChange(of: focus, perform: { _ in showColor = false })
        .background(Color.systemViewBackground)
        .padding(.top, 10)
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            InfoBanner(
                text: "Scores and teams will stay the same.",
                foregroundColor: Color.systemHackersGreen,
                backgroundColor: Color.systemHackersGreen.opacity(0.1)
            )
            
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
    static var previews: some View {
        EditPlayersView(viewModel: RoundViewModel())
            .holisticPreview()
    }
}
