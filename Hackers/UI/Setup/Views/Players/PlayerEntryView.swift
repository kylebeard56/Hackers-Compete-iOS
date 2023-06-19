//
//  PlayerEntryView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Introspect
import SwiftUI

struct PlayerEntryView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @FocusState private var focus: String?
    @State private var showColor: Bool = false
    
    var body: some View {
        ZStack {
            ScrollView {
                content
            }
            .alignTop()
            
            BigButton(
                title: "Start round",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: $appSession.arePlayersEmpty,
                isLoading: .false,
                onTap: { Task { await appSession.startNewRound() } }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .alignBottom()
            .ignoresSafeArea(.keyboard)

            if focus != nil {
                HStack(spacing: 16) {
                    if let i = appSession.players.firstIndex(where: { $0.id == focus }) {
                        KeyboardColorButton(
                            selectedColor: appSession.players[i].color,
                            reveal: $showColor,
                            onSelect: { c in appSession.players[i].color = c }
                        )
                    }
                    Spacer()
                    KeyboardFloatingButton(
                        systemIcon: "chevron.up",
                        tint:  appSession.players.first?.id == focus ? .systemGray3 : .systemBlue,
                        onTap: back)
                    KeyboardFloatingButton(
                        systemIcon: "chevron.down",
                        tint: appSession.players.last?.id == focus ? .systemGray3 : .systemBlue,
                        onTap: next)
                    KeyboardDismissalButton()
                }
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
            }
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationTitle("Who is playing?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
        })
        .onAppear() {
            if appSession.players[0].name.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                    focus = appSession.players[0].id
                })
            }
        }
        .onChange(of: focus, perform: { _ in showColor = false })
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            ForEach(0..<appSession.players.count, id: \.self) { i in
                let player = appSession.players[i]
                HStack(spacing: 16) {
                    Button(action: {
                        focus = player.id
                        Haptics.fire(.light)
                    }) {
                        Circle()
                            .fill(player.color.value)
                            .frame(width: 15, height: 15, alignment: .center)
                    }
                    
                    TextField("Player \(i + 1)", text: $appSession.players[i].name)
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
        .padding(16)
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
        if let i = appSession.players.firstIndex(where: { $0.id == focus }) {
            focus = appSession.players[safe: i + 1]?.id
        }
    }
    
    private func back() {
        if let i = appSession.players.firstIndex(where: { $0.id == focus }) {
            focus = appSession.players[safe: i - 1]?.id
        }
    }
}

struct PlayerEntry_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                PlayerEntryView()
                    .environmentObject(AppSession())
            }
            .lightModePreview()
            NavigationStack {
                PlayerEntryView()
                    .environmentObject(AppSession())
            }
            .darkModePreview()
        }
    }
}
