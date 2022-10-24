//
//  BigButton.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

struct BigButton: View {
    var title: String
    var appleIcon: String?
    var awesomeIcon: Awesome?
    var labelColor: Color = .white
    var buttonColor: Color = .systemBlue
    var height: CGFloat = 56
    var fontSize: CGFloat = 20
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: OnSelection
    
    var body: some View {
        VStack {
            Button(action: buttonTapped) {
                HStack(spacing: kPadding) {
                    Spacer()
                    if let icon = appleIcon {
                        Image(systemName: icon)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(labelColor)
                    }
                    if let icon = awesomeIcon {
                        AwesomeImage(icon: icon, style: .solid, size: fontSize, color: labelColor)
                    }
                    Text(title)
                        .font(.dmSans(size: fontSize, weight: .bold))
                        .foregroundColor(labelColor)
                    if isLoading && !isDisabled {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: labelColor))
                    }
                    Spacer()
                }
            }
            .frame(height: height)
            .foregroundColor(Color.white)
            .background(isDisabled ? Color.systemGray2 : buttonColor)
            .cornerRadius(8)
            .disabled(isDisabled)
        }
    }
    
    private func buttonTapped() {
        if let action = onTap {
            action()
        }
    }
}

struct BigButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: kPadding) {
            BigButton(title: "Continue", isDisabled: .false, isLoading: .false, onTap: {})
            BigButton(title: "Continue", isDisabled: .true, isLoading: .false, onTap: {})
            BigButton(title: "Continue", isDisabled: .false, isLoading: .true, onTap: {})
            BigButton(title: "Continue", isDisabled: .true, isLoading: .true, onTap: {})
            Divider()
            BigButton(
                title: "Continue",
                labelColor: .black,
                buttonColor: .yellow,
                isDisabled: .false,
                isLoading: .false,
                onTap: {})
            BigButton(
                title: "Continue",
                labelColor: .black,
                buttonColor: .yellow,
                isDisabled: .false,
                isLoading: .true,
                onTap: {})
            BigButton(
                title: "Continue",
                labelColor: .black,
                buttonColor: .yellow,
                isDisabled: .true,
                isLoading: .true,
                onTap: {})
        }
        .padding(kPadding)
    }
}

