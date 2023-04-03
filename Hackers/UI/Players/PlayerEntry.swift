//
//  PlayerEntry.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Introspect
import SwiftUI

struct PlayerEntry: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @FocusState private var focus: String?
    @State private var showColor: Bool = false
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case one, two, three, four }
    
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
            .padding(.horizontal, kPadding)
            .padding(.vertical, kPadding / 2)
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
        VStack(spacing: kPadding) {
            ForEach(0..<appSession.players.count, id: \.self) { i in
                let player = appSession.players[i]
                HStack(spacing: kPadding) {
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
            
//            HStack(spacing: kPadding) {
//                Button(action: {
//                    focusedField = .one
//                    Haptics.fire(.light)
//                }) {
//                    Circle()
//                        .fill(appSession.players[0].color.value)
//                        .frame(width: 15, height: 15, alignment: .center)
//                }
//
//                TextField("Player 1", text: $appSession.players[0].name, onCommit: {
////                    if appSession.players[1].name.isEmpty {
////                        focusedField = .two
////                    }
//                })
//                .font(.dmSans(size: 20, weight: .regular))
//                .keyboardType(.alphabet)
//                .disableAutocorrection(true)
//                .textInputAutocapitalization(.words)
//                .submitLabel(.next)
//                .focused($focusedField, equals: .one)
//                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
//            }
//            .modifier(BorderedTextFieldModifier(isActive: focusedField == .one))
//
//            HStack(spacing: kPadding) {
//                Circle()
//                    .fill(appSession.players[1].color.value)
//                    .frame(width: 15, height: 15, alignment: .center)
//
//                TextField("Player 2", text: $appSession.players[1].name, onCommit: {
////                    if appSession.players[2].name.isEmpty {
////                        focusedField = .three
////                    }
//                })
//                .font(.dmSans(size: 20, weight: .regular))
//                .keyboardType(.alphabet)
//                .disableAutocorrection(true)
//                .textInputAutocapitalization(.words)
//                .submitLabel(.next)
//                .focused($focusedField, equals: .two)
//                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
//            }
//            .modifier(BorderedTextFieldModifier(isActive: focusedField == .two))
//
//            HStack(spacing: kPadding) {
//                Circle()
//                    .fill(appSession.players[2].color.value)
//                    .frame(width: 15, height: 15, alignment: .center)
//
//                TextField("Player 3", text: $appSession.players[2].name, onCommit: {
////                    if appSession.players[3].name.isEmpty {
////                        focusedField = .four
////                    }
//                })
//                .font(.dmSans(size: 20, weight: .regular))
//                .keyboardType(.alphabet)
//                .disableAutocorrection(true)
//                .textInputAutocapitalization(.words)
//                .submitLabel(.next)
//                .focused($focusedField, equals: .three)
//                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
//            }
//            .modifier(BorderedTextFieldModifier(isActive: focusedField == .three))
//
//            HStack(spacing: kPadding) {
//                Circle()
//                    .fill(appSession.players[3].color.value)
//                    .frame(width: 15, height: 15, alignment: .center)
//
//                TextField("Player 4", text: $appSession.players[4].name)
//                .font(.dmSans(size: 20, weight: .regular))
//                .keyboardType(.alphabet)
//                .disableAutocorrection(true)
//                .textInputAutocapitalization(.words)
//                .submitLabel(.return)
//                .focused($focus, equals: appSession.players[3].color)
//                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
//            }
//            .modifier(BorderedTextFieldModifier(isActive: focusedField == .four))
        }
        .padding(kPadding)
//        .toolbar {
//            ToolbarItem(placement: .keyboard) {
//                if focusedField == .one {
//                    toolbar(color: $appSession.players[0].color)
//                }
//                if focusedField == .two {
//                    toolbar(color: $appSession.players[1].color)
//                }
//                if focusedField == .three {
//                    toolbar(color: $appSession.players[2].color)
//                }
//                if focusedField == .four {
//                    toolbar(color: $appSession.players[3].color)
//                }
//            }
//        }
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
                PlayerEntry()
                    .environmentObject(AppSession())
            }
            .lightModePreview()
            NavigationStack {
                PlayerEntry()
                    .environmentObject(AppSession())
            }
            .darkModePreview()
        }
    }
}
