//
//  KeyboardFloatingButton.swift
//  Hackers
//
//  Created by Kyle Beard on 4/2/23.
//

import SwiftUI

struct KeyboardFloatingButton: View {
    @Environment(\.colorScheme) var colorScheme
    var systemIcon: String?
    var awesomeIcon: Awesome?
    var awesomeIconRaw: String?
    var awesomeStyle: AwesomeFont = .regular
    var text: String?
    var tint: Color = .systemBlack
    var background: Color = .systemCard
    var rotation: Double = 0.0
    var haptics: Bool = true
    var onTap: (() -> Void)?
    
    var body: some View {
        Button(action: triggerOnTap) {
            content
        }
        .background(backgroundBlur)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 0)
        .alignBottom()
    }
    
    private var content: some View {
        VStack {
            if text == nil {
                // Show only an icon which is guaranteed to be a circle
                button
                    .frame(width: 40, height: 40)
            } else {
                // Show icon and text with same height but pill shape
                button
                    .padding(.horizontal, 12)
                    .frame(minWidth: 40)
                    .frame(height: 40)
            }
        }
    }
    
    private var backgroundBlur: some View {
        ZStack {
            Blur(style: colorScheme.isLight ? .light : .dark)
            background.opacity(0.925)
        }
    }
    
    private var button: some View {
        HStack(spacing: 6) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                    .rotationEffect(Angle(degrees: rotation))
            }
            
            if let awesomeIcon {
                AwesomeImage(
                    icon: awesomeIcon,
                    style: awesomeStyle,
                    size: 15,
                    color: tint
                )
                .rotationEffect(Angle(degrees: rotation))
            }
            
            if let awesomeIconRaw {
                AwesomeImage(
                    rawIcon: awesomeIconRaw.unicode,
                    style: awesomeStyle,
                    size: 15,
                    color: tint
                )
                .rotationEffect(Angle(degrees: rotation))
            }
            
            if let text {
                Text(text)
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

extension KeyboardFloatingButton {
    func triggerOnTap() {
        if let action = onTap {
            if haptics { Haptics.fire(.light) }
            action()
        }
    }
    
    func onTap(_ action: @escaping () -> Void) -> Self {
        var c = self
        c.onTap = action
        return c
    }
}

struct KeyboardFloatingButton_Previews: PreviewProvider {
    static var view: some View {
        HStack(spacing: 16) {
            KeyboardFloatingButton(systemIcon: "textformat", text: "Title")
            KeyboardFloatingButton(systemIcon: "chevron.up", tint: .systemBlue)
            KeyboardFloatingButton(systemIcon: "chevron.down", tint: .systemBlue)
        }
        .padding(16)
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
