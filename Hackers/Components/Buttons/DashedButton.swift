//
//  DashedButton.swift
//  Hackers
//
//  Created by Kyle Beard on 6/27/23.
//

import SwiftUI

struct DashedButton: View, OnSelectable {
    var title: String
    var appleIcon: String?
    var awesomeIcon: Awesome?
    var labelColor: Color = .systemHackersGreen
    var buttonColor: Color = .systemHackersGreen
    
    var lineWidth: CGFloat = 3
    var height: CGFloat = 56
    var fontSize: CGFloat = 20
    var radius: CGFloat = 12
    
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0,
            dash: [4, 10],
            dashPhase: 0
        )
    }
    
    var body: some View {
        Button(action: buttonTapped) { button }
            .frame(height: height)
            .foregroundColor(isDisabled ? Color.systemGray2 : labelColor)
            .background(Color.systemClear)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(style: strokeStyle)
                    .foregroundColor(isDisabled ? Color.systemGray2 : labelColor)
            )
            .cornerRadius(radius)
            .disabled(isDisabled)
    }
    
    private var button: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
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
                    .foregroundColor(isDisabled ? Color.systemGray : labelColor)
                if isLoading && !isDisabled {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: labelColor))
                }
                Spacer(minLength: 0)
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

struct DashedButton_Previews: PreviewProvider {
    static var view: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                DashedButton(
                    title: "Handicap",
                    appleIcon: "plus.circle",
                    isDisabled: .false,
                    isLoading: .false
                )
                DashedButton(
                    title: "Teams",
                    appleIcon: "plus.circle",
                    isDisabled: .false,
                    isLoading: .false
                )
            }
            
            HStack(spacing: 20) {
                DashedButton(
                    title: "Handicap",
                    appleIcon: "square.and.pencil",
                    isDisabled: .false,
                    isLoading: .false
                )
                DashedButton(
                    title: "Teams",
                    appleIcon: "square.and.pencil",
                    isDisabled: .false,
                    isLoading: .false
                )
            }
            
            DashedButton(
                title: "Add a side game",
                appleIcon: "plus.circle",
                labelColor: .systemHackersPurple,
                buttonColor: .systemHackersPurple,
                isDisabled: .false,
                isLoading: .false
            )
            
        }.padding(20)
    }
    static var previews: some View {
        view.holisticPreview()
    }
}
