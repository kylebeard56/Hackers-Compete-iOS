//
//  PickPlayersView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Introspect
import SwiftUI

struct PickPlayersView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @FocusState private var focus: String?
    @State private var showColor: Bool = false
    
    var body: some View {
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
                    title: "Next",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: $appSession.arePlayersEmpty,
                    isLoading: .false
                )
                .onTap {
                    appSession.goToSideGames()
                }
                .padding(.horizontal, 20)
            }
//                .padding(.bottom, focus != nil ? 80 : 0)
            .alignBottom()
            .ignoresSafeArea(.keyboard)
            
            if focus != nil {
                HStack(spacing: 20) {
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
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationTitle("Pick your players")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
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
        VStack(spacing: 20) {
//            Text("Nicknames and initials are ok, too.")
//                .font(.dmSans(size: 17, weight: .regular))
//                .foregroundColor(Color.systemBlack)
//                .alignLeading()
            
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

// MARK: - Text Field

struct PlayerTextField: View {
    @Binding var player: Player
    var placeholder: String = ""
    var onFocus: OnFocusSelection?
    
    @State private var showColorPicker: Bool = false
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                showColorPicker = true
                Haptics.fire(.light)
            }) {
                Circle()
                    .fill(player.color.value)
                    .frame(width: 15, height: 15, alignment: .center)
            }
            
            TextField(placeholder, text: $player.name)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.return)
                .focused($focusedField, equals: .field)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
        }
        .resignKeyboardOnDragGesture()
        .modifier(BorderedTextFieldModifier(isActive: focusedField == .field || showColorPicker))
        .onChange(of: focusedField, perform: { focus in
            if let action = onFocus { action!(focus != nil) }
            if focus != nil {
                Haptics.fire(.light)
            }
        })
        .sheet(isPresented: $showColorPicker) {
            PlayerColorSelector(color: $player.color, width: UIScreen.main.bounds.width - 64)
                .presentationDetents([.height(100)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Color Selector

struct PlayerColorSelector: View {
    @Environment(\.dismiss) var dismiss
    @Binding var color: GameColor
    var width: CGFloat
    var diameter: CGFloat = 24
    var keyboardEmbedded: Bool = false
    
    var body: some View {
        HStack(spacing: (width - diameter * 7) / 6) {
            makeCircle(color: GameColor.blue, selected: color == .blue)
            makeCircle(color: GameColor.green, selected: color == .green)
            makeCircle(color: GameColor.purple, selected: color == .purple)
            makeCircle(color: GameColor.indigo, selected: color == .indigo)
            makeCircle(color: GameColor.red, selected: color == .red)
            makeCircle(color: GameColor.pink, selected: color == .pink)
            makeCircle(color: GameColor.orange, selected: color == .orange)
        }
    }
    
    private func makeCircle(color: GameColor, selected: Bool) -> some View {
        Button(action: {
            self.color = color
            if !keyboardEmbedded { dismiss() } // Note: don't dismiss keyboard on color selection.
            Haptics.fire(.light)
        }) {
            VStack {
                if selected {
                    Circle()
                        .fill(color.value)
                        .frame(width: diameter, height: diameter)
                } else {
                    Circle()
                        .stroke(color.value, lineWidth: 3)
                        .frame(width: diameter, height: diameter)
                }
            }
        }
    }
}


// MARK: - Preview

struct PlayerEntry_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                PickPlayersView()
                    .environmentObject(AppSession())
            }
            .lightModePreview()
            NavigationStack {
                PickPlayersView()
                    .environmentObject(AppSession())
            }
            .darkModePreview()
        }
    }
}
