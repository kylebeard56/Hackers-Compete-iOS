//
//  BigButton.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

enum BigButtonStyle {
    case outline, solid
}

struct BigButton: View {
    var style: BigButtonStyle = .solid
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
            if style == .solid {
                Button(action: buttonTapped) { button }
                    .frame(height: height)
                    .foregroundColor(Color.white)
                    .background(isDisabled ? Color.systemGray2 : buttonColor)
                    .cornerRadius(8)
                    .disabled(isDisabled)
            }
            if style == .outline {
                Button(action: buttonTapped) { button }
                    .frame(height: height)
                    .foregroundColor(isDisabled ? Color.systemGray2 : labelColor)
                    .background(Color.systemClear)
                    .border(isDisabled ? Color.systemGray2 : buttonColor, width: 5, cornerRadius: 8)
                    .cornerRadius(8)
                    .disabled(isDisabled)
            }
        }
    }
    
    private var button: some View {
        HStack(spacing: kPadding) {
            Spacer()
            if let icon = appleIcon {
                Image(systemName: icon)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(labelColor)
            }
            if let icon = awesomeIcon {
                AwesomeImage(icon: icon, style: .regular, size: fontSize, color: labelColor)
            }
            Text(title)
                .font(.dmSans(size: fontSize, weight: .bold))
                .foregroundColor(isDisabled && style == .outline ? Color.systemGray : labelColor)
            if isLoading && !isDisabled {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: labelColor))
            }
            Spacer()
        }
    }
    
    private func buttonTapped() {
        if let action = onTap {
            Haptics.fire(.light)
            action()
        }
    }
}

struct BigButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: kPadding) {
            Group {
                BigButton(title: "Continue", isDisabled: .false, isLoading: .false, onTap: {})
                BigButton(title: "Continue", isDisabled: .true, isLoading: .false, onTap: {})
                BigButton(title: "Continue", isDisabled: .false, isLoading: .true, onTap: {})
                BigButton(title: "Continue", isDisabled: .true, isLoading: .true, onTap: {})
            }

            Divider()
            
            Group {
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

            Divider()
            
            Group {
                BigButton(
                    style: .outline,
                    title: "Continue",
                    labelColor: .systemBlue,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {})
                BigButton(
                    style: .outline,
                    title: "Continue",
                    labelColor: .systemBlue,
                    isDisabled: .true,
                    isLoading: .false,
                    onTap: {})
                BigButton(
                    style: .outline,
                    title: "Continue",
                    labelColor: .systemBlue,
                    isDisabled: .false,
                    isLoading: .true,
                    onTap: {})
                BigButton(
                    style: .outline,
                    title: "Continue",
                    labelColor: .systemBlue,
                    isDisabled: .true,
                    isLoading: .true,
                    onTap: {})
            }
        }
        .padding(kPadding)
    }
}

