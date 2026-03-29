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
    let callToAction: String
    let theme: PaletteTheme
    let initialValue: String
    let autocapitalization: TextInputAutocapitalization
    let onDebounce: AsyncCallbackValue<String>?
    /// Fires on every keystroke (not debounced). Use with `onDebounce` when the parent needs the field text for layout before debounce fires.
    let onTextChange: CallbackValue<String>?
    let onFocusChange: CallbackValue<Bool>?
    private let debounceMilliseconds: Int
    
    @State private var text: Debounce = .init(value: "")
    @FocusState private var focus: Bool
    
    init(
        placeholder: String = "Search...",
        callToAction: String = "Cancel",
        initialValue: String = "",
        autocapitalization: TextInputAutocapitalization = .sentences,
        theme: PaletteTheme = .primary,
        milliseconds: Int = 600,
        onDebounce: AsyncCallbackValue<String>? = nil,
        onTextChange: CallbackValue<String>? = nil,
        onFocusChange: CallbackValue<Bool>? = nil
    ) {
        self.placeholder = placeholder
        self.callToAction = callToAction
        self.initialValue = initialValue
        self.autocapitalization = autocapitalization
        self.debounceMilliseconds = milliseconds
        self.text = .init(value: initialValue, milliseconds: milliseconds)
        self.theme = theme
        self.onDebounce = onDebounce
        self.onTextChange = onTextChange
        self.onFocusChange = onFocusChange
    }
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    
    var body: some View {
        HStack(spacing: 0) {
            if palette.theme == .glass {
                searchBarContent
                    .glassCardEffect(shape: .capsule)
            } else {
                searchBarContent
                    .background(palette.searchBar)
                    .cornerRadius(12)
            }

            
            if focus {
                Button(action: {
                    text = .init(value: "", milliseconds: debounceMilliseconds)
                    onTextChange?("")
                    UIApplication.shared.endEditing()
                    Haptics.fire(.light)
                }) {
                    Text(callToAction)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                        .padding(.leading, 10)
                }
            }
        }
        .onChange(of: focus) { old, new in
            onFocusChange?(new)
        }
        .onChange(of: text.value) { _, newValue in
            onTextChange?(newValue)
        }
        .onReceive(text.$debouncedValue, perform: { value in
            Task {
                await onDebounce?(value)
            }
        })
    }
    
    private var searchBarContent: some View {
        HStack(spacing: 12) {
            Icon(name: "magnifyingglass", size: 20, maxSize: 20, weight: .regular)
                .foregroundStyle(Color.neutral3)
            
            TextField(placeholder, text: $text.value)
                .fontStyle(kFontName, size: 17, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(autocapitalization)
                .focused($focus)
            
            Spacer(minLength: 0)
            
            if focus && !text.value.isEmpty {
                Button(action: {
                    text = .init(value: "", milliseconds: debounceMilliseconds)
                    onTextChange?("")
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
