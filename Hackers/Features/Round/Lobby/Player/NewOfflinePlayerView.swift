//
//  NewOfflinePlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/13/25.
//

import SwiftUI

struct NewOfflinePlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var text: String = ""
    var onCreate: CallbackValue<Name>? = nil
    
    @State private var name = ""
    @FocusState private var focus: Bool
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("New offline player")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Enter player name", text: $name)
                        .fontStyle(.poppins, size: 17, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .textInputAutocapitalization(.words)
                        .focused($focus)
                    
                    Spacer(minLength: 0)
                    
                    if focus && name.isPopulated {
                        ClearTextButton(theme: palette.theme, onTap: { name = "" })
                    }
                }
                .borderedContentStyle(isActive: focus, theme: palette.theme)
                
                Text("This player can be managed by anyone during the round or linked to a Hackers account upon joining.")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }
            
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Create",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(name.isEmpty),
                isLoading: .false,
                onTap: {
                    onCreate?(.init(name))
                }
            )
        }
        .padding(16)
        .background(palette.backgroundColor)
        .onAppear() {
            name = text
        }
        .task(delay: 0.2) {
            focus = true
        }
        .resignKeyboardOnTapGesture()
    }
}

#Preview {
    Color.neutral.sheet(isPresented: .true) {
        NewOfflinePlayerView()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
    
}
