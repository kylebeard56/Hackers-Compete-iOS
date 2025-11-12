//
//  SearchBar.swift
//  Hackers
//
//  Created by Kyle Beard on 8/3/25.
//

import SwiftUI

struct SearchBar: View {
    @Environment(\.colorScheme) var colorScheme
    
    let placeholder: String
    let theme: PaletteTheme
    let initialValue: String
    let onDebounce: AsyncCallbackValue<String>?
    let onFocusChange: CallbackValue<Bool>?
    
    @State private var text: Debounce = .init(value: "")
    @FocusState private var focus: Bool
    
    init(
        placeholder: String = "Search...",
        initialValue: String = "",
        theme: PaletteTheme = .primary,
        onDebounce: AsyncCallbackValue<String>? = nil,
        onFocusChange: CallbackValue<Bool>? = nil
    ) {
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.text = .init(value: initialValue, milliseconds: 600)
        self.theme = theme
        self.onDebounce = onDebounce
        self.onFocusChange = onFocusChange
    }
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Icon(name: "magnifyingglass", size: 20, maxSize: 20, weight: .regular)
                    .foregroundStyle(Color.neutral3)
                
                TextField(placeholder, text: $text.value)
                    .fontStyle(.poppins, size: 17, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .autocorrectionDisabled(true)
                    .focused($focus)
                
                Spacer(minLength: 0)
                
                if focus && !text.value.isEmpty {
                    Button(action: {
                        text = .init(value: "")
                        Haptics.fire(.light)
                    }) {
                        Icon(name: "multiply.circle.fill", size: 15, weight: .solid)
                            .foregroundStyle(Color.neutral3)
                            .padding(2)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(palette.textField)
            .cornerRadius(12)
            
            if focus {
                Button(action: {
                    text = .init(value: "")
                    UIApplication.shared.endEditing()
                    Haptics.fire(.light)
                }) {
                    Text("Cancel")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .padding(.leading, 10)
                }
            }
        }
        .onChange(of: focus) { old, new in
            onFocusChange?(new)
        }
        .onReceive(text.$debouncedValue, perform: { value in
            Task {
                await onDebounce?(value)
            }
        })
    }
}

#Preview("Primary Light") {
    ZStack {
        DesignPalette(
            theme: .primary,
            scheme: .light
        ).backgroundColor
        
        SearchBar(theme: .primary)
            .padding(16)
            .alignTop()
    }
    .colorScheme(.light)
}

#Preview("Primary Dark") {
    ZStack {
        DesignPalette(
            theme: .primary,
            scheme: .dark
        ).backgroundColor
        
        SearchBar(theme: .primary)
            .padding(16)
            .alignTop()
    }
    .colorScheme(.dark)
}

#Preview("Secondary Light") {
    ZStack {
        DesignPalette(
            theme: .secondary,
            scheme: .light
        ).backgroundColor
        
        SearchBar(theme: .secondary)
            .padding(16)
            .alignTop()
    }
    .colorScheme(.light)
}

#Preview("Secondary Dark") {
    ZStack {
        DesignPalette(
            theme: .secondary,
            scheme: .dark
        ).backgroundColor
        
        SearchBar(theme: .secondary)
            .padding(16)
            .alignTop()
    }
    .colorScheme(.dark)
}
