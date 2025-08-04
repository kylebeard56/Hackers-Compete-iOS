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
    let background: Color
    let initialValue: String
    let onDebounce: ((String) async -> Void)?
    
    @State private var text: Debounce = .init(value: "")
    @FocusState private var focus: Bool
    
    init(
        placeholder: String = "Search...",
        initialValue: String = "",
        background: Color = .hackersGray6,
        onDebounce: ((String) async -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.text = .init(value: initialValue, milliseconds: 600)
        self.background = background
        self.onDebounce = onDebounce
    }
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Icon(name: "magnifyingglass", size: 20, maxSize: 20, weight: .regular)
                    .foregroundStyle(Color.hackersGray3)
                
                TextField(placeholder, text: $text.value)
                    .fontStyle(.poppins, size: 17, weight: .regular)
                    .foregroundStyle(Color.hackersForeground)
                    .focused($focus)
                
                Spacer(minLength: 0)
                
                if focus && !text.value.isEmpty {
                    Button(action: {
                        text = .init(value: "")
                        Haptics.fire(.light)
                    }) {
                        Icon(name: "multiply.circle.fill", size: 13, weight: .solid)
                            .foregroundStyle(Color.hackersGray3)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(background)
            .cornerRadius(12)
            
            if focus {
                Button(action: {
                    text = .init(value: "")
                    UIApplication.shared.endEditing()
                    Haptics.fire(.light)
                }) {
                    Text("Cancel")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.hackersForeground)
                        .padding(.leading, 10)
                }
            }
        }
        .onReceive(text.$debouncedValue, perform: { value in
            if value.isPopulated && value != initialValue {
                Task {
                    await onDebounce?(value)
                }
            }
        })
    }
}

#Preview {
    ZStack {
        Color.hackersBackground
        SearchBar(initialValue: "")
            .padding(16)
            .alignTop()
    }
}
