//
//  SmallButton.swift
//  Hackers
//
//  Created by Kyle Beard on 6/21/23.
//

import SwiftUI

struct SmallButton: View, OnSelectable {
    @Environment(\.colorScheme) var colorScheme
    var title: String
    var appleIcon: String?
    var awesomeIcon: Awesome?
    var awesomeIconRaw: String?
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    private var foregroundColor: Color { isDisabled ? .systemGray : .systemBlack }
    private var backgroundColor: Color { colorScheme.superlightGray }
    private let height: CGFloat = 40
    private let radius: CGFloat = 8
    private let fontSize: CGFloat = 15
    
    var body: some View {
        Button(action: buttonTapped) {
            button
        }
        .frame(height: height)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(radius)
        .disabled(isDisabled)
    }
    
    private var button: some View {
        HStack(spacing: 16) {
            Spacer()
            if let icon = appleIcon {
                Image(systemName: icon)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
            if let icon = awesomeIcon {
                AwesomeImage(icon: icon, style: .regular, size: fontSize, color: foregroundColor)
            }
            Text(title)
                .font(.dmSans(size: fontSize, weight: .bold))
                .foregroundColor(foregroundColor)
            if isLoading && !isDisabled {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
            }
            Spacer()
        }
    }
    
    private func buttonTapped() {
        triggerOnTap()
        Task {
            await triggerOnTapAsync()
        }
    }
}

struct SmallButton_Previews: PreviewProvider {
    static var previews: some View {
        SmallButton(title: "This is a small button", isDisabled: .false, isLoading: .false)
    }
}
