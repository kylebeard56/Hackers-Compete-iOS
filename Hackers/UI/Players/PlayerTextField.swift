//
//  PlayerTextField.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Introspect
import SwiftUI

struct PlayerTextField: View {
    @Binding var player: Player
    var placeholder: String = ""
    @Binding var isActive: Bool

    var onCommit: OnSelection?
    
    @State private var showColorPicker: Bool = false
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    var body: some View {
        HStack(spacing: kPadding) {
            Button(action: {
                showColorPicker = true
                Haptics.fire(.light)
            }) {
                Circle()
                    .fill(player.color)
                    .frame(width: 15, height: 15, alignment: .center)
            }
            
            TextField(placeholder, text: $player.name, onCommit: {
                focusedField = nil
                if let action = onCommit { action!() }
            })
            .font(.dmSans(size: 20, weight: .regular))
            .keyboardType(.alphabet)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.words)
            .submitLabel(onCommit == nil ? .done : .next)
            .focused($focusedField, equals: .field)
            .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
        }
        .resignKeyboardOnDragGesture()
        .modifier(BorderedTextFieldModifier(isActive: focusedField == .field || showColorPicker))
        .onChange(of: focusedField, perform: { focus in
            if focus != nil {
                Haptics.fire(.light)
            }
            isActive = focus != nil
        })
        .onChange(of: isActive, perform: { active in
            focusedField = active ? .field : nil
        })
        .sheet(isPresented: $showColorPicker) {
            PlayerColorSelector(color: $player.color, width: UIScreen.main.bounds.width - kPadding * 4)
                .presentationDetents([.height(100)])
                .presentationDragIndicator(.visible)
        }
    }
}

struct PlayerTextField_Previews: PreviewProvider {
    static var previews: some View {
        PlayerTextField(player: .player, isActive: .false)
    }
}
