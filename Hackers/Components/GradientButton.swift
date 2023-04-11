//
//  GradientButton.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/23.
//

import SwiftUI

struct GradientButton: View {
    var title: String
    var subtitle: String?
    var awesomeIcon: String?
    var labelTint: Color
    var backgroundTint: Color
    var primaryTint: Color
    var secondaryTint: Color
    var iconSize: CGFloat = 82
    var fontSize: CGFloat = 28
    var subtitleSize: CGFloat = 15
    var radius: CGFloat = 12
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: OnSelection
    
    private var gradient: LinearGradient {
        LinearGradient(colors: [primaryTint, secondaryTint], startPoint: .top, endPoint: .bottom)
    }
    
    var body: some View {
        Button(action: buttonTapped) {
            button
//                .padding(.horizontal, 16)
//                .padding(.vertical, 16)
                .padding(16)
                .alignCenter()
                .alignMiddle()
        }
        .foregroundColor(Color.white)
        .background(
            ZStack {
//                Rectangle()
//                    .fill(Color.black)
//                    .frame(width: 2)
//                RoundedRectangle(cornerRadius: radius)
//                    .fill(backgroundTint)
                RoundedRectangle(cornerRadius: radius)
                    .fill(gradient.opacity(0.125))
//                RoundedRectangle(cornerRadius: radius)
//                    .stroke(backgroundTint, lineWidth: 0)
                RoundedRectangle(cornerRadius: radius)
                    .stroke(gradient.opacity(0.75), lineWidth: radius)
            }
        )
        .cornerRadius(radius)
        .disabled(isDisabled)
    }
    
    private var button: some View {
        VStack(spacing: 24) {
            if isLoading && !isDisabled {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: labelTint))
            } else if let awesomeIcon {
                AwesomeImage(
                    rawIcon: awesomeIcon.unicode,
                    style: .light,
                    size: iconSize,
                    color: primaryTint,
                    secondaryColor: secondaryTint
                )
                .opacity(0.75)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.dmSans(size: fontSize, weight: .bold))
                    .foregroundColor(isDisabled ? Color.systemGray : labelTint)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.dmSans(size: subtitleSize, weight: .medium))
                        .foregroundColor(Color.systemGrayDark)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private func buttonTapped() {
        if let action = onTap {
            Haptics.fire(.light)
            action()
        }
    }
}

struct GradientButton_Previews: PreviewProvider {
    static var view: some View {
        GradientButton(
            title: "Reveal cards",
            awesomeIcon: "e4df",
            labelTint: .systemBlack,
            backgroundTint: .systemCard,
            primaryTint: .systemPurple,
            secondaryTint: .systemPink,
            isDisabled: .false,
            isLoading: .false,
            onTap: {}
        )
        .padding(32)
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
