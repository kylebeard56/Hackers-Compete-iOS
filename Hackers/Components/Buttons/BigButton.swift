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

struct BigButton: View, OnSelectable {
    var style: BigButtonStyle = .solid
    var title: String
    var subtitle: String?
    var appleIcon: String?
    var awesomeIcon: Awesome?
    var awesomeIconRaw: String?
    var labelColor: Color = .white
    var subtitleColor: Color = .white
    var buttonColor: Color = .systemHackersGreen
    var gradient: LinearGradient?
    var height: CGFloat = 56
    var fillContainer: Bool = false
    var fontSize: CGFloat = 20
    var radius: CGFloat = 12
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    var body: some View {
        if fillContainer {
            filledButtons
        } else {
           fixedButtons
        }
    }
    
    private var filledButtons: some View {
        VStack {
            if style == .solid {
                Button(action: buttonTapped) { button.alignMiddle() }
                    .foregroundColor(Color.white)
                    .background(buttonGradient)
                    .cornerRadius(radius)
                    .disabled(isDisabled)
            }
            if style == .outline {
                Button(action: buttonTapped) { button.alignMiddle() }
                    .foregroundColor(isDisabled ? Color.systemGray2 : labelColor)
                    .background(Color.systemClear)
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(buttonGradient, lineWidth: 5))
                    .cornerRadius(radius)
                    .disabled(isDisabled)
            }
        }
    }
    
    private var fixedButtons: some View {
        VStack {
            if style == .solid {
                Button(action: buttonTapped) { button }
                    .frame(height: height)
                    .foregroundColor(Color.white)
                    .background(buttonGradient)
                    .cornerRadius(radius)
                    .disabled(isDisabled)
            }
            if style == .outline {
                Button(action: buttonTapped) { button }
                    .frame(height: height)
                    .foregroundColor(isDisabled ? Color.systemGray2 : labelColor)
                    .background(Color.systemClear)
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(buttonGradient, lineWidth: 5))
                    .cornerRadius(radius)
                    .disabled(isDisabled)
            }
        }
    }
    
    private var buttonGradient: LinearGradient {
        if isDisabled {
            return LinearGradient(colors: [Color.systemGray2], startPoint: .leading, endPoint: .trailing)
        } else {
            return gradient ?? LinearGradient(colors: [buttonColor], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var button: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Spacer()
                if let icon = appleIcon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(labelColor)
                }
                if let icon = awesomeIcon {
                    AwesomeImage(icon: icon, style: .regular, size: fontSize, color: labelColor)
                }
                if let icon = awesomeIconRaw {
                    AwesomeImage(rawIcon: icon.unicode, style: .regular, size: fontSize, color: labelColor)
                }
                Text(title)
                    .font(.dmSans(size: fontSize, weight: .bold))
                    .foregroundColor(isDisabled && style == .outline ? Color.systemGray : labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if isLoading && !isDisabled {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: labelColor))
                }
                Spacer()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.dmSans(size: 11, weight: .medium))
                    .foregroundColor(isDisabled && style == .outline ? Color.systemGray : subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.5)
            }
        }
    }
    
    private func buttonTapped() {
        triggerOnTap()
        Task {
            await triggerOnTapAsync()
        }
    }
}

struct BigButton_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    BigButton(title: "Continue", isDisabled: .false, isLoading: .false)
                    BigButton(title: "Continue", isDisabled: .true, isLoading: .false)
                    BigButton(title: "Continue", isDisabled: .false, isLoading: .true)
                    BigButton(title: "Continue", isDisabled: .true, isLoading: .true)
                }

                Divider()
                
//                Group {
//                    BigButton(
//                        title: "Quick Draw",
//                        labelColor: .white,
//                        gradient: kGameplayPack.style.linearGradient,
//                        isDisabled: .false,
//                        isLoading: .false,
//                        onTap: {})
//                    BigButton(
//                        title: "Quick Draw",
//                        labelColor: .white,
//                        gradient: kDrinkingPack.style.linearGradient,
//                        isDisabled: .false,
//                        isLoading: .false,
//                        onTap: {})
//                    Divider()
//                }
                
                Group {
                    BigButton(
                        title: "Continue",
                        subtitle: "Thru 3 with Kyle, Andrew, Jake, and Santiago",
                        labelColor: .black,
                        subtitleColor: .black,
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
            .padding(16)
        }
    }
}

