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
    var onFocus: OnFocusSelection?
    
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
            PlayerColorSelector(color: $player.color, width: UIScreen.main.bounds.width - kPadding * 4)
                .presentationDetents([.height(100)])
                .presentationDragIndicator(.visible)
        }
    }
}

struct PlayerTextField_Previews: PreviewProvider {
    static var previews: some View {
        PlayerTextField(player: .player)
    }
}
